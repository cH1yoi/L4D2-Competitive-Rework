#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define TEAM_SPECTATOR 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

TopMenu hTopMenu;
TopMenuObject hServerCommands;

public Plugin myinfo =
{
    name = "Admin Health & Respawn Menu",
    description = "狗管理神权时刻",
    author = "Hana",
    version = "1.0",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

public void OnPluginStart()
{
    RegAdminCmd("sm_hp", Command_GiveHP, ADMFLAG_CHEATS, "Restore health for survivors");
    RegAdminCmd("sm_givehp", Command_GiveHP, ADMFLAG_CHEATS, "Restore health for survivors");
    RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_CHEATS, "Respawn a specific player");

    LoadTranslations("common.phrases");

    TopMenu topmenu = GetAdminTopMenu();
    if(topmenu != null)
    {
        OnAdminMenuReady(topmenu);
    }
}

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
    if(topmenu == hTopMenu) return;

    hTopMenu = topmenu;
    hServerCommands = hTopMenu.FindCategory(ADMINMENU_SERVERCOMMANDS);
    
    if(hServerCommands != INVALID_TOPMENUOBJECT)
    {
        hTopMenu.AddItem("sm_givehp", AdminMenu_GiveHP, hServerCommands, "sm_givehp", ADMFLAG_CHEATS);
        hTopMenu.AddItem("sm_respawn", AdminMenu_Respawn, hServerCommands, "sm_respawn", ADMFLAG_CHEATS);
    }
}

public Action Command_GiveHP(int client, int args)
{
    char command[32];
    GetCmdArg(0, command, sizeof(command));
    
    if(StrEqual(command, "sm_hp", false))
    {
        for(int i = 1; i <= MaxClients; i++)
        {
            if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
            {
                CheatCommand(i);
            }
        }
        PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01恢复了 \x05全体生还者 \x04的生命值", client);
        return Plugin_Handled;
    }
    
    if(StrEqual(command, "sm_givehp", false) && args < 1)
    {
        DisplayHPMenu(client);
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true, false);
    if(target != -1 && GetClientTeam(target) == TEAM_SURVIVORS)
    {
        CheatCommand(target);
        PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01恢复了 \x05%N \x04的生命值", client, target);
    }
    
    return Plugin_Handled;
}

public Action Command_Respawn(int client, int args)
{
    if(args < 1)
    {
        DisplayRespawnMenu(client);
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true, false);
    if(target != -1 && GetClientTeam(target) == TEAM_SURVIVORS)
    {
        float pos[3];
        if(GetClientAimPosition(client, pos))
        {
            RespawnPlayer(target, pos);
            PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01复活了玩家 \x05%N", client, target);
        }
    }
    
    return Plugin_Handled;
}

void DisplayHPMenu(int client)
{
    Menu menu = new Menu(MenuHandler_GiveHP);
    menu.SetTitle("选择要恢复血量的目标:");
    menu.AddItem("0", "全体生还者");
    
    char userid[12], name[MAX_NAME_LENGTH];
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
        {
            Format(userid, sizeof(userid), "%d", GetClientUserId(i));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(userid, name);
        }
    }
    
    AddMenuExitBack(menu, client);
}

void DisplayRespawnMenu(int client)
{
    Menu menu = new Menu(MenuHandler_RespawnPlayer);
    menu.SetTitle("选择要复活的玩家:");
    
    char userid[12], name[MAX_NAME_LENGTH];
    bool foundTarget = false;
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS && !IsPlayerAlive(i))
        {
            Format(userid, sizeof(userid), "%d", GetClientUserId(i));
            GetClientName(i, name, sizeof(name));
            menu.AddItem(userid, name);
            foundTarget = true;
        }
    }
    
    if(!foundTarget)
    {
        menu.AddItem("", "人都活着你还想复活谁", ITEMDRAW_DISABLED);
    }
    
    AddMenuExitBack(menu, client);
}

void AddMenuExitBack(Menu menu, int client)
{
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_GiveHP(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            
            int userid = StringToInt(item);
            if(userid == 0)
            {
                for(int i = 1; i <= MaxClients; i++)
                {
                    if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVORS)
                    {
                        CheatCommand(i);
                    }
                }
                PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01恢复了 \x05全体生还者 \x04的生命值", param1);
            }
            else
            {
                int target = GetClientOfUserId(userid);
                if(target && IsClientInGame(target))
                {
                    CheatCommand(target);
                    PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01恢复了 \x05%N \x04的生命值", param1, target);
                }
            }
            DisplayHPMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack && hTopMenu)
            {
                hTopMenu.Display(param1, TopMenuPosition_LastCategory);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public int MenuHandler_RespawnPlayer(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char item[12];
            menu.GetItem(param2, item, sizeof(item));
            
            int userid = StringToInt(item);
            int target = GetClientOfUserId(userid);
            
            if(target && IsClientInGame(target))
            {
                float pos[3];
                if(GetClientAimPosition(param1, pos))
                {
                    RespawnPlayer(target, pos);
                    PrintToChatAll("\x01[\x05!\x01] 管理员 \x03%N \x01复活了玩家 \x05%N", param1, target);
                }
            }
            DisplayRespawnMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack && hTopMenu)
            {
                hTopMenu.Display(param1, TopMenuPosition_LastCategory);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

void RespawnPlayer(int client, float pos[3])
{
    float ang[3];
    GetClientEyeAngles(client, ang);
    
    if(GetClientTeam(client) != TEAM_SURVIVORS)
    {
        ChangeClientTeam(client, TEAM_SURVIVORS);
    }
    
    L4D_RespawnPlayer(client);
    
    DataPack dp = new DataPack();
    dp.WriteCell(GetClientUserId(client));
    dp.WriteFloat(pos[0]);
    dp.WriteFloat(pos[1]);
    dp.WriteFloat(pos[2]);
    dp.WriteFloat(ang[0]);
    dp.WriteFloat(ang[1]);
    dp.WriteFloat(ang[2]);
    RequestFrame(OnPlayerRespawned, dp);
}

public void OnPlayerRespawned(DataPack dp)
{
    dp.Reset();
    int client = GetClientOfUserId(dp.ReadCell());
    
    if(client && IsClientInGame(client))
    {
        float pos[3], ang[3];
        pos[0] = dp.ReadFloat();
        pos[1] = dp.ReadFloat();
        pos[2] = dp.ReadFloat();
        ang[0] = dp.ReadFloat();
        ang[1] = dp.ReadFloat();
        ang[2] = dp.ReadFloat();
        
        TeleportEntity(client, pos, ang, NULL_VECTOR);
        
        int give_flags = GetCommandFlags("give");
        SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
        FakeClientCommand(client, "give health");
        FakeClientCommand(client, "give pistol");
        FakeClientCommand(client, "give smg");
        SetCommandFlags("give", give_flags);
        
        SetEntityMoveType(client, MOVETYPE_WALK);
    }
    
    delete dp;
}

void CheatCommand(int client)
{
    int give_flags = GetCommandFlags("give");
    SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

    if(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") || 
       (IsIncapacitated(client) && GetInfectedAttacker(client) == -1) ||
       GetClientHealth(client) < 100)
    {
        FakeClientCommand(client, "give health");
        if(!GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
        {
            SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
        }
    }
    
    SetCommandFlags("give", give_flags);
}

bool IsIncapacitated(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

int GetInfectedAttacker(int client)
{
    static const char attackerProps[][] = {
        "m_pummelAttacker",
        "m_carryAttacker",
        "m_jockeyAttacker",
        "m_pounceAttacker",
        "m_tongueOwner"
    };
    
    int attacker;
    for(int i = 0; i < sizeof(attackerProps); i++)
    {
        attacker = GetEntPropEnt(client, Prop_Send, attackerProps[i]);
        if(attacker > 0) return attacker;
    }
    return -1;
}

bool GetClientAimPosition(int client, float pos[3])
{
    float vAngles[3], vOrigin[3];
    GetClientEyePosition(client, vOrigin);
    GetClientEyeAngles(client, vAngles);
    
    Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    if(TR_DidHit(trace))
    {
        TR_GetEndPosition(pos, trace);
        delete trace;
        return true;
    }
    delete trace;
    return false;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity > MaxClients || !entity;
}

public void AdminMenu_GiveHP(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if(action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "恢复血量");
    }
    else if(action == TopMenuAction_SelectOption)
    {
        DisplayHPMenu(param);
    }
}

public void AdminMenu_Respawn(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if(action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "复活玩家");
    }
    else if(action == TopMenuAction_SelectOption)
    {
        DisplayRespawnMenu(param);
    }
}