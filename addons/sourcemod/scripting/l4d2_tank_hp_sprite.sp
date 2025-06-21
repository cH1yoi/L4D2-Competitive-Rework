#pragma semicolon 1

#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS						FCVAR_NOTIFY

#define SpriteCustomVMTPathString		"mart/mart_custombar2.vmt"
#define SpriteCustomVTFPathString		"mart/mart_custombar2.vtf"	

int SpriteEntityID[32];
int SpriteFrameEntityID[32];
int EntityMyOwner[2049];

bool RoundEnd;

float CheckInterval = 0.5;
float SpriteTankHigh = 90.0;
int SpriteTankAlpha = 200;
char SpriteTankScale[5] = "0.60";
char SpriteTankColors[12] = "208 0 0";
int SpriteTankVisibility = 7;
bool SpriteTankTeamVisibility[3] = {true, true, true};

ConVar GCheckInterval;
ConVar GSpriteTankHigh;
ConVar GSpriteTankAlpha;
ConVar GSpriteTankScale;
ConVar GSpriteTankColors;
ConVar GSpriteTankVisibility;

public void OnPluginStart()
{
	ReZero();

	GCheckInterval						=  CreateConVar("l4d2_tank_hp_sprite_check_interval",
														"0.2",
														"Tank血量显示条计时器检查的时间间隔.",
														CVAR_FLAGS, true, 0.1);
	GSpriteTankHigh						=  CreateConVar("l4d2_tank_hp_sprite_high",
														"90.0",
														"Tank血量显示条位于对应玩家的高度.",
														CVAR_FLAGS, true, 0.0);
	GSpriteTankAlpha					=  CreateConVar("l4d2_tank_hp_sprite_alpha",
														"200",
														"Tank血量显示条的可见度. (0 = 完全透明, 255 = 完全不透明)",
														CVAR_FLAGS, true, 0.0, true, 255.0);
	GSpriteTankScale					=  CreateConVar("l4d2_tank_hp_sprite_scale",
														"0.60",
														"Tank血量显示条的大小.",
														CVAR_FLAGS, true, 0.01);
	GSpriteTankColors					=  CreateConVar("l4d2_tank_hp_sprite_colors",
														"208 0 0",
														"Tank血量显示条的RGB.",
														CVAR_FLAGS);
	GSpriteTankVisibility				=  CreateConVar("l4d2_tank_hp_sprite_visibility",
														"3",
														"可以看见Tank血量显示条的队伍. (1 = 旁观 2 = 生还 4 = 感染者)\n 将需要项相加",
														CVAR_FLAGS, true, 0.0, true, 7.0);

	GCheckInterval.AddChangeHook(ConVarChanged);
	GSpriteTankHigh.AddChangeHook(ConVarChanged);
	GSpriteTankAlpha.AddChangeHook(ConVarChanged);
	GSpriteTankScale.AddChangeHook(ConVarChanged);
	GSpriteTankColors.AddChangeHook(ConVarChanged);
	GSpriteTankVisibility.AddChangeHook(ConVarChanged);

	AddFileToDownloadsTable(SpriteCustomVMTPathString);
	AddFileToDownloadsTable(SpriteCustomVTFPathString);

	HookEvent("round_start",		Event_RoundStart,			EventHookMode_PostNoCopy);
	HookEvent("round_end",			Event_RoundEnd,				EventHookMode_PostNoCopy);
	HookEvent("tank_spawn",			Event_TankSpawn);
	HookEvent("player_death",		Event_PlayerDeath);

	AutoExecConfig(true, "l4d2_tank_hp_sprite");
}





// ====================================================================================================
// ConVar Changed
// ====================================================================================================

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

public void GetCvars()
{
	CheckInterval		= GCheckInterval.FloatValue;
	SpriteTankHigh		= GSpriteTankHigh.FloatValue;
	SpriteTankAlpha		= GSpriteTankAlpha.IntValue;

	float fSpriteTankScale = GSpriteTankScale.FloatValue;
	FloatToString(fSpriteTankScale, SpriteTankScale, sizeof(SpriteTankScale));

	SpriteTankVisibility	= GSpriteTankVisibility.IntValue;

	if (SpriteTankVisibility >= 4)
	{
		SpriteTankTeamVisibility[2] = true;
		SpriteTankTeamVisibility[1] = SpriteTankVisibility >= 6 ? true : false;
	}
	else
	{
		SpriteTankTeamVisibility[2] = false;
		SpriteTankTeamVisibility[1] = SpriteTankVisibility >= 2 ? true : false;
	}
	SpriteTankTeamVisibility[0] = (SpriteTankVisibility % 2) == 1 ? true : false;

	char TempStr[12], Buffers[3][4];
	int TempI3[3];
	GSpriteTankColors.GetString(TempStr, sizeof(TempStr));
	TrimString(TempStr);
	ExplodeString(TempStr, " ", Buffers, sizeof(Buffers), sizeof(Buffers[]));
	for (int j = 0; j < 3 ; j++)
	{
		TempI3[j] = StringToInt(Buffers[j]);
		TempI3[j] = CorrectInt(TempI3[j], 0, 255);
	}
	Format(SpriteTankColors, sizeof(SpriteTankColors), "%d %d %d", TempI3[0], TempI3[1], TempI3[2]);
}





// ====================================================================================================
// Game void
// ====================================================================================================

public void OnMapStart()
{
	PrecacheModel(SpriteCustomVMTPathString, true);
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients ; i++)
		KillSprite(i);
}





// ====================================================================================================
// Hook Event
// ====================================================================================================

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ReZero();
	RoundEnd = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	RoundEnd = true;
	OnMapEnd();
	ReZero();
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) 
{
	if (RoundEnd)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsTank(client))
		return;

	CreateTimer(1.0, CheckTankAlive, client, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsTank(client))
		return;

	KillSprite(client);
}





// ====================================================================================================
// Game Action
// ====================================================================================================

public Action OnSetTransmit(int entity, int client)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	int own = EntityMyOwner[entity];

	if (own == client)
		return Plugin_Handled;

	if (!IsTank(own) || !IsPlayerAlive(own))
		return Plugin_Handled;

	int cteam = GetClientTeam(client);
	
	if (cteam < 1 || cteam > 3)
		return Plugin_Handled;

	if (SpriteTankTeamVisibility[cteam - 1])
		return Plugin_Continue;

	return Plugin_Handled;
}





// ====================================================================================================
// Timer Action
// ====================================================================================================

public Action CheckTankAlive(Handle timer, int client)
{
	if (RoundEnd)
		return Plugin_Continue;

	if (IsTank(client) && IsPlayerAlive(client))
		CreateTimer(CheckInterval, TSC, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action TSC(Handle timer, int client)
{
	if (RoundEnd)
		return Plugin_Stop;

	if (!IsTank(client) || !IsPlayerAlive(client))
	{
		KillSprite(client);
		return Plugin_Stop;
	}

	OneTankSpriteCheck(client);
	return Plugin_Continue;
}





// ====================================================================================================
// void
// ====================================================================================================

public void OneTankSpriteCheck(int client)
{
	char SpriteName[20];
	FormatEx(SpriteName, sizeof(SpriteName), "%s-%02i", "l4d2_tank_sprite", client);

	int entity = INVALID_ENT_REFERENCE;

	if (SpriteEntityID[client] != INVALID_ENT_REFERENCE)
		entity = EntRefToEntIndex(SpriteEntityID[client]);

	if (entity == INVALID_ENT_REFERENCE)
	{
		float TankPos[3];
		GetClientAbsOrigin(client, TankPos);
		TankPos[2] += SpriteTankHigh;

		entity = CreateEntityByName("env_sprite");
		SpriteEntityID[client] = EntIndexToEntRef(entity);
		EntityMyOwner[entity] = client;
		DispatchKeyValue(entity, "targetname", SpriteName);
		DispatchKeyValue(entity, "spawnflags", "1");
		DispatchKeyValueVector(entity, "origin", TankPos);

		SDKHook(entity, SDKHook_SetTransmit, OnSetTransmit);
	}

	int colorAlpha[4];
	GetEntityRenderColor(client, colorAlpha[0], colorAlpha[1], colorAlpha[2], colorAlpha[3]);

	char sAlpha[4];
	IntToString(RoundFloat(SpriteTankAlpha * colorAlpha[3] / 255.0), sAlpha, sizeof(sAlpha));

	DispatchKeyValue(entity, "model", SpriteCustomVMTPathString);
	DispatchKeyValue(entity, "rendercolor", SpriteTankColors);
	DispatchKeyValue(entity, "renderamt", sAlpha);
	DispatchKeyValue(entity, "renderfx", "0");
	DispatchKeyValue(entity, "scale", SpriteTankScale);
	DispatchKeyValue(entity, "fademindist", "-1");
	DispatchSpawn(entity);

	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);
	AcceptEntityInput(entity, "ShowSprite");

	int entityFrame = INVALID_ENT_REFERENCE;

	if (SpriteFrameEntityID[client] != INVALID_ENT_REFERENCE)
		entityFrame = EntRefToEntIndex(SpriteFrameEntityID[client]);

	if (entityFrame == INVALID_ENT_REFERENCE)
	{
		entityFrame = CreateEntityByName("env_texturetoggle");
		SpriteFrameEntityID[client] = EntIndexToEntRef(entityFrame);
		DispatchKeyValue(entityFrame, "targetname", SpriteName);
		DispatchKeyValue(entityFrame, "target", SpriteName);
		DispatchSpawn(entityFrame);

		SetVariantString("!activator");
		AcceptEntityInput(entityFrame, "SetParent", entity);
	}

	int Tank_NowHP	= GetClientHealth(client);
	int Tank_MaxHP	= GetEntProp(client, Prop_Data, "m_iMaxHealth");
	int frame		= Tank_NowHP * 100 / Tank_MaxHP;

	frame = CorrectInt(frame, 0, 100);

	char input[38];
	FormatEx(input, sizeof(input), "OnUser1 !self:SetTextureIndex:%i:0:1", frame);
	SetVariantString(input);
	AcceptEntityInput(entityFrame, "AddOutput");
	AcceptEntityInput(entityFrame, "FireUser1");
}

public void ReZero()
{
	for (int i = 1; i <= MaxClients ; i++)
	{
		SpriteEntityID[i]		= INVALID_ENT_REFERENCE;
		SpriteFrameEntityID[i]	= INVALID_ENT_REFERENCE;
	}
}

public void KillSprite(int client)
{
	if (SpriteEntityID[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(SpriteEntityID[client]);

		if (entity != INVALID_ENT_REFERENCE)
			AcceptEntityInput(entity, "Kill");

		SpriteEntityID[client] = INVALID_ENT_REFERENCE;
	}

	if (SpriteFrameEntityID[client] != INVALID_ENT_REFERENCE)
	{
		int entityFrame = EntRefToEntIndex(SpriteFrameEntityID[client]);

		if (entityFrame != INVALID_ENT_REFERENCE)
			AcceptEntityInput(entityFrame, "Kill");

		SpriteFrameEntityID[client] = INVALID_ENT_REFERENCE;
	}
}





// ====================================================================================================
// int
// ====================================================================================================

public int CorrectInt(int value, int min, int max)
{
	if (value < min)
		return min;
	
	if (value > max)
		return max;
	
	return value;
}





// ====================================================================================================
// bool
// ====================================================================================================

public bool IsTank(int client)
{
	return (client > 0 &&
			client <= MaxClients &&
			IsClientInGame(client) &&
			GetClientTeam(client) == 3 &&
			GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}