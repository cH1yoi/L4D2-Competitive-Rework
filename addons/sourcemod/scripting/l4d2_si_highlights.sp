#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define MAX_PINNED_DISPLAY 12

public Plugin myinfo = 
{
    name = "L4D2 Special Infected Highlights",
    author = "Hana",    // 碎碎念, 写的有点久
    description = "Announce special infected highlights",
    version = "1.2",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

enum struct TankAttack
{
    int Punch;
    int Rock;
    int Hittable;
    
    void Reset() {
        this.Punch = 0;
        this.Rock = 0;
        this.Hittable = 0;
    }
}

enum struct InfectedState {
    int victimCount;
    bool victims[MAXPLAYERS+1];
    bool printed;
    bool isActive;
    Handle timer;
}

TankAttack g_TankAttacks[MAXPLAYERS+1];
InfectedState g_Charger[MAXPLAYERS+1];
InfectedState g_Boomer[MAXPLAYERS+1];
InfectedState g_Tank[MAXPLAYERS+1];

bool g_bIsCarryingSurvivor[MAXPLAYERS+1];
bool g_bIsReadyToCharge[MAXPLAYERS+1];
float g_fLastChargeTime[MAXPLAYERS+1];

bool g_bHasAnnouncedCount[MAX_PINNED_DISPLAY + 1] = {false, ...};

int g_iTempAttacker;
int g_iTempTankVictims;
int g_iTempBoomerVictims;

bool g_bIsPinned[MAXPLAYERS+1];
int g_iPinnedBy[MAXPLAYERS+1];

float g_fLastTankPunchTime[MAXPLAYERS+1];
#define TANK_PUNCH_WINDOW 1.5

public void OnPluginStart()
{
    HookEvent("ability_use", Event_AbilityUse);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    
    HookEvent("charger_charge_start", Event_ChargeStart);
    HookEvent("charger_impact", Event_ChargerImpact);
    HookEvent("charger_carry_start", Event_ChargeCarryStart);
    HookEvent("charger_carry_end", Event_ChargeCarryEnd);
    
    HookEvent("player_now_it", Event_BoomerVomit);
    
    HookEvent("tongue_grab", Event_SpecialInfectedGrab);
    HookEvent("choke_start", Event_SpecialInfectedGrab);
    HookEvent("lunge_pounce", Event_SpecialInfectedGrab);
    HookEvent("jockey_ride", Event_SpecialInfectedGrab);
    HookEvent("charger_carry_start", Event_ChargerGrab);
    HookEvent("charger_pummel_start", Event_ChargerGrab);
    HookEvent("player_incapacitated", Event_PlayerIncapacitated);
    HookEvent("tongue_release", Event_PinnedEnd);
    HookEvent("pounce_end", Event_PinnedEnd);
    HookEvent("jockey_ride_end", Event_PinnedEnd);
    HookEvent("charger_carry_end", Event_PinnedEnd);
    HookEvent("charger_pummel_end", Event_PinnedEnd);
}

public void OnMapStart()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_Charger[i].timer != null)
        {
            KillTimer(g_Charger[i].timer);
            g_Charger[i].timer = null;
        }
        g_Charger[i].isActive = false;
        g_Charger[i].victimCount = 0;
        for (int j = 1; j <= MaxClients; j++)
        {
            g_Charger[i].victims[j] = false;
        }
    }
    
    for (int i = 0; i < sizeof(g_bHasAnnouncedCount); i++)
    {
        g_bHasAnnouncedCount[i] = false;
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        ResetClientStats(i);
    }
}

void ResetClientStats(int client)
{
    g_Charger[client].victimCount = 0;
    g_Boomer[client].victimCount = 0;
    g_Tank[client].victimCount = 0;
    
    g_Charger[client].printed = false;
    g_Boomer[client].printed = false;
    g_bIsCarryingSurvivor[client] = false;
    g_bIsReadyToCharge[client] = false;
    g_Charger[client].isActive = false;
    
    g_TankAttacks[client].Reset();
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Charger[client].victims[i] = false;
        g_Boomer[client].victims[i] = false;
        g_Tank[client].victims[i] = false;
    }
    g_fLastTankPunchTime[client] = 0.0;
}

public Action Timer_ShowTankMessage(Handle timer)
{
    g_Tank[g_iTempAttacker].timer = null;
    
    char stars[32];
    stars[0] = '\0';
    int count = g_iTempTankVictims > MAX_PINNED_DISPLAY ? MAX_PINNED_DISPLAY : g_iTempTankVictims;
    
    for (int i = 0; i < count; i++)
    {
        StrCat(stars, sizeof(stars), "★");
    }
    
    if (IsFakeClient(g_iTempAttacker))
    {
        CPrintToChatAll("{red}%s {olive}AI{default}({red}Tank{default}) {red}一拍 {olive}%d", 
            stars, g_iTempTankVictims);
    }
    else
    {
        CPrintToChatAll("{red}%s {olive}%N{default}({red}Tank{default}) {red}一拍 {olive}%d", 
            stars, g_iTempAttacker, g_iTempTankVictims);
    }
    
    g_Tank[g_iTempAttacker].victimCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Tank[g_iTempAttacker].victims[i] = false;
    }
    
    return Plugin_Stop;
}

public void Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsCharger(client))
        return;
        
    ResetChargerStats(client);
    g_Charger[client].isActive = true;
    g_fLastChargeTime[client] = GetGameTime();
}

public void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    
    if (!IsCharger(client) || !IsSurvivor(victim) || !IsPlayerAlive(victim))
        return;
        
    if (g_Charger[client].isActive && !g_Charger[client].victims[victim])
    {
        g_Charger[client].victims[victim] = true;
        g_Charger[client].victimCount++;
    }
}

void ResetChargerStats(int client)
{
    g_Charger[client].printed = false;
    g_Charger[client].victimCount = 0;
    g_bIsReadyToCharge[client] = true;
    g_bIsCarryingSurvivor[client] = false;
    g_Charger[client].isActive = false;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_Charger[client].victims[i] = false;
    }
}

public Action Timer_ShowChargeResult(Handle timer, any client)
{
    g_Charger[client].timer = null;
    
    if (g_Charger[client].victimCount >= 2)
    {
        char stars[32];
        stars[0] = '\0';
        int count = g_Charger[client].victimCount > MAX_PINNED_DISPLAY ? MAX_PINNED_DISPLAY : g_Charger[client].victimCount;
        
        for (int i = 0; i < count; i++)
        {
            StrCat(stars, sizeof(stars), "★");
        }
        
        if (IsFakeClient(client))
        {
            CPrintToChatAll("{red}%s {olive}AI{default}({red}Charger{default}) {red}一撞 {olive}%d", 
                stars, g_Charger[client].victimCount);
        }
        else
        {
            CPrintToChatAll("{red}%s {olive}%N{default}({red}Charger{default}) {red}一撞 {olive}%d", 
                stars, client, g_Charger[client].victimCount);
        }
    }
    
    g_Charger[client].isActive = false;
    return Plugin_Stop;
}

public void Event_BoomerVomit(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsBoomer(attacker) || !IsSurvivor(victim))
        return;
        
    if (!g_Boomer[attacker].victims[victim])
    {
        g_Boomer[attacker].victims[victim] = true;
        g_Boomer[attacker].victimCount++;
        
        if (g_Boomer[attacker].victimCount >= 2)
        {
            if (g_Boomer[attacker].timer != null)
            {
                KillTimer(g_Boomer[attacker].timer);
                g_Boomer[attacker].timer = null;
            }
            
            g_iTempBoomerVictims = g_Boomer[attacker].victimCount;
            g_iTempAttacker = attacker;
            g_Boomer[attacker].timer = CreateTimer(1.5, Timer_ShowBoomerMessage);
        }
    }
}

public Action Timer_ShowBoomerMessage(Handle timer)
{
    g_Boomer[g_iTempAttacker].timer = null;
    
    char stars[32];
    stars[0] = '\0';
    int count = g_iTempBoomerVictims > MAX_PINNED_DISPLAY ? MAX_PINNED_DISPLAY : g_iTempBoomerVictims;
    
    for (int i = 0; i < count; i++)
    {
        StrCat(stars, sizeof(stars), "★");
    }
    
    if (IsFakeClient(g_iTempAttacker))
    {
        CPrintToChatAll("{red}%s {olive}AI{default}({red}Boomer{default}) {red}一喷 {olive}%d", 
            stars, g_iTempBoomerVictims);
    }
    else
    {
        CPrintToChatAll("{red}%s {olive}%N{default}({red}Boomer{default}) {red}一喷 {olive}%d", 
            stars, g_iTempAttacker, g_iTempBoomerVictims);
    }
    
    return Plugin_Stop;
}

public void Event_SpecialInfectedGrab(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("victim"));
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsSurvivor(victim) || !IsPlayerAlive(victim))
        return;
        
    g_bIsPinned[victim] = true;
    g_iPinnedBy[victim] = attacker;
    
    CreateTimer(0.1, Timer_CheckPinned);
}

public void Event_ChargerGrab(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(1.1, Timer_CheckPinned);
}

public Action Timer_CheckPinned(Handle timer)
{
    int pinned_count = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_bIsPinned[i] && IsClientInGame(i) && IsPlayerAlive(i))
        {
            pinned_count++;
        }
    }

    if (pinned_count > MAX_PINNED_DISPLAY)
    {
        pinned_count = MAX_PINNED_DISPLAY;
    }

    if (pinned_count >= 2 && !g_bHasAnnouncedCount[pinned_count])
    {
        char stars[32];
        stars[0] = '\0';

        for (int i = 0; i < pinned_count; i++)
        {
            StrCat(stars, sizeof(stars), "★");
        }
        
        CPrintToChatAll("{red}%s {red}特感阵营达成 {olive}%d {red}控", stars, pinned_count);
        
        g_bHasAnnouncedCount[pinned_count] = true;
    }
    else if (pinned_count < 2)
    {
        for (int i = 0; i < sizeof(g_bHasAnnouncedCount); i++)
        {
            g_bHasAnnouncedCount[i] = false;
        }
    }
    
    return Plugin_Stop;
}

bool IsCharger(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && 
            GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 6);
}

bool IsBoomer(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && 
            GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 2);
}

bool IsTank(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && 
            GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}

bool IsSurvivor(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

public void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    char ability[64];
    event.GetString("ability", ability, sizeof(ability));
    
    if (!IsCharger(client) || !IsPlayerAlive(client))
        return;
        
    if (strcmp(ability, "ability_charge") == 0)
    {
        g_Charger[client].isActive = true;
        g_Charger[client].victimCount = 0;
        
        if (g_Charger[client].timer != null)
        {
            KillTimer(g_Charger[client].timer);
            g_Charger[client].timer = null;
        }
        
        for (int i = 1; i <= MaxClients; i++)
            g_Charger[client].victims[i] = false;
            
        g_Charger[client].timer = CreateTimer(3.0, Timer_ShowChargeResult, client);
    }
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    if (!attacker || !victim || !IsClientInGame(attacker) || !IsClientInGame(victim))
        return;
    
    if (IsCharger(attacker) && IsPlayerAlive(attacker))
    {
        if (IsSurvivor(victim) && IsPlayerAlive(victim))
        {
            if (g_Charger[attacker].isActive && !g_Charger[attacker].victims[victim])
            {
                g_Charger[attacker].victims[victim] = true;
                g_Charger[attacker].victimCount++;
            }
        }
        return;
    }
    
    if (!IsTank(attacker) || !IsSurvivor(victim))
        return;
        
    if (strcmp(weapon, "tank_rock") == 0)
    {
        PrintTankAction(attacker, victim, "投掷石头命中", "★");
    }
    else if (strcmp(weapon, "tank_claw") == 0)
    {
        float currentTime = GetGameTime();
    
        if ((currentTime - g_fLastTankPunchTime[attacker]) > TANK_PUNCH_WINDOW)
        {
            g_Tank[attacker].victimCount = 0;
            for (int i = 1; i <= MaxClients; i++)
            {
                g_Tank[attacker].victims[i] = false;
            }
        }
        
        g_fLastTankPunchTime[attacker] = currentTime;
        
        if (!g_Tank[attacker].victims[victim])
        {
            g_Tank[attacker].victims[victim] = true;
            g_Tank[attacker].victimCount++;
            
            if (g_Tank[attacker].victimCount >= 2)
            {
                if (g_Tank[attacker].timer != null)
                {
                    KillTimer(g_Tank[attacker].timer);
                    g_Tank[attacker].timer = null;
                }
                
                g_iTempTankVictims = g_Tank[attacker].victimCount;
                g_iTempAttacker = attacker;
                g_Tank[attacker].timer = CreateTimer(0.1, Timer_ShowTankMessage);
            }
        }
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        ResetClientStats(client);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        ResetClientStats(client);
        g_bIsPinned[client] = false;
        g_iPinnedBy[client] = 0;
    }
}

public void Event_ChargeCarryStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    
    if (!IsCharger(client) || !IsSurvivor(victim) || !IsPlayerAlive(victim))
        return;
        
    if (g_Charger[client].isActive && !g_Charger[client].victims[victim])
    {
        g_Charger[client].victims[victim] = true;
        g_Charger[client].victimCount++;
    }
    
    g_bIsCarryingSurvivor[client] = true;
}

public void Event_ChargeCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsCharger(client))
    {
        g_bIsCarryingSurvivor[client] = false;
    }
}

public void Event_PlayerIncapacitated(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    if (!IsTank(attacker) || !IsSurvivor(victim))
        return;
        
    if (strcmp(weapon, "prop_physics") == 0)
    {
        PrintTankAction(attacker, victim, "打铁命中", "★★★");
    }
}

void PrintTankAction(int attacker, int victim, const char[] action, const char[] stars)
{
    if (IsFakeClient(attacker))
    {
        CPrintToChatAll("{red}%s {olive}AI{default}({red}Tank{default}) {red}%s {olive}%N", 
            stars, action, victim);
    }
    else
    {
        CPrintToChatAll("{red}%s {olive}%N{default}({red}Tank{default}) {red}%s {olive}%N", 
            stars, attacker, action, victim);
    }
}

public void Event_PinnedEnd(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("victim"));
    if (victim > 0)
    {
        g_bIsPinned[victim] = false;
        g_iPinnedBy[victim] = 0;
        CreateTimer(0.1, Timer_CheckPinned);
    }
}