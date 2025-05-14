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
	g_bLeftSafeArea;

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
    HookEvent("mission_lost", 				Event_MissionLost, 		EventHookMode_PostNoCopy);
	
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

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker))
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || victim == attacker || !IsClientInGame(victim))
		return;

	switch (GetClientTeam(victim)) {
		case 2: {
			switch (GetClientTeam(attacker)) {
				case 2: {
					int dmg = event.GetInt("dmg_health");
					g_iTotalFF += dmg;
					g_esData[attacker].teamFF += dmg;

					g_iTotalRF += dmg;
					g_esData[victim].teamRF += dmg;
				}

				case 3: {
					if (GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8) {
						char weapon[32];
						event.GetString("weapon", weapon, sizeof weapon);
						if (strcmp(weapon, "tank_claw") == 0)
							g_esData[attacker].tankClaw[victim]++;
						else if (strcmp(weapon, "tank_rock") == 0)
							g_esData[attacker].tankRock[victim]++;
						else
							g_esData[attacker].tankHittable[victim]++;
					}
				}
			}
		}
		
		case 3: {
			if (GetClientTeam(attacker) == 2) {
				int dmg = event.GetInt("dmg_health");
				switch (GetEntProp(victim, Prop_Send, "m_zombieClass")) {
					case 1, 2, 3, 4, 5, 6: {
						g_iTotaldmgSI += dmg;
						g_esData[attacker].dmgSI += dmg;
					}
		
					case 8: {
						if (!GetEntProp(victim, Prop_Send, "m_isIncapacitated")) {
							g_esData[victim].totalTankDmg += dmg;
							g_esData[victim].tankDmg[attacker] += dmg;

							g_esData[victim].lastTankHealth = event.GetInt("health");
						}
					}
				}
			}
		}
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
		g_esData[victim].tankDmg[attacker] += g_esData[victim].lastTankHealth;

		PrintTankStatistics(victim);
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

void PrintTankStatistics(int tank) {
    if (g_esData[tank].totalTankDmg <= 0)
        return;

    // 显示Tank总伤害信息
    CPrintToChatAll("{default}  -------------------------");
    CPrintToChatAll("{default}[{red}Tank统计{default}] {olive}总伤害: {green}%d {default}| {olive}控制者: {green}%N%s", 
        g_esData[tank].totalTankDmg, tank, IsFakeClient(tank) ? " (AI)" : "");

    // 收集伤害数据
    ArrayList survivorClients = new ArrayList();
    int infectedDamage = 0;
    int infectedClaw = 0;
    int infectedRock = 0;
    int infectedHittable = 0;
    int otherDamage = g_esData[tank].totalTankDmg;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) == 2) {
            // 生还者伤害
            if (g_esData[tank].tankDmg[i] > 0 || g_esData[tank].tankClaw[i] > 0 || 
                g_esData[tank].tankRock[i] > 0 || g_esData[tank].tankHittable[i] > 0) {
                survivorClients.Push(i);
                otherDamage -= g_esData[tank].tankDmg[i];
            }
        }
        else if (GetClientTeam(i) == 3) {
            // 特感伤害（包括其他Tank的拳/砖/铁伤害）
            if (g_esData[tank].tankDmg[i] > 0) {
                infectedDamage += g_esData[tank].tankDmg[i];
            }
            if (g_esData[tank].tankClaw[i] > 0) {
                infectedClaw += g_esData[tank].tankClaw[i];
            }
            if (g_esData[tank].tankRock[i] > 0) {
                infectedRock += g_esData[tank].tankRock[i];
            }
            if (g_esData[tank].tankHittable[i] > 0) {
                infectedHittable += g_esData[tank].tankHittable[i];
            }
            otherDamage -= (g_esData[tank].tankDmg[i] + g_esData[tank].tankClaw[i] + 
                          g_esData[tank].tankRock[i] + g_esData[tank].tankHittable[i]);
        }
    }

    // 检查是否有任何伤害
    bool hasDamage = survivorClients.Length > 0 || infectedDamage > 0 || infectedClaw > 0 || 
                    infectedRock > 0 || infectedHittable > 0 || otherDamage > 0;

    if (hasDamage) {
        // 显示标题（玩家列在最后）
        CPrintToChatAll("{default}  输出\t\t拳\t砖\t铁\t玩家");

        // 显示生还者伤害
        char buffer[256];
        char name[MAX_NAME_LENGTH];
        for (int i = 0; i < survivorClients.Length; i++) {
            int client = survivorClients.Get(i);
            GetClientName(client, name, sizeof(name));
            
            // 添加AI标识
            if (IsFakeClient(client)) {
                Format(name, sizeof(name), "AI %s", name);
            }
            
            // 根据数字长度调整制表符
            char dmgTabs[8] = "\t\t";
            if (g_esData[tank].tankDmg[client] >= 10000) {
                dmgTabs = "\t";
            }
            
            Format(buffer, sizeof(buffer), "{blue}  %d%s%d\t%d\t%d\t%s", 
                g_esData[tank].tankDmg[client],
                dmgTabs,
                g_esData[tank].tankClaw[client],
                g_esData[tank].tankRock[client],
                g_esData[tank].tankHittable[client],
                name);

            CPrintToChatAll("%s", buffer);
        }

        // 显示特感伤害（包括其他Tank的伤害）
        if (infectedDamage > 0 || infectedClaw > 0 || infectedRock > 0 || infectedHittable > 0) {
            char dmgTabs[8] = "\t\t";
            if (infectedDamage >= 10000) {
                dmgTabs = "\t";
            }
            CPrintToChatAll("{red}  %d%s%d\t%d\t%d\t特感", 
                infectedDamage, dmgTabs,
                infectedClaw, infectedRock, infectedHittable);
        }

        // 显示其他伤害
        if (otherDamage > 0) {
            char dmgTabs[8] = "\t\t";
            if (otherDamage >= 10000) {
                dmgTabs = "\t";
            }
            CPrintToChatAll("{default}  %d%s-\t-\t-\t其他", otherDamage, dmgTabs);
        }
    }

    delete survivorClients;
}

void PrintSingleTankDamageStats(int tank) 
{
    if (!IsClientInGame(tank) || GetClientTeam(tank) != 3 || GetEntProp(tank, Prop_Send, "m_zombieClass") != 8)
        return;

    int tankHealth = GetClientHealth(tank);
    if (tankHealth < 0) tankHealth = 0;

    CPrintToChatAll("{default}  -------------------------");
    CPrintToChatAll("{default}[{red}Tank统计{default}] {olive}剩余血量: {green}%d {default}| {olive}控制者: {green}%N%s", 
        tankHealth, tank, IsFakeClient(tank) ? " (AI)" : "");

    // 收集伤害数据
    ArrayList survivorClients = new ArrayList();
    int infectedDamage = 0;
    int infectedClaw = 0;
    int infectedRock = 0;
    int infectedHittable = 0;
    int otherDamage = g_esData[tank].totalTankDmg;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i))
            continue;

        if (GetClientTeam(i) == 2) {
            // 生还者伤害
            if (g_esData[tank].tankDmg[i] > 0 || g_esData[tank].tankClaw[i] > 0 || 
                g_esData[tank].tankRock[i] > 0 || g_esData[tank].tankHittable[i] > 0) {
                survivorClients.Push(i);
                otherDamage -= g_esData[tank].tankDmg[i];
            }
        }
        else if (GetClientTeam(i) == 3) {
            // 特感伤害（包括其他Tank的拳/砖/铁伤害）
            if (g_esData[tank].tankDmg[i] > 0) {
                infectedDamage += g_esData[tank].tankDmg[i];
            }
            if (g_esData[tank].tankClaw[i] > 0) {
                infectedClaw += g_esData[tank].tankClaw[i];
            }
            if (g_esData[tank].tankRock[i] > 0) {
                infectedRock += g_esData[tank].tankRock[i];
            }
            if (g_esData[tank].tankHittable[i] > 0) {
                infectedHittable += g_esData[tank].tankHittable[i];
            }
            otherDamage -= (g_esData[tank].tankDmg[i] + g_esData[tank].tankClaw[i] + 
                          g_esData[tank].tankRock[i] + g_esData[tank].tankHittable[i]);
        }
    }

    // 检查是否有任何伤害
    bool hasDamage = survivorClients.Length > 0 || infectedDamage > 0 || infectedClaw > 0 || 
                    infectedRock > 0 || infectedHittable > 0 || otherDamage > 0;

    if (hasDamage) {
        // 显示标题（玩家列在最后）
        CPrintToChatAll("{default}  输出\t\t拳\t砖\t铁\t玩家");

        // 显示生还者伤害
        char buffer[256];
        char name[MAX_NAME_LENGTH];
        for (int i = 0; i < survivorClients.Length; i++) {
            int client = survivorClients.Get(i);
            GetClientName(client, name, sizeof(name));
            
            // 根据数字长度调整制表符
            char dmgTabs[8] = "\t\t";
            if (g_esData[tank].tankDmg[client] >= 10000) {
                dmgTabs = "\t";
            }
            
            Format(buffer, sizeof(buffer), "{blue}  %d%s%d\t%d\t%d\t%s", 
                g_esData[tank].tankDmg[client],
                dmgTabs,
                g_esData[tank].tankClaw[client],
                g_esData[tank].tankRock[client],
                g_esData[tank].tankHittable[client],
                name);

            CPrintToChatAll("%s", buffer);
        }

        // 显示特感伤害（包括其他Tank的伤害）
        if (infectedDamage > 0 || infectedClaw > 0 || infectedRock > 0 || infectedHittable > 0) {
            char dmgTabs[8] = "\t\t";
            if (infectedDamage >= 10000) {
                dmgTabs = "\t";
            }
            CPrintToChatAll("{red}  %d%s%d\t%d\t%d\t特感", 
                infectedDamage, dmgTabs,
                infectedClaw, infectedRock, infectedHittable);
        }

        // 显示其他伤害
        if (otherDamage > 0) {
            char dmgTabs[8] = "\t\t";
            if (otherDamage >= 10000) {
                dmgTabs = "\t";
            }
            CPrintToChatAll("{default}  %d%s-\t-\t-\t其他", otherDamage, dmgTabs);
        }
    }

    delete survivorClients;
}

// 按伤害值降序排序的比较函数
public int SortByDamageDesc(int index1, int index2, ArrayList array, Handle hndl)
{
    int tank = hndl;
    int damage1 = g_esData[tank].tankDmg[index1];
    int damage2 = g_esData[tank].tankDmg[index2];
    
    if (damage1 > damage2) return -1;
    if (damage1 < damage2) return 1;
    return 0;
}

// 添加团灭事件处理
void Event_MissionLost(Event event, const char[] name, bool dontBroadcast) {
    PrintAllTanksDamageStatistics();
}

// 修改 PrintAllTanksDamageStatistics 函数中的调用方式
void PrintAllTanksDamageStatistics() {
    // 查找所有存活的Tank
    ArrayList tanks = new ArrayList();
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8) {
            tanks.Push(i);
        }
    }

    int tankCount = tanks.Length;
    if (tankCount == 0) {
        delete tanks;
        return;
    }

    // 为每个Tank显示伤害统计
    for (int i = 0; i < tankCount; i++) {
        int tank = tanks.Get(i);
        PrintSingleTankDamageStats(tank);  // 移除了第二个参数
    }

    delete tanks;
}

int Max(int a, int b) {
    return a > b ? a : b;
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