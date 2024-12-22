#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <l4d_CreateSurvivorBot>
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

// 添加新变量来追踪当前坦克事件
bool g_bIsTankEventActive = false;

public Plugin myinfo = {
    name = "L4D Multi-Versus",
    author = "Hana",
    description = "支持Multi-Versus的基础插件，包含多坦克机制",
    version = "1.5",
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
    
    CreateTimer(1.0, Timer_CreateSurvivorBots);
}

public void OnClientDisconnect(int client)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    if (client > 0 && !IsFakeClient(client))
    {
        char steamId[64];
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        
    }
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
    g_bIsTankEventActive = false;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    g_iTanksSpawned = 0;
    g_bIsTankEventActive = false;
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    int tank = GetClientOfUserId(event.GetInt("userid"));
    if (!tank || !IsClientInGame(tank))
        return;
        
    if (!g_bIsTankEventActive)
    {
        g_bIsTankEventActive = true;
        g_iTanksSpawned = 0;
        GetClientAbsOrigin(tank, g_vFirstTankPos);
        
        // 检查并重置坦克队列
        CheckAndResetTankQueue();
    }
    
    g_iTanksSpawned++;
    
    // 记录第一个坦克的位置和控制者
    if (g_iTanksSpawned == 1)
    {
        // 获取坦克玩家的 Steam ID 并标记为已玩过坦克
        if (!IsFakeClient(tank))
        {
            char steamId[64];
            GetClientAuthId(tank, AuthId_Steam2, steamId, sizeof(steamId));
            OnTankGiven(steamId);
        }
    }
    
    if (g_iTanksSpawned < g_cvTankCount.IntValue)
    {
        CreateTimer(g_cvTankSpawnDelay.FloatValue, Timer_SpawnAdditionalTank);
    }
}

void CheckAndResetTankQueue()
{
    // 清空现有队列
    ClearWhosHadTank();

    ArrayList infectedPlayers = new ArrayList(64);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
        {
            char steamId[64];
            GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
            infectedPlayers.PushString(steamId);
        }
    }
    
    // 随机打乱顺序并添加到队列
    int remainingPlayers = infectedPlayers.Length;
    while (remainingPlayers > 0)
    {
        int index = GetRandomInt(0, remainingPlayers - 1);
        char steamId[64];
        infectedPlayers.GetString(index, steamId, sizeof(steamId));
        AddToTankQueue(steamId);
        infectedPlayers.Erase(index);
        remainingPlayers--;
    }
    
    delete infectedPlayers;
}

public void OnEntityDestroyed(int entity)
{
    if (!g_cvPluginEnabled.BoolValue || !g_bIsTankEventActive)
        return;
        
    bool tankAlive = false;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
        {
            tankAlive = true;
            break;
        }
    }
    
    // 如果没有存活的坦克，重置事件状态
    if (!tankAlive)
    {
        g_bIsTankEventActive = false;
    }
}

public void OnTankGiven(const char[] steamId)
{
    // 将玩家添加到已玩过坦克的列表中
    ArrayList hadTankList = GetWhosHadTank();
    if (hadTankList != null)
    {
        if (hadTankList.FindString(steamId) == -1)
        {
            hadTankList.PushString(steamId);
        }
        delete hadTankList;
    }
}

public Action Timer_SpawnAdditionalTank(Handle timer)
{
    // 确保有足够的玩家可以控制坦克
    ArrayList tankQueue = GetTankQueue();
    ArrayList notHadTankList = GetWhosNotHadTank();
    
    // 如果队列为空且所有人都玩过坦克，重置队列
    if ((tankQueue == null || tankQueue.Length == 0) && 
        (notHadTankList == null || notHadTankList.Length == 0))
    {
        CheckAndResetTankQueue();
        // 获取新的队列
        delete tankQueue;
        tankQueue = GetTankQueue();
    }
    
    delete notHadTankList;
    
    // 如果还是没有可用的玩家，延迟生成
    if (tankQueue == null || tankQueue.Length == 0)
    {
        delete tankQueue;
        CreateTimer(1.0, Timer_SpawnAdditionalTank);
        return Plugin_Stop;
    }
    
    float spawnPos[3];
    bool foundValidPos = false;
    
    // 获取第一个坦克的 Nav Area
    Address firstTankArea = L4D_GetNearestNavArea(g_vFirstTankPos, 1000.0, false, false, false, TEAM_INFECTED);
    if (firstTankArea != Address_Null)
    {
        int maxAttempts = 10;
        while (maxAttempts-- > 0)
        {
            spawnPos[0] = g_vFirstTankPos[0] + GetRandomFloat(-g_cvTankSpawnDistance.FloatValue, g_cvTankSpawnDistance.FloatValue);
            spawnPos[1] = g_vFirstTankPos[1] + GetRandomFloat(-g_cvTankSpawnDistance.FloatValue, g_cvTankSpawnDistance.FloatValue);
            spawnPos[2] = g_vFirstTankPos[2];
            
            Address nearestArea = L4D_GetNearestNavArea(spawnPos, 1000.0, false, false, false, TEAM_INFECTED);
            if (nearestArea != Address_Null)
            {
                L4D_FindRandomSpot(view_as<int>(nearestArea), spawnPos);
                float distance = GetVectorDistance(g_vFirstTankPos, spawnPos);
                if (distance <= g_cvTankSpawnDistance.FloatValue)
                {
                    foundValidPos = true;
                    break;
                }
            }
        }
    }
    
    if (!foundValidPos)
    {
        spawnPos = g_vFirstTankPos;
    }
    
    // 在生成坦克之前先获取下一个玩家
    char steamId[64];
    tankQueue.GetString(0, steamId, sizeof(steamId));
    int targetPlayer = -1;
    
    // 找到对应的玩家
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || IsFakeClient(i))
            continue;
            
        char playerSteamId[64];
        GetClientAuthId(i, AuthId_Steam2, playerSteamId, sizeof(playerSteamId));
        
        if (strcmp(steamId, playerSteamId) == 0)
        {
            targetPlayer = i;
            break;
        }
    }
    
    // 只有在找到目标玩家时才生成坦克
    if (targetPlayer != -1)
    {
        int tank = L4D2_SpawnTank(spawnPos, NULL_VECTOR);
        if (tank > 0)
        {
            g_iTanksSpawned++;
            
            // 立即将坦克分配给玩家
            L4D_ReplaceTank(tank, targetPlayer);
            OnTankGiven(steamId);
            
            // 如果还需要生成更多坦克
            if (g_iTanksSpawned < g_cvTankCount.IntValue)
            {
                CreateTimer(g_cvTankSpawnDelay.FloatValue, Timer_SpawnAdditionalTank);
            }
        }
        else
        {
            // 如果生成失败，重试
            CreateTimer(1.0, Timer_SpawnAdditionalTank);
        }
    }
    else
    {
        // 如果没找到合适的玩家，重试
        CreateTimer(1.0, Timer_SpawnAdditionalTank);
    }
    
    delete tankQueue;
    return Plugin_Stop;
}

public bool TraceFilter_NoPlayers(int entity, int contentsMask)
{
    if (entity <= MaxClients)
        return false;
    return true;
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

public Action Timer_CreateSurvivorBots(Handle timer)
{
    int currentSurvivorCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
        {
            currentSurvivorCount++;
        }
    }
    
    int botsNeeded = g_cvSurvivorLimit.IntValue - currentSurvivorCount;
    for (int i = 0; i < botsNeeded; i++)
    {
        if (CreateSurvivorBot() == -1)
        {
            LogError("Failed to create survivor bot (%d/%d)", i + 1, botsNeeded);
            break;
        }
    }

    return Plugin_Stop;
}