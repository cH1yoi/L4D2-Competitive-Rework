#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
    name = "L4D2 Special Infected Highlights",
    author = "Hana",    // 碎碎念, 写的有点久
    description = "Announce special infected highlights",
    version = PLUGIN_VERSION,
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

TankAttack g_TankAttacks[MAXPLAYERS+1];
int g_iTankVictimCount[MAXPLAYERS+1];
bool g_bTankVictims[MAXPLAYERS+1][MAXPLAYERS+1];
Handle g_hTankTimer = null;

int g_iChargerVictimCount[MAXPLAYERS+1];
bool g_bChargerVictims[MAXPLAYERS+1][MAXPLAYERS+1];
bool g_bChargerPrinted[MAXPLAYERS+1];
bool g_bIsCarryingSurvivor[MAXPLAYERS+1];
bool g_bIsReadyToCharge[MAXPLAYERS+1];
bool g_bChargeInProgress[MAXPLAYERS+1];
float g_fLastChargeTime[MAXPLAYERS+1];

int g_iBoomerVictimCount[MAXPLAYERS+1];
bool g_bBoomerVictims[MAXPLAYERS+1][MAXPLAYERS+1];
bool g_bBoomerPrinted[MAXPLAYERS+1];

bool g_bHasAnnouncedCount[5] = {false, ...};

Handle g_hBoomerTimer = null;

int g_iTempAttacker;
int g_iTempTankVictims;
int g_iTempBoomerVictims;

Handle g_hChargeTimer[MAXPLAYERS+1];

bool g_bIsPinned[MAXPLAYERS+1];
int g_iPinnedBy[MAXPLAYERS+1];

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
        if (g_hChargeTimer[i] != null)
        {
            KillTimer(g_hChargeTimer[i]);
            g_hChargeTimer[i] = null;
        }
        g_bChargeInProgress[i] = false;
        g_iChargerVictimCount[i] = 0;
        for (int j = 1; j <= MaxClients; j++)
        {
            g_bChargerVictims[i][j] = false;
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
    g_iChargerVictimCount[client] = 0;
    g_iBoomerVictimCount[client] = 0;
    g_iTankVictimCount[client] = 0;
    
    g_bChargerPrinted[client] = false;
    g_bBoomerPrinted[client] = false;
    g_bIsCarryingSurvivor[client] = false;
    g_bIsReadyToCharge[client] = false;
    g_bChargeInProgress[client] = false;
    
    g_TankAttacks[client].Reset();
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bChargerVictims[client][i] = false;
        g_bBoomerVictims[client][i] = false;
        g_bTankVictims[client][i] = false;
    }
}

public Action Timer_ShowTankMessage(Handle timer)
{
    g_hTankTimer = null;
    
    char stars[16];
    switch(g_iTempTankVictims)
    {
        case 2: stars = "★★";
        case 3: stars = "★★★";
        case 4: stars = "★★★★";
        default: stars = "★★★★";
    }
    
    if (IsFakeClient(g_iTempAttacker))
    {
        CPrintToChatAll("{red}%s {olive}AI{default}({red}Tank{default}) {red}一拳命中 {olive}%d {red}人", 
            stars, g_iTempTankVictims);
    }
    else
    {
        CPrintToChatAll("{red}%s {olive}%N{default}({red}Tank{default}) {red}一拳命中 {olive}%d {red}人", 
            stars, g_iTempAttacker, g_iTempTankVictims);
    }
    
    g_iTankVictimCount[g_iTempAttacker] = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bTankVictims[g_iTempAttacker][i] = false;
    }
    
    return Plugin_Stop;
}

public void Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsCharger(client))
        return;
        
    ResetChargerStats(client);
    g_bChargeInProgress[client] = true;
    g_fLastChargeTime[client] = GetGameTime();
}

public void Event_ChargerImpact(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    
    if (!IsCharger(client) || !IsSurvivor(victim) || !IsPlayerAlive(victim))
        return;
        
    if (g_bChargeInProgress[client] && !g_bChargerVictims[client][victim])
    {
        g_bChargerVictims[client][victim] = true;
        g_iChargerVictimCount[client]++;
    }
}

void ResetChargerStats(int client)
{
    g_bChargerPrinted[client] = false;
    g_iChargerVictimCount[client] = 0;
    g_bIsReadyToCharge[client] = true;
    g_bIsCarryingSurvivor[client] = false;
    g_bChargeInProgress[client] = false;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bChargerVictims[client][i] = false;
    }
}

public Action Timer_ShowChargeResult(Handle timer, any client)
{
    g_hChargeTimer[client] = null;
    
    if (g_iChargerVictimCount[client] >= 2)
    {
        char stars[16];
        switch(g_iChargerVictimCount[client])
        {
            case 2: stars = "★★";
            case 3: stars = "★★★";
            case 4: stars = "★★★★";
            default: stars = "★★★★";
        }
        
        if (IsFakeClient(client))
        {
            CPrintToChatAll("{red}%s {olive}AI{default}({red}Charger{default}) {red}冲锋撞中 {olive}%d {red}人", 
                stars, g_iChargerVictimCount[client]);
        }
        else
        {
            CPrintToChatAll("{red}%s {olive}%N{default}({red}Charger{default}) {red}冲锋撞中 {olive}%d {red}人", 
                stars, client, g_iChargerVictimCount[client]);
        }
    }
    
    g_bChargeInProgress[client] = false;
    return Plugin_Stop;
}

public void Event_BoomerVomit(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IsBoomer(attacker) || !IsSurvivor(victim))
        return;
        
    if (!g_bBoomerVictims[attacker][victim])
    {
        g_bBoomerVictims[attacker][victim] = true;
        g_iBoomerVictimCount[attacker]++;
        
        if (g_iBoomerVictimCount[attacker] >= 2)
        {
            if (g_hBoomerTimer != null)
            {
                KillTimer(g_hBoomerTimer);
                g_hBoomerTimer = null;
            }
            
            g_iTempBoomerVictims = g_iBoomerVictimCount[attacker];
            g_iTempAttacker = attacker;
            g_hBoomerTimer = CreateTimer(1.5, Timer_ShowBoomerMessage);
        }
    }
}

public Action Timer_ShowBoomerMessage(Handle timer)
{
    g_hBoomerTimer = null;
    
    char stars[16];
    switch(g_iTempBoomerVictims)
    {
        case 2: stars = "★★";
        case 3: stars = "★★★";
        case 4: stars = "★★★★";
        default: stars = "★";
    }
    
    if (IsFakeClient(g_iTempAttacker))
    {
        CPrintToChatAll("{red}%s {olive}AI{default}({red}Boomer{default}) {red}喷吐命中 {olive}%d {red}人", 
            stars, g_iTempBoomerVictims);
    }
    else
    {
        CPrintToChatAll("{red}%s {olive}%N{default}({red}Boomer{default}) {red}喷吐命中 {olive}%d {red}人", 
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

    if (pinned_count >= 2 && !g_bHasAnnouncedCount[pinned_count])
    {
        char stars[16];
        switch(pinned_count)
        {
            case 2: stars = "★★";
            case 3: stars = "★★★";
            case 4: stars = "★★★★";
            default: stars = "★★★★";
        }
        
        CPrintToChatAll("{red}%s {red}特感阵营达成 {olive}%d {red}控", 
            stars, pinned_count);
        
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
        g_bChargeInProgress[client] = true;
        g_iChargerVictimCount[client] = 0;
        
        if (g_hChargeTimer[client] != null)
        {
            KillTimer(g_hChargeTimer[client]);
            g_hChargeTimer[client] = null;
        }
        
        for (int i = 1; i <= MaxClients; i++)
            g_bChargerVictims[client][i] = false;
            
        g_hChargeTimer[client] = CreateTimer(3.0, Timer_ShowChargeResult, client);
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
            if (g_bChargeInProgress[attacker] && !g_bChargerVictims[attacker][victim])
            {
                g_bChargerVictims[attacker][victim] = true;
                g_iChargerVictimCount[attacker]++;
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
        if (!g_bTankVictims[attacker][victim])
        {
            g_bTankVictims[attacker][victim] = true;
            g_iTankVictimCount[attacker]++;
            
            if (g_iTankVictimCount[attacker] >= 2)
            {
                if (g_hTankTimer != null)
                {
                    KillTimer(g_hTankTimer);
                    g_hTankTimer = null;
                }
                
                g_iTempTankVictims = g_iTankVictimCount[attacker];
                g_iTempAttacker = attacker;
                g_hTankTimer = CreateTimer(0.1, Timer_ShowTankMessage);
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
        
    if (g_bChargeInProgress[client] && !g_bChargerVictims[client][victim])
    {
        g_bChargerVictims[client][victim] = true;
        g_iChargerVictimCount[client]++;
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