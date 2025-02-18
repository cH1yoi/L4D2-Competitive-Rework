#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <colors>
#include <left4dhooks>

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
#define SI_CLASS_TANK 8

public Plugin myinfo = {
    name        = "Tank Damage Stats",
    author      = "HANA",
    description = "瞅瞅集火,什么! 1%  √√√×",
    version     = "1.0",
    url         = "https://steamcommunity.com/profiles/76561197983870853/"
};

ArrayList g_aTankDamage;
bool g_bIsTankInPlay;
int g_iWasTank[MAXPLAYERS + 1];
char g_sLastHumanTankName[MAX_NAME_LENGTH];

public void OnPluginStart()
{
    g_aTankDamage = new ArrayList(2);
    
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
    g_bIsTankInPlay = false;
    g_sLastHumanTankName[0] = '\0';
    ClearTankDamage();
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
        
    if (!IsFakeClient(client)) {
        GetClientName(client, g_sLastHumanTankName, sizeof(g_sLastHumanTankName));
    }
    
    if (g_bIsTankInPlay) return;
    
    g_bIsTankInPlay = true;
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bIsTankInPlay) return;
    
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if (!IsValidClient(victim) || !IsValidClient(attacker) || !IsTank(victim))
        return;
        
    int damage = event.GetInt("dmg_health");
    AddTankDamage(attacker, damage);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsValidClient(victim))
        return;
        
    if (IsTank(victim))
    {
        CreateTimer(0.1, Timer_DisplayDamage, victim);
        return;
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
    if (g_aTankDamage.Length == 0)
        return;
        
    char tankName[32];
    GetTankControlName(tank, tankName, sizeof(tankName));
    
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
    for (int i = 0; i < g_aTankDamage.Length; i += 2) {
        totalDamage += g_aTankDamage.Get(i + 1);
    }
    
    if (totalDamage <= 0)
        return;
    
    SortTankDamage();
    
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsValidClient(i) || !IsClientInGame(i))
            continue;
            
        CPrintToChat(i, "┌ <{green}Tank{default}> {olive}%s{default} 受到的伤害:", displayName);
        
        for (int j = 0; j < g_aTankDamage.Length; j += 2) {
            int userId = g_aTankDamage.Get(j);
            int client = GetClientOfUserId(userId);
            
            if (client <= 0 || !IsClientInGame(client))
                continue;
                
            int damage = g_aTankDamage.Get(j + 1);
            int percentage = RoundToNearest((float(damage) / float(totalDamage)) * 100.0);
            
            char spaces[8];
            Format(spaces, sizeof(spaces), "%s", (damage < 1000) ? "  " : "");
            
            if (j == g_aTankDamage.Length - 2) {
                CPrintToChat(i, "└ %s{olive}%4d{default} [{green}%3d%%{default}] {blue}%N{default}", 
                    spaces, damage, percentage, client);
            } else {
                CPrintToChat(i, "├ %s{olive}%4d{default} [{green}%3d%%{default}] {blue}%N{default}", 
                    spaces, damage, percentage, client);
            }
        }
    }
}

void AddTankDamage(int client, int damage)
{
    if (damage <= 0 || !IsValidClient(client))
        return;
        
    int index = -1;
    for (int i = 0; i < g_aTankDamage.Length; i += 2)
    {
        if (g_aTankDamage.Get(i) == GetClientUserId(client))
        {
            index = i;
            break;
        }
    }
    
    if (index == -1)
    {
        g_aTankDamage.Push(GetClientUserId(client));
        g_aTankDamage.Push(damage);
    }
    else
    {
        g_aTankDamage.Set(index + 1, g_aTankDamage.Get(index + 1) + damage);
    }
}

void SortTankDamage()
{
    for (int i = 0; i < g_aTankDamage.Length - 2; i += 2) {
        for (int j = 0; j < g_aTankDamage.Length - 2 - i; j += 2) {
            if (g_aTankDamage.Get(j + 1) < g_aTankDamage.Get(j + 3)) {
                SwapDamageValues(j, j + 2);
            }
        }
    }
}

void SwapDamageValues(int index1, int index2)
{
    int tempDamage = g_aTankDamage.Get(index1 + 1);
    int tempId = g_aTankDamage.Get(index1);
    
    g_aTankDamage.Set(index1 + 1, g_aTankDamage.Get(index2 + 1));
    g_aTankDamage.Set(index1, g_aTankDamage.Get(index2));
    
    g_aTankDamage.Set(index2 + 1, tempDamage);
    g_aTankDamage.Set(index2, tempId);
}

void ClearTankDamage()
{
    g_aTankDamage.Clear();
    g_bIsTankInPlay = false;
    for (int i = 1; i <= MaxClients; i++) {
        g_iWasTank[i] = 0;
    }
}

bool GetTankControlName(int tank, char[] name, int maxlen)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i) && g_iWasTank[i] == 2) {
            GetClientName(i, name, maxlen);
            return true;
        }
    }
    
    if (!IsFakeClient(tank)) {
        GetClientName(tank, name, maxlen);
        return true;
    }
    
    return false;
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

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bIsTankInPlay) {
        DisplayTankDamage(GetTankClient());
    }
    ClearTankDamage();
}