#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <colors>
#include <mix_team>
#include <steamworks>
#include <exp_interface>


public Plugin myinfo = { 
	name = "MixTeamExperience",
	author = "SirP, TouchMe, Hana",
	description = "Adds mix team by game experience",
	version = "build_0001"
};

#define TRANSLATIONS            "mt_experience.phrases"

#define MIN_PLAYERS             4

// Other
#define APP_L4D2                550

// Macros
#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_REAL_CLIENT(%1)      (IsClientInGame(%1) && !IsFakeClient(%1))

enum struct PlayerInfo {
	int id;
	int rating;
}

float g_fSurr = 0.0, g_fInfr = 0.0;

enum struct PlayerStats {
	int playedTime;
	int tankRocks;
	int gamesWon;
	int gamesLost;
	int killBySilenced;
	int killBySmg;
	int killByChrome;
	int killByPump;
}


/**
 * Loads dictionary files. On failure, stops the plugin execution.
 */
void InitTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "translations/" ... TRANSLATIONS ... ".txt");

	if (FileExists(sPath)) {
		LoadTranslations(TRANSLATIONS);
	} else {
		SetFailState("Path %s not found", sPath);
	}
}

/**
 * Called when the plugin is fully initialized and all known external references are resolved.
 */
public void OnPluginStart() {
	InitTranslations();
}

public void OnAllPluginsLoaded() {
	AddMix("exp", MIN_PLAYERS, 0);
}

public void GetVoteDisplayMessage(int iClient, char[] sDisplayMsg) {
	Format(sDisplayMsg, DISPLAY_MSG_SIZE, "%T", "VOTE_DISPLAY_MSG", iClient);
}
public void GetVoteEndMessage(int iClient, char[] sMsg) {
    Format(sMsg, VOTEEND_MSG_SIZE, "%T", "VOTE_END_MSG", iClient);
}
/**
 * Starting the mix.
 */
public Action OnMixInProgress()
{
    Handle hPlayers = CreateArray(sizeof(PlayerInfo));
    PlayerInfo tPlayer;
    g_fSurr = 0.0;
    g_fInfr = 0.0;

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient) || !IsMixMember(iClient)) {
            continue;
        }

        tPlayer.id = iClient;
        tPlayer.rating = L4D2_GetClientExp(iClient);

        if (tPlayer.rating <= 0)
        {
            CPrintToChatAll("%t", "FAIL_PLAYER_HIDE_INFO_STOP", iClient);
            Call_AbortMix();
            return Plugin_Handled;
        }

        PushArrayArray(hPlayers, tPlayer);
    }

    SortADTArrayCustom(hPlayers, SortPlayerByRating);

    int iPlayers = GetArraySize(hPlayers);
    
    for (int i = 0; i < iPlayers; i++)
    {
        GetArrayArray(hPlayers, i, tPlayer);
        
        bool bAssignToSurvivor;
        
        if (i < 2) {
            bAssignToSurvivor = (i == 0);
        } else {
            bAssignToSurvivor = (g_fSurr < g_fInfr);
        }

        SetClientTeam(tPlayer.id, bAssignToSurvivor ? TEAM_SURVIVOR : TEAM_INFECTED);
        
        if (bAssignToSurvivor) {
            g_fSurr += float(tPlayer.rating);
        } else {
            g_fInfr += float(tPlayer.rating);
        }
    }

    int iSurvivorCount = 0, iInfectedCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i) || IsFakeClient(i) || !IsMixMember(i)) {
            continue;
        }
        
        if (GetClientTeam(i) == TEAM_SURVIVOR) {
            iSurvivorCount++;
        } else if (GetClientTeam(i) == TEAM_INFECTED) {
            iInfectedCount++;
        }
    }

    CPrintToChatAll("分配结果: %d生还 vs %d特感", iSurvivorCount, iInfectedCount);
    CPrintToChatAll("队伍评分 - 生还: %.2f / 特感: %.2f (差值: %.2f)", 
        g_fSurr, g_fInfr, FloatAbs(g_fSurr - g_fInfr));
    
    return Plugin_Continue;
}

public void SteamWorks_OnValidateClient(int iOwnerAuthId, int iAuthId)
{
    CreateTimer(0.5, Timer_RequestStats, iAuthId);
}

public Action Timer_RequestStats(Handle timer, any iAuthId)
{
    int iClient = GetClientFromSteamID(iAuthId);
    
    if(IS_VALID_CLIENT(iClient) && IsClientConnected(iClient) && IsClientInGame(iClient) && !IsFakeClient(iClient)) {
        SteamWorks_RequestStats(iClient, APP_L4D2);
    }
    
    return Plugin_Stop;
}

/**
  * @param indexFirst    First index to compare.
  * @param indexSecond   Second index to compare.
  * @param hArrayList    Array that is being sorted (order is undefined).
  * @param hndl          Handle optionally passed in while sorting.
  *
  * @return              -1 if first should go before second
  *                      0 if first is equal to second
  *                      1 if first should go after second
  */
int SortPlayerByRating(int indexFirst, int indexSecond, Handle hArrayList, Handle hndl)
{
	PlayerInfo tPlayerFirst, tPlayerSecond;

	GetArrayArray(hArrayList, indexFirst, tPlayerFirst);
	GetArrayArray(hArrayList, indexSecond, tPlayerSecond);

	if (tPlayerFirst.rating < tPlayerSecond.rating) {
		return -1;
	}

	if (tPlayerFirst.rating > tPlayerSecond.rating) {
		return 1;
	}

	return 0;
}

int GetClientFromSteamID(int authid)
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(!IsClientConnected(iClient) || GetSteamAccountID(iClient) != authid) {
			continue;
		}

		return iClient;
	}

	return -1;
}