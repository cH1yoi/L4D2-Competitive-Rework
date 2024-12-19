#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util_rounds>
#include <witch_and_tankifier>
#undef REQUIRE_PLUGIN
#include <l4d_tank_control_eq>
#define REQUIRE_PLUGIN


#pragma semicolon 1
#pragma newdecls required

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ConVar g_cvSurvivorLimit;
ConVar g_cvInfectedLimit;
ConVar g_cvGameSurvivorLimit;
ConVar g_cvGameInfectedLimit;
ConVar g_cvTankCount;
ConVar g_cvTankSpawnDelay;
ConVar g_cvTankSpawnDistance;
ConVar g_cvPluginEnabled;

float g_vFirstTankPos[3];
int g_iTanksSpawned;

ArrayList g_hPlayedTankList;

public Plugin myinfo = {
    name = "L4D Multi-Versus",
    author = "Hana",
    description = "支持Multi-Versus的基础插件，包含多坦克机制",
    version = "1.2",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    g_cvPluginEnabled = CreateConVar("l4d_superversus_enabled", "1", "启用插件 (1: 启用, 0: 禁用)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvSurvivorLimit = CreateConVar("l4d_survivor_limit", "4", "幸存者数量上限", FCVAR_NOTIFY, true, 1.0, true, 14.0);
    g_cvInfectedLimit = CreateConVar("l4d_infected_limit", "4", "感染者数量上限", FCVAR_NOTIFY, true, 1.0, true, 14.0);
    
    g_cvTankCount = CreateConVar("l4d_tank_count", "1", "每轮生成的坦克数量", FCVAR_NOTIFY, true, 1.0, true, 5.0);
    g_cvTankSpawnDelay = CreateConVar("l4d_tank_spawn_delay", "3.5", "不能低于3.5秒生成", FCVAR_NOTIFY, true, 3.5);
    g_cvTankSpawnDistance = CreateConVar("l4d_tank_spawn_distance", "150.0", "坦克之间的最小生成距离", FCVAR_NOTIFY, true, 50.0);
    
    g_cvGameSurvivorLimit = FindConVar("survivor_limit");
    g_cvGameInfectedLimit = FindConVar("z_max_player_zombies");

    SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
    SetConVarBounds(g_cvGameInfectedLimit, ConVarBound_Upper, false);
    
    HookConVarChange(g_cvSurvivorLimit, OnLimitChange);
    HookConVarChange(g_cvInfectedLimit, OnLimitChange);
    
    g_hPlayedTankList = new ArrayList(ByteCountToCells(64));
    
    RegConsoleCmd("sm_sur", Command_JoinSurvivor, "加入生还者");
    RegConsoleCmd("sm_inf", Command_JoinInfected, "加入感染者");
    
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
}

public void OnMapStart()
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    g_iTanksSpawned = 0;
    g_hPlayedTankList.Clear();
    
    CreateTimer(1.0, Timer_ForceUpdateBots);
}

public void OnClientDisconnect(int client)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    if (client > 0 && !IsFakeClient(client))
    {
        char steamId[64];
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        
        int index = g_hPlayedTankList.FindString(steamId);
        if (index != -1)
            g_hPlayedTankList.Erase(index);
    }
}

public Action Timer_ForceUpdateBots(Handle timer)
{
    int currentLimit = g_cvGameSurvivorLimit.IntValue;
    int desiredLimit = g_cvSurvivorLimit.IntValue;
    
    SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
    
    if (currentLimit == desiredLimit)
    {
        g_cvGameSurvivorLimit.IntValue = 4;
        CreateTimer(0.5, Timer_SetFinalLimit, desiredLimit);
    }
    else
    {
        g_cvGameSurvivorLimit.IntValue = desiredLimit;
    }
    
    return Plugin_Stop;
}

public Action Timer_SetFinalLimit(Handle timer, any desiredLimit)
{
    SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
    g_cvGameSurvivorLimit.IntValue = desiredLimit;
    return Plugin_Stop;
}

public void OnLimitChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    if (convar == g_cvSurvivorLimit)
    {
        SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
        g_cvGameSurvivorLimit.IntValue = g_cvSurvivorLimit.IntValue;
    }
    else if (convar == g_cvInfectedLimit)
    {
        SetConVarBounds(g_cvGameInfectedLimit, ConVarBound_Upper, false);
        g_cvGameInfectedLimit.IntValue = g_cvInfectedLimit.IntValue;
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    g_iTanksSpawned = 0;
    g_hPlayedTankList.Clear();
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    g_iTanksSpawned = 0;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    int tank = GetClientOfUserId(event.GetInt("userid"));
    if (!tank || !IsClientInGame(tank))
        return;
        
    // 记录第一个坦克的位置和控制者
    if (g_iTanksSpawned == 0)
    {
        GetClientAbsOrigin(tank, g_vFirstTankPos);
        g_iTanksSpawned++;
        
        if (g_iTanksSpawned < g_cvTankCount.IntValue)
        {
            CreateTimer(g_cvTankSpawnDelay.FloatValue, Timer_SpawnAdditionalTank);
        }
    }
}

public Action Timer_SpawnAdditionalTank(Handle timer)
{
    int currentTankPlayer = GetTankSelection();
    if (currentTankPlayer <= 0)
    {
        CreateTimer(0.5, Timer_SpawnAdditionalTank);
        return Plugin_Stop;
    }
    
    float spawnPos[3];
    spawnPos = g_vFirstTankPos;
    spawnPos[0] += GetRandomFloat(-g_cvTankSpawnDistance.FloatValue, g_cvTankSpawnDistance.FloatValue);
    spawnPos[1] += GetRandomFloat(-g_cvTankSpawnDistance.FloatValue, g_cvTankSpawnDistance.FloatValue);
    
    int tank = L4D2_SpawnTank(spawnPos, NULL_VECTOR);
    if (tank > 0)
    {
        g_iTanksSpawned++;
        
        int selectedPlayer = GetNextTankPlayer();
        if (selectedPlayer > 0)
        {
            L4D_ReplaceTank(tank, selectedPlayer);
        }
        
        if (g_iTanksSpawned < g_cvTankCount.IntValue)
        {
            CreateTimer(g_cvTankSpawnDelay.FloatValue, Timer_SpawnAdditionalTank);
        }
    }
    else
    {
        CreateTimer(1.0, Timer_SpawnAdditionalTank);
    }
    
    return Plugin_Stop;
}

public Action Command_JoinSurvivor(int client, int args)
{
    if (!g_cvPluginEnabled.BoolValue)
        return Plugin_Continue;
        
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    if (GetClientTeam(client) == TEAM_SURVIVOR)
    {
        CPrintToChat(client, "{blue}[{default}Multi-Versus{blue}] {default}你已经在生还者队伍中了!");
        return Plugin_Handled;
    }
    
    int targetBot = -1;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
        {
            targetBot = i;
            break;
        }
    }
    
    if (targetBot == -1)
    {
        CPrintToChat(client, "{blue}[{default}Multi-Versus{blue}] {default}生还者队伍已满!");
        return Plugin_Handled;
    }
    
    L4D_SetHumanSpec(targetBot, client);
    L4D_TakeOverBot(client);
    
    CPrintToChatAll("{blue}[{default}Multi-Versus{blue}] {olive}%N {default}加入了生还者队伍", client);
    return Plugin_Handled;
}

public Action Command_JoinInfected(int client, int args)
{
    if (!g_cvPluginEnabled.BoolValue)
        return Plugin_Continue;
        
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    if (GetClientTeam(client) == TEAM_INFECTED)
    {
        CPrintToChat(client, "{blue}[{default}Multi-Versus{blue}] {default}你已经在感染者队伍中了!");
        return Plugin_Handled;
    }
    
    int currentInfected = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
            currentInfected++;
    }
    
    if (currentInfected >= g_cvInfectedLimit.IntValue)
    {
        CPrintToChat(client, "{blue}[{default}Multi-Versus{blue}] {default}感染者队伍已满!");
        return Plugin_Handled;
    }
    
    ChangeClientTeam(client, TEAM_INFECTED);
    CPrintToChatAll("{blue}[{default}Multi-Versus{blue}] {olive}%N {default}加入了感染者队伍", client);
    return Plugin_Handled;
}

public void TankControl_OnTankSelection(char sQueuedTank[64])
{
    if (sQueuedTank[0] != '\0')
    {
        g_hPlayedTankList.PushString(sQueuedTank);
    }
}

int GetNextTankPlayer()
{
    // 获取当前第一个坦克的控制者
    int currentTankPlayer = GetTankSelection();
    
    ArrayList eligiblePlayers = new ArrayList();
    ArrayList allPlayers = new ArrayList();
    
    // 收集所有感染者玩家（排除当前坦克控制者）
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != 3 || IsFakeClient(i) || i == currentTankPlayer)
            continue;
            
        char steamId[64];
        GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
        allPlayers.Push(i);
        
        if (g_hPlayedTankList.FindString(steamId) == -1)
        {
            eligiblePlayers.Push(i);
        }
    }
    
    int selectedPlayer = -1;
    
    if (eligiblePlayers.Length > 0)
    {
        int randomIndex = GetRandomInt(0, eligiblePlayers.Length - 1);
        selectedPlayer = eligiblePlayers.Get(randomIndex);
        
        char steamId[64];
        GetClientAuthId(selectedPlayer, AuthId_Steam2, steamId, sizeof(steamId));
        g_hPlayedTankList.PushString(steamId);
        
    }
    else if (allPlayers.Length > 0)
    {
        int randomIndex = GetRandomInt(0, allPlayers.Length - 1);
        selectedPlayer = allPlayers.Get(randomIndex);
        
    }
    
    delete eligiblePlayers;
    delete allPlayers;
    return selectedPlayer;
}