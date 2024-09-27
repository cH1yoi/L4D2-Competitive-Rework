#pragma semicolon 1

#define TEAM_SPECTATE 1
#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

#define TEAM_A 0
#define TEAM_B 1

#include <sourcemod>
#include <sdktools>

// This plugin is rewrite of "L4D2 Score/Team Manager" by AtomicStryker (https://forums.alliedmods.net/showthread.php?p=1029519)

public Plugin:myinfo =
{
	name = "L4D2 Team Unscrambler",
	author = "Quattros",
	description = "Ignore team balancing and swap players to their teams.",
	version = "0.3",
	url = ""
};

static Handle:g_hCVarSurvivorLimit = INVALID_HANDLE;
static Handle:g_hCVarInfectedLimit = INVALID_HANDLE;

static Handle:g_hDesiredTeamPlacement = INVALID_HANDLE;

static g_iSurvivorLimit;
static g_iInfectedLimit;

static g_iTeamPlacementTry[256];
static g_iTeamPlacementAttempts[256];

static bool:g_bPendingTryTeamPlacement;
static bool:g_bRoundSwitch;

public OnPluginStart()
{
	g_hCVarSurvivorLimit = FindConVar("survivor_limit");
	g_hCVarInfectedLimit = FindConVar("z_max_player_zombies");

	g_iSurvivorLimit = GetConVarInt(g_hCVarSurvivorLimit);
	g_iInfectedLimit = GetConVarInt(g_hCVarInfectedLimit);

	HookConVarChange(g_hCVarSurvivorLimit, CVarChangeSurvivorLimit);
	HookConVarChange(g_hCVarInfectedLimit, CVarChangeInfectedLimit);

	g_hDesiredTeamPlacement = CreateTrie();

	HookEvent("round_start", EventRoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", EventRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", EventPlayerDisconnect, EventHookMode_Post);
	HookEvent("player_team", EventPlayerTeam, EventHookMode_Post);
}

public OnPluginEnd()
{
	CloseHandle(g_hDesiredTeamPlacement);
}

public CVarChangeSurvivorLimit(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	g_iSurvivorLimit = StringToInt(sNewValue);
}

public CVarChangeInfectedLimit(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	g_iInfectedLimit = StringToInt(sNewValue);
}

public EventRoundStart(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
	g_bRoundSwitch = false;
}

public EventRoundEnd(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
	if (!g_bRoundSwitch && InSecondHalfOfRound())
	{
		CreateTimer(10.0, TimerCalculateTeamPlacement, _, TIMER_FLAG_NO_MAPCHANGE);
	}

	g_bRoundSwitch = true;
}

public EventPlayerDisconnect(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
	if (!g_bRoundSwitch && !IsClientHuman(GetClientOfUserId(GetEventInt(hEvent, "userid"))))
	{
		TryTeamPlacementDelayed();
	}
}

public EventPlayerTeam(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
	if (g_bRoundSwitch)
	{
		return;
	}

	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	if (iClient < 1 || iClient > MaxClients || IsFakeClient(iClient))
	{
		return;
	}

	new iTeam;

	decl String:sAuthID[32];
	GetClientAuthString(iClient, sAuthID, sizeof(sAuthID));

	if (GetTrieValue(g_hDesiredTeamPlacement, sAuthID, iTeam))
	{
		g_iTeamPlacementTry[iClient] = iTeam;

		RemoveFromTrie(g_hDesiredTeamPlacement, sAuthID);
	}

	TryTeamPlacementDelayed();
}

public Action:TimerCalculateTeamPlacement(Handle:hTimer)
{
	new iTeamScores[2];

	iTeamScores[TEAM_A] = GetVsCampaignScores(TEAM_A);
	iTeamScores[TEAM_B] = GetVsCampaignScores(TEAM_B);

	new bool:bTeamsFlipped = AreTeamsFlipped();
	new bool:bRevertTeams;

	if ((bTeamsFlipped && iTeamScores[TEAM_A] > iTeamScores[TEAM_B])
	|| (!bTeamsFlipped && iTeamScores[TEAM_A] < iTeamScores[TEAM_B]))
	{
		bRevertTeams = true;
	}

	ClearTeamPlacement();

	new iDesiredTeam;
	decl String:sAuthID[32];

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			GetClientAuthString(i, sAuthID, sizeof(sAuthID));

			iDesiredTeam = GetClientTeamForNextMap(bRevertTeams, GetClientTeam(i));

			SetTrieValue(g_hDesiredTeamPlacement, sAuthID, iDesiredTeam);
		}
	}
}

static GetClientTeamForNextMap(bool:bRevertTeams, iTeam)
{
	if (!bRevertTeams)
	{
		return iTeam;
	}

	switch (iTeam)
	{
		case TEAM_SURVIVORS:
		{
			return TEAM_INFECTED;
		}

		case TEAM_INFECTED:
		{
			return TEAM_SURVIVORS;
		}
	}

	return TEAM_SPECTATE;
}

static TryTeamPlacementDelayed()
{
	if (!g_bPendingTryTeamPlacement)
	{
		CreateTimer(0.1, TimerTryTeamPlacement);

		g_bPendingTryTeamPlacement = true;
	}
}

public Action:TimerTryTeamPlacement(Handle:hTimer)
{
	TryTeamPlacement();

	g_bPendingTryTeamPlacement = false;
}

static TryTeamPlacement()
{
	new iFreeSlots[4];

	iFreeSlots[TEAM_SPECTATE] = GetTeamMaxHumans(TEAM_SPECTATE);
	iFreeSlots[TEAM_SURVIVORS] = GetTeamMaxHumans(TEAM_SURVIVORS);
	iFreeSlots[TEAM_INFECTED] = GetTeamMaxHumans(TEAM_INFECTED);

	iFreeSlots[TEAM_SURVIVORS] -= GetTeamHumanCount(TEAM_SURVIVORS);
	iFreeSlots[TEAM_INFECTED] -= GetTeamHumanCount(TEAM_INFECTED);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			new iTeam = g_iTeamPlacementTry[i];

			if (!iTeam)
			{
				continue;
			}

			new iOldTeam = GetClientTeam(i);

			if (iTeam == iOldTeam)
			{
				g_iTeamPlacementTry[i] = 0;
				g_iTeamPlacementAttempts[i] = 0;
			}
			else if (iFreeSlots[iTeam] > 0)
			{
				ChangePlayerTeamDelayed(i, iTeam);

				iFreeSlots[iTeam]--;
				iFreeSlots[iOldTeam]++;
			}
			else
			{
				if (g_iTeamPlacementAttempts[i] > 0)
				{
					if (GetClientTeam(i) != TEAM_SPECTATE)
					{
						g_iTeamPlacementTry[i] = 0;

						g_iTeamPlacementAttempts[i] = 0;
					}
				}
				else
				{
					iFreeSlots[TEAM_SPECTATE]--;
					iFreeSlots[iOldTeam]++;

					ChangePlayerTeamDelayed(i, TEAM_SPECTATE);

					g_iTeamPlacementAttempts[i]++;
				}
			}
		}
		else
		{
			if (!IsClientConnected(i) || IsFakeClient(i))
			{
				g_iTeamPlacementTry[i] = 0;
				g_iTeamPlacementAttempts[i] = 0;
			}
		}
	}
}

static ChangePlayerTeamDelayed(iClient, iTeam)
{
	new Handle:hPack;

	CreateDataTimer(0.1, TimerChangePlayerTeam, hPack);

	WritePackCell(hPack, iClient);
	WritePackCell(hPack, iTeam);
}

public Action:TimerChangePlayerTeam(Handle:hTimer, Handle:hPack)
{
	ResetPack(hPack);

	new iClient = ReadPackCell(hPack);
	new iTeam = ReadPackCell(hPack);

	if (IsClientHuman(iClient))
	{
		ChangePlayerTeam(iClient, iTeam);
	}
}

static bool:ChangePlayerTeam(iClient, iTeam)
{
	if (GetClientTeam(iClient) == iTeam)
	{
		return true;
	}

	if (iTeam == TEAM_SPECTATE)
	{
		ChangeClientTeam(iClient, iTeam);

		return true;
	}

	if (GetTeamHumanCount(iTeam) == GetTeamMaxHumans(iTeam))
	{
		return false;
	}

	if (iTeam == TEAM_INFECTED)
	{
		ChangeClientTeam(iClient, iTeam);

		return true;
	}

	new iBot = FindSurvivorBot();
	new iFlags;

	if (iBot == -1)
	{
		ChangeClientTeam(iClient, _:iTeam);
		iFlags = GetCommandFlags("respawn");
		SetCommandFlags("respawn", iFlags & ~FCVAR_CHEAT);
		FakeClientCommand(iClient, "respawn");
		SetCommandFlags("respawn", iFlags);
	}
	else
	{
		iFlags = GetCommandFlags("sb_takecontrol");
		SetCommandFlags("sb_takecontrol", iFlags & ~FCVAR_CHEAT);
		FakeClientCommand(iClient, "sb_takecontrol");
		SetCommandFlags("sb_takecontrol", iFlags);
	}

	return true;
}

static ClearTeamPlacement()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		g_iTeamPlacementTry[i] = 0;
		g_iTeamPlacementAttempts[i] = 0;
	}

	ClearTrie(g_hDesiredTeamPlacement);
}

stock bool:IsClientHuman(iClient)
{
	return bool:(iClient > 0 && iClient <= MaxClients && IsClientInGame(iClient) && !IsFakeClient(iClient));
}

stock bool:InSecondHalfOfRound()
{
	return bool:GameRules_GetProp("m_bInSecondHalfOfRound");
}

stock bool:AreTeamsFlipped()
{
	return bool:GameRules_GetProp("m_bAreTeamsFlipped");
}

stock GetVsCampaignScores(iTeamNumber)
{
	return GameRules_GetProp("m_iCampaignScore", _, iTeamNumber);
}

stock GetOppositeClientTeam(iClient)
{
	return OppositeCurrentTeam(GetClientTeam(iClient));
}

stock OppositeCurrentTeam(iTeam)
{
	if (iTeam == TEAM_SPECTATE)
	{
		return TEAM_SPECTATE;
	}
	else if (iTeam == TEAM_SURVIVORS)
	{
		return TEAM_INFECTED;
	}
	else if (iTeam == TEAM_INFECTED)
	{
		return TEAM_SURVIVORS;
	}

	return -1;
}

stock GetTeamHumanCount(iTeam)
{
	new iHumans = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == iTeam)
		{
			iHumans++;
		}
	}

	return iHumans;
}

stock GetTeamMaxHumans(iTeam)
{
	if (iTeam == TEAM_SURVIVORS)
	{
		return g_iSurvivorLimit;
	}
	else if (iTeam == TEAM_INFECTED)
	{
		return g_iInfectedLimit;
	}
	else if (iTeam == TEAM_SPECTATE)
	{
		return MaxClients;
	}

	return -1;
}

stock FindSurvivorBot()
{
	new iBot;

	for (iBot = 1; iBot <= MaxClients && (!IsClientInGame(iBot) || !IsFakeClient(iBot) || (GetClientTeam(iBot) != TEAM_SURVIVORS)); iBot++) { }

	return (iBot == MaxClients + 1) ? -1 : iBot;
}