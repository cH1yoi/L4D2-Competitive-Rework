#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <left4dhooks>
#include <c4s2_ghost>

float  g_fUnfreezeTime[MAXPLAYERS + 1];
bool   g_bPluginEnable, g_bGameStart;
ConVar g_hItemsEnable;

public Plugin myinfo =
{
	name		= "C4S2 Ghost - Grenades",
	author		= "Nepkey",
	description = "幽灵模式附加插件 - 生还者特殊投掷",
	version		= "1.0 - 2024.10.8",
	url			= "https://space.bilibili.com/436650372"
};

//---------------------------------------------------------------
//							基础设置
//---------------------------------------------------------------
public void C4S2Ghost_OnRoundStart_Post(bool gamestart)
{
	g_bGameStart = gamestart;
}

public void C4S2_OnGameover()
{
	g_bGameStart = false;
}

public void OnAllPluginsLoaded()
{
	g_bPluginEnable = LibraryExists("c4s2_ghost");
	g_hItemsEnable	= FindConVar("c4s2_ghost_special_items");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "c4s2_ghost")) g_bPluginEnable = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "c4s2_ghost")) g_bPluginEnable = false;
}

public void OnEntityCreated(int entity)
{
	if (!g_bPluginEnable || !g_bGameStart || !g_hItemsEnable.BoolValue) return;
	char sname[64];
	GetEntityClassname(entity, sname, sizeof(sname));
	if (StrEqual(sname, "pipe_bomb_projectile"))
	{
		//需要加一帧才能识别投掷者
		RequestFrame(OnPipeBombCreated_NextFrame, entity);
	}
}

void OnPipeBombCreated_NextFrame(int entity)
{
	int thrower = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
	CreteLandmine(thrower);
	PrecacheSound("player/orch_hit_csharp_short.wav");
	EmitSoundToClient(thrower, "player/orch_hit_csharp_short.wav", .volume = 0.5);
	PrecacheSound("player/laser_on.wav");
	EmitSoundToClient(thrower, "player/laser_on.wav");
	AcceptEntityInput(entity, "Kill");
}

public void OnEntityDestroyed(int entity)
{
	if (!g_bPluginEnable || !g_bGameStart || !g_hItemsEnable.BoolValue) return;
	char sname[64];
	GetEntityClassname(entity, sname, sizeof(sname));
	if (StrEqual(sname, "vomitjar_projectile"))
	{
		float pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);
		CreateSmoke(pos);
		//只有存活的幽灵会受到减速弹影响
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsClientInGhost(i) && IsPlayerAlive(i) && GetEntityDistance(i, entity) <= 500.0)
			{
				g_fUnfreezeTime[i] = GetGameTime() + 5.0;
				PrefetchSound("physics/glass/glass_impact_bullet4.wav");
				EmitSoundToClient(i, "physics/glass/glass_impact_bullet4.wav", .volume = 0.5);
			}
		}
	}
}

// 地雷相关
void CreteLandmine(int client)
{
	float vOrigin[3];
	float vAngles[3];
	GetClientAbsAngles(client, vAngles);
	GetClientAbsOrigin(client, vOrigin);
	vAngles[0]	= 90.0;
	int iEntity = CreateEntityByName("prop_dynamic_override");
	if (iEntity == -1)
	{
		return;
	}
	TeleportEntity(iEntity, vOrigin, vAngles, NULL_VECTOR);
	char sModelName[PLATFORM_MAX_PATH];
	Format(sModelName, sizeof(sModelName), "models/props_doors/shackwall01.mdl");
	PrecacheModel(sModelName, true);
	SetEntityModel(iEntity, sModelName);
	DispatchKeyValue(iEntity, "disableshadows", "1");
	SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);

	SetEntProp(iEntity, Prop_Data, "m_nSolidType", 6);
	DispatchSpawn(iEntity);

	SDKHook(iEntity, SDKHook_SetTransmit, OnMineTransmit);
	SDKHook(iEntity, SDKHook_Touch, OnMineTouch);
}

Action OnMineTransmit(int iEntity, int client)
{
	if (IsClientInGhost(client))
	{
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

Action OnMineTouch(int entity, int other)
{
	if (!IsValidClientIndex(other) || IsClientInSoldier(other))
	{
		return Plugin_Continue;
	}
	int iParent = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	//向地雷的主人发出声音, 提醒有幽灵踩中地雷。
	PrecacheSound("weapons/hegrenade/beep.wav");
	EmitSoundToClient(iParent, "weapons/hegrenade/beep.wav");
	//致盲幽灵, 提醒其踩中了探测地雷。
	DataPack dpin = new DataPack();
	dpin.WriteCell(other);
	dpin.WriteCell(1);
	dpin.WriteCell(1.0);
	DataPack dpout = new DataPack();
	dpout.WriteCell(other);
	dpout.WriteCell(0);
	dpout.WriteCell(1.0);
	CreateTimer(0.01, FlashBomb, dpin, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, FlashBomb, dpout, TIMER_FLAG_NO_MAPCHANGE);
	AcceptEntityInput(entity, "Kill");
	return Plugin_Continue;
}

Action FlashBomb(Handle timer, DataPack dp)
{
	dp.Reset();
	UserMsg g_FadeUserMsgId;
	int		clients[2];
	clients[0]	   = dp.ReadCell();
	int	  isfadein = dp.ReadCell();
	float percent  = dp.ReadCell();
	int	  duration;
	int	  holdtime;
	int	  flags;

	if (isfadein == 1)
	{
		flags	 = (0x0002 | 0x0010);
		holdtime = RoundFloat(2000 * percent);
		duration = 10;
	}
	else
	{
		flags	 = (0x0001 | 0x0010);
		holdtime = RoundFloat(255 * percent);
		duration = holdtime;
	}
	int color[4]	= { 255, 255, 255, 255 };
	g_FadeUserMsgId = GetUserMessageId("Fade");
	Handle message	= StartMessageEx(g_FadeUserMsgId, clients, 1);
	if (GetUserMessageType() == UM_Protobuf)
	{
		Protobuf pb = UserMessageToProtobuf(message);
		pb.SetInt("duration", duration);
		pb.SetInt("hold_time", holdtime);
		pb.SetInt("flags", flags);
		pb.SetColor("clr", color);
	}
	else
	{
		BfWriteShort(message, duration);
		BfWriteShort(message, holdtime);
		BfWriteShort(message, flags);
		BfWriteByte(message, color[0]);
		BfWriteByte(message, color[1]);
		BfWriteByte(message, color[2]);
		BfWriteByte(message, color[3]);
	}
	EndMessage();
	delete dp;
}

// 减速弹相关, 减速判定持续5秒, 烟雾持续5秒

void CreateSmoke(float[3] pos)
{
	int	 SmokeEnt = CreateEntityByName("env_smokestack");

	char originData[64];
	Format(originData, sizeof(originData), "%f %f %f", pos[0], pos[1], pos[2]);

	if (SmokeEnt)
	{
		// Create the Smoke
		DispatchKeyValue(SmokeEnt, "targetname", "Smoke");
		DispatchKeyValue(SmokeEnt, "Origin", originData);
		DispatchKeyValue(SmokeEnt, "BaseSpread", "100");
		DispatchKeyValue(SmokeEnt, "SpreadSpeed", "70");
		DispatchKeyValue(SmokeEnt, "Speed", "80");
		DispatchKeyValue(SmokeEnt, "StartSize", "300");
		DispatchKeyValue(SmokeEnt, "EndSize", "2");
		DispatchKeyValue(SmokeEnt, "Rate", "75");
		DispatchKeyValue(SmokeEnt, "JetLength", "400");
		DispatchKeyValue(SmokeEnt, "Twist", "20");
		DispatchKeyValue(SmokeEnt, "RenderColor", "255 255 255");	 // red green blue
		DispatchKeyValue(SmokeEnt, "RenderAmt", "255");
		DispatchKeyValue(SmokeEnt, "SmokeMaterial", "particle/particle_smokegrenade.vmt");

		DispatchSpawn(SmokeEnt);
		AcceptEntityInput(SmokeEnt, "TurnOn");

		// Start timer to stop smoke
		DataPack pack = new DataPack();
		CreateDataTimer(5.0, Timer_KillSmoke, pack);
		WritePackCell(pack, SmokeEnt);

		// Start timer to remove smoke
		DataPack pack2 = new DataPack();
		CreateDataTimer(10.0, Timer_StopSmoke, pack2);
		WritePackCell(pack2, SmokeEnt);
	}
}

Action Timer_KillSmoke(Handle timer, DataPack pack)
{
	pack.Reset();
	int SmokeEnt = ReadPackCell(pack);

	StopSmokeEnt(SmokeEnt);
}

void StopSmokeEnt(int target)
{
	if (IsValidEntity(target))
	{
		AcceptEntityInput(target, "TurnOff");
	}
}

Action Timer_StopSmoke(Handle timer, DataPack pack)
{
	pack.Reset();
	int SmokeEnt = ReadPackCell(pack);

	RemoveSmokeEnt(SmokeEnt);
}

void RemoveSmokeEnt(int target)
{
	if (IsValidEntity(target))
	{
		AcceptEntityInput(target, "Kill");
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (GetGameTime() > g_fUnfreezeTime[client])
	{
		return Plugin_Continue;
	}
	buttons |= IN_SPEED;
	return Plugin_Changed;
}

float GetEntityDistance(int ent1, int ent2)
{
	float vpos1[3];
	float vpos2[3];
	GetEntPropVector(ent1, Prop_Data, "m_vecAbsOrigin", vpos1);
	GetEntPropVector(ent2, Prop_Data, "m_vecAbsOrigin", vpos2);
	return GetVectorDistance(vpos1, vpos2);
}
