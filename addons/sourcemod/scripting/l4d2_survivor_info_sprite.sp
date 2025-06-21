#pragma semicolon 1

#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <clientprefs>
#include <l4d2util>
#include <colors>
#include <godframecontrol>

#define CVAR_FLAGS						FCVAR_NOTIFY

#define MaxColorsType					9

#define Hunter_GetUp_Timer				2.0
#define	Charger_GetUp_Timer				3.0
#define Boomed_Fade_Timer				10.0

#define SpritePathString				"vgui/healthbar_white.vmt"
#define SpriteCustomVMTPathString		"mart/mart_custombar2.vmt"
#define SpriteCustomVTFPathString		"mart/mart_custombar2.vtf"	

char SpriteSWPVMTPathString[5][36] =
{
	"weapon/weapon_secondaryweapon.vmt",
	"weapon/weapon_primaryweapon.vmt",
	"weapon/weapon_rifleweapon.vmt",
	"weapon/weapon_otherweapon.vmt",
	"weapon/weapon_nowepaon.vmt"
};

char SpriteSWPVTFPathString[5][36] =
{
	"weapon/weapon_secondaryweapon.vtf",
	"weapon/weapon_primaryweapon.vtf",
	"weapon/weapon_rifleweapon.vtf",
	"weapon/weapon_otherweapon.vtf",
	"weapon/weapon_nowepaon.vtf"
};

int SpriteEntityID[32];
int SpriteFrameEntityID[32];
int EntityMyOwner[2049];
int SpriteSWPEntityID[32];
int SpriteSWPFrameEntityID[32];
int SurvivorPinnedFrom[32];
bool IsSWPEntity[2049];

int ColorsType[MaxColorsType][3] =
{
	{  0, 240,   0},				// 健康 40 ~
	{208, 208,   0},				// 瘸腿 25 ~ 39
	{  0, 128, 128},				// 低血 1 ~ 24
	{240,   0,   0},				// 倒地
	{120,   0,   0},				// 挂边
	{208, 208, 208},				// 黑白
	{255,   0,   0},				// 被控
	{208,   0, 208},				// 被喷
	{224, 126, 149}					// 起身
};

char ColorsTypeConVarString[MaxColorsType][12] =
{
	"healthy",
	"limp",
	"lowhp",
	"fallen",
	"falling",
	"blackwhite",
	"pinned",
	"boomed",
	"getup"
};

char ColorsTypeTextString[MaxColorsType][16] =
{
	"健康",
	"瘸腿",
	"低血量",
	"倒地",
	"挂边",
	"黑白",
	"被控",
	"被喷",
	"起身"
};

char MeleeModelNameString[13][64] =
{
	"models/weapons/melee/v_bat.mdl",					// 棒球棍
	"models/weapons/melee/v_shovel.mdl",				// 铲子
	"models/weapons/melee/v_pitchfork.mdl",				// 草叉
	"models/v_models/v_knife_t.mdl",					// 小刀
	"models/weapons/melee/v_electric_guitar.mdl",		// 电吉他
	"models/weapons/melee/v_cricket_bat.mdl",			// 板球拍
	"models/weapons/melee/v_golfclub.mdl",				// 高尔夫球杆
	"models/weapons/melee/v_tonfa.mdl",					// 警棍
	"models/weapons/melee/v_katana.mdl",				// 武士刀
	"models/weapons/melee/v_machete.mdl",				// 砍刀
	"models/weapons/melee/v_fireaxe.mdl",				// 消防斧
	"models/weapons/melee/v_frying_pan.mdl",			// 平底锅
	"models/weapons/melee/v_crowbar.mdl"				// 撬棍
};

int ColorsTypeWeight[MaxColorsType] =
{
	2,			// 健康 40 ~
	2,			// 瘸腿 25 ~ 39
	2,			// 低血 1 ~ 24
	4,			// 倒地
	4,			// 挂边
	3,			// 黑白
	5,			// 被控
	7,			// 被喷
	6			// 起身
};

float FewAmmoFloat = 0.2;
char EnoughAmmoColors[12]	= "255 255 255";
char FewAmmoColors[12]		= "240 240 0";
char NoAmmoColors[12]		= "240 0 0";

float CheckInterval = 0.2;
bool LookOwnEnable = false;

float SpriteAliveHigh = 88.0;
int SpriteAliveAlpha = 200;
char SpriteAliveScale[5] = "0.60";
bool SpriteAliveGetUpTimerEnable = true;
bool SpriteAlivePinnedFromEnable = true;

bool SpriteSWPEnable = true;
float SpriteSWPHigh = 78.0;
int SpriteSWPAlpha = 255;
char SpriteSWPScale[5] = "0.15";

int SpriteAliveVisibility = 3;
bool SpriteAliveTeamVisibility[3] = {true, true, false};
float SpriteAliveDistanceVisibility = 0.0;
int SpriteSWPVisibility = 3;
bool SpriteSWPTeamVisibility[3] = {true, true, false};
float SpriteSWPDistanceVisibility = 100.0;

bool CanShowSprite[32];

ConVar GCheckInterval;
ConVar GLookOwnEnable;
ConVar GSpriteAliveHigh;
ConVar GSpriteAliveAlpha;
ConVar GSpriteAliveScale;
ConVar GSpriteAliveGetUpTimerEnable;
ConVar GSpriteAlivePinnedFromEnable;
ConVar GSpriteSWPEnable;
ConVar GSpriteSWPHigh;
ConVar GSpriteSWPAlpha;
ConVar GSpriteSWPScale;
ConVar GSpriteAliveVisibility;
ConVar GSpriteAliveDistanceVisibility;
ConVar GSpriteSWPVisibility;
ConVar GSpriteSWPDistanceVisibility;
ConVar GColorsType[MaxColorsType];
ConVar GColorsTypeWeight[MaxColorsType];
ConVar GFewAmmoFloat;
ConVar GEnoughAmmoColors;
ConVar GFewAmmoColors;
ConVar GNoAmmoColors;

Handle CheckTimerHandle;

ConVar GSurvivor_Incap_Health;
ConVar GSurvivor_Max_Incapacitated_Count;
ConVar GSurvivor_Limp_Health;

float VomitStart[32];
float VomitEnd[32];
float GetUpStart[32];
float GetUpEnd[32];
bool IsGetUp[32];
bool IsBoomed[32];

float MySDVSetting[32][2];

Cookie SelfSADV, SelfSWDV;

bool bLate;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) 
{
	EngineVersion test = GetEngineVersion();
	
	if (test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	bLate = late;
	return APLRes_Success; 
}

public void OnPluginStart()
{
	SelfSADV = RegClientCookie("l4d2_self_sadv_setting",	"MySelf_SADV_Setting", CookieAccess_Protected);
	SelfSWDV = RegClientCookie("l4d2_self_swdv_setting",	"MySelf_SWDV_Setting", CookieAccess_Protected);

	GSurvivor_Incap_Health				= FindConVar("survivor_incap_health");
	GSurvivor_Max_Incapacitated_Count	= FindConVar("survivor_max_incapacitated_count");
	GSurvivor_Limp_Health				= FindConVar("survivor_limp_health");

	for (int i = 1; i <= MaxClients ; i++)
	{
		MySDVSetting[i][0] = 0.0;
		MySDVSetting[i][1] = 0.0;
	}

	GCheckInterval						=  CreateConVar("l4d2_sis_check_interval",
														"0.1",
														"显示条计时器检查的时间间隔.",
														CVAR_FLAGS, true, 0.1);
	GLookOwnEnable						=  CreateConVar("l4d2_sis_look_own_enable",
														"0",
														"玩家是否可以看见自己的显示条? (0 = 否, 1 = 是)",
														CVAR_FLAGS, true, 0.0, true, 1.0);
	GSpriteAliveHigh					=  CreateConVar("l4d2_sis_alive_high",
														"98.0",
														"血量显示条位于对应玩家的高度.",
														CVAR_FLAGS, true, 0.0);
	GSpriteAliveAlpha					=  CreateConVar("l4d2_sis_alive_alpha",
														"170",
														"血量显示条的可见度. (0 = 完全透明, 255 = 完全不透明)",
														CVAR_FLAGS, true, 0.0, true, 255.0);
	GSpriteAliveScale					=  CreateConVar("l4d2_sis_alive_scale",
														"0.60",
														"血量显示条的大小.",
														CVAR_FLAGS, true, 0.01);
	GSpriteAliveGetUpTimerEnable		=  CreateConVar("l4d2_sis_alive_getup_timer_enable",
														"1",
														"启用当处于起身状态时, 血量显示条将显示剩余硬直时间. (0 = 禁用, 1 = 启用)",
														CVAR_FLAGS, true, 0.0, true, 1.0);
	GSpriteAlivePinnedFromEnable		=  CreateConVar("l4d2_sis_alive_pinned_infected_enable",
														"1",
														"启用当处于被控状态时, 血量显示条将显示控制特感的血量. (0 = 禁用, 1 = 启用)",
														CVAR_FLAGS, true, 0.0, true, 1.0);
	GSpriteSWPEnable					=  CreateConVar("l4d2_sis_swp_enable",
														"1",
														"启用武器显示条. (0 = 禁用, 1 = 启用)",
														CVAR_FLAGS, true, 0.0, true, 1.0);
	GSpriteSWPHigh						=  CreateConVar("l4d2_sis_swp_high",
														"88.0",
														"武器显示条位于对应玩家的高度.",
														CVAR_FLAGS, true, 0.0);
	GSpriteSWPAlpha						=  CreateConVar("l4d2_sis_swp_alpha",
														"200",
														"武器显示条的可见度. (0 = 完全透明, 255 = 完全不透明)",
														CVAR_FLAGS, true, 0.0, true, 255.0);
	GSpriteSWPScale						=  CreateConVar("l4d2_sis_swp_scale",
														"0.15",
														"武器显示条的大小. (在一定范围内[0.01~  0.4~  0.8~]是同一个大小, 不建议调)",
														CVAR_FLAGS, true, 0.01);
	GSpriteAliveVisibility				=  CreateConVar("l4d2_sis_alive_visibility",
														"3",
														"可以看见血量显示条的队伍. (1 = 旁观 2 = 生还 4 = 感染者)\n 将需要项相加",
														CVAR_FLAGS, true, 0.0, true, 7.0);
	GSpriteAliveDistanceVisibility		=  CreateConVar("l4d2_sis_alive_distance_visibility",
														"0.0",
														"距离血量显示条对应的玩家多近时将看不见其血量显示条?",
														CVAR_FLAGS, true, 0.0);
	GSpriteSWPVisibility				=  CreateConVar("l4d2_sis_swp_visibility",
														"3",
														"可以看见武器显示条的队伍. (1 = 旁观 2 = 生还 4 = 感染者)\n 将需要项相加",
														CVAR_FLAGS, true, 0.0, true, 7.0);
	GSpriteSWPDistanceVisibility		=  CreateConVar("l4d2_sis_swp_distance_visibility",
														"100.0",
														"距离武器显示条对应的玩家多近时将看不见其武器显示条?",
														CVAR_FLAGS, true, 0.0);
	GFewAmmoFloat						=  CreateConVar("l4d2_sis_swp_few_ammo_float",
														"0.2",
														"武器弹夹子弹数量低于等于这个比例时视为不充足.",
														CVAR_FLAGS, true, 0.01, true, 1.00);
	GEnoughAmmoColors					=  CreateConVar("l4d2_sis_swp_enough_ammo_color",
														"255 255 255",
														"武器弹夹子弹数量充足时武器显示条的颜色. (RGB全为255将显示原色)",
														CVAR_FLAGS);
	GFewAmmoColors						=  CreateConVar("l4d2_sis_swp_few_ammo_color",
														"240 240 0",
														"武器弹夹子弹数量不充足时武器显示条的颜色. (RGB全为255将显示原色)",
														CVAR_FLAGS);
	GNoAmmoColors						=  CreateConVar("l4d2_sis_swp_no_ammo_color",
														"240 0 0",
														"武器弹夹子弹数量为0时武器显示条的颜色. (RGB全为255将显示原色) ",
														CVAR_FLAGS);
	
	char TempStr1[48], TempStr2[12], TempStr3[64];
	for (int i = 0; i < MaxColorsType ; i++)
	{
		Format(TempStr1, sizeof(TempStr1), "l4d2_sis_color_t%d_%s", i + 1, ColorsTypeConVarString[i]);
		Format(TempStr2, sizeof(TempStr2), "%d %d %d", ColorsType[i][0], ColorsType[i][1], ColorsType[i][2]);
		Format(TempStr3, sizeof(TempStr3), "%s状态下血量显示条的RGB.", ColorsTypeTextString[i]);
		GColorsType[i] = CreateConVar(TempStr1, TempStr2, TempStr3, CVAR_FLAGS);
	}
	for (int i = 0; i < MaxColorsType ; i++)
	{
		Format(TempStr1, sizeof(TempStr1), "l4d2_sis_color_w%d_%s", i + 1, ColorsTypeConVarString[i]);
		Format(TempStr2, sizeof(TempStr2), "%d", ColorsTypeWeight[i]);
		Format(TempStr3, sizeof(TempStr3), "%s状态下血量显示条的优先级.", ColorsTypeTextString[i]);
		GColorsTypeWeight[i] = CreateConVar(TempStr1, TempStr2, TempStr3, CVAR_FLAGS, true, 0.0);
	}

	GCheckInterval.AddChangeHook(ConVarChanged);
	GLookOwnEnable.AddChangeHook(ConVarChanged);
	GSpriteAliveHigh.AddChangeHook(ConVarChanged);
	GSpriteAliveAlpha.AddChangeHook(ConVarChanged);
	GSpriteAliveScale.AddChangeHook(ConVarChanged);
	GSpriteAliveGetUpTimerEnable.AddChangeHook(ConVarChanged);
	GSpriteAlivePinnedFromEnable.AddChangeHook(ConVarChanged);
	GSpriteSWPEnable.AddChangeHook(ConVarChanged);
	GSpriteSWPHigh.AddChangeHook(ConVarChanged);
	GSpriteSWPAlpha.AddChangeHook(ConVarChanged);
	GSpriteSWPScale.AddChangeHook(ConVarChanged);
	GSpriteAliveVisibility.AddChangeHook(ConVarChanged);
	GSpriteAliveDistanceVisibility.AddChangeHook(ConVarChanged);
	GSpriteSWPVisibility.AddChangeHook(ConVarChanged);
	GSpriteSWPDistanceVisibility.AddChangeHook(ConVarChanged);
	GFewAmmoFloat.AddChangeHook(ConVarChanged);
	GEnoughAmmoColors.AddChangeHook(ConVarChanged);
	GFewAmmoColors.AddChangeHook(ConVarChanged);
	GNoAmmoColors.AddChangeHook(ConVarChanged);

	for (int i = 0; i < MaxColorsType ; i++)
	{
		GColorsType[i].AddChangeHook(ConVarChanged);
		GColorsTypeWeight[i].AddChangeHook(ConVarChanged);
	}

	AddFileToDownloadsTable(SpriteCustomVMTPathString);
	AddFileToDownloadsTable(SpriteCustomVTFPathString);
	for (int i = 0; i < 5 ; i++)
	{
		AddFileToDownloadsTable(SpriteSWPVMTPathString[i]);
		AddFileToDownloadsTable(SpriteSWPVTFPathString[i]);
	}

	HookEvent("round_start",			Event_RoundStart,			EventHookMode_PostNoCopy);
	HookEvent("round_end",				Event_RoundEnd,				EventHookMode_PostNoCopy);
	HookEvent("tongue_grab",			Event_SurvivorPinned);
	HookEvent("choke_start",			Event_SurvivorPinned);
	HookEvent("lunge_pounce",			Event_SurvivorPinned);
	HookEvent("jockey_ride",			Event_SurvivorPinned);
	HookEvent("charger_carry_start",	Event_SurvivorPinned);
	HookEvent("charger_pummel_start",	Event_SurvivorPinned);
	HookEvent("pounce_stopped",			Event_PounceEnd);
	HookEvent("charger_pummel_end",		Event_PummelEnd);

	RegConsoleCmd("sm_selfsdv",			Command_Save_MySelf_SDV,	"记录距离可视性设置.");

	AutoExecConfig(true, "l4d2_survivor_info_sprite");

	if (bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				OnClientCookiesCached(i);
		}
	}
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
	LookOwnEnable		= GLookOwnEnable.BoolValue;
	SpriteAliveHigh		= GSpriteAliveHigh.FloatValue;
	SpriteAliveAlpha	= GSpriteAliveAlpha.IntValue;

	float fSpriteAliveScale = GSpriteAliveScale.FloatValue;
	FloatToString(fSpriteAliveScale, SpriteAliveScale, sizeof(SpriteAliveScale));

	SpriteSWPEnable		= GSpriteSWPEnable.BoolValue;
	SpriteSWPHigh		= GSpriteSWPHigh.FloatValue;
	SpriteSWPAlpha		= GSpriteSWPAlpha.IntValue;
	
	float fSpriteSWPScale = GSpriteSWPScale.FloatValue;
	FloatToString(fSpriteSWPScale, SpriteSWPScale, sizeof(SpriteSWPScale));

	SpriteAliveGetUpTimerEnable	= GSpriteAliveGetUpTimerEnable.BoolValue;
	SpriteAlivePinnedFromEnable	= GSpriteAlivePinnedFromEnable.BoolValue;

	SpriteAliveVisibility	= GSpriteAliveVisibility.IntValue;

	if (SpriteAliveVisibility >= 4)
	{
		SpriteAliveTeamVisibility[2] = true;
		SpriteAliveTeamVisibility[1] = SpriteAliveVisibility >= 6 ? true : false;
	}
	else
	{
		SpriteAliveTeamVisibility[2] = false;
		SpriteAliveTeamVisibility[1] = SpriteAliveVisibility >= 2 ? true : false;
	}
	SpriteAliveTeamVisibility[0] = (SpriteAliveVisibility % 2) == 1 ? true : false;

	SpriteSWPVisibility		= GSpriteSWPVisibility.IntValue;

	if (SpriteSWPVisibility >= 4)
	{
		SpriteSWPTeamVisibility[2] = true;
		SpriteSWPTeamVisibility[1] = SpriteSWPVisibility >= 6 ? true : false;
	}
	else
	{
		SpriteSWPTeamVisibility[2] = false;
		SpriteSWPTeamVisibility[1] = SpriteSWPVisibility >= 2 ? true : false;
	}
	SpriteSWPTeamVisibility[0] = (SpriteSWPVisibility % 2) == 1 ? true : false;

	SpriteAliveDistanceVisibility	= GSpriteAliveDistanceVisibility.FloatValue;
	SpriteSWPDistanceVisibility		= GSpriteSWPDistanceVisibility.FloatValue;

	FewAmmoFloat = GFewAmmoFloat.FloatValue;
	
	char TargetStr[12], Buffers[3][4];
	int TempI;
	for (int i = 0; i < MaxColorsType ; i++)
	{
		GColorsType[i].GetString(TargetStr, sizeof(TargetStr));
		TrimString(TargetStr);
		ExplodeString(TargetStr, " ", Buffers, sizeof(Buffers), sizeof(Buffers[]));
		for (int j = 0; j < 3 ; j++)
		{
			TempI = StringToInt(Buffers[j]);
			ColorsType[i][j] = CorrectInt(TempI, 0, 255);
		}
		ColorsTypeWeight[i] = GColorsTypeWeight[i].IntValue;
	}

	int TempI3[3];
	GEnoughAmmoColors.GetString(TargetStr, sizeof(TargetStr));
	TrimString(TargetStr);
	ExplodeString(TargetStr, " ", Buffers, sizeof(Buffers), sizeof(Buffers[]));
	for (int j = 0; j < 3 ; j++)
	{
		TempI3[j] = StringToInt(Buffers[j]);
		TempI3[j] = CorrectInt(TempI3[j], 0, 255);
	}
	Format(EnoughAmmoColors, sizeof(EnoughAmmoColors), "%d %d %d", TempI3[0], TempI3[1], TempI3[2]);

	GFewAmmoColors.GetString(TargetStr, sizeof(TargetStr));
	TrimString(TargetStr);
	ExplodeString(TargetStr, " ", Buffers, sizeof(Buffers), sizeof(Buffers[]));
	for (int j = 0; j < 3 ; j++)
	{
		TempI3[j] = StringToInt(Buffers[j]);
		TempI3[j] = CorrectInt(TempI3[j], 0, 255);
	}
	Format(FewAmmoColors, sizeof(FewAmmoColors), "%d %d %d", TempI3[0], TempI3[1], TempI3[2]);

	GNoAmmoColors.GetString(TargetStr, sizeof(TargetStr));
	TrimString(TargetStr);
	ExplodeString(TargetStr, " ", Buffers, sizeof(Buffers), sizeof(Buffers[]));
	for (int j = 0; j < 3 ; j++)
	{
		TempI3[j] = StringToInt(Buffers[j]);
		TempI3[j] = CorrectInt(TempI3[j], 0, 255);
	}
	Format(NoAmmoColors, sizeof(NoAmmoColors), "%d %d %d", TempI3[0], TempI3[1], TempI3[2]);

	for (int i = 1; i <= MaxClients ; i++)
	{
		if (CIsSurvivor(i) && IsPlayerAlive(i))
			KillSprite(i);
	}

	if (CheckTimerHandle != null)
		delete CheckTimerHandle;
	if (CheckTimerHandle == null)
		CheckTimerHandle = CreateTimer(CheckInterval, SpriteCheck, _, TIMER_REPEAT);
}





// ====================================================================================================
// Cookie
// ====================================================================================================

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
		return;
	
	char TempStr[2][8];
	SelfSADV.Get(client, TempStr[0], sizeof(TempStr[]));
	MySDVSetting[client][0] = StringToFloat(TempStr[0]);
	SelfSWDV.Get(client, TempStr[1], sizeof(TempStr[]));
	MySDVSetting[client][1] = StringToFloat(TempStr[1]);
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;
	
	char TempStr[2][8];
	FloatToString(MySDVSetting[client][0], TempStr[0], sizeof(TempStr[]));
	SelfSADV.Set(client, TempStr[0]);
	FloatToString(MySDVSetting[client][1], TempStr[1], sizeof(TempStr[]));
	SelfSWDV.Set(client, TempStr[1]);
	MySDVSetting[client][0] = 0.0;
	MySDVSetting[client][1] = 0.0;
}





// ====================================================================================================
// Game void
// ====================================================================================================

public void OnMapStart()
{
	PrecacheModel(SpritePathString, true);
	PrecacheModel(SpriteCustomVMTPathString, true);
	for (int i = 0; i < 5 ; i++)
		PrecacheModel(SpriteSWPVMTPathString[i], true);
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients ; i++)
		KillSprite(i);
	ReZero();
	if (CheckTimerHandle != null)
		delete CheckTimerHandle;
}





// ====================================================================================================
// Hook Event
// ====================================================================================================

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ReZero();
	for (int i = 1; i <= MaxClients ; i++)
	{
		VomitStart[i]			= 0.0;
		VomitEnd[i]				= 0.0;
		GetUpStart[i]			= 0.0;
		GetUpEnd[i]				= 0.0;
		IsGetUp[i]				= false;
		IsBoomed[i]				= false;
		SurvivorPinnedFrom[i]	= 0;
	}
	if (CheckTimerHandle == null)
		CheckTimerHandle = CreateTimer(CheckInterval, SpriteCheck, _, TIMER_REPEAT);
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

public void Event_SurvivorPinned(Event event, const char[] name, bool dontBroadcast)
{
	int attacker	= GetClientOfUserId(GetEventInt(event, "userid"));

	if (!CIsValidInfected(attacker))
		return;
	
	int client		= GetClientOfUserId(GetEventInt(event, "victim"));

	if (!CIsValidSurvivor(client))
		return;

	SurvivorPinnedFrom[client] = attacker;
}

public void Event_PounceEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "victim"));

	if (!CIsValidSurvivor(client))
		return;

	if (IsGetUp[client])
		return;
	
	IsGetUp[client] = true;
	GetUpStart[client] = GetGameTime();
	GetUpEnd[client] = GetUpStart[client] + Hunter_GetUp_Timer;
	EveryOneSpriteCheck();
	CreateTimer(Hunter_GetUp_Timer, ReCold_IsGetUp, client, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_PummelEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "victim"));

	if (!CIsValidSurvivor(client))
		return;

	if (IsGetUp[client])
		return;
	
	IsGetUp[client] = true;
	GetUpStart[client] = GetGameTime();
	GetUpEnd[client] = GetUpStart[client] + Charger_GetUp_Timer;
	EveryOneSpriteCheck();
	CreateTimer(Charger_GetUp_Timer, ReCold_IsGetUp, client, TIMER_FLAG_NO_MAPCHANGE);
}





// ====================================================================================================
// Command Action
// ====================================================================================================

public Action Command_Save_MySelf_SDV(int client, int args)
{
	if (!CIsValidClientIndex(client) || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if (args == 0)
	{
		CPrintToChat(client, "{olive}[INFO] {default}当前服务器{blue}血量显示条{default}最近显示距离为: {olive}%.2f",
					SpriteAliveDistanceVisibility);
		CPrintToChat(client, "{olive}[INFO] {default}当前服务器{blue}武器显示条{default}最近显示距离为: {olive}%.2f",
					SpriteSWPDistanceVisibility);
	}
	else if (args == 1)
	{
		CPrintToChat(client, "{olive}[INFO] {default}你当前{blue}血量显示条{default}最近显示距离为: {olive}%.2f",
					MySDVSetting[client][0]);
		CPrintToChat(client, "{olive}[INFO] {default}你当前{blue}武器显示条{default}最近显示距离为: {olive}%.2f",
					MySDVSetting[client][1]);
	}
	else if (args >= 2)
	{
		float argf1 = GetCmdArgFloat(1);
		float argf2 = GetCmdArgFloat(2);
		MySDVSetting[client][0] = argf1;
		MySDVSetting[client][1] = argf2;
		CPrintToChat(client, "{olive}[INFO] {default}你已经将{blue}血量显示条{default}最近显示距离设置为: {olive}%.2f",
					MySDVSetting[client][0]);
		CPrintToChat(client, "{olive}[INFO] {default}你已经将{blue}武器显示条{default}最近显示距离设置为: {olive}%.2f",
					MySDVSetting[client][1]);
	}
	return Plugin_Handled;
}





// ====================================================================================================
// Game Action
// ====================================================================================================

public Action OnSetTransmit(int entity, int client)
{
	if (!CIsValidClientIndex(client) || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!LookOwnEnable && EntityMyOwner[entity] == client)
		return Plugin_Handled;

	int own = EntityMyOwner[entity];
	if (GetClientTeam(own) != 2 || !IsPlayerAlive(own))
		return Plugin_Handled;

	if (IsSWPEntity[entity])
	{
		if (IsPinned(own) || !IsPlayerState(own))
			return Plugin_Handled;
	}

	if (own != client)
	{
		float OwnPos[3], ClientPos[3], Dist;
		GetClientAbsOrigin(own, OwnPos);
		GetClientAbsOrigin(client, ClientPos);
		Dist = GetVectorDistance(OwnPos, ClientPos);
		float MinDist = IsSWPEntity[entity] ?
						(MySDVSetting[client][1] > 0.0 ? MySDVSetting[client][1] : SpriteSWPDistanceVisibility) :
						(MySDVSetting[client][0] > 0.0 ? MySDVSetting[client][0] : SpriteAliveDistanceVisibility);
		if (Dist <= MinDist)
			return Plugin_Handled;
	}

	int cteam = GetClientTeam(client);
	
	if (cteam < 1 || cteam > 3)
		return Plugin_Handled;

	if (IsSWPEntity[entity])
	{
		if (SpriteSWPTeamVisibility[cteam - 1])
			return Plugin_Continue;
	}
	else
	{
		if (SpriteAliveTeamVisibility[cteam - 1])
			return Plugin_Continue;
	}

	return Plugin_Handled;
}





// ====================================================================================================
// Timer Action
// ====================================================================================================

public Action SpriteCheck(Handle timer)
{
	EveryOneSpriteCheck();
	return Plugin_Continue;
}

public Action ReCold_IsGetUp(Handle timer, int client)
{
	IsGetUp[client] = false;
	return Plugin_Continue;
}

public Action ReCold_IsBoomed(Handle timer, int client)
{
	IsBoomed[client] = false;
	return Plugin_Continue;
}





// ====================================================================================================
// void
// ====================================================================================================

public void EveryOneSpriteCheck()
{
	for (int i = 1; i <= MaxClients ; i++)
	{
		CanShowSprite[i] = (CIsSurvivor(i) && IsPlayerAlive(i));

		if (!CanShowSprite[i])
		{
			KillSprite(i);
			continue;
		}

		static int MaxIncapHP = -1, MaxIncapCount = -1, LimpHP = -1;
		if (MaxIncapHP < 0)
			MaxIncapHP = GSurvivor_Incap_Health.IntValue;
		if (MaxIncapCount < 0)
			MaxIncapCount = GSurvivor_Max_Incapacitated_Count.IntValue;
		if (LimpHP < 0)
			LimpHP = GSurvivor_Limp_Health.IntValue;

		char SpriteName[20], SWPName[20];
		FormatEx(SpriteName, sizeof(SpriteName), "%s-%02i", "l4d2_info_sprite", i);
		FormatEx(SWPName, sizeof(SWPName), "%s-%02i", "l4d2_info_swp", i);

		int entity = INVALID_ENT_REFERENCE;

		if (SpriteEntityID[i] != INVALID_ENT_REFERENCE)
			entity = EntRefToEntIndex(SpriteEntityID[i]);

		if (entity == INVALID_ENT_REFERENCE)
		{
			float ClientPos[3];
			GetClientAbsOrigin(i, ClientPos);
			ClientPos[2] += SpriteAliveHigh;

			entity = CreateEntityByName("env_sprite");
			SpriteEntityID[i] = EntIndexToEntRef(entity);
			EntityMyOwner[entity] = i;
			IsSWPEntity[entity] = false;
			DispatchKeyValue(entity, "targetname", SpriteName);
			DispatchKeyValue(entity, "spawnflags", "1");
			DispatchKeyValueVector(entity, "origin", ClientPos);

			SDKHook(entity, SDKHook_SetTransmit, OnSetTransmit);
		}

		int colorAlpha[4];
		GetEntityRenderColor(i, colorAlpha[0], colorAlpha[1], colorAlpha[2], colorAlpha[3]);

		char sAlpha[4];
		IntToString(RoundFloat(SpriteAliveAlpha * colorAlpha[3] / 255.0), sAlpha, sizeof(sAlpha));

		int color[3];
		int now_weight = -1;
		int now_colortype = -1;

		int NowHP = IsPlayerState(i) ? GetSurvivorHP(i) : GetClientHealth(i);

		float vstart	= GetEntPropFloat(i, Prop_Send, "m_vomitStart");
		float vend		= GetEntPropFloat(i, Prop_Send, "m_vomitFadeStart");

		if (vstart > VomitStart[i] || vend > VomitEnd[i])
		{
			VomitStart[i] = vstart;
			VomitEnd[i] = vend;
			if (!IsBoomed[i])
			{
				IsBoomed[i] = true;
				CreateTimer(Boomed_Fade_Timer, ReCold_IsBoomed, i, TIMER_FLAG_NO_MAPCHANGE);
			}
		}

		if (IsPlayerState(i))
		{
			if (NowHP >= LimpHP)
			{
				now_weight = ColorsTypeWeight[0];
				now_colortype = 0;
			}
			else if (NowHP > 24)
			{
				now_weight = ColorsTypeWeight[1];
				now_colortype = 1;
			}
			else
			{
				now_weight = ColorsTypeWeight[2];
				now_colortype = 2;
			}
		}
		else if (IsPlayerFallen(i))
		{
			now_weight = ColorsTypeWeight[3];
			now_colortype = 3;
		}
		else if (IsPlayerFalling(i))
		{
			now_weight = ColorsTypeWeight[4];
			now_colortype = 4;
		}

		if (now_weight < ColorsTypeWeight[5] && GetEntProp(i, Prop_Send, "m_currentReviveCount") >= MaxIncapCount)
		{
			now_weight = ColorsTypeWeight[5];
			now_colortype = 5;
		}

		if (now_weight < ColorsTypeWeight[6] && IsPinned(i))
		{
			now_weight = ColorsTypeWeight[6];
			now_colortype = 6;
		}

		if (now_weight < ColorsTypeWeight[7] && IsBoomed[i])
		{
			now_weight = ColorsTypeWeight[7];
			now_colortype = 7;
		}

		if (now_weight < ColorsTypeWeight[8] && IsPlayerState(i) && !IsPinned(i) && IsGetUp[i])
		{
			if (!IsClientInGodFrames(i))
			{
				now_weight = ColorsTypeWeight[8];
				now_colortype = 8;
			}
		}

		for (int j = 0; j < 3 ; j++)
			color[j] = ColorsType[now_colortype][j];

		char rendercolor[12];
		Format(rendercolor, sizeof(rendercolor), "%i %i %i", color[0], color[1], color[2]);

		DispatchKeyValue(entity, "model", SpriteCustomVMTPathString);
		DispatchKeyValue(entity, "rendercolor", rendercolor);
		DispatchKeyValue(entity, "renderamt", sAlpha);
		DispatchKeyValue(entity, "renderfx", "0");
		DispatchKeyValue(entity, "scale", SpriteAliveScale);
		DispatchKeyValue(entity, "fademindist", "-1");
		DispatchSpawn(entity);

		SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", i);
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", i);
		AcceptEntityInput(entity, "ShowSprite");

		int entityFrame = INVALID_ENT_REFERENCE;

		if (SpriteFrameEntityID[i] != INVALID_ENT_REFERENCE)
			entityFrame = EntRefToEntIndex(SpriteFrameEntityID[i]);

		if (entityFrame == INVALID_ENT_REFERENCE)
		{
			entityFrame = CreateEntityByName("env_texturetoggle");
			SpriteFrameEntityID[i] = EntIndexToEntRef(entityFrame);
			IsSWPEntity[entityFrame] = false;
			DispatchKeyValue(entityFrame, "targetname", SpriteName);
			DispatchKeyValue(entityFrame, "target", SpriteName);
			DispatchSpawn(entityFrame);

			SetVariantString("!activator");
			AcceptEntityInput(entityFrame, "SetParent", entity);
		}

		int frame = IsPlayerState(i) ? NowHP : (NowHP * 100 / MaxIncapHP);

		if (SpriteAliveGetUpTimerEnable && now_colortype == 8)
		{
			float GameTimer = GetGameTime();
			frame = RoundToNearest((GetUpEnd[i] - GameTimer) / (GetUpEnd[i] - GetUpStart[i]) * 100.0);
		}

		if (SpriteAlivePinnedFromEnable && now_colortype == 6)
		{
			int infected = SurvivorPinnedFrom[i];
			if (CIsValidInfected(infected))
			{
				int Infected_NowHP = GetClientHealth(infected);
				int Infected_MaxHP = GetEntProp(infected, Prop_Data, "m_iMaxHealth");
				frame = Infected_NowHP * 100 / Infected_MaxHP;
			}
		}

		frame = CorrectInt(frame, 0, 100);

		char input[38];
		FormatEx(input, sizeof(input), "OnUser1 !self:SetTextureIndex:%i:0:1", frame);
		SetVariantString(input);
		AcceptEntityInput(entityFrame, "AddOutput");
		AcceptEntityInput(entityFrame, "FireUser1");

		if (!SpriteSWPEnable)
			continue;

		int entitySwp = INVALID_ENT_REFERENCE;

		if (SpriteSWPEntityID[i] != INVALID_ENT_REFERENCE)
			entitySwp = EntRefToEntIndex(SpriteSWPEntityID[i]);
		
		if (entitySwp == INVALID_ENT_REFERENCE)
		{
			float ClientPos[3];
			GetClientAbsOrigin(i, ClientPos);
			ClientPos[2] += SpriteSWPHigh;

			entitySwp = CreateEntityByName("env_sprite");
			SpriteSWPEntityID[i] = EntIndexToEntRef(entitySwp);
			IsSWPEntity[entitySwp] = true;
			EntityMyOwner[entitySwp] = i;
			DispatchKeyValue(entitySwp, "targetname", SWPName);
			DispatchKeyValue(entitySwp, "spawnflags", "1");
			DispatchKeyValueVector(entitySwp, "origin", ClientPos);

			SDKHook(entitySwp, SDKHook_SetTransmit, OnSetTransmit);
		}

		int MyWeapon		= GetEntPropEnt(i, Prop_Data, "m_hActiveWeapon");
		int MyClip			= -1;
		int Clip_Size		= 1;
		int FewClip			= 0;
		int swp_wepid		= IdentifyWeapon(MyWeapon);
		int swp_modelindex	= GetWepidModelIndex(swp_wepid);

		char Swprendercolor[12];
		
		if (IsAllowWepid(swp_wepid))
		{
			char weapon_name[64];
			GetClientWeapon(i, weapon_name, sizeof(weapon_name));
			MyClip		= GetEntProp(MyWeapon, Prop_Data, "m_iClip1");
			Clip_Size	= L4D2_GetIntWeaponAttribute(weapon_name, L4D2IWA_ClipSize);
			FewClip		= RoundToFloor(float(Clip_Size) * FewAmmoFloat);

			if (MyClip == 0)
				Format(Swprendercolor, sizeof(Swprendercolor), "%s", NoAmmoColors);
			else if (MyClip <= FewClip)
				Format(Swprendercolor, sizeof(Swprendercolor), "%s", FewAmmoColors);
		}

		if (MyClip == -1 || MyClip > FewClip)
			Format(Swprendercolor, sizeof(Swprendercolor), "%s", EnoughAmmoColors);

		char SwpsAlpha[4];
		IntToString(SpriteSWPAlpha, SwpsAlpha, sizeof(SwpsAlpha));

		DispatchKeyValue(entitySwp, "model", SpriteSWPVMTPathString[swp_modelindex]);
		DispatchKeyValue(entitySwp, "scale", SpriteSWPScale);
		DispatchKeyValue(entitySwp, "rendercolor", Swprendercolor);
		DispatchKeyValue(entitySwp, "renderamt", SwpsAlpha);
		DispatchKeyValue(entitySwp, "renderfx", "0");
		DispatchKeyValue(entitySwp, "fademindist", "-1");
		DispatchSpawn(entitySwp);

		SetEntPropEnt(entitySwp, Prop_Send, "m_hOwnerEntity", i);
		SetVariantString("!activator");
		AcceptEntityInput(entitySwp, "SetParent", i);
		AcceptEntityInput(entitySwp, "ShowSprite");

		int entitySwpFrame = INVALID_ENT_REFERENCE;

		if (SpriteSWPFrameEntityID[i] != INVALID_ENT_REFERENCE)
			entitySwpFrame = EntRefToEntIndex(SpriteSWPFrameEntityID[i]);

		if (entitySwpFrame == INVALID_ENT_REFERENCE)
		{
			entitySwpFrame = CreateEntityByName("env_texturetoggle");
			SpriteSWPFrameEntityID[i] = EntIndexToEntRef(entitySwpFrame);
			IsSWPEntity[entitySwpFrame] = false;
			DispatchKeyValue(entitySwpFrame, "targetname", SWPName);
			DispatchKeyValue(entitySwpFrame, "target", SWPName);
			DispatchSpawn(entitySwpFrame);

			SetVariantString("!activator");
			AcceptEntityInput(entitySwpFrame, "SetParent", entitySwp);
		}

		int swpframe = 98;

		switch (swp_modelindex)
		{
			case 0 :
			{
				switch (swp_wepid)
				{
					case 1 : // pistol  小手枪
					{
						if (GetEntProp(MyWeapon, Prop_Send, "m_isDualWielding", 1) > 0)
							swpframe = CorrectInt((MyClip + 20), 20, 59);
						else
							swpframe = CorrectInt(MyClip, 0, 19);
					}
					case 19 : // melee  近战
					{
						char sModelName[64];
						GetEntPropString(MyWeapon, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
						for (int j = 0; j < 13 ; j++)
						{
							if (strcmp(sModelName, MeleeModelNameString[j]) == 0)
							{
								swpframe = j + 81;
								break;
							}
						}
					}
					case 20 : // chainsaw  电锯
						swpframe = 99;
					case 32 : // magnum  马格南
						swpframe = CorrectInt((MyClip + 60), 60, 80);
				}
			}
			case 1 :
			{
				switch (swp_wepid)
				{
					case 2 : // UZI
						swpframe = CorrectInt(MyClip, 0, 70);
					case 3 : // pump_shotgun  木喷
						swpframe = CorrectInt((MyClip + 71), 71, 89);
					case 7 : // SMG
						swpframe = CorrectInt((MyClip + 90), 90, 160);
					case 8 : // shotgun_chrome  铁喷
						swpframe = CorrectInt((MyClip + 161), 161, 179);
					case 33 : // MP5
						swpframe = CorrectInt((MyClip + 180), 180, 250);
				}
			}
			case 2 :
			{
				switch (swp_wepid)
				{
					case 5 : // m16
						swpframe = CorrectInt(MyClip, 0, 54);
					case 9 : // SCAR
						swpframe = CorrectInt((MyClip + 60), 60, 120);
					case 26 : // AK47
						swpframe = CorrectInt((MyClip + 130), 130, 178);
					case 34 : // SG552
						swpframe = CorrectInt((MyClip + 180), 180, 234);
					case 37 : // M60
					{
						swpframe = MyClip == 0 ? 235 : (RoundToCeil(float(MyClip) / 10.0) + 235);
						swpframe = CorrectInt(swpframe, 235, 250);
					}
				}
			}
			case 3 :
			{
				switch (swp_wepid)
				{
					case 4 : // m1014  一代连喷
						swpframe = CorrectInt((MyClip + 150), 150, 178);
					case 6 : // hunting_rifle  15连狙
						swpframe = CorrectInt(MyClip, 0, 28);
					case 10 : // sniper_military  30连狙
						swpframe = CorrectInt((MyClip + 30), 30, 78);
					case 11 : // SPAS  二代连喷
						swpframe = CorrectInt((MyClip + 180), 180, 208);
					case 21 : // grenade_launcher  榴弹发射器
						swpframe = CorrectInt((MyClip + 210), 210, 220);
					case 35 : // AWP  大狙
						swpframe = CorrectInt((MyClip + 110), 110, 148);
					case 36 : // Scout  鸟狙
						swpframe = CorrectInt((MyClip + 80), 80, 108);
				}
			}
			case 4 :
				swpframe = CorrectInt(swp_wepid, 0, 37);
		}

		char swpinput[42];
		FormatEx(swpinput, sizeof(swpinput), "OnUser1 !self:SetTextureIndex:%i:0:1", swpframe);
		SetVariantString(swpinput);
		AcceptEntityInput(entitySwpFrame, "AddOutput");
		AcceptEntityInput(entitySwpFrame, "FireUser1");
	}
}

public void ReZero()
{
	for (int i = 1; i <= MaxClients ; i++)
	{
		CanShowSprite[i]			= false;
		SpriteEntityID[i]			= INVALID_ENT_REFERENCE;
		SpriteFrameEntityID[i]		= INVALID_ENT_REFERENCE;
		SpriteSWPEntityID[i]		= INVALID_ENT_REFERENCE;
		SpriteSWPFrameEntityID[i]	= INVALID_ENT_REFERENCE;
	}
}

public void KillSprite(int client)
{
	if (SpriteEntityID[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(SpriteEntityID[client]);

		if (entity != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(entity, "Kill");
			IsSWPEntity[entity] = false;
		}
		SpriteEntityID[client] = INVALID_ENT_REFERENCE;
	}

	if (SpriteFrameEntityID[client] != INVALID_ENT_REFERENCE)
	{
		int entityFrame = EntRefToEntIndex(SpriteFrameEntityID[client]);

		if (entityFrame != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(entityFrame, "Kill");
			IsSWPEntity[entityFrame] = false;
		}
		SpriteFrameEntityID[client] = INVALID_ENT_REFERENCE;
	}

	if (SpriteSWPEntityID[client] != INVALID_ENT_REFERENCE)
	{
		int entitySwp = EntRefToEntIndex(SpriteSWPEntityID[client]);

		if (entitySwp != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(entitySwp, "Kill");
			IsSWPEntity[entitySwp] = false;
		}
		SpriteSWPEntityID[client] = INVALID_ENT_REFERENCE;
	}

	if (SpriteSWPFrameEntityID[client] != INVALID_ENT_REFERENCE)
	{
		int entitySwpFrame = EntRefToEntIndex(SpriteSWPFrameEntityID[client]);

		if (entitySwpFrame != INVALID_ENT_REFERENCE)
		{
			AcceptEntityInput(entitySwpFrame, "Kill");
			IsSWPEntity[entitySwpFrame] = false;
		}
		SpriteSWPFrameEntityID[client] = INVALID_ENT_REFERENCE;
	}
}





// ====================================================================================================
// int
// ====================================================================================================

public int GetWepidModelIndex(int wepid)
{
	if (wepid == 1 || wepid == 32 || wepid == 19 || wepid == 20)
		return 0;
	
	if (wepid == 2 || wepid == 3 || wepid == 7 || wepid == 8 || wepid == 33)
		return 1;
	
	if (wepid == 5 || wepid == 9 || wepid == 26 || wepid == 34 || wepid == 37)
		return 2;
	
	if (wepid == 4 || wepid == 6 || wepid == 10 || wepid == 11 || wepid == 21 || wepid == 35 || wepid == 36)
		return 3;
	
	return 4;
}

// Int型变量修正
public int CorrectInt(int value, int min, int max)
{
	if (value < min)
		return min;
	
	if (value > max)
		return max;
	
	return value;
}

// 获取幸存者总生命值
public int GetSurvivorHP(int client)
{
	if (CIsValidSurvivor(client) && IsPlayerAlive(client))
		return (GetClientHealth(client) + GetPlayerTempHealth(client));
	return 0;
}

// 获取虚血值
public int GetPlayerTempHealth(int client)
{
	static Handle painPillsDecayCvar = null;
	if (painPillsDecayCvar == null)
	{
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
		if (painPillsDecayCvar == null)
			return -1;
	}

	float Buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float BufferTimer = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float Gfloat = GetConVarFloat(painPillsDecayCvar);
	int tempHealth = RoundToCeil(Buffer - ((GetGameTime() - BufferTimer) * Gfloat)) - 1;
	return tempHealth < 0 ? 0 : tempHealth;
}





// ====================================================================================================
// bool
// ====================================================================================================

// 判定是否为有效玩家序列
public bool CIsValidClientIndex(int client)
{
	return client > 0 && client <= MaxClients;
}

public bool CIsSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2;
}

public bool CIsInfected(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 3;
}

public bool CIsValidSurvivor(int client)
{
	return CIsValidClientIndex(client) && CIsSurvivor(client) && IsPlayerAlive(client);
}

public bool CIsValidInfected(int client)
{
	return CIsValidClientIndex(client) && CIsInfected(client) && IsPlayerAlive(client);
}

public bool IsAllowWepid(int wepid)
{
	if (wepid == 1 || wepid == 32)
		return true;
	
	if (wepid == 2 || wepid == 3 || wepid == 7 || wepid == 8 || wepid == 33)
		return true;
	
	if (wepid == 5 || wepid == 9 || wepid == 26 || wepid == 34 || wepid == 37)
		return true;
	
	if (wepid == 4 || wepid == 6 || wepid == 10 || wepid == 11 || wepid == 21 || wepid == 35 || wepid == 36)
		return true;

	return false;
}

// 判定幸存者是否为正常状态
public bool IsPlayerState(int client)
{
	return !GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

// 判定幸存者是否为倒地状态
public bool IsPlayerFallen(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && !GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

// 判定幸存者是否为挂边状态
public bool IsPlayerFalling(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") && GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
}

// 判定幸存者是否被控
public bool IsPinned(int client)
{
	return (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ||
			GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0);
}