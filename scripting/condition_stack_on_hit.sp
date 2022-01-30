#pragma semicolon 1
#include <sourcemod>

#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required

#include <tf2utils>
#include <tf_custom_attributes>
#include <stocksoup/value_remap>
#include <stocksoup/var_strings>

public void OnMapStart() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage,
		int damagetype, int weapon, const float damageForce[3], const float damagePosition[3]) {
	char attr[256];
	if (!IsValidEntity(weapon)
			|| !TF2CustAttr_GetString(weapon, "condition stack on hit", attr, sizeof(attr))) {
		return;
	}
	
	TFCond condition;
	if (!ReadTFCondVar(attr, "condition", condition)) {
		return;
	}
	
	float falloffRange[2], falloffDuration[2];
	
	falloffRange[0] = ReadFloatVar(attr, "falloff_range_min", 32.0);
	falloffRange[1] = ReadFloatVar(attr, "falloff_range_max", falloffRange[0]);
	
	falloffDuration[0] = ReadFloatVar(attr, "duration_at_min");
	falloffDuration[1] = ReadFloatVar(attr, "duration_at_max", 0.0);
	
	float flMaxDuration = ReadFloatVar(attr, "max_duration", 10.0);
	bool additive = !!ReadIntVar(attr, "additive");
	
	if (!condition) {
		return;
	}
	
	float flDistance = GetDistanceBetweenClients(attacker, victim);
	float flDuration = RemapValueFloat(falloffRange, falloffDuration, flDistance, true);
	if (!TF2_IsPlayerInCondition(victim, condition) || !additive) {
		TF2_AddCondition(victim, condition, flDuration, attacker);
	} else {
		float flNewDuration = TF2Util_GetPlayerConditionDuration(victim, condition);
		
		// don't reduce an existing duration that exceeds the max
		if (flNewDuration <= flMaxDuration) {
			flNewDuration += flDuration;
			
			if (flNewDuration > flMaxDuration) {
				flNewDuration = flMaxDuration;
			}
			
			TF2Util_SetPlayerConditionDuration(victim, condition, flNewDuration);
		}
		
	}
}

float GetDistanceBetweenClients(int client, int otherClient, bool ignoreHeight = false) {
	float vecClientOrigin[3], vecOtherClientOrigin[3];
	GetClientAbsOrigin(client, vecClientOrigin);
	GetClientAbsOrigin(otherClient, vecOtherClientOrigin);
	
	if (ignoreHeight) {
		vecClientOrigin[2] = 0.0;
		vecOtherClientOrigin[2] = 0.0;
	}
	
	return GetVectorDistance(vecClientOrigin, vecOtherClientOrigin);
}

bool ReadTFCondVar(const char[] varstring, const char[] key, TFCond &value) {
	char condString[32];
	if (!ReadStringVar(varstring, key, condString, sizeof(condString))) {
		return false;
	}
	
	int result;
	if (StringToIntEx(condString, result)) {
		value = view_as<TFCond>(result);
		return true;
	}
	
	static StringMap s_Conditions;
	if (!s_Conditions) {
		char buffer[64];
		
		s_Conditions = new StringMap();
		for (TFCond cond; cond <= TF2Util_GetLastCondition(); cond++) {
			if (TF2Util_GetConditionName(cond, buffer, sizeof(buffer))) {
				s_Conditions.SetValue(buffer, cond);
			}
		}
	}
	
	if (s_Conditions.GetValue(condString, value)) {
		return true;
	}
	
	// log message if given string does not resolve to a condition
	static StringMap s_LoggedConditions;
	if (!s_LoggedConditions) {
		s_LoggedConditions = new StringMap();
	}
	any ignored;
	if (!s_LoggedConditions.GetValue(condString, ignored)) {
		LogError("Could not translate condition name %s to index.", condString);
		s_LoggedConditions.SetValue(condString, true);
	}
	return false;
}
