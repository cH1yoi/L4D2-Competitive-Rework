#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <builtinvotes>
#include <l4d2util_constants>
#include <l4d2util_weapons>
#undef REQUIRE_PLUGIN
#include <c4s2_ghost>

bool g_bSpecEnable[MAXPLAYERS + 1];
bool g_bAllowShow;
bool g_bPluginEnable;

public Plugin myinfo =
{
	name		= "C4S2 Ghost - SpecHud",
	author		= "Nepkey",
	description = "幽灵模式附加插件 -旁观者面板",
	version		= "1.0 - 2024.10.8",
	url			= "https://space.bilibili.com/436650372"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_spechud", SpecHud_CMD);
	CreateTimer(0.5, DrawPlayersToPanel, _, TIMER_REPEAT);
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

public void OnClientPutInServer(int client)
{
	g_bSpecEnable[client] = false;
}

public void C4S2Ghost_OnRoundStart_Post(bool start)
{
	if (start)
	{
		g_bAllowShow = true;
	}
}

public void C4S2_OnGameover()
{
	g_bAllowShow = false;
}

Action SpecHud_CMD(int client, int args)
{
	g_bSpecEnable[client] = !g_bSpecEnable[client];
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "[SpecHud]旁观面板已%s。", g_bSpecEnable[client] ? "启用" : "禁用");
	}
}

Action DrawPlayersToPanel(Handle timer)
{
	if (!g_bPluginEnable || !g_bAllowShow) return Plugin_Continue;
	Panel hPanel = CreatePanel();
	FillHeadInfo(hPanel);
	FillSoldiersInfo(hPanel);
	FillGhostsInfo(hPanel);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 1 || IsFakeClient(i) || !g_bSpecEnable[i])
		{
			continue;
		}
		if (BuiltinVote_IsVoteInProgress() && IsClientInBuiltinVotePool(i))
		{
			continue;
		}

		if (Game_IsVoteInProgress())
		{
			int voteteam = Game_GetVoteTeam();
			if (voteteam == -1 || voteteam == GetClientTeam(i))
			{
				continue;
			}
		}

		switch (GetClientMenu(i))
		{
			case MenuSource_External, MenuSource_Normal: continue;
		}
		hPanel.Send(i, PlayersHudHandler, 1);
	}
	delete hPanel;
	return Plugin_Continue;
}

//----------------------------------
//              HUD方法
//----------------------------------

void FillHeadInfo(Handle hud)
{
	DrawPanelText(hud, "!spechud可打开或关闭此面板");
}

void FillSoldiersInfo(Handle hud)
{
	char info[250];
	DrawPanelText(hud, "生还队伍:");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientInSoldier(i)) continue;
		char name[64];
		GetClientOriginalName(i, name, 32);
		char hp[32];
		if (IsPlayerAlive(i))
		{
			Format(hp, 32, "%d HP", GetClientHealth(i));	//  string.inc
		}
		else
		{
			Format(hp, 32, "死亡");	   //  string.inc
		}
		char weaponinfo[64];
		if (IsPlayerAlive(i))
		{
			char weaponshortname[64];
			char weaponclassname[64];
			int	 weapon = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
			GetEntityClassname(weapon, weaponclassname, 64);
			GetWeaponData(weaponclassname, 5, weaponshortname, 64);
			int primaryWep	 = GetPlayerWeaponSlot(i, L4D2WeaponSlot_Primary);
			int activeWepId	 = IdentifyWeapon(weapon);
			int primaryWepId = IdentifyWeapon(primaryWep);
			if (activeWepId == WEPID_PISTOL)
			{
				Format(weaponinfo, sizeof(weaponinfo), "%s %d/无限", weaponshortname, GetWeaponClipAmmo(weapon));
			}
			else
			{
				Format(weaponinfo, sizeof(weaponinfo), "%s %d/%d", weaponshortname, GetWeaponClipAmmo(weapon), GetWeaponExtraAmmo(i, primaryWepId));
			}
		}
		Format(info, sizeof(info), "%s | %s | %s", hp, name, weaponinfo);
		DrawPanelText(hud, info);
	}
}

void FillGhostsInfo(Handle hud)
{
	char info[128];
	DrawPanelText(hud, "幽灵队伍:");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientInGhost(i)) continue;
		char name[64];
		GetClientOriginalName(i, name, 32);
		char hp[32];
		if (IsPlayerAlive(i))
		{
			Format(hp, 32, "%d HP", GetClientHealth(i));	//  string.inc
		}
		else
		{
			Format(hp, 32, "死亡");	   //  string.inc
		}
		char moveinfo[64];
		if (IsPlayerAlive(i))
		{
			float movespeed = GetClientSpeed(i);
			if (movespeed == 0.00)
			{
				Format(moveinfo, sizeof(moveinfo), "静止中");
			}
			else if (movespeed <= 90 && (GetEntityFlags(i) & FL_ONGROUND))
			{
				Format(moveinfo, sizeof(moveinfo), "静步中 速度:%d", RoundFloat(movespeed));
			}
			else
			{
				Format(moveinfo, sizeof(moveinfo), "移动中 速度:%d", RoundFloat(movespeed));
			}
		}
		Format(info, sizeof(info), "%s | %s | %s", hp, name, moveinfo);
		DrawPanelText(hud, info);
	}
}

int PlayersHudHandler(Menu hMenu, MenuAction action, int param1, int param2)
{
	return 1;
}

//----------------------------------
//              辅助方法
//----------------------------------

#define ASSAULT_RIFLE_OFFSET_IAMMO	  12;
#define SMG_OFFSET_IAMMO			  20;
#define PUMPSHOTGUN_OFFSET_IAMMO	  28;
#define AUTO_SHOTGUN_OFFSET_IAMMO	  32;
#define HUNTING_RIFLE_OFFSET_IAMMO	  36;
#define MILITARY_SNIPER_OFFSET_IAMMO  40;
#define GRENADE_LAUNCHER_OFFSET_IAMMO 68;

int GetWeaponExtraAmmo(int client, int wepid)
{
	static int ammoOffset;
	if (!ammoOffset) ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");

	int offset;
	switch (wepid)
	{
		case WEPID_RIFLE, WEPID_RIFLE_AK47, WEPID_RIFLE_DESERT, WEPID_RIFLE_SG552:
		{
			offset = ASSAULT_RIFLE_OFFSET_IAMMO
		}
		case WEPID_SMG, WEPID_SMG_SILENCED:
		{
			offset = SMG_OFFSET_IAMMO
		}
		case WEPID_PUMPSHOTGUN, WEPID_SHOTGUN_CHROME:
		{
			offset = PUMPSHOTGUN_OFFSET_IAMMO
		}
		case WEPID_AUTOSHOTGUN, WEPID_SHOTGUN_SPAS:
		{
			offset = AUTO_SHOTGUN_OFFSET_IAMMO
		}
		case WEPID_HUNTING_RIFLE:
		{
			offset = HUNTING_RIFLE_OFFSET_IAMMO
		}
		case WEPID_SNIPER_MILITARY, WEPID_SNIPER_AWP, WEPID_SNIPER_SCOUT:
		{
			offset = MILITARY_SNIPER_OFFSET_IAMMO
		}
		case WEPID_GRENADE_LAUNCHER:
		{
			offset = GRENADE_LAUNCHER_OFFSET_IAMMO
		}
		default:
		{
			return -1;
		}
	}
	return GetEntData(client, ammoOffset + offset);
}

int GetWeaponClipAmmo(int weapon)
{
	return (weapon > 0 ? GetEntProp(weapon, Prop_Send, "m_iClip1") : -1);
}

float GetClientSpeed(int client)
{
	float vecSpeed[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecSpeed);
	return GetVectorLength(vecSpeed);
}