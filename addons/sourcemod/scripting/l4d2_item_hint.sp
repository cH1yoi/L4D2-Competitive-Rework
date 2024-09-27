//fdxx, BHaType	@ 2021
//Harry @ 2022
//插件由 QQ：892510007 修改及补充

#pragma semicolon 1
#pragma newdecls required

#include <sdkhooks>
#include <sdktools>
#include <colors>
#include <sourcemod>

#define MAXENTITIES 2048
#define MODEL_MARK_FIELD 	"materials/sprites/laserbeam.vmt"
#define CLASSNAME_INFO_TARGET         "info_target"
#define CLASSNAME_ENV_SPRITE          "env_sprite"
#define ENTITY_WORLDSPAWN             0
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define ENTITY_SAFE_LIMIT 2000
#define L4D2_BEAM_LIFE_MIN 0.1
#define DIRECTION_OUT 0
#define DIRECTION_IN 1

ConVar g_hItemHintCoolDown, g_hSpotMarkCoolDown, g_hInfectedMarkCoolDown, g_hAllNumberTimes, g_hAllCycleTime, g_hAllAnnounceType,
	g_hItemUseHintRange, g_hAllUseSound, g_hItemUseSound, g_hItemAnnounceType, g_hItemGlowTimer, g_hItemGlowRange, g_hItemCvarColor,
	g_hItemInstructorHint, g_hItemInstructorColor, g_hItemInstructorIcon,g_hInfectedMarkLicense,g_hAllResAnnType,
	g_hSpotMarkUseRange, g_hSpotMarkUseSound, g_hSpotMarkGlowTimer, g_hSpotMarkCvarColor, g_hSpotMarkSpriteModel,
	g_hSpotMarkInstructorHint, g_hSpotMarkInstructorColor, g_hSpotMarkInstructorIcon,
	g_hInfectedMarkUseRange, g_hInfectedMarkUseSound, g_hInfectedMarkAnnounceType, g_hInfectedMarkGlowTimer, g_hInfectedMarkGlowRange, g_hInfectedMarkCvarColor, g_hInfectedMarkWitch;
int g_iAllNumberTimes, g_iItemAnnounceType, g_iItemGlowRange, g_iItemCvarColor, g_iAllAnnounceType, g_iAllResAnnType,
	g_iSpotMarkCvarColorArray[3],i_ItemsNumber[MAXENTITIES+1],
	g_iInfectedMarkAnnounceType, g_iInfectedMarkGlowRange, g_iInfectedMarkCvarColor;
float g_fItemHintCoolDown, g_fSpotMarkCoolDown, g_fInfectedMarkCoolDown,
	g_fItemUseHintRange, g_fItemGlowTimer, g_fAllCycleTime,
	g_fSpotMarkUseRange, g_fSpotMarkGlowTimer,
	g_fInfectedMarkUseRange, g_fInfectedMarkGlowTimer;
float       g_fItemHintCoolDownTime[MAXPLAYERS + 1], g_fSpotMarkCoolDownTime[MAXPLAYERS + 1], g_fInfectedMarkCoolDownTime[MAXPLAYERS + 1];
static char g_sItemInstructorColor[12], g_sItemInstructorIcon[16], g_sSpotMarkCvarColor[12], g_sAllUseSound[100], g_sItemUseSound[100], g_sSpotMarkUseSound[100], g_sKillDelay[32],
			g_sInfectedMarkUseSound[100], g_sSpotMarkInstructorColor[12], g_sSpotMarkInstructorIcon[16], g_sSpotMarkSpriteModel[PLATFORM_MAX_PATH];
bool g_bItemInstructorHint, g_bSpotMarkInstructorHint, g_bInfectedMarkLicense, g_bInfectedMarkWitch;


static bool   ge_bMoveUp[MAXENTITIES+1];
int       g_iModelIndex[MAXENTITIES+1] = {0};
Handle    g_iModelTimer[MAXENTITIES+1] = {null};
int       g_iInstructorIndex[MAXENTITIES+1] = {0};
Handle    g_iInstructorTimer[MAXENTITIES+1] = {null};
int       g_iTargetInstructorIndex[MAXENTITIES+1] = {0};
Handle    g_iTargetInstructorTimer[MAXENTITIES+1] = {null};
Handle    g_hUseEntity, increase=INVALID_HANDLE;
StringMap g_smModelToName;
StringMap g_smModelHeight;
bool g_bMapStarted;

enum EHintType {
	eItemHint,
	eSpotMarker,
	eInfectedMaker,
}

public Plugin myinfo =
{
	name        = "L4D2 Item hint",
	author      = "BHaType, fdxx, HarryPotter",
	description = "When using 'Look' in vocalize menu, print corresponding item to chat area and make item glow or create spot marker/infeced maker like back 4 blood.",
	version     = "2.3",
	url         = "https://forums.alliedmods.net/showpost.php?p=2765332&postcount=30"
};

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

public void OnAllPluginsLoaded()
{
	// Use Priority Patch
	if( FindConVar("l4d_use_priority_version") == null )
	{
		LogMessage("\n==========\nWarning: You should install \"[L4D & L4D2] Use Priority Patch\" to fix attached models blocking +USE action (item hint): https://forums.alliedmods.net/showthread.php?t=327511\n==========\n");
	}
}

public void OnPluginStart()
{
	GameData hGameData = new GameData("l4d2_item_hint");
	if (hGameData != null)
	{
		int iOffset = hGameData.GetOffset("FindUseEntity");
		if (iOffset != -1)
		{
			// https://forums.alliedmods.net/showpost.php?p=2753773&postcount=2
			StartPrepSDKCall(SDKCall_Player);
			PrepSDKCall_SetVirtual(iOffset);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
			PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
			g_hUseEntity = EndPrepSDKCall();
		}
		else SetFailState("Failed to load offset");
	}
	else SetFailState("Failed to load l4d2_item_hint.txt file");
	delete hGameData;

	// g_hItemUseHintRange = FindConVar("player_use_radius");
	AddCommandListener(Vocalize_Listener, "vocalize");

	g_hAllNumberTimes		= CreateConVar("l4d2_all_number_times", "3", "玩家每回合可以创建查看物品和标记的次数（0：不限制）", FCVAR_NOTIFY, true, 0.0);
	g_hAllCycleTime			= CreateConVar("l4d2_all_cycle_time", "180.0", "每隔多少秒给玩家增加1次标记次数（0：禁用）", FCVAR_NOTIFY, true, 0.0);
	g_hAllAnnounceType		= CreateConVar("l4d2_all_cycle_announce_type", "1", "增加标记次数的提示方式。（0：禁用，1：在聊天中，2：在提示框中，4：在屏幕中心；数字相加）", FCVAR_NOTIFY);
	g_hAllResAnnType		= CreateConVar("l4d2_all_residue_announce_type", "1", "剩余标记次数的提示方式。（0：禁用，1：在聊天中，2：在提示框中，4：在屏幕中心；数字相加）", FCVAR_NOTIFY);
	g_hAllUseSound 		    = CreateConVar("l4d2_all_use_sound", "ui/helpful_event_1.wav", "增加标记次数的提示音（格式一般是：“sound/”，无内容：禁用）", FCVAR_NOTIFY);
	g_hItemHintCoolDown		= CreateConVar("l4d2_item_hint_cooldown_time", "1.0", "玩家使用语音菜单“Z”键的“看”创建查看物品的冷却时间", FCVAR_NOTIFY, true, 0.0);
	g_hItemUseHintRange		= CreateConVar("l4d2_item_hint_use_range", "800", "玩家使用语音菜单查看物品最远距离", FCVAR_NOTIFY, true, 1.0);
	g_hItemUseSound			= CreateConVar("l4d2_item_hint_use_sound", "buttons/blip1.wav", "物品提示音（格式一般是：“sound/”，无内容：禁用）", FCVAR_NOTIFY);
	g_hItemAnnounceType		= CreateConVar("l4d2_item_hint_announce_type", "3", "物品提示的显示方式。（0：禁用，1：在聊天中，2：在提示框中，4：在屏幕中心；数字相加）", FCVAR_NOTIFY);
	g_hItemGlowTimer		= CreateConVar("l4d2_item_hint_glow_timer", "180.0", "物品发光的持续时间", FCVAR_NOTIFY, true, 0.0);
	g_hItemGlowRange		= CreateConVar("l4d2_item_hint_glow_range", "2000", "物品发光的范围", FCVAR_NOTIFY, true, 0.0);
	g_hItemCvarColor		= CreateConVar("l4d2_item_hint_glow_color", "0 255 255", "物品发光颜色：https://tool.oschina.net/commons?type=3（无内容：禁用物品发光）", FCVAR_NOTIFY);
	g_hItemInstructorHint	= CreateConVar("l4d2_item_instructorhint_enable", "1", "在物品上方显示物品提示（0：禁用，1启用）", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hItemInstructorColor	= CreateConVar("l4d2_item_instructorhint_color", "0 255 255", "物品上方提示的颜色", FCVAR_NOTIFY);
	g_hItemInstructorIcon	= CreateConVar("l4d2_item_instructorhint_icon", "icon_interact", "物品上方提示的图标：https://developer.valvesoftware.com/wiki/Env_instructor_hint", FCVAR_NOTIFY);

	g_hSpotMarkCoolDown			= CreateConVar("l4d2_spot_marker_cooldown_time", "1.0", "玩家使用语音菜单“Z”键的“看”创建标记的冷却时间", FCVAR_NOTIFY, true, 0.0);
	g_hSpotMarkUseRange     	= CreateConVar("l4d2_spot_marker_use_range", "2000", "玩家可以标记的最大范围", FCVAR_NOTIFY, true, 1.0);
	g_hSpotMarkUseSound     	= CreateConVar("l4d2_spot_marker_use_sound", "buttons/blip1.wav", "标记提示音（格式一般是：“sound/”，无内容：禁用）", FCVAR_NOTIFY);
	g_hSpotMarkGlowTimer		= CreateConVar("l4d2_spot_marker_duration", "120.0", "标记持续时间", FCVAR_NOTIFY, true, 0.0);
	g_hSpotMarkCvarColor		= CreateConVar("l4d2_spot_marker_color", "200 200 200", "标记颜色：https://tool.oschina.net/commons?type=3（无内容：禁用标记）", FCVAR_NOTIFY);
	g_hSpotMarkSpriteModel      = CreateConVar("l4d2_spot_marker_sprite_model", "materials/vgui/icon_arrow_down.vmt", "标记模型(无内容=禁用模型)");
	g_hSpotMarkInstructorHint	= CreateConVar("l4d2_spot_marker_instructorhint_enable", "1", "在标记上方创建标记提示（0：禁用，1启用）", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hSpotMarkInstructorColor	= CreateConVar("l4d2_spot_marker_instructorhint_color", "200 200 200", "标记上方提示的颜色：https://tool.oschina.net/commons?type=3", FCVAR_NOTIFY);
	g_hSpotMarkInstructorIcon	= CreateConVar("l4d2_spot_marker_instructorhint_icon", "icon_info", "标记上方提示图标", FCVAR_NOTIFY);

	g_hInfectedMarkLicense		= CreateConVar("l4d2_infected_marker_license", "0", "允许玩家标记特殊感染者（0：禁止，1：允许）", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hInfectedMarkCoolDown		= CreateConVar("l4d2_infected_marker_cooldown_time", "1.0", "玩家使用语音菜单“Z”键的“看”标记发光特殊感染者的冷却时间", FCVAR_NOTIFY, true, 0.0);
	g_hInfectedMarkUseRange     = CreateConVar("l4d2_infected_marker_use_range", "2000", "玩家多远可以标记特殊感染者", FCVAR_NOTIFY, true, 1.0);
	g_hInfectedMarkUseSound		= CreateConVar("l4d2_infected_marker_use_sound", "items/suitchargeok1.wav", "标记特殊感染者的提示音（格式一般是：sound/,无内容：禁用）", FCVAR_NOTIFY);
	g_hInfectedMarkAnnounceType	= CreateConVar("l4d2_infected_marker_announce_type", "3", "特殊感染者提示的显示方式。(0：禁用，1：在聊天中，2：在提示框中，4：在屏幕中心；数字相加）", FCVAR_NOTIFY, true);
	g_hInfectedMarkGlowTimer   	= CreateConVar("l4d2_infected_marker_glow_timer", "3.0", "特殊感染者标记的持续时间", FCVAR_NOTIFY, true, 0.0);
	g_hInfectedMarkGlowRange   	= CreateConVar("l4d2_infected_marker_glow_range", "2500", "特殊感染者可视的最大距离", FCVAR_NOTIFY, true, 0.0);
	g_hInfectedMarkCvarColor   	= CreateConVar("l4d2_infected_marker_glow_color", "255 120 203", "特殊感染者标记颜色：https://tool.oschina.net/commons?type=3（无内容=禁用特殊感染者发光）", FCVAR_NOTIFY);
	g_hInfectedMarkWitch    	= CreateConVar("l4d2_infected_marker_witch_enable", "1", "可以标记Witch（0：禁用，1启用）", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	AutoExecConfig(true, "l4d2_item_hint");

	GetCvars();
	g_hAllNumberTimes.AddChangeHook(ConVarChanged_Cvars);
	g_hAllCycleTime.AddChangeHook(ConVarChanged_Cvars);
	g_hAllAnnounceType.AddChangeHook(ConVarChanged_Cvars);
	g_hAllResAnnType.AddChangeHook(ConVarChanged_Cvars);
	g_hAllUseSound.AddChangeHook(ConVarChanged_Cvars);
	g_hItemHintCoolDown.AddChangeHook(ConVarChanged_Cvars);
	g_hItemUseHintRange.AddChangeHook(ConVarChanged_Cvars);
	g_hItemUseSound.AddChangeHook(ConVarChanged_Cvars);
	g_hItemAnnounceType.AddChangeHook(ConVarChanged_Cvars);
	g_hItemGlowTimer.AddChangeHook(ConVarChanged_Cvars);
	g_hItemGlowRange.AddChangeHook(ConVarChanged_Cvars);
	g_hItemCvarColor.AddChangeHook(ConVarChanged_Cvars);
	g_hItemInstructorHint.AddChangeHook(ConVarChanged_Cvars);
	g_hItemInstructorColor.AddChangeHook(ConVarChanged_Cvars);
	g_hItemInstructorIcon.AddChangeHook(ConVarChanged_Cvars);

	g_hSpotMarkCoolDown.AddChangeHook(ConVarChanged_Cvars);
	g_hSpotMarkUseRange.AddChangeHook(ConVarChanged_Cvars);
	g_hSpotMarkUseSound.AddChangeHook(ConVarChanged_Cvars);
	g_hSpotMarkGlowTimer.AddChangeHook(ConVarChanged_Cvars);
	g_hSpotMarkCvarColor.AddChangeHook(ConVarChanged_Cvars);
	g_hSpotMarkSpriteModel.AddChangeHook(ConVarChanged_Cvars);
	g_hSpotMarkInstructorHint.AddChangeHook(ConVarChanged_Cvars);
	g_hSpotMarkInstructorColor.AddChangeHook(ConVarChanged_Cvars);
	g_hSpotMarkInstructorIcon.AddChangeHook(ConVarChanged_Cvars);

	g_hInfectedMarkLicense.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedMarkCoolDown.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedMarkUseRange.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedMarkUseSound.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedMarkAnnounceType.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedMarkGlowTimer.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedMarkGlowRange.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedMarkCvarColor.AddChangeHook(ConVarChanged_Cvars);
	g_hInfectedMarkWitch.AddChangeHook(ConVarChanged_Cvars);

	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_Round_End_Host);
	HookEvent("map_transition", Event_Round_End);         //戰役過關到下一關的時候 (沒有觸發round_end)
	HookEvent("mission_lost", Event_Round_End);           //戰役滅團重來該關卡的時候 (之後有觸發round_end)
	HookEvent("finale_vehicle_leaving", Event_Round_End); //救援載具離開之時  (沒有觸發round_end)
	HookEvent("spawner_give_item", Event_SpawnerGiveItem);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("witch_killed", Event_WitchKilled);

	CreateStringMap();

	if (bLate)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
			i_ItemsNumber[i] = g_iAllNumberTimes;
		}

		char classname[21];
		int entity;

		classname = "prop_minigun_l4d1";
		entity = INVALID_ENT_REFERENCE;
		while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
		{
			if(!IsValidEntity(entity)) continue;
			
			SDKHook(entity, SDKHook_UsePost, OnUse);
		}

		classname = "prop_minigun";
		entity = INVALID_ENT_REFERENCE;
		while ((entity = FindEntityByClassname(entity, classname)) != INVALID_ENT_REFERENCE)
		{
			if(!IsValidEntity(entity)) continue;
			
			SDKHook(entity, SDKHook_UsePost, OnUse);
		}
	}
}

public void OnPluginEnd()
{
	delete g_smModelToName;
	delete g_smModelHeight;
	RemoveAllGlow_Timer();
	RemoveAllSpotMark();
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_fAllCycleTime = g_hAllCycleTime.FloatValue;
	g_iAllNumberTimes = g_hAllNumberTimes.IntValue;
	g_iAllAnnounceType = g_hAllAnnounceType.IntValue;
	g_iAllResAnnType = g_hAllResAnnType.IntValue;
	g_hAllUseSound.GetString(g_sAllUseSound, sizeof(g_sAllUseSound));
	if (strlen(g_sSpotMarkUseSound) > 0 && g_bMapStarted) PrecacheSound(g_sAllUseSound);
	g_fItemHintCoolDown = g_hItemHintCoolDown.FloatValue;
	g_fItemUseHintRange = g_hItemUseHintRange.FloatValue;
	g_hItemUseSound.GetString(g_sItemUseSound, sizeof(g_sItemUseSound));
	if (strlen(g_sItemUseSound) > 0 && g_bMapStarted) PrecacheSound(g_sItemUseSound);
	g_iItemAnnounceType = g_hItemAnnounceType.IntValue;
	g_fItemGlowTimer      = g_hItemGlowTimer.FloatValue;
	g_iItemGlowRange 	= g_hItemGlowRange.IntValue;
	char sColor[16];
	g_hItemCvarColor.GetString(sColor, sizeof(sColor));
	g_iItemCvarColor = GetColor(sColor);
	g_bItemInstructorHint = g_hItemInstructorHint.BoolValue;
	g_hItemInstructorColor.GetString(g_sItemInstructorColor, sizeof(g_sItemInstructorColor));
	TrimString(g_sItemInstructorColor);
	g_hItemInstructorIcon.GetString(g_sItemInstructorIcon, sizeof(g_sItemInstructorIcon));

	g_fSpotMarkCoolDown = g_hSpotMarkCoolDown.FloatValue;
	g_fSpotMarkUseRange = g_hSpotMarkUseRange.FloatValue;
	g_hSpotMarkUseSound.GetString(g_sSpotMarkUseSound, sizeof(g_sSpotMarkUseSound));
	if (strlen(g_sSpotMarkUseSound) > 0 && g_bMapStarted) PrecacheSound(g_sSpotMarkUseSound);
	g_fSpotMarkGlowTimer = g_hSpotMarkGlowTimer.FloatValue;
	FormatEx(g_sKillDelay, sizeof(g_sKillDelay), "OnUser1 !self:Kill::%.2f:-1", g_fSpotMarkGlowTimer);
	g_hSpotMarkCvarColor.GetString(g_sSpotMarkCvarColor, sizeof(g_sSpotMarkCvarColor));
	TrimString(g_sSpotMarkCvarColor);
	g_iSpotMarkCvarColorArray = ConvertRGBToIntArray(g_sSpotMarkCvarColor);
	g_hSpotMarkSpriteModel.GetString(g_sSpotMarkSpriteModel, sizeof(g_sSpotMarkSpriteModel));
	TrimString(g_sSpotMarkSpriteModel);
	if ( strlen(g_sSpotMarkSpriteModel) > 0 && g_bMapStarted) PrecacheModel(g_sSpotMarkSpriteModel, true);
	g_bSpotMarkInstructorHint = g_hSpotMarkInstructorHint.BoolValue;
	g_hSpotMarkInstructorColor.GetString(g_sSpotMarkInstructorColor, sizeof(g_sSpotMarkInstructorColor));
	TrimString(g_sSpotMarkInstructorColor);
	g_hSpotMarkInstructorIcon.GetString(g_sSpotMarkInstructorIcon, sizeof(g_sSpotMarkInstructorIcon));

	g_bInfectedMarkLicense = g_hInfectedMarkLicense.BoolValue;
	g_fInfectedMarkCoolDown = g_hInfectedMarkCoolDown.FloatValue;
	g_fInfectedMarkUseRange = g_hInfectedMarkUseRange.FloatValue;
	g_hInfectedMarkUseSound.GetString(g_sInfectedMarkUseSound, sizeof(g_sInfectedMarkUseSound));
	if (strlen(g_sInfectedMarkUseSound) > 0 && g_bMapStarted) PrecacheSound(g_sInfectedMarkUseSound);
	g_iInfectedMarkAnnounceType = g_hInfectedMarkAnnounceType.IntValue;
	g_fInfectedMarkGlowTimer = g_hInfectedMarkGlowTimer.FloatValue;
	g_iInfectedMarkGlowRange = g_hInfectedMarkGlowRange.IntValue;
	g_hInfectedMarkCvarColor.GetString(sColor, sizeof(sColor));
	g_iInfectedMarkCvarColor = GetColor(sColor);
	g_bInfectedMarkWitch = g_hInfectedMarkWitch.BoolValue;
}

void CreateStringMap()
{
	g_smModelToName = new StringMap();

	// Case-sensitive
	g_smModelToName.SetString("models/w_models/weapons/w_eq_medkit.mdl", "急救包");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_defibrillator.mdl", "心脏除颤器");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_painpills.mdl", "止痛药");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_adrenaline.mdl", "肾上腺素");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_bile_flask.mdl", "胆汁");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_molotov.mdl", "燃烧瓶");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_pipebomb.mdl", "土制炸弹");
	g_smModelToName.SetString("models/w_models/weapons/w_laser_sights.mdl", "激光瞄准器");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_incendiary_ammopack.mdl", "燃烧弹部署盒");
	g_smModelToName.SetString("models/w_models/weapons/w_eq_explosive_ammopack.mdl", "高爆弹部署盒");
	g_smModelToName.SetString("models/props/terror/ammo_stack.mdl", "弹药堆");
	g_smModelToName.SetString("models/props_unique/spawn_apartment/coffeeammo.mdl", "弹药堆");
	g_smModelToName.SetString("models/props/de_prodigy/ammo_can_02.mdl", "弹药堆");
	g_smModelToName.SetString("models/weapons/melee/w_chainsaw.mdl", "电锯");
	g_smModelToName.SetString("models/w_models/weapons/w_pistol_b.mdl", "P226");
	g_smModelToName.SetString("models/w_models/weapons/w_pistol_a.mdl", "P226");
	g_smModelToName.SetString("models/w_models/weapons/w_desert_eagle.mdl", "Magnum");
	g_smModelToName.SetString("models/w_models/weapons/w_shotgun.mdl", "Pump");
	g_smModelToName.SetString("models/w_models/weapons/w_pumpshotgun_a.mdl", "Chrome");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_uzi.mdl", "UZI");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_a.mdl", "MAC10");
	g_smModelToName.SetString("models/w_models/weapons/w_smg_mp5.mdl", "MP5");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_m16a2.mdl", "M16");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_sg552.mdl", "SG552");
	g_smModelToName.SetString("models/w_models/weapons/w_rifle_ak47.mdl", "AK47");
	g_smModelToName.SetString("models/w_models/weapons/w_desert_rifle.mdl", "SCAR");
	g_smModelToName.SetString("models/w_models/weapons/w_shotgun_spas.mdl", "SPAS-12");
	g_smModelToName.SetString("models/w_models/weapons/w_autoshot_m4super.mdl", "XM1014");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_mini14.mdl", "MINI14");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_military.mdl", "G3SG1");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_scout.mdl", "Scout");
	g_smModelToName.SetString("models/w_models/weapons/w_sniper_awp.mdl", "AWP");
	g_smModelToName.SetString("models/w_models/weapons/w_grenade_launcher.mdl", "Grenade Launcher");
	g_smModelToName.SetString("models/w_models/weapons/w_m60.mdl", "M60");
	g_smModelToName.SetString("models/props_junk/gascan001a.mdl", "汽油桶");
	g_smModelToName.SetString("models/props_junk/explosive_box001.mdl", "烟花礼盒");
	g_smModelToName.SetString("models/props_junk/propanecanister001a.mdl", "煤气罐");
	g_smModelToName.SetString("models/props_equipment/oxygentank01.mdl", "氧气瓶");
	g_smModelToName.SetString("models/props_junk/gnome.mdl", "玩偶");
	g_smModelToName.SetString("models/w_models/weapons/w_cola.mdl", "可乐");
	g_smModelToName.SetString("models/w_models/weapons/50cal.mdl", "重机枪炮台");
	g_smModelToName.SetString("models/w_models/weapons/w_minigun.mdl", "轻机枪炮台");
	g_smModelToName.SetString("models/props/terror/exploding_ammo.mdl", "高爆弹药盒");
	g_smModelToName.SetString("models/props/terror/incendiary_ammo.mdl", "燃烧弹药盒");
	g_smModelToName.SetString("models/w_models/weapons/w_knife_t.mdl", "海豹短刀");
	g_smModelToName.SetString("models/weapons/melee/w_bat.mdl", "棒球棍");
	g_smModelToName.SetString("models/weapons/melee/w_cricket_bat.mdl", "板球拍");
	g_smModelToName.SetString("models/weapons/melee/w_crowbar.mdl", "撬棍");
	g_smModelToName.SetString("models/weapons/melee/w_electric_guitar.mdl", "吉他");
	g_smModelToName.SetString("models/weapons/melee/w_fireaxe.mdl", "消防斧");
	g_smModelToName.SetString("models/weapons/melee/w_frying_pan.mdl", "平底锅");
	g_smModelToName.SetString("models/weapons/melee/w_katana.mdl", "武士刀");
	g_smModelToName.SetString("models/weapons/melee/w_machete.mdl", "砍刀");
	g_smModelToName.SetString("models/weapons/melee/w_tonfa.mdl", "警棍");
	g_smModelToName.SetString("models/weapons/melee/w_golfclub.mdl", "高尔夫球杆");
	g_smModelToName.SetString("models/weapons/melee/w_pitchfork.mdl", "草叉");
	g_smModelToName.SetString("models/weapons/melee/w_shovel.mdl", "铁铲");
	g_smModelToName.SetString("models/infected/boomette.mdl", "Boomer");
	g_smModelToName.SetString("models/infected/boomer.mdl", "Boomer");
	g_smModelToName.SetString("models/infected/boomer_l4d1.mdl", "Boomer");
	g_smModelToName.SetString("models/infected/hulk.mdl", "Tank");
	g_smModelToName.SetString("models/infected/hulk_l4d1.mdl", "Tank");
	g_smModelToName.SetString("models/infected/hulk_dlc3.mdl", "Tank");
	g_smModelToName.SetString("models/infected/smoker.mdl", "Smoker");
	g_smModelToName.SetString("models/infected/smoker_l4d1.mdl", "Smoker");
	g_smModelToName.SetString("models/infected/hunter.mdl", "Hunter");
	g_smModelToName.SetString("models/infected/hunter_l4d1.mdl", "Hunter");
	g_smModelToName.SetString("models/infected/witch.mdl", "Witch");
	g_smModelToName.SetString("models/infected/witch_bride.mdl", "Witch");
	g_smModelToName.SetString("models/infected/spitter.mdl", "Spitter");
	g_smModelToName.SetString("models/infected/jockey.mdl", "Jockey");
	g_smModelToName.SetString("models/infected/charger.mdl", "Charger");

	g_smModelHeight = CreateTrie();

	// Case-sensitive
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_medkit.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_defibrillator.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_painpills.mdl", 5.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_adrenaline.mdl", 5.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_bile_flask.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_molotov.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_pipebomb.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_laser_sights.mdl", 18.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_incendiary_ammopack.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_eq_explosive_ammopack.mdl", 10.0);
	g_smModelHeight.SetValue("models/props/terror/ammo_stack.mdl", 5.0);
	g_smModelHeight.SetValue("models/props_unique/spawn_apartment/coffeeammo.mdl", 15.0);
	g_smModelHeight.SetValue("models/props/de_prodigy/ammo_can_02.mdl", 10.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_chainsaw.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_pistol_b.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_pistol_a.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_desert_eagle.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_shotgun.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_pumpshotgun_a.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_smg_uzi.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_smg_a.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_smg_mp5.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_rifle_m16a2.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_rifle_sg552.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_rifle_ak47.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_desert_rifle.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_shotgun_spas.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_autoshot_m4super.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_sniper_mini14.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_sniper_military.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_sniper_scout.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_sniper_awp.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_grenade_launcher.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_m60.mdl", 10.0);
	g_smModelHeight.SetValue("models/props_junk/gascan001a.mdl", 5.0);
	g_smModelHeight.SetValue("models/props_junk/explosive_box001.mdl", 5.0);
	g_smModelHeight.SetValue("models/props_junk/propanecanister001a.mdl", 5.0);
	g_smModelHeight.SetValue("models/props_equipment/oxygentank01.mdl", 5.0);
	g_smModelHeight.SetValue("models/props_junk/gnome.mdl", 10.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_cola.mdl", 5.0);
	g_smModelHeight.SetValue("models/w_models/weapons/50cal.mdl", 55.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_minigun.mdl", 55.0);
	g_smModelHeight.SetValue("models/props/terror/exploding_ammo.mdl", 15.0);
	g_smModelHeight.SetValue("models/props/terror/incendiary_ammo.mdl", 15.0);
	g_smModelHeight.SetValue("models/w_models/weapons/w_knife_t.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_bat.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_cricket_bat.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_crowbar.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_electric_guitar.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_fireaxe.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_frying_pan.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_katana.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_machete.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_tonfa.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_golfclub.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_pitchfork.mdl", 5.0);
	g_smModelHeight.SetValue("models/weapons/melee/w_shovel.mdl", 5.0);
}

int g_iFieldModelIndex;
public void OnMapStart()
{
	g_bMapStarted = true;
	if (strlen(g_sAllUseSound) > 0) PrecacheSound(g_sAllUseSound);
	if (strlen(g_sItemUseSound) > 0) PrecacheSound(g_sItemUseSound);
	if (strlen(g_sSpotMarkUseSound) > 0) PrecacheSound(g_sSpotMarkUseSound);
	if (strlen(g_sInfectedMarkUseSound) > 0) PrecacheSound(g_sInfectedMarkUseSound);
	g_iFieldModelIndex = PrecacheModel(MODEL_MARK_FIELD, true);
	if ( strlen(g_sSpotMarkSpriteModel) > 0 ) PrecacheModel(g_sSpotMarkSpriteModel, true);

}

public void OnMapEnd()
{
	g_bMapStarted = false;
	RemoveAllGlow_Timer();
}

public void OnClientPutInServer(int client)
{
	Clear(client);
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
}

public void OnWeaponEquipPost(int client, int weapon)
{
	if (!IsValidEntity(weapon))
		return;

	RemoveEntityModelGlow(weapon);
	delete g_iModelTimer[weapon];

	RemoveInstructor(weapon);
	delete g_iInstructorTimer[weapon];

	RemoveTargetInstructor(weapon);
	delete g_iTargetInstructorTimer[weapon];
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	Clear();
	if(g_fAllCycleTime>0)
		increase = CreateTimer(g_fAllCycleTime, NumberTimesPlusOne, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action NumberTimesPlusOne(Handle timer)
{
	for (int k = 1; k <= MaxClients; k++)
	{
		if(i_ItemsNumber[k] < g_iAllNumberTimes)
		{
			i_ItemsNumber[k]++;
			if(IsClientInGame(k) && g_iAllNumberTimes>0)
			{
				switch(g_iAllAnnounceType)
				{
					case 0:{/*nothing*/}
					case 1:SwitchAllAnnounceType(k,1);
					case 2:SwitchAllAnnounceType(k,2);
					case 4:SwitchAllAnnounceType(k,4);
					
					case 3:{SwitchAllAnnounceType(k,1);SwitchAllAnnounceType(k,2);}
					case 5:{SwitchAllAnnounceType(k,1);SwitchAllAnnounceType(k,4);}
					case 6:{SwitchAllAnnounceType(k,2);SwitchAllAnnounceType(k,4);}
					case 7:{SwitchAllAnnounceType(k,1);SwitchAllAnnounceType(k,2);SwitchAllAnnounceType(k,4);}
				}
				if (strlen(g_sSpotMarkUseSound) > 0)
					EmitSoundToClient(k, g_sAllUseSound);
			}
		}
	}
	return Plugin_Continue;
}

public void SwitchAllAnnounceType(int player, int select)
{
	switch(select)
	{
		case 1:PrintToChat(player, "\x04[提示]\x03标记次数加\x011\x03，剩余\x01%d/%d\x03次。", i_ItemsNumber[player], g_iAllNumberTimes);
		case 2:PrintHintText(player, "标记次数加1，剩余〈%d/%d〉次。", i_ItemsNumber[player], g_iAllNumberTimes);
		case 4:PrintCenterText(player, "标记次数加1，剩余〈%d/%d〉次。", i_ItemsNumber[player], g_iAllNumberTimes);
	}
}

public void Event_Round_End(Event event, const char[] name, bool dontBroadcast)
{
	RemoveAllGlow_Timer();
	RemoveAllSpotMark();
}

public void Event_Round_End_Host(Event event, const char[] name, bool dontBroadcast)
{
	RemoveAllGlow_Timer();
	RemoveAllSpotMark();
	
	if(increase != INVALID_HANDLE)
	{
		KillTimer(increase);
		increase = INVALID_HANDLE;
	}
}

public void Event_SpawnerGiveItem(Event event, const char[] name, bool dontBroadcast)
{
	int entity = event.GetInt("spawner");
	int count  = GetEntProp(entity, Prop_Data, "m_itemCount");

	if (count <= 1)
	{
		RemoveEntityModelGlow(entity);
		delete g_iModelTimer[entity];

		RemoveInstructor(entity);
		delete g_iInstructorTimer[entity];

		RemoveTargetInstructor(entity);
		delete g_iTargetInstructorTimer[entity];
	}
}

public void L4D_OnEnterGhostState(int client)
{
	RemoveEntityModelGlow(client);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	RemoveEntityModelGlow(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	RemoveEntityModelGlow(GetClientOfUserId(event.GetInt("userid")));
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	//infected
	int infected = GetClientOfUserId(event.GetInt("userid"));
	if(infected && IsClientInGame(infected))
		RemoveEntityModelGlow(infected);
}

public void Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
	RemoveEntityModelGlow(event.GetInt("witchid"));
}

public Action Vocalize_Listener(int client, const char[] command, int argc)
{
	if (IsRealSur(client) && !IsHandingFromLedge(client) && GetInfectedAttacker(client) == -1)
	{
		static char sCmdString[32];
		if (GetCmdArgString(sCmdString, sizeof(sCmdString)) > 1)
		{
			if (strncmp(sCmdString, "smartlook #", 11, false) == 0)
			{
				bool bIsAimInfeced = false, bIsAimWitch = false, bIsVaildItem = false;
				static char sItemName[64], sEntModelName[PLATFORM_MAX_PATH];

				// marker priority (infected maker > item hint > spot marker)

				if (g_iInfectedMarkCvarColor != 0)
				{
					int clientAim = GetClientViewClient(client); //ignore glow model

					if (1 <= clientAim <= MaxClients && IsClientInGame(clientAim) && GetClientTeam(clientAim) == TEAM_INFECTED && IsPlayerAlive(clientAim) && !IsPlayerGhost(clientAim))
					{
						bIsAimInfeced = true;
						//PrintToChatAll("look at %N", clientAim);
						
						if( CreateInfectedMarker(client, clientAim) == true )
							return Plugin_Continue;
					}
					else if ( IsWitch(clientAim) )
					{
						bIsAimWitch = true;

						if( CreateInfectedMarker(client, clientAim, true) == true )
							return Plugin_Continue;
					}
				}

				static int iEntity;
				iEntity = GetUseEntity(client, g_fItemUseHintRange);
				//PrintToChatAll("%N is looking at %d", client, iEntity);
				if ( !bIsAimInfeced && !bIsAimWitch && IsValidEntityIndex(iEntity) && IsValidEntity(iEntity) && HasParentClient(iEntity) == false )
				{
					static char targetname[128];
					GetEntPropString(iEntity, Prop_Data, "m_iName", targetname, sizeof(targetname));
					if (strcmp(targetname, "harry_marked_item") == 0) //custom model
					{
						iEntity = GetEntPropEnt(iEntity, Prop_Data, "m_pParent");
					}

					if (HasEntProp(iEntity, Prop_Data, "m_ModelName"))
					{
						if (GetEntPropString(iEntity, Prop_Data, "m_ModelName", sEntModelName, sizeof(sEntModelName)) > 1)
						{
							//PrintToChatAll("Model - %s", sEntModelName);
							StringToLowerCase(sEntModelName);
							float fHeight = 10.0;
							if (g_smModelToName.GetString(sEntModelName, sItemName, sizeof(sItemName)))
							{
								g_smModelHeight.GetValue(sEntModelName, fHeight);
								bIsVaildItem = true;
							}
							else if (StrContains(sEntModelName, "/melee/") != -1) // entity is not in the listb(custom melee weapon model)
							{
								FormatEx(sItemName, sizeof sItemName, "%s", "Melee!");
								fHeight = 5.0;

								bIsVaildItem = true;
							}
							else if (StrContains(sEntModelName, "/weapons/") != -1) // entity is not in the list (custom weapom model)
							{
								FormatEx(sItemName, sizeof sItemName, "%s", "Weapons!");
								fHeight = 10.0;

								bIsVaildItem = true;
							}
							else // entity is not in the list (other entity model on the map)
							{
								bIsVaildItem = false;
							}

							if(bIsVaildItem)
							{
								if(i_ItemsNumber[client]>0 || g_iAllNumberTimes==0)
								{
									if(GetEngineTime() > g_fItemHintCoolDownTime[client])
									{
										i_ItemsNumber[client]--;
										
										if(g_iAllNumberTimes>0)
											switch(g_iAllResAnnType)
											{
												case 1:SwitchAllResAnnType(client,1);
												case 2:SwitchAllResAnnType(client,2);
												case 4:SwitchAllResAnnType(client,4);
												
												case 3:{SwitchAllResAnnType(client,1);SwitchAllResAnnType(client,2);}
												case 5:{SwitchAllResAnnType(client,1);SwitchAllResAnnType(client,4);}
												case 6:{SwitchAllResAnnType(client,2);SwitchAllResAnnType(client,4);}
												case 7:{SwitchAllResAnnType(client,1);SwitchAllResAnnType(client,2);SwitchAllResAnnType(client,4);}
											}
										
										NotifyMessage(client, sItemName, view_as<EHintType>(eItemHint));
										if (strlen(g_sItemUseSound) > 0)
										{
											for (int target = 1; target <= MaxClients; target++)
											{
												if (!IsClientInGame(target))
													continue;

												if (IsFakeClient(target))
													continue;

												if (GetClientTeam(target) == TEAM_INFECTED)
													continue;

												EmitSoundToClient(target, g_sItemUseSound, client);
											}
										}

										g_fItemHintCoolDownTime[client] = GetEngineTime() + g_fItemHintCoolDown;
										CreateEntityModelGlow(iEntity, sEntModelName);

										if(g_bItemInstructorHint)
										{
											float vEndPos[3];
											GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vEndPos);
											vEndPos[2] = vEndPos[2] + fHeight;
											CreateInstructorHint(client, vEndPos, sItemName, iEntity, view_as<EHintType>(eItemHint));
										}
									}
								}
								return Plugin_Continue;
							}
						}
					}
				}

				// client / world / witch
				CreateSpotMarker(client, bIsAimInfeced);
			}
		}
	}

	return Plugin_Continue;
}

public void SwitchAllResAnnType(int client, int select)
{
		switch(select)
		{
			case 0:{}
			case 1:
			{
				if(i_ItemsNumber[client]>0)
					PrintToChat(client, "\x04[提示]\x03还剩\x01%d\x03次标记次数。", i_ItemsNumber[client]);
				else
					PrintToChat(client, "\x04[提示]\x03标记次数已用尽。");
			}
			case 2:
			{
				if(i_ItemsNumber[client]>0)
					PrintHintText(client, "还剩%d次标记次数", i_ItemsNumber[client]);
				else
					PrintHintText(client, "标记次数已用尽");
			}
			case 4:
			{
				if(i_ItemsNumber[client]>0)
					PrintCenterText(client, "还剩%d次标记次数", i_ItemsNumber[client]);
				else
					PrintCenterText(client, "标记次数已用尽");
			}
		}
}

public Action Timer_ItemGlow(Handle timer, int iEntity)
{
	RemoveEntityModelGlow(iEntity);
	g_iModelTimer[iEntity] = null;

	return Plugin_Continue;
}

void RemoveEntityModelGlow(int iEntity)
{
	int glowentity = g_iModelIndex[iEntity];
	g_iModelIndex[iEntity] = 0;

	if (IsValidEntRef(glowentity))
		RemoveEntity(glowentity);
}

int GetUseEntity(int client, float fRadius)
{
	return SDKCall(g_hUseEntity, client, fRadius, 0.0, 0.0, 0, 0);
}

bool IsRealSur(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR && IsPlayerAlive(client) && !IsFakeClient(client));
}

void Clear(int client = -1)
{
	if (client == -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			g_fItemHintCoolDownTime[i] = 0.0;
			g_fSpotMarkCoolDownTime[i] = 0.0;
			g_fInfectedMarkCoolDownTime[i] = 0.0;
			i_ItemsNumber[i] = g_iAllNumberTimes;
		}
	}
	else
	{
		g_fItemHintCoolDownTime[client] = 0.0;
		g_fSpotMarkCoolDownTime[client] = 0.0;
		g_fInfectedMarkCoolDownTime[client] = 0.0;
		i_ItemsNumber[client] = g_iAllNumberTimes;
	}
}

int GetColor(char[] sTemp)
{
	if (StrEqual(sTemp, ""))
		return 0;

	char sColors[3][4];
	int  color = ExplodeString(sTemp, " ", sColors, 3, 4);

	if (color != 3)
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

bool IsValidEntRef(int entity)
{
	if (entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE)
		return true;
	return false;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	switch (classname[0])
	{
		case 'p':
		{
			if( strcmp(classname, "prop_minigun_l4d1") == 0 )
			{
				SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
			}
			else if( strcmp(classname, "prop_minigun") == 0 )
			{
				SDKHook(entity, SDKHook_SpawnPost, SpawnPost);
			}
		}
	}
}

void SpawnPost(int entity)
{
    // Validate
    if( !IsValidEntity(entity) ) return;

    SDKHook(entity, SDKHook_UsePost, OnUse);
}

public void OnUse(int weapon, int client, int caller, UseType type, float value)
{
	if(client && IsClientInGame(client))
	{
		RemoveEntityModelGlow(weapon);
		delete g_iModelTimer[weapon];

		RemoveInstructor(weapon);
		delete g_iInstructorTimer[weapon];

		RemoveTargetInstructor(weapon);
		delete g_iTargetInstructorTimer[weapon];
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntityIndex(entity))
		return;

	RemoveEntityModelGlow(entity);
	delete g_iModelTimer[entity];

	RemoveInstructor(entity);
	delete g_iInstructorTimer[entity];

	RemoveTargetInstructor(entity);
	delete g_iTargetInstructorTimer[entity];

	ge_bMoveUp[entity] = false;
}

void RemoveAllGlow_Timer()
{
	for (int entity = 1; entity < MAXENTITIES; entity++)
	{
		RemoveEntityModelGlow(entity);
		delete g_iModelTimer[entity];

		RemoveInstructor(entity);
		delete g_iInstructorTimer[entity];

		RemoveTargetInstructor(entity);
		delete g_iTargetInstructorTimer[entity];
	}
}

void RemoveAllSpotMark()
{
    int entity;
    char targetname[16];

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, CLASSNAME_INFO_TARGET)) != INVALID_ENT_REFERENCE)
    {
        GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
        if (StrEqual(targetname, "l4d_mark_hint"))
            AcceptEntityInput(entity, "Kill");
    }

    entity = INVALID_ENT_REFERENCE;
    while ((entity = FindEntityByClassname(entity, CLASSNAME_ENV_SPRITE)) != INVALID_ENT_REFERENCE)
    {
        GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
        if (StrEqual(targetname, "l4d_mark_hint"))
            AcceptEntityInput(entity, "Kill");
    }
}

bool IsValidEntityIndex(int entity)
{
	return (MaxClients + 1 <= entity <= GetMaxEntities());
}

void CreateEntityModelGlow(int iEntity, const char[] sEntModelName)
{
	if (g_iItemCvarColor == 0) return; //no glow

	// Spawn dynamic prop entity
	int entity = CreateEntityByName("prop_dynamic_override");
	if( !CheckIfEntityMax(entity) ) return;

	// Delete previous glow first
	RemoveEntityModelGlow(iEntity);
	delete g_iModelTimer[iEntity];

	// Set new fake model
	DispatchKeyValue(entity, "model", sEntModelName);
	DispatchKeyValue(entity, "targetname", "harry_marked_item");
	DispatchSpawn(entity);

	float vPos[3], vAng[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(iEntity, Prop_Send, "m_angRotation", vAng);
	TeleportEntity(entity, vPos, vAng, NULL_VECTOR);

	// Set outline glow color
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", g_iItemGlowRange);
	SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iItemCvarColor);
	AcceptEntityInput(entity, "StartGlowing");

	// Set model invisible
	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(entity, 0, 0, 0, 0);

	// Set model attach to item, and always synchronize
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", iEntity);
	///////發光物件完成//////////

	g_iModelIndex[iEntity] = EntIndexToEntRef(entity);

	g_iModelTimer[iEntity] = CreateTimer(g_fItemGlowTimer, Timer_ItemGlow, iEntity);

	//model 只能給誰看?
	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
}

bool CreateInfectedMarker(int client, int infected, bool bIsWitch = false)
{
	if( GetEngineTime() < g_fInfectedMarkCoolDownTime[client]) return true; //colde down not yet

	if (bIsWitch && g_bInfectedMarkWitch == false)	// disable infected mark on witch
	{
		CreateSpotMarker(client, false);
		return false;
	}

	float vStartPos[3], vEndPos[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", vStartPos);
	GetEntPropVector(infected, Prop_Data, "m_vecOrigin", vEndPos);
	if (!g_bInfectedMarkLicense || GetVectorDistance(vStartPos, vEndPos, true) > g_fInfectedMarkUseRange * g_fInfectedMarkUseRange) // over distance
	{
		CreateSpotMarker(client, false);
		return false;
	}

	// Spawn dynamic prop entity
	int entity = -1;
	entity = CreateEntityByName("prop_dynamic_ornament");

	if( !CheckIfEntityMax(entity) ) return false;

	// Delete previous glow first
	RemoveEntityModelGlow(infected);
	delete g_iModelTimer[infected];

	// Get Model
	static char sModelName[64];
	GetEntPropString(infected, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

	// Set new fake model
	SetEntityModel(entity, sModelName);
	DispatchSpawn(entity);

	// Set outline glow color
	SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 0);
	SetEntProp(entity, Prop_Send, "m_nGlowRange", g_iInfectedMarkGlowRange);
	SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iInfectedMarkCvarColor);
	AcceptEntityInput(entity, "StartGlowing");

	// Set model invisible
	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
	SetEntityRenderColor(entity, 0, 0, 0, 0);

	// Set model attach to infected, and always synchronize
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetAttached", infected);
	AcceptEntityInput(entity, "TurnOn");
	///////發光物件完成//////////

	g_iModelIndex[infected] = EntIndexToEntRef(entity);

	g_iModelTimer[infected] = CreateTimer(g_fInfectedMarkGlowTimer, Timer_ItemGlow, infected);

	//model 只能給誰看?
	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);

	g_fInfectedMarkCoolDownTime[client] = GetEngineTime() + g_fInfectedMarkCoolDown;

	if (strlen(g_sInfectedMarkUseSound) > 0)
	{
		for (int target = 1; target <= MaxClients; target++)
		{
			if (!IsClientInGame(target))
				continue;

			if (IsFakeClient(target))
				continue;

			if (GetClientTeam(target) == TEAM_INFECTED)
				continue;

			EmitSoundToClient(target, g_sInfectedMarkUseSound, client);
		}
	}

	static char sItemName[64];
	StringToLowerCase(sModelName);
	g_smModelToName.GetString(sModelName, sItemName, sizeof(sItemName));
	NotifyMessage(client, sItemName, view_as<EHintType>(eInfectedMaker));

	return true;
}

void CreateSpotMarker(int client, bool bIsAimInfeced)
{
	if (bIsAimInfeced || i_ItemsNumber[client]<=0 && g_iAllNumberTimes>0) return;
	if (GetEngineTime() < g_fSpotMarkCoolDownTime[client]) return; // cool down not yet
	i_ItemsNumber[client]--;
	
	bool hit = false;
	float vStartPos[3], vEndPos[3];
	GetClientAbsOrigin(client, vStartPos);

	float vPos[3];
	GetClientEyePosition(client, vPos);

	float vAng[3];
	GetClientEyeAngles(client, vAng);

	Handle trace = TR_TraceRayFilterEx(vPos, vAng, MASK_ALL, RayType_Infinite, TraceFilter, client);

	if (TR_DidHit(trace))
	{
		hit = true;
		TR_GetEndPosition(vEndPos, trace);
	}

	delete trace;

	if (!hit) // not hit
		return;

	if ( g_bSpotMarkInstructorHint ) CreateInstructorHint(client, vEndPos, "", 0, view_as<EHintType>(eSpotMarker));

	if ( strlen(g_sSpotMarkCvarColor) == 0 ) return; //disable spot mark glow

	if (GetVectorDistance(vStartPos, vEndPos, true) > g_fSpotMarkUseRange * g_fSpotMarkUseRange) // over distance
		return;

	float vBeamPos[3];
	vBeamPos = vEndPos;
	vBeamPos[2] += (2.0 + 1.0); // Change the Z pos to go up according with the width for better looking

	int color[4];
	color[0] = g_iSpotMarkCvarColorArray[0];
	color[1] = g_iSpotMarkCvarColorArray[1];
	color[2] = g_iSpotMarkCvarColorArray[2];
	color[3] = 255;

	int direction = DIRECTION_IN;
	float timeLimit = GetGameTime() + g_fSpotMarkGlowTimer;

	DataPack pack;
	CreateDataTimer(1.0, TimerField, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(direction);
	pack.WriteCell(color[0]);
	pack.WriteCell(color[1]);
	pack.WriteCell(color[2]);
	pack.WriteCell(color[3]);
	pack.WriteFloat(timeLimit);
	pack.WriteFloat(vBeamPos[0]);
	pack.WriteFloat(vBeamPos[1]);
	pack.WriteFloat(vBeamPos[2]);

	float fieldDuration = (timeLimit - GetGameTime() < 1.0 ? timeLimit - GetGameTime() : 1.0);

	if (fieldDuration < L4D2_BEAM_LIFE_MIN) // Prevents rounding to 0, which makes the beam not disappear
		fieldDuration = L4D2_BEAM_LIFE_MIN;

	int targets[MAXPLAYERS+1];
	int targetCount;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!IsClientInGame(target))
			continue;

		if (IsFakeClient(target))
			continue;

		if (GetClientTeam(target) == TEAM_INFECTED)
			continue;

		targets[targetCount++] = target;
	}

	TE_SetupBeamRingPoint(vBeamPos, 75.0, 100.0, g_iFieldModelIndex, 0, 0, 0, fieldDuration, 2.0, 0.0, color, 0, 0);
	TE_Send(targets, targetCount);

	float vSpritePos[3];
	vSpritePos = vEndPos;
	vSpritePos[2] += 50.0;

	char targetname[19];
	FormatEx(targetname, sizeof(targetname), "%s-%02i", "l4d_mark_hint", client);

	g_fSpotMarkCoolDownTime[client] = GetEngineTime() + g_fSpotMarkCoolDown;

	if (strlen(g_sSpotMarkUseSound) > 0)
	{
		for (int target = 1; target <= MaxClients; target++)
		{
			if (!IsClientInGame(target))
				continue;

			if (IsFakeClient(target))
				continue;

			if (GetClientTeam(target) == TEAM_INFECTED)
				continue;

			EmitSoundToClient(target, g_sSpotMarkUseSound, client);
		}
	}

	if ( strlen(g_sSpotMarkSpriteModel) == 0 ) return; //disable spot marker info target

	int infoTarget = CreateEntityByName(CLASSNAME_INFO_TARGET);
	if( CheckIfEntityMax(infoTarget) )
	{
		DispatchKeyValue(infoTarget, "targetname", targetname);

		TeleportEntity(infoTarget, vSpritePos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(infoTarget);
		ActivateEntity(infoTarget);

		SetEntPropEnt(infoTarget, Prop_Send, "m_hOwnerEntity", client);

		SetVariantString(g_sKillDelay);
		AcceptEntityInput(infoTarget, "AddOutput");
		AcceptEntityInput(infoTarget, "FireUser1");

		int sprite       = CreateEntityByName(CLASSNAME_ENV_SPRITE);
		if( CheckIfEntityMax(sprite) )
		{
			DispatchKeyValue(sprite, "targetname", targetname);
			DispatchKeyValue(sprite, "spawnflags", "1");
			SDKHook(sprite, SDKHook_SetTransmit, Hook_SetTransmit);

			DispatchKeyValue(sprite, "model", g_sSpotMarkSpriteModel);
			DispatchKeyValue(sprite, "rendercolor", g_sSpotMarkCvarColor);
			DispatchKeyValue(sprite, "renderamt", "255"); // If renderamt goes before rendercolor, it doesn't render
			DispatchKeyValue(sprite, "scale", "0.25");
			DispatchKeyValue(sprite, "fademindist", "-1");

			TeleportEntity(sprite, vSpritePos, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(sprite);
			ActivateEntity(sprite);

			SetVariantString("!activator");
			AcceptEntityInput(sprite, "SetParent", infoTarget); // We need parent the entity to an info_target, otherwise SetTransmit won't work

			SetEntPropEnt(sprite, Prop_Send, "m_hOwnerEntity", client);
			AcceptEntityInput(sprite, "ShowSprite");
			SetVariantString(g_sKillDelay);
			AcceptEntityInput(sprite, "AddOutput");
			AcceptEntityInput(sprite, "FireUser1");

			CreateTimer(0.1, TimerMoveSprite, EntIndexToEntRef(sprite), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action TimerField(Handle timer, DataPack pack)
{
	int direction;
	int color[4];
	float timeLimit;
	float vBeamPos[3];

	pack.Reset();
	direction = pack.ReadCell();
	color[0] = pack.ReadCell();
	color[1] = pack.ReadCell();
	color[2] = pack.ReadCell();
	color[3] = pack.ReadCell();
	timeLimit = pack.ReadFloat();
	vBeamPos[0] = pack.ReadFloat();
	vBeamPos[1] = pack.ReadFloat();
	vBeamPos[2] = pack.ReadFloat();

	if (timeLimit < GetGameTime())
		return Plugin_Continue;

	float fieldDuration = (timeLimit - GetGameTime() < 1.0 ? timeLimit - GetGameTime() : 1.0);

	if (fieldDuration < L4D2_BEAM_LIFE_MIN) // Prevents rounding to 0, which makes the beam not disappear
		fieldDuration = L4D2_BEAM_LIFE_MIN;

	int targets[MAXPLAYERS+1];
	int targetCount;
	for (int target = 1; target <= MaxClients; target++)
	{
		if (!IsClientInGame(target))
			continue;

		if (IsFakeClient(target))
			continue;

		if (GetClientTeam(target) == TEAM_INFECTED)
			continue;

		targets[targetCount++] = target;
	}

	switch (direction)
	{
		case DIRECTION_OUT:
		{
			direction = DIRECTION_IN;
			TE_SetupBeamRingPoint(vBeamPos, 75.0, 100.0, g_iFieldModelIndex, 0, 0, 0, fieldDuration, 2.0, 0.0, color, 0, 0);
			TE_Send(targets, targetCount);
		}
		case DIRECTION_IN:
		{
			direction = DIRECTION_OUT;
			TE_SetupBeamRingPoint(vBeamPos, 100.0, 75.0, g_iFieldModelIndex, 0, 0, 0, fieldDuration, 2.0, 0.0, color, 0, 0);
			TE_Send(targets, targetCount);
		}
	}

	DataPack pack2;
	CreateDataTimer(1.0, TimerField, pack2, TIMER_FLAG_NO_MAPCHANGE);
	pack2.WriteCell(direction);
	pack2.WriteCell(color[0]);
	pack2.WriteCell(color[1]);
	pack2.WriteCell(color[2]);
	pack2.WriteCell(color[3]);
	pack2.WriteFloat(timeLimit);
	pack2.WriteFloat(vBeamPos[0]);
	pack2.WriteFloat(vBeamPos[1]);
	pack2.WriteFloat(vBeamPos[2]);

	return Plugin_Continue;
}

public Action TimerMoveSprite(Handle timer, int entityRef)
{
    int entity = EntRefToEntIndex(entityRef);

    if (entity == INVALID_ENT_REFERENCE)
        return Plugin_Stop;

    float vPos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);

    if (ge_bMoveUp[entity])
    {
        vPos[2] += 1.0;

        if (vPos[2] >= 4.0)
            ge_bMoveUp[entity] = false;
    }
    else
    {
        vPos[2] -= 1.0;

        if (vPos[2] <= -4.0)
            ge_bMoveUp[entity] = true;
    }

    TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

    return Plugin_Continue;
}

int[] ConvertRGBToIntArray(char[] sColor)
{
    int color[3];

    if (sColor[0] == 0)
        return color;

    char sColors[3][4];
    int count = ExplodeString(sColor, " ", sColors, sizeof(sColors), sizeof(sColors[]));

    switch (count)
    {
        case 1:
        {
            color[0] = StringToInt(sColors[0]);
        }
        case 2:
        {
            color[0] = StringToInt(sColors[0]);
            color[1] = StringToInt(sColors[1]);
        }
        case 3:
        {
            color[0] = StringToInt(sColors[0]);
            color[1] = StringToInt(sColors[1]);
            color[2] = StringToInt(sColors[2]);
        }
    }

    return color;
}

public bool TraceFilter(int entity, int contentsMask, int client)
{
	if (entity == client)
		return false;

	if (entity == ENTITY_WORLDSPAWN)
		return true;


	if (1 <= entity <= MaxClients && IsClientInGame(entity))
	{
		switch(GetClientTeam(entity))
		{
			case TEAM_SPECTATOR: return false;
			case TEAM_INFECTED: {
				if(IsPlayerGhost(entity))
					return false;
			}
			default:{
				return true;
			}
		}

		return true;
	}

	return false;
}

void StringToLowerCase(char[] input)
{
    for (int i = 0; i < strlen(input); i++)
    {
        input[i] = CharToLower(input[i]);
    }
}

void NotifyMessage(int client, const char[] sItemName, EHintType eType)
{
	if (eType == view_as<EHintType>(eItemHint))
	{
		switch(g_iItemAnnounceType)
		{
			case 0: {/*nothing*/}
			case 1: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 1, sItemName);
					}
				}
			}
			case 2: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 2, sItemName);
					}
				}
			}
			case 4: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 4, sItemName);
					}
				}
			}
			/**************************************************/
			case 3: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 1, sItemName);
						SwitchItemAnnounceType(i, client, 2, sItemName);
					}
				}
			}
			case 5: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 1, sItemName);
						SwitchItemAnnounceType(i, client, 4, sItemName);
					}
				}
			}
			case 6: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 2, sItemName);
						SwitchItemAnnounceType(i, client, 4, sItemName);
					}
				}
			}
			case 7: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 1, sItemName);
						SwitchItemAnnounceType(i, client, 2, sItemName);
						SwitchItemAnnounceType(i, client, 4, sItemName);
					}
				}
			}
		}
	}
	else if (eType == view_as<EHintType>(eInfectedMaker))
	{
		switch(g_iInfectedMarkAnnounceType)
		{
			case 0: {/*nothing*/}
			case 1: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 1, sItemName);
					}
				}
			}
			case 2: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 2, sItemName);
					}
				}
			}
			case 4: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 4, sItemName);
					}
				}
			}
			/**************************************************/
			case 3: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 1, sItemName);
						SwitchItemAnnounceType(i, client, 2, sItemName);
					}
				}
			}
			case 5: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 1, sItemName);
						SwitchItemAnnounceType(i, client, 4, sItemName);
					}
				}
			}
			case 6: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 2, sItemName);
						SwitchItemAnnounceType(i, client, 4, sItemName);
					}
				}
			}
			case 7: {
				for (int i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != TEAM_INFECTED)
					{
						SwitchItemAnnounceType(i, client, 1, sItemName);
						SwitchItemAnnounceType(i, client, 2, sItemName);
						SwitchItemAnnounceType(i, client, 4, sItemName);
					}
				}
			}
		}
	}
}

public void SwitchItemAnnounceType(int player, int client, int select, const char[] sItemName)
{
	switch(select)
	{
		case 1:CPrintToChat(player, "{blue}%N{default}：我发现了〈%s〉。", client, sItemName);
		case 2:PrintHintText(player, "%N 发现了 %s", client, sItemName);
		case 4:PrintCenterText(player, " %N 发现了 %s", client, sItemName);
	}
}

stock bool IsHandingFromLedge(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

int GetInfectedAttacker(int client)
{
	int attacker;

	/* Charger */
	attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
	if (attacker > 0)
	{
		return attacker;
	}

	attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
	if (attacker > 0)
	{
		return attacker;
	}
	/* Jockey */
	attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
	if (attacker > 0)
	{
		return attacker;
	}

	/* Hunter */
	attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
	if (attacker > 0)
	{
		return attacker;
	}

	/* Smoker */
	attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
	if (attacker > 0)
	{
		return attacker;
	}

	return -1;
}

bool IsWitch(int entity)
{
    if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
    {
        char strClassName[64];
        GetEdictClassname(entity, strClassName, sizeof(strClassName));
        return strcmp(strClassName, "witch", false) == 0;
    }
    return false;
}

bool IsPlayerGhost(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}

public Action Hook_SetTransmit(int entity, int client)
{
	if( GetClientTeam(client) == TEAM_INFECTED)
		return Plugin_Handled;

	return Plugin_Continue;
}

bool CheckIfEntityMax(int entity)
{
	if(entity == -1) return false;

	if(	entity > ENTITY_SAFE_LIMIT)
	{
		AcceptEntityInput(entity, "Kill");
		return false;
	}
	return true;
}

// by BHaType: https://forums.alliedmods.net/showthread.php?p=2709810#post2709810
void CreateInstructorHint(int client, const float vOrigin[3], const char[] sItemName, int iEntity, EHintType type)
{
	static char sTargetName[64], sCaption[128];
	Format(sTargetName, sizeof sTargetName, "%i_%.0f", client, GetEngineTime());

	switch(type)
	{
		case view_as<EHintType>(eItemHint):
		{
			if( Create_info_target(iEntity, vOrigin, sTargetName, g_fItemGlowTimer) )
			{
				FormatEx(sCaption, sizeof sCaption, "%s", sItemName);
				Create_env_instructor_hint(iEntity, view_as<EHintType>(eItemHint), vOrigin, sTargetName, g_sItemInstructorIcon, sCaption, g_sItemInstructorColor, g_fItemGlowTimer, float(g_iItemGlowRange));
			}
		}
		case view_as<EHintType>(eSpotMarker):
		{
			if( Create_info_target(iEntity, vOrigin, sTargetName, g_fSpotMarkGlowTimer) )
			{
				if(g_iAllNumberTimes>0)
				{
					switch(g_iAllResAnnType)
					{
						case 1:SwitchAllResAnnType(client,1);
						case 2:SwitchAllResAnnType(client,2);
						case 4:SwitchAllResAnnType(client,4);
						
						case 3:{SwitchAllResAnnType(client,1);SwitchAllResAnnType(client,2);}
						case 5:{SwitchAllResAnnType(client,1);SwitchAllResAnnType(client,4);}
						case 6:{SwitchAllResAnnType(client,2);SwitchAllResAnnType(client,4);}
						case 7:{SwitchAllResAnnType(client,1);SwitchAllResAnnType(client,2);SwitchAllResAnnType(client,4);}
					}
				}
				
				FormatEx(sCaption, sizeof sCaption, "%N 标记了此处", client);
				Create_env_instructor_hint(iEntity, view_as<EHintType>(eSpotMarker), vOrigin, sTargetName, g_sSpotMarkInstructorIcon, sCaption, g_sSpotMarkInstructorColor, g_fSpotMarkGlowTimer, g_fSpotMarkUseRange);
			}
		}
	}
}

bool Create_info_target(int iEntity, const float vOrigin[3], const char[] sTargetName, float duration)
{
	int entity = CreateEntityByName(CLASSNAME_INFO_TARGET);
	if (!CheckIfEntityMax(entity)) return false;

	DispatchKeyValue(entity, "targetname", sTargetName);
	DispatchKeyValue(entity, "spawnflags", "1"); //Only visible to survivors
	DispatchSpawn(entity);
	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", iEntity); // We need parent the info_target to an entity, otherwise it won't follow moveable item such as gascan, pill and throwable

	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);

	if (iEntity > 0)
	{
		//delete previous info_target first
		RemoveTargetInstructor(iEntity);
		delete g_iTargetInstructorTimer[iEntity];

		g_iTargetInstructorIndex[iEntity] = EntIndexToEntRef(entity);
		g_iTargetInstructorTimer[iEntity] = CreateTimer(duration, Timer_target_instructor_hint, iEntity);
	}
	else
	{
		char szBuffer[36];
		Format(szBuffer, sizeof szBuffer, "OnUser1 !self:Kill::%f:-1", duration);

		SetVariantString(szBuffer);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}

	return true;
}

void Create_env_instructor_hint(int iEntity, EHintType eType, const float vOrigin[3], const char[] sTargetName, const char[] icon_name, const char[] caption, const char[] hint_color, float duration, float range)
{
	int entity = CreateEntityByName("env_instructor_hint");
	if (!CheckIfEntityMax(entity)) return;

	char sDuration[4];
	IntToString(RoundFloat(duration), sDuration, sizeof sDuration);
	char sRange[8];
	IntToString(RoundFloat(range), sRange, sizeof sRange);

	DispatchKeyValue(entity, "hint_timeout", sDuration);
	DispatchKeyValue(entity, "hint_allow_nodraw_target", "1");
	DispatchKeyValue(entity, "hint_target", sTargetName);
	DispatchKeyValue(entity, "hint_auto_start", "1");
	DispatchKeyValue(entity, "hint_color", hint_color);
	DispatchKeyValue(entity, "hint_icon_offscreen", icon_name);
	DispatchKeyValue(entity, "hint_instance_type", "0");
	DispatchKeyValue(entity, "hint_icon_onscreen", icon_name);
	DispatchKeyValue(entity, "hint_caption", caption);
	DispatchKeyValue(entity, "hint_static", "0");
	DispatchKeyValue(entity, "hint_nooffscreen", "0");
	if (eType == view_as<EHintType>(eSpotMarker)) DispatchKeyValue(entity, "hint_icon_offset", "10");
	else if (eType == view_as<EHintType>(eItemHint)) DispatchKeyValue(entity, "hint_icon_offset", "0");
	DispatchKeyValue(entity, "hint_range", sRange);
	DispatchKeyValue(entity, "hint_forcecaption", "1");
	DispatchSpawn(entity);
	TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	//AcceptEntityInput(entity, "ShowHint"); //double hint

	if (iEntity > 0)
	{
		//delete previous env_instructor_hint first
		RemoveInstructor(iEntity);
		delete g_iInstructorTimer[iEntity];

		g_iInstructorIndex[iEntity] = EntIndexToEntRef(entity);
		g_iInstructorTimer[iEntity] = CreateTimer(duration, Timer_instructor_hint, iEntity);
	}
	else
	{
		char szBuffer[36];
		Format(szBuffer, sizeof szBuffer, "OnUser1 !self:Kill::%f:-1", duration);

		SetVariantString(szBuffer);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}
}


public Action Timer_instructor_hint(Handle timer, int iEntity)
{
	RemoveInstructor(iEntity);
	g_iInstructorTimer[iEntity] = null;

	return Plugin_Continue;
}

void RemoveInstructor(int iEntity)
{
	int instructor_hint = g_iInstructorIndex[iEntity];
	g_iInstructorIndex[iEntity] = 0;

	if (IsValidEntRef(instructor_hint))
		RemoveEntity(instructor_hint);
}

public Action Timer_target_instructor_hint(Handle timer, int iEntity)
{
	RemoveTargetInstructor(iEntity);
	g_iTargetInstructorTimer[iEntity] = null;

	return Plugin_Continue;
}

void RemoveTargetInstructor(int iEntity)
{
	int target_instructor_hint = g_iTargetInstructorIndex[iEntity];
	g_iTargetInstructorIndex[iEntity] = 0;

	if (IsValidEntRef(target_instructor_hint))
		RemoveEntity(target_instructor_hint);
}

bool HasParentClient(int entity)
{
	if(HasEntProp(entity, Prop_Data, "m_pParent"))
	{
		int parent_entity = GetEntPropEnt(entity, Prop_Data, "m_pParent");
		//PrintToChatAll("%d m_pParent: %d", entity, parent_entity);
		if (1 <= parent_entity <= MaxClients && IsClientInGame(parent_entity))
		{
			return true;
		}
	}

	return false;
}

int GetClientViewClient(int client) {
    float m_vecOrigin[3];
    float m_angRotation[3];
    GetClientEyePosition(client, m_vecOrigin);
    GetClientEyeAngles(client, m_angRotation);
    Handle tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_ALL, RayType_Infinite, TRDontHitSelf, client);
    int pEntity = -1;
    if (TR_DidHit(tr)) {
        pEntity = TR_GetEntityIndex(tr);
        delete tr;

        return pEntity;
    }
    delete tr;

    return -1;
}

bool TRDontHitSelf(int entity, int mask, any data) {
    if (entity == data)
        return false;
    return true;
}