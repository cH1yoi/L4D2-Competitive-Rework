#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define SI_CLASS_TANK 8

public Plugin myinfo = {
    name        = "Tank Damage Stats",
    author      = "HANA",
    description = "瞅瞅集火,什么! 1%  √√√×",
    version     = "1.4",
    url         = "https://steamcommunity.com/profiles/76561197983870853/"
};

enum struct TankDamageStats {
    int damage[MAXPLAYERS + 1]; 
    int userId[MAXPLAYERS + 1];
    int count;
    ArrayList tanks;
    bool hadTankControl[MAXPLAYERS + 1];
}

enum struct TankInfo {
    int health;
    int worldDamage;
    int teamDamage;
    bool isAlive;
    char name[MAX_NAME_LENGTH];
    int controlHistory[MAXPLAYERS + 1];
}

TankDamageStats g_TankDamage;
bool g_bIsTankInPlay;
char g_sLastHumanTankName[MAX_NAME_LENGTH];

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    g_TankDamage.tanks = new ArrayList(sizeof(TankInfo));
}

public void OnMapStart()
{
    g_bIsTankInPlay = false;
    g_sLastHumanTankName[0] = '\0';
    ClearTankDamage();
}

void ClearTankDamage()
{
    for (int i = 1; i <= MaxClients; i++) {
        g_TankDamage.damage[i] = 0;
        g_TankDamage.userId[i] = 0;
    }
    g_TankDamage.count = 0;
    g_TankDamage.tanks.Clear();
    g_bIsTankInPlay = false;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bIsTankInPlay = false;
    g_sLastHumanTankName[0] = '\0';
    ClearTankDamage();
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))
        return;
        
    TankInfo tank;
    tank.health = GetEntProp(client, Prop_Data, "m_iHealth");
    tank.isAlive = true;
    
    for(int i = 1; i <= MaxClients; i++) {
        tank.controlHistory[i] = 0;
    }
    
    if (!IsFakeClient(client)) {
        GetClientName(client, tank.name, MAX_NAME_LENGTH);
        strcopy(g_sLastHumanTankName, sizeof(g_sLastHumanTankName), tank.name);
    } else {
        if (g_sLastHumanTankName[0] != '\0') {
            Format(tank.name, MAX_NAME_LENGTH, "AI [%s]", g_sLastHumanTankName);
        } else {
            strcopy(tank.name, MAX_NAME_LENGTH, "AI");
        }
    }
    
    g_TankDamage.tanks.PushArray(tank);
    g_bIsTankInPlay = true;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bIsTankInPlay) return;
    
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int damage = event.GetInt("dmg_health");
    
    if (!IsValidClient(victim) || !IsTank(victim))
        return;
    
    int tanksCount = g_TankDamage.tanks.Length;
    if (tanksCount == 0) return;
    
    TankInfo tank;
    g_TankDamage.tanks.GetArray(tanksCount-1, tank);
        
    if (!IsValidClient(attacker)) {
        tank.worldDamage += damage;
    }
    else if (GetClientTeam(attacker) == TEAM_INFECTED) {
        tank.teamDamage += damage;
    }
    else if (GetClientTeam(attacker) == TEAM_SURVIVOR) {
        AddTankDamage(attacker, damage);
    }
    
    tank.health = GetEntProp(victim, Prop_Data, "m_iHealth");
    g_TankDamage.tanks.SetArray(tanksCount-1, tank);
}

void AddTankDamage(int client, int damage)
{
    if (damage <= 0 || !IsValidClient(client))
        return;
        
    int userId = GetClientUserId(client);
    
    g_TankDamage.hadTankControl[client] = true;
    
    int tanksCount = g_TankDamage.tanks.Length;
    if(tanksCount > 0) {
        TankInfo tank;
        g_TankDamage.tanks.GetArray(tanksCount-1, tank);
        tank.controlHistory[client] += damage;
        g_TankDamage.tanks.SetArray(tanksCount-1, tank);
    }
    
    for (int i = 1; i <= g_TankDamage.count; i++) {
        if (g_TankDamage.userId[i] == userId) {
            g_TankDamage.damage[i] += damage;
            return;
        }
    }
    
    g_TankDamage.count++;
    g_TankDamage.userId[g_TankDamage.count] = userId;
    g_TankDamage.damage[g_TankDamage.count] = damage;
}

void SortTankDamage()
{
    for (int i = 1; i <= g_TankDamage.count - 1; i++) {
        for (int j = 1; j <= g_TankDamage.count - i; j++) {
            if (g_TankDamage.damage[j] < g_TankDamage.damage[j + 1]) {
                int tempDamage = g_TankDamage.damage[j];
                int tempUserId = g_TankDamage.userId[j];
                
                g_TankDamage.damage[j] = g_TankDamage.damage[j + 1];
                g_TankDamage.userId[j] = g_TankDamage.userId[j + 1];
                
                g_TankDamage.damage[j + 1] = tempDamage;
                g_TankDamage.userId[j + 1] = tempUserId;
            }
        }
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsValidClient(victim))
        return;
        
    if (IsTank(victim))
    {
        CreateTimer(0.1, Timer_DisplayDamage, victim);
    }
}

Action Timer_DisplayDamage(Handle timer, int tank)
{
    DisplayTankDamage(tank);
    ClearTankDamage();
    return Plugin_Stop;
}

void DisplayTankDamage(int tank)
{
    if (g_TankDamage.count == 0)
        return;
        
    char displayName[64];
    if (IsFakeClient(tank)) {
        if (g_sLastHumanTankName[0] != '\0') {
            Format(displayName, sizeof(displayName), "AI [%s]", g_sLastHumanTankName);
        } else {
            Format(displayName, sizeof(displayName), "AI");
        }
    } else {
        GetClientName(tank, displayName, sizeof(displayName));
        strcopy(g_sLastHumanTankName, sizeof(g_sLastHumanTankName), displayName);
    }
    
    int totalDamage = 0;
    for (int i = 1; i <= g_TankDamage.count; i++) {
        totalDamage += g_TankDamage.damage[i];
    }
    
    int totalWorldDamage = 0;
    int totalTeamDamage = 0;
    
    // 计算所有其他来源的伤害
    for(int k = 0; k < g_TankDamage.tanks.Length; k++) {
        TankInfo tankInfo;
        g_TankDamage.tanks.GetArray(k, tankInfo);
        totalWorldDamage += tankInfo.worldDamage;
        totalTeamDamage += tankInfo.teamDamage;
    }
    
    // 计算总伤害时加入其他伤害
    totalDamage += totalWorldDamage + totalTeamDamage;
    
    if (totalDamage <= 0)
        return;
    
    SortTankDamage();
    
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidClient(i) || !IsClientInGame(i))
            continue;
            
        CPrintToChat(i, "┌ <{green}Tank{default}> {olive}%s{default} 受到的伤害:", displayName);
        
        for (int j = 1; j <= MaxClients; j++) {
            if(!g_TankDamage.hadTankControl[j]) continue;
            
            int totalControlDamage = 0;
            
            for(int k = 0; k < g_TankDamage.tanks.Length; k++) {
                TankInfo tankInfo;
                g_TankDamage.tanks.GetArray(k, tankInfo);
                totalControlDamage += tankInfo.controlHistory[j];
            }
            
            if(totalControlDamage > 0) {
                int percentage = RoundToNearest((float(totalControlDamage) / float(totalDamage)) * 100.0);
                char spaces[8];
                Format(spaces, sizeof(spaces), "%s", (totalControlDamage < 1000) ? "  " : "");
                
                CPrintToChat(i, "├ %s{olive}%4d{default} [{green}%3d%%{default}] {blue}%N{default}", 
                    spaces, totalControlDamage, percentage, j);
            }
        }
        
        if(totalWorldDamage > 0) {
            int percentage = RoundToNearest((float(totalWorldDamage) / float(totalDamage)) * 100.0);
            char spaces[8];
            Format(spaces, sizeof(spaces), "%s", (totalWorldDamage < 1000) ? "  " : "");
            CPrintToChat(i, "├ %s{olive}%4d{default} [{green}%3d%%{default}] {olive}Other{default}", 
                spaces, totalWorldDamage, percentage);
        }
        
        if(totalTeamDamage > 0) {
            int percentage = RoundToNearest((float(totalTeamDamage) / float(totalDamage)) * 100.0);
            char spaces[8];
            Format(spaces, sizeof(spaces), "%s", (totalTeamDamage < 1000) ? "  " : "");
            CPrintToChat(i, "├ %s{olive}%4d{default} [{green}%3d%%{default}] {red}Team{default}", 
                spaces, totalTeamDamage, percentage);
        }
        
        CPrintToChat(i, "└ {olive}总伤害: %d", totalDamage);
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bIsTankInPlay) {
        int currentTank = GetTankClient();
        DisplayTankDamage(currentTank);
        
        if (currentTank > 0) {
            int currentHealth = GetEntProp(currentTank, Prop_Data, "m_iHealth");
            char tankName[MAX_NAME_LENGTH];
            
            if (IsFakeClient(currentTank)) {
                if (g_sLastHumanTankName[0] != '\0') {
                    Format(tankName, sizeof(tankName), "AI [%s]", g_sLastHumanTankName);
                } else {
                    strcopy(tankName, sizeof(tankName), "AI");
                }
            } else {
                GetClientName(currentTank, tankName, sizeof(tankName));
            }
            
            for (int client = 1; client <= MaxClients; client++) {
                if (IsValidClient(client) && IsClientInGame(client)) {
                    CPrintToChat(client, "{default}<{green}Tank{default}> {olive}%s{default} 剩余血量: {red}%d", 
                        tankName, currentHealth);
                }
            }
        }
    }
    ClearTankDamage();
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

bool IsTank(int client)
{
    return (GetClientTeam(client) == TEAM_INFECTED && GetEntProp(client, Prop_Send, "m_zombieClass") == SI_CLASS_TANK);
}

int GetTankClient()
{
    if (!g_bIsTankInPlay) return 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsTank(i))
        {
            return i;
        }
    }
    return 0;
}