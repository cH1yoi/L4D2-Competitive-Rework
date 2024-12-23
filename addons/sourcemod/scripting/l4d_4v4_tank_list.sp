#pragma semicolon 1
#pragma newdecls required

#define REQUIRE_PLUGIN
#include <sourcemod>
#include <l4d_tank_control_eq>


public void OnPluginStart()
{
    // Register sm_tankinfo
    RegConsoleCmd("sm_tankinfo", Cmd_TankInfo, "tankinfo");
    //Register sm_tanklist
    RegConsoleCmd("sm_tanklist", Cmd_TankList, "tanklist_info");
}

// Get Tankinfo which players are in list 
public Action Cmd_TankInfo(int client, int args)
{
    if (!client)
        return Plugin_Handled;
    //use the GetTankQueue to get Tankinfo    
    ArrayList tankQueue = GetTankQueue();
    
    if (tankQueue == null){
        return Plugin_Handled;
    }
        PrintToChat(client, "[Tank Info] Tank队列:");
    // show player  who is in tanklist 
    char steamId[64], playerName[MAX_NAME_LENGTH];
    for (int i = 0; i < tankQueue.Length; i++)
    {
        tankQueue.GetString(i, steamId, sizeof(steamId));
        int target = GetClientBySteamId(steamId);
        if (target != -1)
        {
            GetClientName(target, playerName, sizeof(playerName));
            PrintToChat(client, "%d. %s", i + 1, playerName);
        }
    }
    //delete Internal memory
    delete tankQueue;
    return Plugin_Handled;
}
//Get TankList which players will are to play tank
public Action Cmd_TankList(int client, int args)
{
    if (!client){
        return Plugin_Handled;
    }
    //Get WHO was play the tank and who was not play the tank
    ArrayList hadTank = GetWhosHadTank();
    ArrayList notHadTank = GetWhosNotHadTank();

    if (hadTank == null || notHadTank == null){
        return Plugin_Handled;
    }
    PrintToChat(client, "[Tank Info] 已经当过Tank的玩家:");
        PrintPlayerList(client, hadTank);
    PrintToChat(client, "[Tank Info] 还没当过Tank的玩家:");
        PrintPlayerList(client, notHadTank);

    //delete Internal memory
    delete hadTank;
    delete notHadTank;
    return Plugin_Handled;
}

//Get player SteamID
int GetClientBySteamId(const char[] steamId)
{
    char tempSteamId[64];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            GetClientAuthId(i, AuthId_Steam2, tempSteamId, sizeof(tempSteamId));
            if (StrEqual(steamId, tempSteamId))
            {
                return i;
            }
        }
    }
    return -1;
}

//Print playername
void PrintPlayerList(int client, ArrayList list)
{
    char steamId[64], playerName[MAX_NAME_LENGTH];
    for (int i = 0; i < list.Length; i++)
    {
        list.GetString(i, steamId, sizeof(steamId));
        int target = GetClientBySteamId(steamId);
        
        if (target != -1)
        {
            GetClientName(target, playerName, sizeof(playerName));
            PrintToChat(client, "- %s", playerName);
        }
    }
}