#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.0"
#define team_Survivors 2
#define team_Infecteds 3

ConVar g_hCvarEnable;

public Plugin myinfo =
{
	name		= "fix join team exception",
	author		= "HANA",
	description = "修复在zonemod基础上生还/感染>4人但无法M加入问题",
	version		= PLUGIN_VERSION,
	url			= "https://www.hanacloud.site"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion Game = GetEngineVersion();
	if (Game != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_hCvarEnable = CreateConVar("l4d2_fix_jointeam_enable", "1", "1 = Enable, 0 = Disable", _, true, 0.0, true, 1.0);
	AddCommandListener(CallBack_JoinTeam, "jointeam");
}

public Action CallBack_JoinTeam(int client, const char[] command, int argc)
{
	if (g_hCvarEnable.BoolValue)
	{
		char s_command[128];
		GetCmdArg(1, s_command, sizeof(s_command));
		if (StrEqual(s_command, "3", false) || StrEqual(s_command, "infected", false))
		{
			if (!IsTeamFull(team_Infecteds))
				ChangeClientTeam(client, 3);
		}
		else if (StrEqual(s_command, "2", false) || StrEqual(s_command, "survivor", false))
		{
			if (!IsTeamFull(team_Survivors))
				CheatCommand(client, "sb_takecontrol");
		}
	}
	return Plugin_Continue;
}

bool IsTeamFull(int teamnum)
{
	ConVar hcounts;
	int	   icounts;
	switch (teamnum)
	{
		case team_Survivors:
			hcounts = FindConVar("survivor_limit");
		case team_Infecteds:
			hcounts = FindConVar("z_max_player_zombies");
	}
	if (hcounts != null)
	{
		icounts = hcounts.IntValue;
	}
	return RealPlayers(teamnum) < icounts ? false : true;
}

int RealPlayers(int teamnum)
{
	int count;
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == teamnum)
			count++;
	}
	return count;
}

void CheatCommand(int client, const char[] sCommand)
{
	if (client == 0 || !IsClientInGame(client))
		return;

	char sCmd[16];
	SplitString(sCommand, " ", sCmd, sizeof(sCmd));
	int bits = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(sCmd);
	SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, sCommand);
	SetCommandFlags(sCmd, flags);
	SetUserFlagBits(client, bits);
	if (sCommand[0] == 'g' && strcmp(sCommand[5], "health") == 0)
	{
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	}
}
