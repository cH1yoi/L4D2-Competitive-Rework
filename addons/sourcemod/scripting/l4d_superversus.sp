#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define TEAM_SPECTATOR 1
#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3

ConVar g_cvSurvivorLimit;
ConVar g_cvInfectedLimit;
ConVar g_cvGameSurvivorLimit;
ConVar g_cvGameInfectedLimit;

public Plugin myinfo = {
    name = "L4D Multi-Versus",
    author = "Your Name",
    description = "Allows configurable team sizes in versus mode",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    // Create plugin ConVars
    g_cvSurvivorLimit = CreateConVar("l4d_survivor_limit", "4", "Maximum number of survivors", FCVAR_NOTIFY, true, 1.0, true, 24.0);
    g_cvInfectedLimit = CreateConVar("l4d_infected_limit", "4", "Maximum number of infected", FCVAR_NOTIFY, true, 1.0, true, 24.0);
    
    // Get game ConVars
    g_cvGameSurvivorLimit = FindConVar("survivor_limit");
    g_cvGameInfectedLimit = FindConVar("z_max_player_zombies");
    
    // Remove game limits
    SetConVarBounds(g_cvGameSurvivorLimit, ConVarBound_Upper, false);
    SetConVarBounds(g_cvGameInfectedLimit, ConVarBound_Upper, false);
    
    // Hook ConVar changes
    HookConVarChange(g_cvSurvivorLimit, OnLimitChange);
    HookConVarChange(g_cvInfectedLimit, OnLimitChange);
    
    // Register commands
    RegConsoleCmd("sm_sur", Command_JoinSurvivor, "Join survivor team");
    RegConsoleCmd("sm_inf", Command_JoinInfected, "Join infected team");
    RegAdminCmd("sm_versus_setup", Command_SetupVersus, ADMFLAG_ROOT, "Setup versus teams");
    
    AutoExecConfig(true, "l4d_multiverse");
}

public Action Command_JoinSurvivor(int client, int args)
{
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    if (GetClientTeam(client) == TEAM_SURVIVOR)
    {
        PrintToChat(client, "\x01[\x04Multi-Versus\x01] You are already on the survivor team!");
        return Plugin_Handled;
    }
    
    // Check if there's room on survivor team
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
            count++;
    }
    
    if (count >= g_cvSurvivorLimit.IntValue)
    {
        PrintToChat(client, "\x01[\x04Multi-Versus\x01] The survivor team is full!");
        return Plugin_Handled;
    }
    
    // Create a bot for the player if needed
    L4D_RespawnPlayer(client);
    L4D_SetHumanSpec(client, 0); // Clear any existing idle state
    L4D_TakeOverBot(client);
    
    return Plugin_Handled;
}

public Action Command_JoinInfected(int client, int args)
{
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
        
    if (GetClientTeam(client) == TEAM_INFECTED)
    {
        PrintToChat(client, "\x01[\x04Multi-Versus\x01] You are already on the infected team!");
        return Plugin_Handled;
    }
    
    // Check if there's room on infected team
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
            count++;
    }
    
    if (count >= g_cvInfectedLimit.IntValue)
    {
        PrintToChat(client, "\x01[\x04Multi-Versus\x01] The infected team is full!");
        return Plugin_Handled;
    }
    
    L4D_State_Transition(client, 8); // Set to ghost state
    ChangeClientTeam(client, TEAM_INFECTED);
    
    return Plugin_Handled;
}

public void OnLimitChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // Update game limits when plugin limits change
    if(convar == g_cvSurvivorLimit)
    {
        g_cvGameSurvivorLimit.IntValue = g_cvSurvivorLimit.IntValue;
    }
    else if(convar == g_cvInfectedLimit) 
    {
        g_cvGameInfectedLimit.IntValue = g_cvInfectedLimit.IntValue;
    }
}

public Action Command_SetupVersus(int client, int args)
{
    // Force update limits
    g_cvGameSurvivorLimit.IntValue = g_cvSurvivorLimit.IntValue;
    g_cvGameInfectedLimit.IntValue = g_cvInfectedLimit.IntValue;
    
    // Notify
    PrintToChatAll("\x01[\x04Multi-Versus\x01] Teams set to \x05%d\x01v\x05%d", 
        g_cvSurvivorLimit.IntValue,
        g_cvInfectedLimit.IntValue);
    
    return Plugin_Handled;
}

public void OnMapStart()
{
    // Ensure limits are set on map change
    CreateTimer(1.0, Timer_SetupTeams);
}

public Action Timer_SetupTeams(Handle timer)
{
    g_cvGameSurvivorLimit.IntValue = g_cvSurvivorLimit.IntValue;
    g_cvGameInfectedLimit.IntValue = g_cvInfectedLimit.IntValue;
    return Plugin_Stop;
}