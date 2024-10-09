#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <left4dhooks>
#include <c4s2_ghost>

#define DMG_MELEE	 2097152
#define DMG_HEADSHOT 1073741824
#define GunDataFile	 "data/c4s2_gundata.txt"

bool
	g_bPluginEnable,
	g_bGameStart,
	g_bRoundAlive;
GlobalForward
	g_hOnPlayerHurt_Pre,
	g_hOnPlayerHurt_Post,
	g_hOnPlayerKilled_Pre,
	g_hOnPlayerKilled_Post,
	g_hOnRoundStart_Post,
	g_hOnRoundEnd_Post,
	g_hOnPlayerSpawn_Post;
ArrayList
	g_hGunData;
char
	g_sClientName[MAXPLAYERS + 1][128];

enum struct WeaponData
{
	char  name[64];
	float dmg;
	float ap;
	float decline;
	char  showname[64];
}

public Plugin myinfo =
{
	name		= "C4S2 Ghost - Entertain Mod",
	author		= "Nepkey",
	description = "幽灵模式插件",
	version		= "1.0 - 2024.9.29",
	url			= "https://space.bilibili.com/436650372"
};

//---------------------------------------------------------------
//							基础设置
//---------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("c4s2_ghost");
	return APLRes_Success;
}

public void OnPluginStart()
{
	//设置本机函数
	CreateNative("SetGameState", Native_SetGameState);
	CreateNative("GetGameState", Native_GetGameState);
	CreateNative("GiveClientRandomWeapon", Native_GiveClientRandomWeapon);
	CreateNative("GetClientOriginalName", Native_GetClientOriginalName);
	CreateNative("GetWeaponData", Native_GetWeaponData);

	//设置全局转发
	g_hOnPlayerHurt_Pre	   = new GlobalForward("OnPlayerHurt_Pre", ET_Single, Param_Cell, Param_Cell, Param_Float);
	g_hOnPlayerHurt_Post   = new GlobalForward("OnPlayerHurt_Post", ET_Ignore, Param_Cell, Param_Cell, Param_Float);
	g_hOnPlayerKilled_Pre  = new GlobalForward("OnPlayerKilled_Pre", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell);
	g_hOnPlayerKilled_Post = new GlobalForward("OnPlayerKilled_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell);
	g_hOnRoundStart_Post   = new GlobalForward("C4S2Ghost_OnRoundStart_Post", ET_Ignore, Param_Cell);
	g_hOnRoundEnd_Post	   = new GlobalForward("C4S2Ghost_OnRoundEnd_Post", ET_Ignore, Param_Cell, Param_String);
	g_hOnPlayerSpawn_Post  = new GlobalForward("OnPlayerSpawn_Post", ET_Ignore, Param_Cell, Param_Cell);

	//挂钩事件
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_death", Event_MemberStatistics, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	// HookEvent("player_disconnect", Event_MemberStatistics, EventHookMode_Pre);

	//读取武器数据
	g_hGunData = new ArrayList(sizeof(WeaponData));
	LoadWeaponData();
}

public void OnAllPluginsLoaded()
{
	g_bPluginEnable = LibraryExists("left4dhooks");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "left4dhooks")) g_bPluginEnable = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "left4dhooks")) g_bPluginEnable = false;
}

//---------------------------------------------------------------
//							全局转发
//---------------------------------------------------------------
public void OnMapStart()
{
	g_bGameStart = false;
}

public void OnClientPutInServer(int client)
{
	if (!g_bPluginEnable) return;
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage_CallBack);
		Format(g_sClientName[client], sizeof(g_sClientName[]), "%N", client);
	}
}

//---------------------------------------------------------------
//							本机函数
//---------------------------------------------------------------

any Native_SetGameState(Handle plugin, int numParams)
{
	g_bGameStart = GetNativeCell(1);
}

any Native_GetGameState(Handle plugin, int numParams)
{
	return g_bGameStart;
}

any Native_GiveClientRandomWeapon(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (IsFakeClient(client)) return;
	int weapon = GetRandomWeaponEnt();
	EquipPlayerWeapon(client, weapon);
}

any Native_GetClientOriginalName(Handle plugin, int numParams)
{
	SetNativeString(2, g_sClientName[GetNativeCell(1)], GetNativeCell(2));
}

any Native_GetWeaponData(Handle plugin, int numParams)
{
	char searchin[128];
	GetNativeString(1, searchin, sizeof(searchin));
	int index = g_hGunData.FindString(searchin);
	if (index > -1)
	{
		WeaponData WD;
		g_hGunData.GetArray(index, WD);
		// char info[64];
		switch (GetNativeCell(2))
		{
			case 1:
			{
				SetNativeString(3, WD.name, GetNativeCell(4));
			}
			case 5:
			{
				SetNativeString(3, WD.showname, GetNativeCell(4));
			}
		}
	}
}

//---------------------------------------------------------------
//							事件回调
//---------------------------------------------------------------

void Event_RoundStart(Event e, const char[] name, bool boardcast)
{
	if (!g_bPluginEnable) return;
	g_bRoundAlive = true;
	Call_StartForward(g_hOnRoundStart_Post);
	Call_PushCell(g_bGameStart);
	Call_Finish();
}

Action Event_MemberStatistics(Event e, const char[] name, bool b)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	// 仅death需要获取这些信息。
	int	 victim	  = GetClientOfUserId(e.GetInt("userid"));
	int	 attacker = GetClientOfUserId(e.GetInt("attacker"));
	char weaponname[128];
	int	 damagetype = e.GetInt("type");
	e.GetString("weapon", weaponname, sizeof(weaponname));
	//识别到来自插件的自杀，丢弃该事件，防止被其他插件使用。
	if (victim == attacker && StrEqual(weaponname, "world") && damagetype == 6144)
	{
		return Plugin_Handled;
	}
	//游戏没开始或者回合已结束, 不触发统计。
	if (!g_bGameStart || !g_bRoundAlive)
	{
		return Plugin_Continue;
	}
	//幽灵团灭的情况
	if (MemberStatistics(3) == 0)
	{
		g_bRoundAlive = false;
		Call_StartForward(g_hOnRoundEnd_Post);
		Call_PushCell(3);
		Call_PushString("幽灵阵营团灭, 人类获胜。");
		Call_Finish();
	}
	//人类团灭的情况。
	else if (MemberStatistics(2) == 0)
	{
		g_bRoundAlive = false;
		Call_StartForward(g_hOnRoundEnd_Post);
		Call_PushCell(2);
		Call_PushString("人类阵营团灭, 幽灵获胜。");
		Call_Finish();
	}
	return Plugin_Continue;
}

void Event_PlayerSpawn(Event e, const char[] name, bool b)
{
	if (!g_bPluginEnable) return;
	//给予重生转发0.3秒的延迟, 修复顺序错误问题。
	int client = GetClientOfUserId(e.GetInt("userid"));
	CreateTimer(0.3, PlayerSpawn_Delay, client, TIMER_FLAG_NO_MAPCHANGE);
}

//---------------------------------------------------------------
//							回调函数
//---------------------------------------------------------------

Action OnTakeDamage_CallBack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	//当受击者处于无敌状态或游戏回合结束时、游戏尚未开始时，阻挡伤害。
	if (IsClientInGod(victim) || !g_bRoundAlive || !g_bGameStart)
	{
		return Plugin_Handled;
	}
	//放行子弹和近战以外的伤害, 但是照常计算溢出。
	if (!(damagetype & DMG_BULLET) && !(damagetype & DMG_BUCKSHOT) && !(damagetype & DMG_MELEE))
	{
		if (GetClientHealth(victim) <= damage)
		{
			KillPlayerAsNormal(victim, victim, weapon, false, false);
		}
		return Plugin_Continue;
	}
	//放行不属于幽灵和生还的伤害, 但是照常计算溢出。
	if (!IsValidClientIndex(attacker))
	{
		if (GetClientHealth(victim) <= damage)
		{
			KillPlayerAsNormal(victim, victim, weapon, false, false);
		}
		return Plugin_Continue;
	}
	//拦截幽灵友伤。
	if ((IsClientInGhost(victim) && IsClientInGhost(attacker)) && victim != attacker)
	{
		return Plugin_Handled;
	}
	int health = GetClientHealth(victim);
	if ((damagetype & DMG_BUCKSHOT) || (damagetype & DMG_BULLET))
	{
		damage = OverRide_BulletDamageCount(victim, attacker, damagetype, weapon, damagePosition);
	}
	else if (damagetype & DMG_MELEE)
	{
		damage = OverRide_MeleeDamageCount(victim, attacker, damagetype, weapon);
	}
	// pre转发。
	Action result;
	Call_StartForward(g_hOnPlayerHurt_Pre);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushFloat(health - damage > 0 ? damage : float(health));
	Call_Finish(result);
	if (result == Plugin_Handled)
	{
		return Plugin_Handled;
	}
	// post转发。
	Call_StartForward(g_hOnPlayerHurt_Post);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushFloat(health - damage > 0 ? damage : float(health));
	Call_Finish();
	//计算伤害，或是处死玩家。
	if (health - RoundFloat(damage) > 0)
	{
		SetEntityHealth(victim, health - RoundFloat(damage));
		//对受击的生还施加无敌
		if (IsClientInSoldier(victim))
		{
			SetClientInGod(victim, 0.3, true);
		}
	}
	else
	{
		KillPlayerAsNormal(victim, attacker, weapon, IsHeadShot(damagetype, damagePosition, victim), IsBackstab(damagetype, victim, attacker));
	}
	return Plugin_Handled;
}

//---------------------------------------------------------------
//							计时回调
//---------------------------------------------------------------

Action RemoveGod_Delay(Handle timer, int client)
{
	int flag = GetEntityFlags(client);
	if (flag & FL_GODMODE)
	{
		flag &= ~FL_GODMODE;
		SetEntityFlags(client, flag);
	}
}

Action PlayerSpawn_Delay(Handle timer, int client)
{
	Call_StartForward(g_hOnPlayerSpawn_Post);
	Call_PushCell(client);
	Call_PushCell(g_bGameStart);
	Call_Finish();
	return Plugin_Stop;
}

//---------------------------------------------------------------
//							辅助方法
//---------------------------------------------------------------

//用于伤害计算, element为0,1,2分别匹配伤害,穿甲系数,距离衰减。不正确的参数只会返回-1
float MatchDataInList(const char[] weaponname, int element)
{
	for (int i = 0; i < g_hGunData.Length; i++)
	{
		WeaponData WD;
		g_hGunData.GetArray(i, WD);
		if (StrEqual(WD.name, weaponname))
		{
			switch (element)
			{
				case 0: return WD.dmg;
				case 1: return WD.ap;
				case 2: return WD.decline;
			}
		}
	}
	return -1.0;
}

void SetClientInGod(int client, float releasetime, bool autorelease)
{
	int flag = GetEntityFlags(client);
	if (!(flag & FL_GODMODE))
	{
		flag |= FL_GODMODE;
		SetEntityFlags(client, flag);
		if (autorelease)
		{
			CreateTimer(releasetime, RemoveGod_Delay, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

float OverRide_MeleeDamageCount(int victim, int &attacker, int damagetype, int &weapon)
{
	float damage = 50.0;
	//是否误伤队友,幽灵友伤系数0
	if (C4S2Ghost_GetClientTeam(victim) == C4S2Ghost_GetClientTeam(attacker))
	{
		damage = 0.0;
	}
	//是否爆头或背刺
	if (IsHeadShot(damagetype, NULL_VECTOR, victim) || IsBackstab(damagetype, victim, attacker))
	{
		damage = 100.0;
	}
	return damage;
}

float OverRide_BulletDamageCount(int victim, int &attacker, int damagetype, int &weapon, float damagePosition[3])
{
	char weaponname[64];
	GetEntityClassname(weapon, weaponname, sizeof(weaponname));
	float damage = MatchDataInList(weaponname, 0);
	//是否误伤队友,生还友伤系数0.25
	if (C4S2Ghost_GetClientTeam(victim) == C4S2Ghost_GetClientTeam(attacker) && victim != attacker)
	{
		damage *= 0.25;
	}
	//是否爆头
	if (IsHeadShot(damagetype, damagePosition, victim))
	{
		damage *= 4;
	}
	//是否有护甲(幽灵应自动设置护甲)
	if (GetClientArmor(victim) > 0)
	{
		damage *= (MatchDataInList(weaponname, 1) * 0.01);
	}
	//计算距离伤害衰减
	float pos[3];
	GetClientEyePosition(attacker, pos);
	float distance = GetVectorDistance(pos, damagePosition);
	int	  ratio	   = RoundToFloor(distance / 500.0);
	for (int i = 0; i < ratio; i++)
	{
		damage *= (MatchDataInList(weaponname, 2) * 0.01);
	}
	return damage;
}

void KillPlayerAsNormal(int victim, int attacker, int weapon, bool headshot, bool backstab)
{
	char weaponname[64];
	if (IsValidEntity(weapon))
	{
		GetEntityClassname(weapon, weaponname, sizeof(weaponname));
	}
	// Pre转发。这个转发只用于修复死亡音效不播报，没有Handle返回。
	Call_StartForward(g_hOnPlayerKilled_Pre);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushString(weaponname);
	Call_PushCell(headshot);
	Call_PushCell(backstab);
	Call_Finish();
	//模拟正常死亡事件，供其他插件使用。
	ForcePlayerSuicide(victim);
	Event deathevent = CreateEvent("player_death", true);
	deathevent.SetInt("userid", GetClientUserId(victim));
	deathevent.SetInt("attacker", GetClientUserId(attacker));
	deathevent.SetString("weapon", weaponname);
	deathevent.Fire();
	// Post转发。
	Call_StartForward(g_hOnPlayerKilled_Post);
	Call_PushCell(victim);
	Call_PushCell(attacker);
	Call_PushString(weaponname);
	Call_PushCell(headshot);
	Call_PushCell(backstab);
	Call_Finish();
}

bool IsHeadShot(int damagetype, float damagePosition[3], int victim)
{
	if (damagetype & DMG_BUCKSHOT)
	{
		float victimpos[3];
		GetClientEyePosition(victim, victimpos);
		float distance = GetVectorDistance(victimpos, damagePosition);
		if (distance <= 8.0)
		{
			return true;
		}
	}
	else if (damagetype & DMG_HEADSHOT)
	{
		return true;
	}
	return false;
}

bool IsBackstab(int damagetype, int victim, int attacker)
{
	if (!(damagetype & DMG_MELEE))
	{
		return false;
	}
	float clienta[3];
	float clientb[3];
	float fFwdA[3];
	float fFwdB[3];
	GetClientEyeAngles(victim, clienta);
	GetClientEyeAngles(attacker, clientb);
	clienta[0] = 0.00;
	clientb[0] = 0.00;
	GetAngleVectors(clienta, fFwdA, NULL_VECTOR, NULL_VECTOR);
	GetAngleVectors(clientb, fFwdB, NULL_VECTOR, NULL_VECTOR);
	return RadToDeg(ArcCosine(fFwdA[0] * fFwdB[0] + fFwdA[1] * fFwdB[1] + fFwdA[2] * fFwdB[2])) <= 40;
}

int GetRandomWeaponEnt()
{
	int weaponent;
	while (weaponent == 0)
	{
		WeaponData WD;
		g_hGunData.GetArray(GetRandomInt(0, g_hGunData.Length - 1), WD);
		//只随机smg，步枪和喷子
		if ((StrContains(WD.name, "smg") > -1 || StrContains(WD.name, "shotgun") > -1 || StrContains(WD.name, "rifle") > -1) && StrContains(WD.name, "hunting") == -1)
		{
			weaponent = CreateEntityByName(WD.name);
			if (weaponent > 0)
			{
				DispatchSpawn(weaponent);
			}
		}
	}
	return weaponent;
}

void LoadWeaponData()
{
	g_hGunData = new ArrayList(sizeof(WeaponData));
	KeyValues hKeyValues;
	hKeyValues = InitializeKV(GunDataFile, "c4s2_gundata");
	hKeyValues.GotoFirstSubKey();

	WeaponData WD;
	do
	{
		hKeyValues.GetSectionName(WD.name, sizeof(WD.name));
		WD.ap	   = hKeyValues.GetFloat("ap", 0.0);
		WD.dmg	   = hKeyValues.GetFloat("dmg", 0.0);
		WD.decline = hKeyValues.GetFloat("decline", 100.0);
		hKeyValues.GetString("name", WD.showname, sizeof(WD.showname));
		g_hGunData.PushArray(WD);
	}
	while (hKeyValues.GotoNextKey());

	delete hKeyValues;
}

int MemberStatistics(int team)
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && C4S2Ghost_GetClientTeam(i) == team && IsPlayerAlive(i))
		{
			count++;
		}
	}
	return count;
}

bool IsClientInGod(int client)
{
	int flag = GetEntityFlags(client);
	return flag & FL_GODMODE ? true : false;
}

KeyValues InitializeKV(const char[] path, const char[] keyname)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), path);
	KeyValues kv = new KeyValues(keyname);
	kv.SetEscapeSequences(true);
	kv.ImportFromFile(sPath);
	return kv;
}