#pragma semicolon 1
#include <sourcemod>

#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required

#include <tf_custom_attributes>
#include <tf_ontakedamage>
#include <stocksoup/var_strings>

public Action TF2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage,
		int &damagetype, int &weapon, float damageForce[3], float damagePosition[3],
		int damagecustom, CritType &critType) {
	if (!IsValidEntity(weapon)) {
		return Plugin_Continue;
	}
	
	// we use a bitwise or here because we don't want to short-circuit the check
	// attacker condition crit mod might be higher than the target's
	if (ApplyTargetConditionCritMod(victim, weapon, critType)
			| ApplyAttackerConditionCritMod(attacker, weapon, critType)) {
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

bool ApplyTargetConditionCritMod(int victim, int weapon, CritType &critType) {
	char attr[64];
	if (!TF2CustAttr_GetString(weapon, "mod crit type on target condition",
			attr, sizeof(attr))) {
		return false;
	}
	
	TFCond cond = view_as<TFCond>(ReadIntVar(attr, "condition"));
	if (!TF2_IsPlayerInCondition(victim, cond)) {
		return false;
	}
	
	CritType newCritType = view_as<CritType>(ReadIntVar(attr, "crit_type"));
	if (newCritType > critType) {
		critType = newCritType;
		return true;
	}
	return false;
}

bool ApplyAttackerConditionCritMod(int attacker, int weapon, CritType &critType) {
	if (attacker < 1 || attacker > MaxClients) {
		return false;
	}
	
	char attr[64];
	if (!TF2CustAttr_GetString(weapon, "mod crit type on attacker condition",
			attr, sizeof(attr))) {
		return false;
	}
	
	TFCond cond = view_as<TFCond>(ReadIntVar(attr, "condition"));
	if (!TF2_IsPlayerInCondition(attacker, cond)) {
		return false;
	}
	
	CritType newCritType = view_as<CritType>(ReadIntVar(attr, "crit_type"));
	if (newCritType > critType) {
		critType = newCritType;
		return true;
	}
	return false;
}
