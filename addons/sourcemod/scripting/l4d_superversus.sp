#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util_rounds>
#include <witch_and_tankifier>

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

int g_iTanksSpawned;
bool g_bFirstTankSpawned;
float g_vFirstTankPos[3];
bool g_bSecondRound;

ArrayList h_whosHadTank;

public Plugin myinfo = {
    name = "L4D Multi-Versus",
    author = "Hana",
    description = "支持Multi-Versus的基础插件，包含多坦克机制",
    version = "1.1",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    g_cvPluginEnabled = CreateConVar("l4d_superversus_enabled", "1", "启用插件 (1: 启用, 0: 禁用)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_cvSurvivorLimit = CreateConVar("l4d_survivor_limit", "4", "幸存者数量上限", FCVAR_NOTIFY, true, 1.0, true, 14.0);
    g_cvInfectedLimit = CreateConVar("l4d_infected_limit", "4", "感染者数量上限", FCVAR_NOTIFY, true, 1.0, true, 14.0);
    
    g_cvTankCount = CreateConVar("l4d_tank_count", "1", "每轮生成的坦克数量", FCVAR_NOTIFY, true, 1.0, true, 5.0);
    g_cvTankSpawnDelay = CreateConVar("l4d_tank_spawn_delay", "3.0", "多坦克之间的生成延迟(秒)", FCVAR_NOTIFY, true, 0.1);
    g_cvTankSpawnDistance = CreateConVar("l4d_tank_spawn_distance", "150.0", "坦克之间的最小生成距离", FCVAR_NOTIFY, true, 50.0);
    
    g_cvGameSurvivorLimit = FindConVar("survivor_limit");
    g_cvGameInfectedLimit = FindConVar("z_max_player_zombies");

    SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
    SetConVarBounds(g_cvGameInfectedLimit, ConVarBound_Upper, false);
    
    HookConVarChange(g_cvSurvivorLimit, OnLimitChange);
    HookConVarChange(g_cvInfectedLimit, OnLimitChange);
    
    h_whosHadTank = new ArrayList(ByteCountToCells(64));
    
    RegConsoleCmd("sm_sur", Command_JoinSurvivor, "加入生还者");
    RegConsoleCmd("sm_inf", Command_JoinInfected, "加入感染者");
    
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
}

public void OnMapStart()
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    g_iTanksSpawned = 0;
    g_bFirstTankSpawned = false;
    h_whosHadTank.Clear();
    g_bSecondRound = InSecondHalfOfRound();
}

public void OnClientDisconnect(int client)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    if (client > 0 && !IsFakeClient(client))
    {
        char steamId[64];
        GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
        
        int index = h_whosHadTank.FindString(steamId);
        if (index != -1)
            h_whosHadTank.Erase(index);
    }
}

public void OnRoundEnd()
{
    if (!g_cvPluginEnabled.BoolValue)
        return;

    bool isSecondRound = InSecondHalfOfRound();
    
    if (g_bSecondRound != isSecondRound)
    {
        g_bSecondRound = isSecondRound;
        g_iTanksSpawned = 0;
        g_bFirstTankSpawned = false;
        h_whosHadTank.Clear();
    }
}

public void OnRoundStart()
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    g_iTanksSpawned = 0;
    g_bFirstTankSpawned = false;
    
    if (!g_bSecondRound)
    {
        h_whosHadTank.Clear();
    }
}

public void L4D_OnSpawnTank_Post(int client, const float vecPos[3], const float vecAng[3])
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    if (!g_bFirstTankSpawned)
    {
        g_bFirstTankSpawned = true;
        g_vFirstTankPos = vecPos;
        g_iTanksSpawned = 1;
        
        if (client > 0 && !IsFakeClient(client))
        {
            char steamId[64];
            GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
            h_whosHadTank.PushString(steamId);
        }
        
        if (g_cvTankCount.IntValue > 1)
        {
            CreateTimer(g_cvTankSpawnDelay.FloatValue, Timer_SpawnAdditionalTanks);
        }
    }
}

public Action Timer_SpawnAdditionalTanks(Handle timer)
{
    if (g_iTanksSpawned >= g_cvTankCount.IntValue)
        return Plugin_Stop;
        
    float spawnPos[3];
    if (FindSafeSpawnPosition(g_vFirstTankPos, spawnPos))
    {
        int tankPlayer = GetNextTankPlayer();
        int tank = L4D2_SpawnTank(spawnPos, NULL_VECTOR);
        
        if (tank > 0)
        {
            if (tankPlayer != -1)
            {
                L4D_ReplaceTank(tank, tankPlayer);
            }
            
            g_iTanksSpawned++;
            
            if (g_iTanksSpawned < g_cvTankCount.IntValue)
            {
                CreateTimer(g_cvTankSpawnDelay.FloatValue, Timer_SpawnAdditionalTanks);
            }
        }
    }
    
    return Plugin_Stop;
}

int GetNextTankPlayer()
{
    int infectedPlayerCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
        {
            infectedPlayerCount++;
        }
    }
    
    if (infectedPlayerCount == 1 && g_iTanksSpawned > 0)
    {
        return -1;
    }
    
    ArrayList eligiblePlayers = new ArrayList();
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || IsFakeClient(i))
            continue;
            
        char steamId[64];
        GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
        
        if (h_whosHadTank.FindString(steamId) == -1)
        {
            eligiblePlayers.Push(i);
        }
    }
    
    int chosen = -1;
    if (eligiblePlayers.Length > 0)
    {
        int index = GetRandomInt(0, eligiblePlayers.Length - 1);
        chosen = eligiblePlayers.Get(index);
        
        char steamId[64];
        GetClientAuthId(chosen, AuthId_Steam2, steamId, sizeof(steamId));
        h_whosHadTank.PushString(steamId);
    }
    
    delete eligiblePlayers;
    return chosen;
}

bool FindSafeSpawnPosition(const float originalPos[3], float outPos[3])
{
    float distance = g_cvTankSpawnDistance.FloatValue;
    float angles[3];
    
    for (int i = 0; i < 8; i++)
    {
        float radians = float(i) * (3.14159265359 / 4.0);
        outPos[0] = originalPos[0] + Cosine(radians) * distance;
        outPos[1] = originalPos[1] + Sine(radians) * distance;
        outPos[2] = originalPos[2];
        
        TR_TraceRay(outPos, angles, MASK_SOLID, RayType_Infinite);
        if (!TR_DidHit())
        {
            return true;
        }
    }
    
    outPos = originalPos;
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
    
    if (GetClientTeam(client) == TEAM_INFECTED)
    {
        ChangeClientTeam(client, TEAM_SPECTATOR);
        CreateTimer(0.1, Timer_JoinSurvivor, GetClientUserId(client));
        return Plugin_Handled;
    }
    
    ChangeClientTeam(client, TEAM_SURVIVOR);
    L4D_SetHumanSpec(targetBot, client);
    L4D_TakeOverBot(client);
    
    CPrintToChatAll("{blue}[{default}Multi-Versus{blue}] {olive}%N {default}加入了生还者队伍", client);
    return Plugin_Handled;
}

public Action Timer_JoinSurvivor(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    
    if (client <= 0 || !IsClientInGame(client))
        return Plugin_Stop;
        
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
        return Plugin_Stop;
        
    ChangeClientTeam(client, TEAM_SURVIVOR);
    L4D_SetHumanSpec(targetBot, client);
    L4D_TakeOverBot(client);
    
    return Plugin_Stop;
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
    
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
            count++;
    }
    
    if (count >= g_cvInfectedLimit.IntValue)
    {
        CPrintToChat(client, "{blue}[{default}Multi-Versus{blue}] {default}感染者队伍已满!");
        return Plugin_Handled;
    }
    
    L4D_State_Transition(client, 8);
    ChangeClientTeam(client, TEAM_INFECTED);
    
    CPrintToChatAll("{blue}[{default}Multi-Versus{blue}] {olive}%N {default}加入了感染者队伍", client);
    return Plugin_Handled;
}

public void OnLimitChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_cvPluginEnabled.BoolValue)
        return;
        
    if (convar == g_cvSurvivorLimit)
    {
        g_cvGameSurvivorLimit.IntValue = g_cvSurvivorLimit.IntValue;
    }
    else if (convar == g_cvInfectedLimit)
    {
        g_cvGameInfectedLimit.IntValue = g_cvInfectedLimit.IntValue;
    }
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    OnRoundStart();
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    OnRoundEnd();
    return Plugin_Continue;
}