#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <builtinvotes>
#include <colors>

public Plugin myinfo =
{
	name = "Vote for run command or cfg file",
	description = "使用!vote投票执行命令或cfg文件",
	author = "东",
	version = "1.3.1",
	url = "https://github.com/fantasylidong/"
};

Handle g_hVote, g_hVoteKick, g_hCfgsKV;
ConVar g_hVoteFilelocation;
char g_sCfg[128], g_sVoteFile[128];
int kickclient;

public void OnPluginStart()
{
	char g_sBuffer[128];
	g_hVoteFilelocation = CreateConVar("votecfgfile", "data/cfgs.txt", "投票文件的位置(位于sourcemod/文件夹)", FCVAR_NOTIFY);

	GetConVarString(g_hVoteFilelocation, g_sVoteFile, sizeof(g_sVoteFile));
	RegConsoleCmd("sm_v", VoteRequest, "投票加载cfg或cvar");
	RegConsoleCmd("sm_vote", VoteRequest, "投票加载cfg或cvar");
	RegConsoleCmd("sm_votes", VoteRequest, "投票加载cfg或cvar");
	RegConsoleCmd("sm_vk", KickRequest, "投票踢出玩家");
	RegAdminCmd("sm_cv", VoteCancle, ADMFLAG_GENERIC, "管理员终止此次投票", "", 0);
	g_hVoteFilelocation.AddChangeHook(FileLocationChanged);
	g_hCfgsKV = CreateKeyValues("Cfgs", "", "");
	BuildPath(Path_SM, g_sBuffer, 128, g_sVoteFile);
	if (!FileToKeyValues(g_hCfgsKV, g_sBuffer))
	{
		SetFailState("无法加载%s文件!", g_sVoteFile);
	}
}

public void FileLocationChanged(ConVar convar, const char[] oldValue, const char[] newValue){
	char g_sBuffer[128];
	GetConVarString(g_hVoteFilelocation, g_sVoteFile, sizeof(g_sVoteFile));
	g_hCfgsKV = CreateKeyValues("Cfgs", "", "");
	BuildPath(Path_SM, g_sBuffer, 128, g_sVoteFile);
	if (!FileToKeyValues(g_hCfgsKV, g_sBuffer))
	{
		SetFailState("无法加载%s文件!", g_sVoteFile);
	}
}

public Action VoteCancle(int client, int args)
{
	if (IsBuiltinVoteInProgress())
	{
		CancelBuiltinVote();
		CPrintToChatAll("[{olive}vote{default}] {blue}管理员取消了当前投票!");
		return Plugin_Handled;
	}
	ReplyToCommand(client, "没有投票在进行!");
	return Plugin_Handled;
}

// *************************
// 			生还者
// *************************
// 判断是否有效玩家 id，有效返回 true，无效返回 false
stock bool IsValidClient(int client)
{
	if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
	{
		return true;
	}
	else
	{
		return false;
	}
}

stock bool IsPlayer(int client)
{
	int team = GetClientTeam(client);
	return (team == 2 || team == 3);
}

public Action VoteRequest(int client, int args)
{
	if (!client)
	{
		return Plugin_Handled;
	}
	if (IsValidClient(client) && !IsPlayer(client))
	{
		CPrintToChat(client, "[{olive}vote{default}] {blue}旁观者不允许投票执行命令或cfg文件!");
		return Plugin_Handled;
	}
	if (args > 0)
	{
		char sCfg[128];
		char sBuffer[256];
		GetCmdArg(1, sCfg, sizeof(sCfg));
		BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/%s", sCfg);
		if (DirExists(sBuffer))
		{
			FindConfigName(sCfg, sBuffer, sizeof(sBuffer));
			if (StartVote(client, sBuffer))
			{
				strcopy(g_sCfg, sizeof(g_sCfg), sCfg);
				FakeClientCommand(client, "Vote Yes");
			}
			return Plugin_Handled;
		}
	}
	ShowVoteMenu(client);
	return Plugin_Handled;
}

bool FindConfigName(char[] cfg, char[] message, int maxlength)
{
	KvRewind(g_hCfgsKV);
	if (KvGotoFirstSubKey(g_hCfgsKV, true))
	{
		while (KvJumpToKey(g_hCfgsKV, cfg, false))
		{
			if (KvGotoNextKey(g_hCfgsKV, true))
			{
			}
		}
		KvGetString(g_hCfgsKV, "message", message, maxlength, "");
		return true;
	}
	return false;
}

void ShowVoteMenu(int client)
{
	Handle hMenu = CreateMenu(VoteMenuHandler, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(hMenu, "选择:");
	char sBuffer[64];
	KvRewind(g_hCfgsKV);
	if (KvGotoFirstSubKey(g_hCfgsKV, true))
	{
		do {
			KvGetSectionName(g_hCfgsKV, sBuffer, sizeof(sBuffer));
			AddMenuItem(hMenu, sBuffer, sBuffer, ITEMDRAW_DEFAULT);
		} while (KvGotoNextKey(g_hCfgsKV, true));
	}
	DisplayMenu(hMenu, client, 20);
}

public int VoteMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[128];
		char sBuffer[128];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		KvRewind(g_hCfgsKV);
		if (KvJumpToKey(g_hCfgsKV, sInfo, false) && KvGotoFirstSubKey(g_hCfgsKV, true))
		{
			Handle hMenu = CreateMenu(ConfigsMenuHandler, MENU_ACTIONS_DEFAULT);
			Format(sBuffer, sizeof(sBuffer), "选择 %s :", sInfo);
			SetMenuTitle(hMenu, sBuffer);
			do {
				KvGetSectionName(g_hCfgsKV, sInfo,  sizeof(sInfo));
				KvGetString(g_hCfgsKV, "message", sBuffer, sizeof(sBuffer), "");
				AddMenuItem(hMenu, sInfo, sBuffer, ITEMDRAW_DEFAULT);
			} while (KvGotoNextKey(g_hCfgsKV, true));
			DisplayMenu(hMenu, param1, 20);
		}
		else
		{
			CPrintToChat(param1, "[{olive}vote{default}] {red}没有相关的文件存在.");
			ShowVoteMenu(param1);
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	return 0;
}

public int ConfigsMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[128];
		char sBuffer[128];
		int style;
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo), style, sBuffer, sizeof(sBuffer));
		strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
		if (!StrEqual(g_sCfg, "sm_vk", true))
		{
			if (StartVote(param1, sBuffer))
			{
				FakeClientCommand(param1, "Vote Yes");
			}
			else
			{
				ShowVoteMenu(param1);
			}
		}
		else
		{
			FakeClientCommand(param1, "sm_vk");
		}
	}
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	if (action == MenuAction_Cancel)
	{
		ShowVoteMenu(param1);
	}
	return 0;
}

bool StartVote(int client, char[] cfgname)
{
	if (!IsBuiltinVoteInProgress())
	{
		char sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BUILTINVOTE_ACTIONS_DEFAULT);
		Format(sBuffer, 64, "执行 '%s' ?", cfgname);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, VoteResultHandler);
		DisplayBuiltinVoteToAllNonSpectators(g_hVote, 12);
		CPrintToChatAll("[{olive}vote{default}] {blue}%N 发起了一个投票", client);
		return true;
	}
	CPrintToChat(client, "[{olive}vote{default}] {red}已经有一个投票正在进行.");
	return false;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i< num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				if (g_hVote == vote)
				{
					DisplayBuiltinVotePass(vote, "文件正在加载...");
					ServerCommand("%s", g_sCfg);
					return;
				}
				if (g_hVoteKick == vote)
				{
					DisplayBuiltinVotePass(vote, "投票已完成...");
					KickClient(kickclient, "投票踢出");
					return;
				}
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action KickRequest(int client, int args)
{
	if (client && client <= MaxClients)
	{
		CreateVotekickMenu(client);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

void CreateVotekickMenu(int client)
{
	Handle menu = CreateMenu(Menu_Voteskick, MENU_ACTIONS_DEFAULT);
	char name[126];
	char info[128];
	char playerid[128];
	SetMenuTitle(menu, "选择踢出玩家");
	int i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			Format(playerid, sizeof(playerid), "%i", GetClientUserId(i));
			if (GetClientName(i, name, sizeof(name)))
			{
				Format(info, sizeof(info), "%s", name);
				AddMenuItem(menu, playerid, info, ITEMDRAW_DEFAULT);
			}
		}
		i++;
	}
	DisplayMenu(menu, client, 30);
}

public int Menu_Voteskick(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char name[128];
		GetMenuItem(menu, param2, name, sizeof(name));
		kickclient = GetClientOfUserId(StringToInt(name));
		if(bCheckClientAccess(kickclient))
			kickclient = param1;
		CPrintToChatAll("[{olive}vote{default}] {blue}%N {default}发起投票踢出 {blue} %N", param1, kickclient);
		if (DisplayVoteKickMenu(param1))
		{
			FakeClientCommand(param1, "Vote Yes");
		}
	}
	return 0;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
		return true;
	return false;
}

public bool DisplayVoteKickMenu(int client)
{
	if (!IsBuiltinVoteInProgress())
	{
		char sBuffer[128];
		g_hVoteKick = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BUILTINVOTE_ACTIONS_DEFAULT);
		Format(sBuffer, 128, "踢出 '%N' ?", kickclient);
		SetBuiltinVoteArgument(g_hVoteKick, sBuffer);
		SetBuiltinVoteInitiator(g_hVoteKick, client);
		SetBuiltinVoteResultCallback(g_hVoteKick, VoteResultHandler);
		DisplayBuiltinVoteToAllNonSpectators(g_hVoteKick, 10);
		CPrintToChatAll("[{olive}vote{default}] {blue}%N 发起了一个投票", client);
		return true;
	}
	CPrintToChat(client, "[{olive}vote{default}] {red}已经有一个投票正在进行.");
	return false;
}

