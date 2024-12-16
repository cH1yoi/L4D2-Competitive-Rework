#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>

int g_iPreviousPinnedCount = 0;

public Plugin myinfo = 
{
    name = "L4D2 Many Pinned Prompt",
    author = "Hana",
    description = "Shows star rating for multiple survivor pins",
    version = "1.0",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    LoadTranslations("l4d2_many_pinned_prompt.phrases");
    
    HookEvent("tongue_grab", Event_SpecialInfectedGrab, EventHookMode_PostNoCopy);
    HookEvent("choke_start", Event_SpecialInfectedGrab, EventHookMode_PostNoCopy);
    HookEvent("lunge_pounce", Event_SpecialInfectedGrab, EventHookMode_PostNoCopy); 
    HookEvent("jockey_ride", Event_SpecialInfectedGrab, EventHookMode_PostNoCopy);
    HookEvent("charger_carry_start", Event_ChargerGrab, EventHookMode_PostNoCopy);
    HookEvent("charger_pummel_start", Event_ChargerGrab, EventHookMode_PostNoCopy);
    
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iPreviousPinnedCount = 0;
}

public void Event_SpecialInfectedGrab(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(1.1, DelayCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_ChargerGrab(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(2.0, DelayCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action DelayCheck(Handle timer)
{
    CheckPinnedNumber();
    return Plugin_Continue;
}

public void CheckPinnedNumber()
{
    int pinned_number = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && 
            GetClientTeam(i) == 2 && 
            IsPlayerAlive(i) &&
            (GetEntPropEnt(i, Prop_Send, "m_tongueOwner") > 0 ||
             GetEntPropEnt(i, Prop_Send, "m_pounceAttacker") > 0 ||
             GetEntPropEnt(i, Prop_Send, "m_carryAttacker") > 0 ||
             GetEntPropEnt(i, Prop_Send, "m_pummelAttacker") > 0 ||
             GetEntPropEnt(i, Prop_Send, "m_jockeyAttacker") > 0))
        {
            pinned_number++;
        }
    }

    if (pinned_number >= 2 && pinned_number != g_iPreviousPinnedCount)
    {
        char buffer[64];
        switch(pinned_number)
        {
            case 2:
                Format(buffer, sizeof(buffer), "%t", "Tag++");
            case 3:
                Format(buffer, sizeof(buffer), "%t", "Tag+++");
            case 4:
                Format(buffer, sizeof(buffer), "%t", "Tag++++");
            default:
                Format(buffer, sizeof(buffer), "%t", "Tag++++");
        }

        CPrintToChatAll("%t", "PinnedMessage", buffer, pinned_number);
        
        g_iPreviousPinnedCount = pinned_number;
    }
    else if (pinned_number < 2)
    {
        g_iPreviousPinnedCount = 0;
    }
}