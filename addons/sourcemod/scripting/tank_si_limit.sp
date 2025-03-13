#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
    name = "TankSpawn SI Limit Manager",
    author = "HANA",
    description = "给克局设定其他特感数量",
    version = "1.0",
    url = "https://github.com/cH1yoi"
};

ConVar g_hHunterLimit;
ConVar g_hBoomerLimit;
ConVar g_hSmokerLimit;
ConVar g_hJockeyLimit;
ConVar g_hChargerLimit;

int g_iOriginalHunterLimit;
int g_iOriginalBoomerLimit;
int g_iOriginalSmokerLimit;
int g_iOriginalJockeyLimit;
int g_iOriginalChargerLimit;

ConVar g_hCustomHunterLimit;
ConVar g_hCustomBoomerLimit;
ConVar g_hCustomSmokerLimit;
ConVar g_hCustomJockeyLimit;
ConVar g_hCustomChargerLimit;
ConVar g_hEnablePlugin;

bool g_bTankIsAlive = false;
int g_iTankClient = 0;

public void OnPluginStart()
{
    g_hEnablePlugin = CreateConVar("tank_si_manager_enable", "0", "Enable/disable the Tank SI Limit Manager plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);

    g_hCustomHunterLimit = CreateConVar("tank_hunter_limit", "2", "Hunter limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 3.0);
    g_hCustomBoomerLimit = CreateConVar("tank_boomer_limit", "1", "Boomer limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 3.0);
    g_hCustomSmokerLimit = CreateConVar("tank_smoker_limit", "2", "Smoker limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 3.0);
    g_hCustomJockeyLimit = CreateConVar("tank_jockey_limit", "2", "Jockey limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 3.0);
    g_hCustomChargerLimit = CreateConVar("tank_charger_limit", "4", "Charger limit when tank is active", FCVAR_NOTIFY, true, 0.0, true, 3.0);
    
    g_hHunterLimit = FindConVar("z_versus_hunter_limit");
    g_hBoomerLimit = FindConVar("z_versus_boomer_limit");
    g_hSmokerLimit = FindConVar("z_versus_smoker_limit");
    g_hJockeyLimit = FindConVar("z_versus_jockey_limit");
    g_hChargerLimit = FindConVar("z_versus_charger_limit");
    
    StoreOriginalValues();
    
    HookEvent("tank_spawn", Event_TankSpawn);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    
    HookConVarChange(g_hHunterLimit, ConVarChanged_SILimit);
    HookConVarChange(g_hBoomerLimit, ConVarChanged_SILimit);
    HookConVarChange(g_hSmokerLimit, ConVarChanged_SILimit);
    HookConVarChange(g_hJockeyLimit, ConVarChanged_SILimit);
    HookConVarChange(g_hChargerLimit, ConVarChanged_SILimit);
}

public void OnPluginEnd()
{
    if (g_bTankIsAlive)
    {
        RestoreOriginalLimits();
    }
}

public void OnMapStart()
{
    StoreOriginalValues();
    g_bTankIsAlive = false;
    g_iTankClient = 0;
    
    RestoreOriginalLimits();
}

public void OnClientDisconnect_Post(int client)
{
    if (!g_bTankIsAlive || client != g_iTankClient) return;
    
    CreateTimer(0.5, Timer_CheckTank, client);
}

void StoreOriginalValues()
{
    if (!g_bTankIsAlive)
    {
        g_iOriginalHunterLimit = g_hHunterLimit.IntValue;
        g_iOriginalBoomerLimit = g_hBoomerLimit.IntValue;
        g_iOriginalSmokerLimit = g_hSmokerLimit.IntValue;
        g_iOriginalJockeyLimit = g_hJockeyLimit.IntValue;
        g_iOriginalChargerLimit = g_hChargerLimit.IntValue;
    }
}

void SetCustomLimits()
{
    if (!g_hEnablePlugin.BoolValue) return;
    
    g_hHunterLimit.IntValue = g_hCustomHunterLimit.IntValue;
    g_hBoomerLimit.IntValue = g_hCustomBoomerLimit.IntValue;
    g_hSmokerLimit.IntValue = g_hCustomSmokerLimit.IntValue;
    g_hJockeyLimit.IntValue = g_hCustomJockeyLimit.IntValue;
    g_hChargerLimit.IntValue = g_hCustomChargerLimit.IntValue;
}

void RestoreOriginalLimits()
{
    if (g_hHunterLimit.IntValue != g_iOriginalHunterLimit || 
        g_hBoomerLimit.IntValue != g_iOriginalBoomerLimit ||
        g_hSmokerLimit.IntValue != g_iOriginalSmokerLimit ||
        g_hJockeyLimit.IntValue != g_iOriginalJockeyLimit ||
        g_hChargerLimit.IntValue != g_iOriginalChargerLimit)
    {
        g_hHunterLimit.IntValue = g_iOriginalHunterLimit;
        g_hBoomerLimit.IntValue = g_iOriginalBoomerLimit;
        g_hSmokerLimit.IntValue = g_iOriginalSmokerLimit;
        g_hJockeyLimit.IntValue = g_iOriginalJockeyLimit;
        g_hChargerLimit.IntValue = g_iOriginalChargerLimit;
    }
}

public void ConVarChanged_SILimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_bTankIsAlive)
    {
        StoreOriginalValues();
    }
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    g_iTankClient = client;
    
    if (g_bTankIsAlive) return;
    
    g_bTankIsAlive = true;
    SetCustomLimits();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (client > 0 && IsTank(client))
    {
        CreateTimer(0.5, Timer_CheckTank, client);
    }
}

public Action Timer_CheckTank(Handle timer, any oldTankClient)
{
    if (g_iTankClient != oldTankClient) return Plugin_Continue;
    
    int tankClient = FindTankClient();
    if (tankClient && tankClient != oldTankClient)
    {
        g_iTankClient = tankClient;
        return Plugin_Continue;
    }
    
    g_bTankIsAlive = false;
    g_iTankClient = 0;
    RestoreOriginalLimits();
    
    return Plugin_Continue;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bTankIsAlive = false;
    g_iTankClient = 0;
    
    StoreOriginalValues();
    
    int tankClient = FindTankClient();
    if (tankClient)
    {
        g_bTankIsAlive = true;
        g_iTankClient = tankClient;
        SetCustomLimits();
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    g_bTankIsAlive = false;
    g_iTankClient = 0;
    RestoreOriginalLimits();
}

bool IsTank(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return false;
    
    return GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
}

int FindTankClient()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && IsTank(i))
        {
            return i;
        }
    }
    return 0;
}