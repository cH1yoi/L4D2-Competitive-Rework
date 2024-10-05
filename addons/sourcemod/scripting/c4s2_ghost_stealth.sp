#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <left4dhooks>
#include <c4s2_ghost>

float	  g_fStealthEndTime;
char	  g_sHeartBeat[] = "player/heartbeatloop.wav";
ArrayList g_hGhostTeam_st;
bool
	g_bPluginEnable,
	g_bHasHeartBeat[MAXPLAYERS + 1],
	g_bTotallyTtealth[MAXPLAYERS + 1],
	g_bSustainShow[MAXPLAYERS + 1];
ConVar
	g_hGhostStealth,
	g_hGhostBuff,
	g_hGhostRun;

public Plugin myinfo =
{
	name		= "C4S2 Ghost - Ghost Stealth",
	author		= "Nepkey",
	description = "幽灵模式附加插件 - 幽灵隐身模块。",
	version		= "1.0 - 2024.9.29",
	url			= "https://space.bilibili.com/436650372"
};

//---------------------------------------------------------------
//							基础设置
//---------------------------------------------------------------
public void OnPluginStart()
{
	g_hGhostTeam_st = new ArrayList();
	g_hGhostStealth = CreateConVar("c4s2_stealth_time", "300.0");
	g_hGhostBuff	= CreateConVar("c4s2_ghost_vampirism", "1");
	g_hGhostRun		= CreateConVar("c4s2_ghost_run_stealth", "1");
	HookEvent("weapon_fire", Weapon_Fire_Event, EventHookMode_Pre);
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
//							全局转发
//---------------------------------------------------------------
public void C4S2Ghost_OnRoundStart_Post(bool gamestart)
{
	if (!g_bPluginEnable) return;
	if (gamestart)
	{
		g_fStealthEndTime = GetGameTime() + float(g_hGhostStealth.IntValue);
	}
}

public Action L4D_OnLedgeGrabbed(int client)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	return Plugin_Handled;
}

public void OnPlayerKilled_Post(int victim, int attaker)
{
	if (!g_bPluginEnable) return;
	if (IsClientInGhost(attaker))
	{
		SetGhostBuff(attaker);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, PostThinkPost_CallBack);
}

public void OnPlayerSpawn_Post(int client, bool gamestart)
{
	if (!g_bPluginEnable || !IsValidClientIndex(client) || !IsClientInGame(client))
	{
		return;
	}
	if (gamestart)
	{
		g_bHasHeartBeat[client]	  = false;
		g_bTotallyTtealth[client] = false;
		g_bSustainShow[client]	  = false;
		if (IsClientInGhost(client))
		{
			L4D2_UseAdrenaline(client, g_fStealthEndTime - GetGameTime(), false, false);
			CreateTimer(2.0, Delay_fix, client, TIMER_FLAG_NO_MAPCHANGE);
			CreatePropGlow(client);
			g_hGhostTeam_st.Push(client);
		}
	}
}

public void C4S2Ghost_OnRoundEnd_Post()
{
	if (!g_bPluginEnable) return;
	for (int i = 0; i < g_hGhostTeam_st.Length; i++)
	{
		int client = g_hGhostTeam_st.Get(i);
		if (!IsValidClientIndex(client) || !IsClientInGame(client))
		{
			continue;
		}
		char oname[128];
		GetClientOriginalName(client, oname, sizeof(oname));
		if (strlen(oname) > 0)
		{
			SetClientInfo(client, "name", oname);
		}
	}
	g_hGhostTeam_st.Clear();
}

//---------------------------------------------------------------
//							回调函数
//---------------------------------------------------------------

void Weapon_Fire_Event(Event event, const char[] name, bool b)
{
	if (!g_bPluginEnable) return;
	char classname[128];
	int	 client = GetClientOfUserId(event.GetInt("userid"));
	event.GetString("weapon", classname, sizeof(classname));
	if (IsClientInGhost(client) && StrContains(classname, "melee") > -1)
	{
		SetGhostDebuff(client);
	}
}

void PostThinkPost_CallBack(int client)
{
	if (!g_bPluginEnable) return;
	SetGhostHeartBeat(client);
	SetGhostStealth(client);
	SetSurvivorCalm(client);
}

Action OnTransmit(int iEntity, int iClient)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	if (!IsValidEdict(iEntity))
	{
		SDKUnhook(iEntity, SDKHook_SetTransmit, OnTransmit);
		return Plugin_Handled;
	}
	int iParent = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if (!IsPlayerAlive(iParent))
	{
		SDKUnhook(iEntity, SDKHook_SetTransmit, OnTransmit);
		AcceptEntityInput(iEntity, "Kill");
		return Plugin_Handled;
	}
	if (IsClientInSoldier(iClient) || iParent == iClient)
	{
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

//---------------------------------------------------------------
//							计时回调
//---------------------------------------------------------------

Action Timer_RemoveTtealth(Handle Timer, int client)
{
	g_bTotallyTtealth[client] = false;
}

Action Timer_RemoveShow(Handle Timer, int client)
{
	g_bSustainShow[client] = false;
}

Action Delay_fix(Handle timer, int client)
{
	int index = g_hGhostTeam_st.FindValue(client);
	if (!IsClientInGame(client))
	{
		return Plugin_Stop;
	}
	char emptychar[64];
	if (index > -1)
	{
		for (int j = 0; j <= index; j++)
		{
			StrCat(emptychar, sizeof(emptychar), " ");
		}
		SetClientInfo(client, "name", emptychar);
	}
	return Plugin_Stop;
}

//---------------------------------------------------------------
//							辅助方法
//---------------------------------------------------------------

void SetGhostBuff(int attacker)
{
	if (g_hGhostBuff.BoolValue)
	{
		int newhealth = GetClientHealth(attacker) + 50 >= 100 ? 100 : GetClientHealth(attacker) + 50;
		SetEntityHealth(attacker, newhealth);
	}
	g_bTotallyTtealth[attacker] = true;
	CreateTimer(3.0, Timer_RemoveTtealth, attacker, TIMER_FLAG_NO_MAPCHANGE);
}

void SetGhostDebuff(int attacker)
{
	g_bSustainShow[attacker] = true;
	CreateTimer(0.75, Timer_RemoveShow, attacker, TIMER_FLAG_NO_MAPCHANGE);
}

void CreatePropGlow(int iTarget)
{
	int iEntity = CreateEntityByName("prop_dynamic_override");
	if (iEntity == -1)
	{
		return;
	}

	float vOrigin[3];
	float vAngles[3] = { 90.0, 0.0, 0.0 };
	GetClientAbsOrigin(iTarget, vOrigin);
	vOrigin[2] += 7.5;
	TeleportEntity(iEntity, vOrigin, vAngles, NULL_VECTOR);
	char sModelName[PLATFORM_MAX_PATH];
	Format(sModelName, sizeof(sModelName), "models/props_collectables/coin.mdl");
	PrecacheModel(sModelName, true);
	SetEntityModel(iEntity, sModelName);
	DispatchKeyValue(iEntity, "targetname", "GlowEnt");
	DispatchSpawn(iEntity);

	SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(iEntity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRange", 5000);
	SetEntProp(iEntity, Prop_Send, "m_nGlowRangeMin", 0);
	SetEntProp(iEntity, Prop_Send, "m_iGlowType", 2);
	SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", 65280);
	SetEntPropFloat(iEntity, Prop_Send, "m_flModelScale", 1.5);
	AcceptEntityInput(iEntity, "StartGlowing");
	SetEntityRenderMode(iEntity, RENDER_NONE);
	SetEntityRenderColor(iEntity, 0, 0, 0, 0);

	SetVariantString("!activator");
	AcceptEntityInput(iEntity, "SetParent", iTarget);
	SetVariantString("eyes");
	AcceptEntityInput(iEntity, "SetParentAttachmentMaintainOffset");

	SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", iTarget);
	SDKHook(iEntity, SDKHook_SetTransmit, OnTransmit);
}

void SetGhostHeartBeat(int client)
{
	if (!g_hGhostRun.BoolValue) return;
	if (!IsClientInGame(client)) return;
	if (IsClientInSoldier(client)) return;
	if (IsClientInGhost(client))
	{
		float pos[3];
		GetClientAbsOrigin(client, pos);
		float vecSpeed[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecSpeed);
		float speed = GetVectorLength(vecSpeed);
		//重复三次停止播放，很蠢，但很有效果
		if ((!IsPlayerAlive(client)) && g_bHasHeartBeat[client])
		{
			g_bHasHeartBeat[client] = false;
			EmitAmbientSound(g_sHeartBeat, pos, client, SNDLEVEL_NORMAL, SND_STOPLOOPING, 0.0);
			EmitAmbientSound(g_sHeartBeat, pos, client, SNDLEVEL_NORMAL, SND_STOPLOOPING, 0.0);
			EmitAmbientSound(g_sHeartBeat, pos, client, SNDLEVEL_NORMAL, SND_STOPLOOPING, 0.0);
		}
		else if (speed < 110 && g_bHasHeartBeat[client] && (GetEntityFlags(client) & FL_ONGROUND))
		{
			g_bHasHeartBeat[client] = false;
			EmitAmbientSound(g_sHeartBeat, pos, client, SNDLEVEL_NORMAL, SND_STOPLOOPING, 0.0);
			EmitAmbientSound(g_sHeartBeat, pos, client, SNDLEVEL_NORMAL, SND_STOPLOOPING, 0.0);
			EmitAmbientSound(g_sHeartBeat, pos, client, SNDLEVEL_NORMAL, SND_STOPLOOPING, 0.0);
		}
		else if (speed > 220 && !g_bHasHeartBeat[client] && IsPlayerAlive(client) && (GetEntityFlags(client) & FL_ONGROUND))
		{
			g_bHasHeartBeat[client] = true;
			EmitAmbientSound(g_sHeartBeat, pos, client, .vol = 1.0);
		}
	}
}

void SetGhostStealth(int client)
{
	if (!IsClientInGame(client)) return;
	if (IsClientInSoldier(client)) return;
	if (IsClientInGhost(client) && IsPlayerAlive(client))
	{
		SetEntityRenderMode(client, RENDER_TRANSALPHA);
		if (g_fStealthEndTime > GetGameTime())
		{
			int percent;
			if (g_bTotallyTtealth[client])
			{
				percent = 0;
			}
			else if (g_bSustainShow[client])
			{
				percent = 255;
			}
			else
			{
				percent = AlphaPersent(client);
			}
			SetGhostThirdStealth(client, percent);
			UpdateViewEffect(client, percent);
		}
		else
		{
			SetGhostThirdStealth(client, 255);
			UpdateViewEffect(client, 255);
		}
	}
}

//额外内容。使生还者始终处于冷静状态，便于听脚步。
void SetSurvivorCalm(int client)
{
	if (!IsClientInGame(client)) return;
	if (IsClientInGhost(client)) return;
	if (IsClientInSoldier(client) && IsPlayerAlive(client))
	{
		SetEntProp(client, Prop_Send, "m_isCalm", 1);
	}
}

int AlphaPersent(int client)
{
	float vecSpeed[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vecSpeed);
	float speed = GetVectorLength(vecSpeed);
	if (speed <= 110 || (g_hGhostRun.BoolValue && speed >= 220))
	{
		return 0;
	}
	else
	{
		return RoundFloat((speed / 260) * 255);
	}
}

void UpdateViewEffect(int client, int alpha)
{
	if (g_bSustainShow[client])
	{
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
	}
	else if (GetEntityFlags(client) & FL_ONGROUND)
	{
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", alpha > 1 ? 1 : 0);
	}
}

void SetGhostThirdStealth(int client, int alpha)
{
	if (g_bSustainShow[client])
	{
		SetEntityRenderColor(client, 255, 0, 0, 255);
	}
	else if (GetEntityFlags(client) & FL_ONGROUND)
	{
		SetEntityRenderColor(client, 255, 0, 0, alpha);
	}
	SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
	int weapon = GetPlayerWeaponSlot(client, 1);
	if (IsValidEntity(weapon))
	{
		int flags = GetEntProp(weapon, Prop_Send, "m_fEffects");
		SetEntProp(weapon, Prop_Send, "m_fEffects", flags | 32);
	}
}