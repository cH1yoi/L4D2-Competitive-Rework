#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sdkhooks>

int g_iLights[MAXPLAYERS+1];

ConVar g_hLightDistance;
ConVar g_hLightRadius;
ConVar g_hLightColor;

public Plugin myinfo =
{
    name = "[L4D & L4D2] Dead/Spectator Light Remake",
    author = "SilverShot, Hana",
    description = "Attaches a personal light when players are dead or spectators.",
    version = "1.1",
    url = "https://github.com/cH1yoi"
};

public void OnPluginStart()
{
    g_hLightDistance = CreateConVar("sm_speclight_distance", "1024.0", "Spectator light distance.", FCVAR_NONE, true, 32.0, true, 2048.0);
    g_hLightRadius = CreateConVar("sm_speclight_radius", "256.0", "Spectator light radius.", FCVAR_NONE, true, 8.0, true, 512.0);
    g_hLightColor = CreateConVar("sm_speclight_color", "255 255 255 255", "Spectator light color RGBA.", FCVAR_NONE);

    RegConsoleCmd("sm_speclight", CmdSpeclight);
    HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", EventPlayerDeath, EventHookMode_Post);
    HookEvent("player_team", EventPlayerTeam, EventHookMode_Post);
}

public void OnPluginEnd()
{
    for( int i = 0; i <= MAXPLAYERS; i++ )
        if( IsValidEntRef(g_iLights[i]) )
            AcceptEntityInput(g_iLights[i], "Kill");
}

public Action CmdSpeclight(int client, int args)
{
    if( client && (GetClientTeam(client) == 0 || !IsPlayerAlive(client)) )
    {
        int ent = g_iLights[client];
        if( IsValidEntRef(ent) )
        {
            // Toggle or set light colour and turn on.
            if( args == 3 )
            {
                char sTemp[12];
                GetCmdArgString(sTemp, sizeof(sTemp));
                SetVariantEntity(ent);
                SetVariantString(sTemp);
                AcceptEntityInput(ent, "color");
            }
            else
                AcceptEntityInput(ent, "toggle");
        }
        else
        {
            MakeLightDynamic(client);
            ent = g_iLights[client];
        }
    }
    return Plugin_Handled;
}

public void EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if( client && !IsFakeClient(client) )
    {
        int ent = g_iLights[client];
        if( IsValidEntRef(ent) )
        {
            AcceptEntityInput(ent, "Kill");
            g_iLights[client] = 0;
        }
    }
}

public void EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if( client && !IsFakeClient(client) && !IsValidEntRef(g_iLights[client]) )
        MakeLightDynamic(client);
}

public void OnClientDisconnect(int client)
{
    if( IsValidEntRef(g_iLights[client]) )
        AcceptEntityInput(g_iLights[client], "Kill");
}

public void EventPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    int team = event.GetInt("team");

    int ent = g_iLights[client];
    if( client && !IsFakeClient(client) && team == 0 )
    {
        if( !IsValidEntRef(ent) )
        {
            CreateTimer(0.1, tmrMake, userid);
        }
    }
}

public Action tmrMake(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if( client )
        MakeLightDynamic(client);
    return Plugin_Handled;
}

void MakeLightDynamic(int client)
{
    int entity = CreateEntityByName("light_dynamic");

    char sTemp[16];
    char sColor[32];
    g_hLightColor.GetString(sColor, sizeof(sColor));
    DispatchKeyValue(entity, "_light", sColor);
    DispatchKeyValue(entity, "brightness", "2");
    DispatchKeyValueFloat(entity, "spotlight_radius", g_hLightRadius.FloatValue);
    DispatchKeyValueFloat(entity, "distance", g_hLightDistance.FloatValue);
    DispatchKeyValue(entity, "style", "0");
    DispatchSpawn(entity);
    AcceptEntityInput(entity, "TurnOn");

    // Attach to survivor
    Format(sTemp, sizeof(sTemp), "FLRL%d%d", entity, client);
    DispatchKeyValue(client, "targetname", sTemp);
    SetVariantString(sTemp);
    AcceptEntityInput(entity, "SetParent", entity, entity, 0);
    SetVariantString("forward");
    AcceptEntityInput(entity, "SetParentAttachment");

    float vPos[3] = {0.0, 0.0, -50.0};
    TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);

    g_iLights[client] = EntIndexToEntRef(entity);
    SDKHook(entity, SDKHook_SetTransmit, OnTransmit);
}

public Action OnTransmit(int entity, int client)
{
    if( g_iLights[client] && EntRefToEntIndex(g_iLights[client]) == entity )
        return Plugin_Continue;
    return Plugin_Handled;
}

bool IsValidEntRef(int entity)
{
    if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
        return true;
    return false;
}