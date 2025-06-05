#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#undef REQUIRE_PLUGIN
#include <l4d2_hittable_control>

#define MAX_EDICTS 2048

ConVar g_hCvarColor;
ConVar g_hCvarGlowTime;
int g_iGlowEntities[MAX_EDICTS];
bool g_bHittableControlExists = false;

public Plugin myinfo = 
{
    name = "L4D2 Tank Props Brief Glow",
    author = "HANA",
    description = "Briefly highlight Tank props when Tank spawns",
    version = "1.0",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    g_hCvarColor = CreateConVar("l4d2_tank_prop_brief_glow_color", "80 180 255", "Prop Glow Color (RGB)", FCVAR_NOTIFY);
    g_hCvarGlowTime = CreateConVar("l4d2_tank_prop_brief_glow_time", "7.0", "How long the glow effect lasts (seconds)", FCVAR_NOTIFY, true, 0.1);
    
    HookEvent("tank_spawn", Event_TankSpawn);
    
    for (int i = 0; i < MAX_EDICTS; i++) {
        g_iGlowEntities[i] = -1;
    }
}

public void OnAllPluginsLoaded()
{
    g_bHittableControlExists = LibraryExists("l4d2_hittable_control");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "l4d2_hittable_control", true)) {
        g_bHittableControlExists = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "l4d2_hittable_control", true)) {
        g_bHittableControlExists = false;
    }
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(0.1, Timer_CreateGlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_CreateGlow(Handle timer)
{
    HighlightAllTankProps();
    return Plugin_Stop;
}

void HighlightAllTankProps()
{
    CleanupGlowEntities();
    
    int iEntCount = GetMaxEntities();
    for (int i = MaxClients + 1; i < iEntCount; i++)
    {
        if (IsTankProp(i))
        {
            CreatePropGlow(i);
        }
    }
    
    CreateTimer(g_hCvarGlowTime.FloatValue, Timer_RemoveGlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool IsTankProp(int iEntity)
{
    if (!IsValidEdict(iEntity)) {
        return false;
    }
    
    if (!HasEntProp(iEntity, Prop_Send, "m_hasTankGlow")) {
        return false;
    }
    
    bool bHasTankGlow = (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1) == 1);
    if (!bHasTankGlow) {
        return false;
    }

    bool bAreForkliftsUnbreakable;
    if (g_bHittableControlExists)
    {
        bAreForkliftsUnbreakable = AreForkliftsUnbreakable();
    }
    else
    {
        bAreForkliftsUnbreakable = false;
    }
    
    char sModel[PLATFORM_MAX_PATH];
    GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
    if (strcmp("models/props/cs_assault/forklift.mdl", sModel) == 0 && bAreForkliftsUnbreakable == false) {
        return false;
    }
    
    return true;
}

void CreatePropGlow(int iTarget)
{
    int iEntity = CreateEntityByName("prop_dynamic_override");
    if (iEntity == -1) return;
    
    float vOrigin[3], vAngles[3];
    GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", vOrigin);
    GetEntPropVector(iTarget, Prop_Data, "m_angRotation", vAngles);
    
    char sModelName[PLATFORM_MAX_PATH];
    GetEntPropString(iTarget, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
    
    SetEntityModel(iEntity, sModelName);
    DispatchSpawn(iEntity);
    
    SetEntProp(iEntity, Prop_Send, "m_CollisionGroup", 0);
    SetEntProp(iEntity, Prop_Send, "m_nSolidType", 0);
    SetEntProp(iEntity, Prop_Send, "m_iGlowType", 3);
    SetEntProp(iEntity, Prop_Send, "m_glowColorOverride", GetColor());
    AcceptEntityInput(iEntity, "StartGlowing");
    
    SetEntityRenderMode(iEntity, RENDER_NONE);
    SetEntityRenderColor(iEntity, 0, 0, 0, 0);
    
    TeleportEntity(iEntity, vOrigin, vAngles, NULL_VECTOR);
    SetVariantString("!activator");
    AcceptEntityInput(iEntity, "SetParent", iTarget);
    
    g_iGlowEntities[iTarget] = EntIndexToEntRef(iEntity);
}

Action Timer_RemoveGlow(Handle timer)
{
    CleanupGlowEntities();
    return Plugin_Stop;
}

void CleanupGlowEntities()
{
    for (int i = 0; i < MAX_EDICTS; i++)
    {
        if (g_iGlowEntities[i] != -1)
        {
            int iEntity = EntRefToEntIndex(g_iGlowEntities[i]);
            if (iEntity != INVALID_ENT_REFERENCE)
            {
                AcceptEntityInput(iEntity, "Kill");
            }
            g_iGlowEntities[i] = -1;
        }
    }
}

int GetColor()
{
    char sTemp[16];
    g_hCvarColor.GetString(sTemp, sizeof(sTemp));
    
    if (strcmp(sTemp, "") == 0)
        return 0;
    
    char sColors[3][4];
    int iColor = ExplodeString(sTemp, " ", sColors, 3, 4);
    
    if (iColor != 3)
        return 0;
    
    iColor = StringToInt(sColors[0]);
    iColor += 256 * StringToInt(sColors[1]);
    iColor += 65536 * StringToInt(sColors[2]);
    
    return iColor;
}

public void OnMapEnd()
{
    CleanupGlowEntities();
}
