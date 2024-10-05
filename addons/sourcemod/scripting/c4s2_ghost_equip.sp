#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <left4dhooks>
#include <c4s2_ghost>

#define GAMEDATA_FILE	  "c4s2_ghost"
#define GAMEDATA_USE_AMMO "CWeaponAmmoSpawn_Use"

Handle hSDKGiveDefaultAmmo;
bool   g_bPluginEnable;
ConVar
	g_hAttackSpeed,
	g_hRandommelee;
	
public Plugin myinfo =
{
	name		= "C4S2 Ghost - Equips",
	author		= "Nepkey",
	description = "幽灵模式附加插件 - 玩家装备",
	version		= "1.0 - 2024.9.29",
	url			= "https://space.bilibili.com/436650372"
};

//---------------------------------------------------------------
//							基础设置
//---------------------------------------------------------------
public void OnPluginStart()
{
	InitSDKCall();
	g_hAttackSpeed = CreateConVar("c4s2_ghost_attackspeed", "1.6");
	g_hRandommelee = CreateConVar("c4s2_ghost_random_melee", "0");
}

public void OnAllPluginsLoaded()
{
	g_bPluginEnable = LibraryExists("c4s2_ghost");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "c4s2_ghost")) g_bPluginEnable = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "c4s2_ghost")) g_bPluginEnable = false;
}

//---------------------------------------------------------------
//						 全局转发
//---------------------------------------------------------------
public void OnPlayerSpawn_Post(int client, bool gamestart)
{
	if (!g_bPluginEnable || !IsValidClientIndex(client) || !IsClientInGame(client))
	{
		return;
	}
	if (gamestart)
	{
		if (IsClientInGhost(client))
		{
			CreateMelee(client);
			SetEntProp(client, Prop_Send, "m_ArmorValue", 100);
		}
		if (IsClientInSoldier(client))
		{
			GiveClientRandomWeapon(client);
			SDKCall(hSDKGiveDefaultAmmo, 0, client);
		}
		int weapon1 = GetPlayerWeaponSlot(client, 3);
		int weapon2 = GetPlayerWeaponSlot(client, 4);
		if (weapon1 > -1)
		{
			AcceptEntityInput(weapon1, "Kill");
		}
		if (weapon2 > -1)
		{
			AcceptEntityInput(weapon2, "Kill");
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, PostThinkPost_CallBack);
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse_CallBack);
	SDKHook(client, SDKHook_WeaponCanSwitchTo, WeaponCanSwitchTo_CallBack);
}

//---------------------------------------------------------------
//							回调函数
//---------------------------------------------------------------

void PostThinkPost_CallBack(int client)
{
	if (!g_bPluginEnable) return;
	SetFlashlightState(client, false);
	if (IsClientInGhost(client) && IsPlayerAlive(client))
	{
		int buttons = GetClientButtons(client);
		if (buttons & IN_ATTACK)
		{
			AdjustWeaponSpeed(client, g_hAttackSpeed.FloatValue, 1);
		}
	}
}

Action WeaponCanUse_CallBack(int client, int weapon)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	char sname[64];
	GetEntityClassname(weapon, sname, sizeof(sname));
	if (IsClientInGhost(client))
	{
		if (StrContains(sname, "melee") > -1)
		{
			return Plugin_Continue;
		}
		else
		{
			return Plugin_Handled;
		}
	}
	if (StrContains(sname, "first_aid_kit") > -1 || StrContains(sname, "defibrillator") > -1 || StrContains(sname, "pain_pills") > -1 || StrContains(sname, "adrenaline") > -1)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action WeaponCanSwitchTo_CallBack(int client, int weapon)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	int weapon1 = GetPlayerWeaponSlot(client, 3);
	int weapon2 = GetPlayerWeaponSlot(client, 4);
	if (weapon1 == weapon || weapon2 == weapon)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

//---------------------------------------------------------------
//							辅助方法
//---------------------------------------------------------------

//来自Mr. Zero - https://forums.alliedmods.net/showthread.php?p=1234248
void SetFlashlightState(int client, bool on)
{
	int g_iFlashlight_Offset = FindSendPropInfo("CTerrorPlayer", "m_fEffects");
	SetEntData(client, g_iFlashlight_Offset, (on ? 4 : 0));
}

//来自Machine - http://forums.alliedmods.net/showthread.php?p=1369117
void AdjustWeaponSpeed(int client, float Amount, int slot)
{
	if (GetPlayerWeaponSlot(client, slot) > 0)
	{
		float m_flNextPrimaryAttack	  = GetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flNextPrimaryAttack");
		float m_flNextSecondaryAttack = GetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flNextSecondaryAttack");
		float m_flCycle				  = GetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flCycle");
		int	  m_bInReload			  = GetEntProp(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_bInReload");
		// Getting the animation cycle at zero seems to be key here, however the scar and pistols weren't seem to be getting affected
		if (m_flCycle == 0.000000 && m_bInReload < 1)
		{
			SetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flPlaybackRate", Amount);
			SetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flNextPrimaryAttack", m_flNextPrimaryAttack - ((Amount - 1.0) / 2));
			SetEntPropFloat(GetPlayerWeaponSlot(client, slot), Prop_Send, "m_flNextSecondaryAttack", m_flNextSecondaryAttack - ((Amount - 1.0) / 2));
		}
	}
}

void InitSDKCall()
{
	/* Preparing SDK Call */
	Handle hConf = LoadGameConfigFile(GAMEDATA_FILE);

	if (hConf == null)
	{
		SetFailState("Gamedata missing: %s", GAMEDATA_FILE);
	}

	StartPrepSDKCall(SDKCall_Entity);

	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, GAMEDATA_USE_AMMO))
	{
		SetFailState("Gamedata missing signature: %s", GAMEDATA_USE_AMMO);
	}

	// Client that used the ammo spawn
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	hSDKGiveDefaultAmmo = EndPrepSDKCall();

	if (hSDKGiveDefaultAmmo == null)
	{
		SetFailState("Failed to finish SDKCall setup: %s", GAMEDATA_USE_AMMO);
	}

	delete hConf;
}

void CreateMelee(int client)
{
	int weapon = CreateEntityByName("weapon_melee_spawn");
	if (weapon)
	{
		float pos[3];
		char  sweapon[32];
		Format(sweapon, sizeof(sweapon), "%s", g_hRandommelee.BoolValue ? "Any" : "knife");
		DispatchKeyValue(weapon, "melee_weapon", sweapon);
		DispatchKeyValue(weapon, "count", "1");
		DispatchKeyValue(weapon, "weaponskin", "-1");
		DispatchKeyValue(weapon, "glowrange", "0");
		DispatchKeyValue(weapon, "spawnflags", "2");
		DispatchSpawn(weapon);
		GetClientAbsOrigin(client, pos);
		TeleportEntity(weapon, pos);
		SetVariantString("!activator");
		AcceptEntityInput(weapon, "use", client);
	}
}