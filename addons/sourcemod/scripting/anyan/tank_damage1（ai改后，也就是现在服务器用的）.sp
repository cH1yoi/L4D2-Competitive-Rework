#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <colors>
#include <left4dhooks>

#define PLUGIN_NAME				"击杀排行统计"
#define PLUGIN_AUTHOR			"白色幽灵 WhiteGT, sorallll"
#define PLUGIN_DESCRIPTION		"击杀排行统计"
#define PLUGIN_VERSION			"0.7"
#define PLUGIN_URL				""

Handle
	g_hTimer;

ConVar
	g_cvPrintTime;

float
	g_fPrintTime;

bool
	g_bLateLoad,
	g_bLeftSafeArea,
	g_bTeamWiped;

int
	g_iTotaldmgSI,
	g_iTotalkillSI,
	g_iTotalkillCI,
	g_iTotalFF,
	g_iTotalRF;

enum struct esData {
	int dmgSI;
	int killSI;
	int killCI;
	int headSI;
	int headCI;
	int teamFF;
	int teamRF;

	int totalTankDmg;
	int lastTankHealth;
	int tankDmg[MAXPLAYERS + 1];
	int tankClaw[MAXPLAYERS + 1];
	int tankRock[MAXPLAYERS + 1];
	int tankHittable[MAXPLAYERS + 1];
    int friendlyTankDmg;  // 特感对Tank造成的友伤
    int unknownTankDmg;   // 环境/无来源对Tank造成的伤害

	void CleanInfected() {
		this.dmgSI = 0;
		this.killSI = 0;
		this.killCI = 0;
		this.headSI = 0;
		this.headCI = 0;
		this.teamFF = 0;
		this.teamRF = 0;
	}

	void CleanTank() {
		this.totalTankDmg = 0;
		this.lastTankHealth = 0;
		this.friendlyTankDmg = 0;
		this.unknownTankDmg = 0;
	
		for (int i = 1; i <= MaxClients; i++) {
			this.tankDmg[i] = 0;
			this.tankClaw[i] = 0;
			this.tankRock[i] = 0;
			this.tankHittable[i] = 0;
		}
	}
}

esData
	g_esData[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {

	HookEvent("round_end",					Event_RoundEnd,			EventHookMode_PostNoCopy);
	HookEvent("round_start",				Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("map_transition",				Event_MapTransition);
	HookEvent("player_hurt",				Event_PlayerHurt);
	HookEvent("player_death",				Event_PlayerDeath,		EventHookMode_Pre);
	HookEvent("infected_death",				Event_InfectedDeath);
	HookEvent("tank_spawn",					Event_TankSpawn);
	HookEvent("player_incapacitated_start",	Event_PlayerIncapacitatedStart);
	HookEvent("mission_lost", 				Event_TeamWiped, 		EventHookMode_PostNoCopy);
	
	//RegConsoleCmd("sm_mvp", cmdShowMvp, "Show Mvp");

	if (g_bLateLoad && L4D_HasAnySurvivorLeftSafeArea())
		L4D_OnFirstSurvivorLeftSafeArea_Post(0);
}

public void OnConfigsExecuted() {
	g_fPrintTime = g_cvPrintTime.FloatValue;
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_fPrintTime = g_cvPrintTime.FloatValue;

	delete g_hTimer;
	if (g_fPrintTime > 0.0 && g_bLeftSafeArea)
		g_hTimer = CreateTimer(g_fPrintTime, tmrPrintStatistics);
}

Action cmdShowMvp(int client, int args) {
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	PrintStatistics();
	return Plugin_Handled;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client) {
	delete g_hTimer;
	if (g_fPrintTime > 0.0 && !g_bLeftSafeArea)
		g_hTimer = CreateTimer(g_fPrintTime, tmrPrintStatistics);

	g_bLeftSafeArea = true;
}

Action tmrPrintStatistics(Handle timer) {
	g_hTimer = null;

	PrintStatistics();

	if (g_fPrintTime > 0.0)
		g_hTimer = CreateTimer(g_fPrintTime, tmrPrintStatistics);

	return Plugin_Continue;
}

public void OnClientDisconnect(int client) {
	g_iTotaldmgSI -= g_esData[client].dmgSI;
	g_iTotalkillSI -= g_esData[client].killSI;
	g_iTotalkillCI -= g_esData[client].killCI;
	g_iTotalFF -= g_esData[client].teamFF;
	g_iTotalRF -= g_esData[client].teamRF;
	
	g_esData[client].CleanInfected();
	g_esData[client].CleanTank();

	for (int i = 1; i <= MaxClients; i++) {
		g_esData[i].tankDmg[client] = 0;
		g_esData[i].tankClaw[client] = 0;
		g_esData[i].tankRock[client] = 0;
		g_esData[i].tankHittable[client] = 0;
	}
}

public void OnMapEnd() {
	delete g_hTimer;
	g_bLeftSafeArea = false;

	ClearData();
	ClearTankData();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	PrintStatistics();

	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	delete g_hTimer;
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) {
	delete g_hTimer;
	PrintStatistics();
}

// 修改 Event_PlayerHurt 事件处理
void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (!victim || !IsClientInGame(victim))
        return;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int dmg = event.GetInt("dmg_health");

    // 特感伤害统计（包括Tank）
    if (GetClientTeam(victim) == 3) {
        int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        
        // Tank伤害统计
        if (zombieClass == 8) {
            if (!GetEntProp(victim, Prop_Send, "m_isIncapacitated")) {
                // 幸存者造成的伤害
                if (attacker && IsClientInGame(attacker) && GetClientTeam(attacker) == 2) {
                    g_esData[victim].totalTankDmg += dmg;
                    g_esData[victim].tankDmg[attacker] += dmg;
                }
                // 特感造成的友伤
                else if (attacker && IsClientInGame(attacker) && GetClientTeam(attacker) == 3) {
                    g_esData[victim].totalTankDmg += dmg;
                    g_esData[victim].friendlyTankDmg += dmg;
                }
                // 环境/无来源伤害
                else {
                    g_esData[victim].totalTankDmg += dmg;
                    g_esData[victim].unknownTankDmg += dmg;
                }

                g_esData[victim].lastTankHealth = event.GetInt("health");
            }
            return;
        }
    }

    // 生还者被攻击统计（Tank攻击类型判定）
    if (GetClientTeam(victim) == 2 && attacker && IsClientInGame(attacker) && GetClientTeam(attacker) == 3) {
        // Tank攻击类型统计
        if (GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8) {
            char weapon[32];
            event.GetString("weapon", weapon, sizeof weapon);
            
            if (strcmp(weapon, "tank_claw") == 0) {
                g_esData[attacker].tankClaw[victim]++; // 送拳统计
            }
            else if (strcmp(weapon, "tank_rock") == 0) {
                g_esData[attacker].tankRock[victim]++; // 吃饼统计
            }
            else if (strncmp(weapon, "prop_", 5) == 0 || StrEqual(weapon, "hittable")) {
                g_esData[attacker].tankHittable[victim]++; // 吸铁统计（投掷物品/可击打物品）
            }
        }
        
        // 特感对生还者伤害统计（非Tank）
        else if (attacker != victim) {
            g_esData[attacker].dmgSI += dmg;
            g_iTotaldmgSI += dmg;
        }
    }

    // 友伤统计
    if (victim != attacker && IsClientInGame(attacker) && GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 2) {
        g_esData[attacker].teamFF += dmg;
        g_iTotalFF += dmg;
    }
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int class = GetEntProp(victim, Prop_Send, "m_zombieClass");
    if (class == 8) {
        g_esData[victim].totalTankDmg += g_esData[victim].lastTankHealth;
        PrintTankStatistics(victim); // 显示击杀统计
	}

	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	if (event.GetBool("headshot"))
		g_esData[attacker].headSI++;

	switch (class) {
		case 1, 2, 3, 4, 5, 6: {
			g_iTotalkillSI++;
			g_esData[attacker].killSI++;
		}
		/*
		case 8:
			g_esData[attacker].killSI++;*/
	}
}


// 团灭时
public void Event_TeamWiped(Event event, const char[] name, bool dontBroadcast) {
    g_bTeamWiped = true;
    PrintAllActiveTanksStats();
}

// 新增函数：打印所有存活Tank的统计
void PrintAllActiveTanksStats() {
    ArrayList aTanks = new ArrayList();
    
    // 收集所有存活Tank
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8) {
            aTanks.Push(i);
        }
    }

    if (aTanks.Length == 0) {
        delete aTanks;
        return;
    }

    // 团灭提示
    CPrintToChatAll("{default}[{red}克局团灭{default}] {olive}幸存者团队已被消灭！");
    
    // 为每个Tank生成统计
    for (int i = 0; i < aTanks.Length; i++) {
        int tank = aTanks.Get(i);
        int currentHealth = GetClientHealth(tank);
        int maxHealth = GetEntProp(tank, Prop_Data, "m_iMaxHealth");
        
        CPrintToChatAll("{default}┌ [{red}%s{default}] {olive}%N {default}|{red}%d/%d {default}({green}%d%%{default})", 
            IsFakeClient(tank) ? "AI" : "PZ", 
            tank,
            currentHealth,
            maxHealth,
            RoundToNearest(float(currentHealth) / float(maxHealth) * 100.0));
            
        PrintTankDamageSources(tank, maxHealth);
    }

    delete aTanks;
    g_bTeamWiped = false;
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	if (event.GetBool("headshot"))
		g_esData[attacker].headCI++;

	g_iTotalkillCI++;
	g_esData[attacker].killCI++;
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client))
		g_esData[client].CleanTank();
}

void Event_PlayerIncapacitatedStart(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 3 || GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 2)
		return;
	
	char weapon[32];
	event.GetString("weapon", weapon, sizeof weapon);
	if (strcmp(weapon, "tank_claw") == 0)
		g_esData[attacker].tankClaw[victim]++;
	else if (strcmp(weapon, "tank_rock") == 0)
		g_esData[attacker].tankRock[victim]++;
	else
		g_esData[attacker].tankHittable[victim]++;
}

void PrintStatistics() {
	int count;
	int client;
	int[] clients = new int[MaxClients];
	for (client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && (!IsFakeClient(client) || GetClientTeam(client) == 2))
			clients[count++] = client;
	}

	if (!count)
		return;

	int infoMax = count < 4 ? count : 4;
	SortCustom1D(clients, count, SortSIKill);

	int i;
	int dmgSI;
	int killSI;
	int headSI;
	int killCI;
	int headCI;
	int teamFF;
	int teamRF;

	char str[12];
	int dataSort[MAXPLAYERS + 1];

	count = 0;
	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].dmgSI;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int dmgSILen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	count = 0;
	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].killSI;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int killSILen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	count = 0;
	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].headSI;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int headSILen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	count = 0;
	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].killCI;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int killCILen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	count = 0;
	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].teamFF;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int teamFFLen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	count = 0;
	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].teamRF;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int teamRFLen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	int numSpace;
	char buffer[254];

	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dmgSI = g_esData[client].dmgSI;
		killSI = g_esData[client].killSI;
		killCI = g_esData[client].killCI;
		headSI = g_esData[client].headSI;
		teamFF = g_esData[client].teamFF;
		teamRF = g_esData[client].teamRF;


		PrintToChatAll("%s", buffer);
	}
}

// 修改 PrintTankDamageSources 函数
void PrintTankDamageSources(int tank, int tankMaxHealth) {
    ArrayList aPlayerDamage = new ArrayList(2);
    ArrayList aOtherDamage = new ArrayList(2);
    
    int totalPlayerDamage = 0;
    int friendlyDamage = g_esData[tank].friendlyTankDmg;
    int unknownDamage = g_esData[tank].unknownTankDmg;

    // 收集幸存者伤害数据
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && g_esData[tank].tankDmg[i] > 0) {
            aPlayerDamage.Set(aPlayerDamage.Push(g_esData[tank].tankDmg[i]), i, 1);
            totalPlayerDamage += g_esData[tank].tankDmg[i];
        }
    }

    // 添加特感友伤
    if (friendlyDamage > 0) {
        aOtherDamage.Set(aOtherDamage.Push(friendlyDamage), 1, 1);
    }

    // 添加环境/无来源伤害
    if (unknownDamage > 0) {
        aOtherDamage.Set(aOtherDamage.Push(unknownDamage), 0, 1);
    }

    // 如果没有伤害数据，显示提示信息
    if (aPlayerDamage.Length == 0 && aOtherDamage.Length == 0) {
        CPrintToChatAll("{default}└ [{red}提示{default}]唉你怎么似了？");
        delete aPlayerDamage;
        delete aOtherDamage;
        return;
    }

    // 排序玩家伤害
    aPlayerDamage.Sort(Sort_Descending, Sort_Integer);

    // 计算最大伤害值用于对齐
    int maxDamage = 0;
    if (aPlayerDamage.Length > 0) maxDamage = aPlayerDamage.Get(0, 0);
    if (aOtherDamage.Length > 0) {
        for (int i = 0; i < aOtherDamage.Length; i++) {
            if (aOtherDamage.Get(i, 0) > maxDamage) {
                maxDamage = aOtherDamage.Get(i, 0);
            }
        }
    }
    
    char str[12];
    int dmgLen = IntToString(maxDamage, str, sizeof str);

    // 显示玩家伤害
    for (int i = 0; i < aPlayerDamage.Length; i++) {
        int client = aPlayerDamage.Get(i, 1);
        int damage = aPlayerDamage.Get(i, 0);
        int percent = tankMaxHealth > 0 ? RoundToNearest(float(damage) / float(tankMaxHealth) * 100.0) : 0;

        char buffer[254];
        Format(buffer, sizeof buffer, i == aPlayerDamage.Length-1 && aOtherDamage.Length == 0 ? "{default}└" : "{default}├");
        
        int numSpace = dmgLen - IntToString(damage, str, sizeof str);
        AppendSpaceChar(buffer, sizeof buffer, numSpace);
        Format(buffer, sizeof buffer, "%s{olive}[{blue}%s{olive}({green}%d%%{olive})]", buffer, str, percent);
        
        if (g_esData[tank].tankClaw[client] > 0) {
            Format(buffer, sizeof buffer, "%s {default}送拳:{olive}%d", buffer, g_esData[tank].tankClaw[client]);
        }
        if (g_esData[tank].tankRock[client] > 0) {
            Format(buffer, sizeof buffer, "%s {default}吃饼:{olive}%d", buffer, g_esData[tank].tankRock[client]);
        }
        if (g_esData[tank].tankHittable[client] > 0) {
            Format(buffer, sizeof buffer, "%s {default}吸铁:{olive}%d", buffer, g_esData[tank].tankHittable[client]);
        }
        
        Format(buffer, sizeof buffer, "%s {default}|{olive}%N", buffer, client);
        CPrintToChatAll("%s", buffer);
    }

    // 显示特感友伤
    for (int i = 0; i < aOtherDamage.Length; i++) {
        if (aOtherDamage.Get(i, 1) == 1) {
            int damage = aOtherDamage.Get(i, 0);
            int percent = tankMaxHealth > 0 ? RoundToNearest(float(damage) / float(tankMaxHealth) * 100.0) : 0;

            char buffer[254];
            Format(buffer, sizeof buffer, i == aOtherDamage.Length-1 ? "{default}└" : "{default}├");
            
            int numSpace = dmgLen - IntToString(damage, str, sizeof str);
            AppendSpaceChar(buffer, sizeof buffer, numSpace);
            Format(buffer, sizeof buffer, "%s{olive}[{red}%s{olive}({green}%d%%{olive})] {default}|{red}感染者", buffer, str, percent);
            
            CPrintToChatAll("%s", buffer);
        }
    }

    // 显示环境/无来源伤害
    for (int i = 0; i < aOtherDamage.Length; i++) {
        if (aOtherDamage.Get(i, 1) == 0) {
            int damage = aOtherDamage.Get(i, 0);
            int percent = tankMaxHealth > 0 ? RoundToNearest(float(damage) / float(tankMaxHealth) * 100.0) : 0;

            char buffer[254];
            Format(buffer, sizeof buffer, "{default}└");
            
            int numSpace = dmgLen - IntToString(damage, str, sizeof str);
            AppendSpaceChar(buffer, sizeof buffer, numSpace);
            Format(buffer, sizeof buffer, "%s{olive}[{default}%s{olive}({green}%d%%{olive})] {default}|其他", buffer, str, percent);
            
            CPrintToChatAll("%s", buffer);
        }
    }

    delete aPlayerDamage;
    delete aOtherDamage;
}

void PrintTankStatistics(int tank) {
    int maxHealth = GetEntProp(tank, Prop_Data, "m_iMaxHealth");
    
    // 团灭情况
    if (g_bTeamWiped) {
        int currentHealth = GetClientHealth(tank);
        CPrintToChatAll("{default}[{red}克局团灭{default}] 幸存者团队已被消灭！");
        CPrintToChatAll("{default}┌ [{red}%s{default}] {olive}%N {default}|{red}%d/%d {default}({green}%d%%{default})", 
            IsFakeClient(tank) ? "AI" : "PZ", 
            tank,
            currentHealth,
            maxHealth,
            RoundToNearest(float(currentHealth) / float(maxHealth) * 100.0));
    } 
    // 正常击杀情况
    else {
        CPrintToChatAll("{default}┌ [{red}%s{default}] {olive}%N {default}似了 | 血量: {red}%d", 
            IsFakeClient(tank) ? "AI" : "PZ", 
            tank, 
            maxHealth);
    }

    // 显示伤害统计
    PrintTankDamageSources(tank, maxHealth);
}

bool IsActive(int tank, int client) {
	return g_esData[tank].tankDmg[client] > 0 || g_esData[tank].tankClaw[client] > 0 || g_esData[tank].tankRock[client] > 0 || g_esData[tank].tankHittable[client] > 0;
}

void AppendSpaceChar(char[] buffer, int maxlength, int numSpace) {
	for (int i; i < numSpace; i++)
		StrCat(buffer, maxlength, " ");
}

int SortSIDamage(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].dmgSI < g_esData[elem1].dmgSI)
		return -1;
	else if (g_esData[elem1].dmgSI < g_esData[elem2].dmgSI)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

int SortSIKill(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].killSI < g_esData[elem1].killSI)
		return -1;
	else if (g_esData[elem1].killSI < g_esData[elem2].killSI)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

int SortCIKill(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].killCI < g_esData[elem1].killCI)
		return -1;
	else if (g_esData[elem1].killCI < g_esData[elem2].killCI)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

int SortTeamFF(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].teamFF < g_esData[elem1].teamFF)
		return -1;
	else if (g_esData[elem1].teamFF < g_esData[elem2].teamFF)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

int SortTeamRF(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].teamRF < g_esData[elem1].teamRF)
		return -1;
	else if (g_esData[elem1].teamRF < g_esData[elem2].teamRF)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

void ClearData() {
	g_iTotaldmgSI = 0;
	g_iTotalkillSI = 0;
	g_iTotalkillCI = 0;
	g_iTotalFF = 0;
	g_iTotalRF = 0;

	for (int i = 1; i <= MaxClients; i++)
		g_esData[i].CleanInfected();
}

void ClearTankData() {
	for (int i = 1; i <= MaxClients; i++)
		g_esData[i].CleanTank();
}