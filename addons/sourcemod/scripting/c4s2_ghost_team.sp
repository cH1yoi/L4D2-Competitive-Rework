#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#undef REQUIRE_PLUGIN
#include <left4dhooks>
#include <c4s2_ghost>

#include "simplevote.sp"

int	   g_iObserveIndex[MAXPLAYERS + 1];
ConVar g_hMaxPlayer;
bool
	g_bPluginEnable,
	g_bRoundStart,
	g_bAllowRespawnRepetitve;
ArrayList
	g_hAllPlayers,
	g_hGhosts,
	g_hSoldiers,
	g_hRespawnPoints,
	g_hMapInfo;
enum struct MapCvar
{
	char mapname[128];
	int	 value;
}
public Plugin myinfo =
{
	name		= "C4S2 Ghost - Team Set",
	author		= "Nepkey",
	description = "幽灵模式附加插件 - 队伍设置模块。",
	version		= "1.0 - 2024.9.29",
	url			= "https://space.bilibili.com/436650372"
};

//---------------------------------------------------------------
//							基础设置
//---------------------------------------------------------------
public void OnPluginStart()
{
	g_hAllPlayers	 = new ArrayList();
	g_hRespawnPoints = new ArrayList();
	g_hGhosts		 = new ArrayList();
	g_hSoldiers		 = new ArrayList();
	g_hMapInfo		 = new ArrayList(sizeof(MapCvar));

	RegConsoleCmd("sm_start", Callvote);
	RegConsoleCmd("sm_jg", JG_CMD);
	RegServerCmd("c4s2_respawn_repetitive", Repetitive_CMD);
	AddCommandListener(OverRide_ObserveTarget, "spec_next");
	AddCommandListener(OverRide_ObserveTarget, "spec_prev");
	AddCommandListener(AFK_CMD, "go_away_from_keyboard");

	SetConVarInt(FindConVar("director_afk_timeout"), 999999);
	g_hMaxPlayer = CreateConVar("c4s2_ghost_max_players", "10");

	CreateTimer(1.0, DrawPlayersToPanel, _, TIMER_REPEAT);
	HookEvent("player_death", PlayerDeath_Event);
}

public void OnAllPluginsLoaded()
{
	g_bPluginEnable = LibraryExists("c4s2_ghost");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "c4s2_ghost")) g_bPluginEnable = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "c4s2_ghost")) g_bPluginEnable = false;
}

//---------------------------------------------------------------
//							全局转发
//---------------------------------------------------------------
public void OnMapStart()
{
	g_bRoundStart = false;
	char mapname[128];
	GetCurrentMap(mapname, sizeof(mapname));
	int index = g_hMapInfo.FindString(mapname);
	if (index > -1)
	{
		MapCvar mc;
		g_hMapInfo.GetArray(index, mc);
		g_bAllowRespawnRepetitve = view_as<bool>(mc.value);
	}
	else
	{
		g_bAllowRespawnRepetitve = false;
	}
	PrintToServer("%s", g_bAllowRespawnRepetitve ? "地图已启用生还重复复活点" : "地图禁用重复复活点");
}

public void OnClientPutInServer(int client)
{
	if (!g_bPluginEnable) return;
	ClientCommand(client, "sm_jg");
	if (g_bRoundStart)
	{
		ForcePlayerSuicide(client);
	}
}

public void C4S2Ghost_OnRoundStart_Post(bool gamestart)
{
	if (!g_bPluginEnable) return;
	GetAllRespawnPoints();
	if (gamestart)
	{
		g_bRoundStart = gamestart;
		GroupPlayersIntoTeams();
	}
}

public void OnPlayerKilled_Pre(int victim)
{
	if (!g_bPluginEnable) return;
	if (C4S2Ghost_GetClientTeam(victim) == 3)
	{
		int index = g_hGhosts.FindValue(victim);
		if (index > -1)
		{
			g_hGhosts.Erase(index);
		}
	}
	else
	{
		int index = g_hSoldiers.FindValue(victim);
		if (index > -1)
		{
			g_hSoldiers.Erase(index);
		}
	}
}

public void OnPlayerSpawn_Post(int client, bool gamestart)
{
	if (!g_bPluginEnable || !IsValidClientIndex(client) || !IsClientInGame(client))
	{
		return;
	}
	if (gamestart)
	{
		if (IsFakeClient(client))
		{
			KickClient(client);
			return;
		}
		TeleportPlayerToStartPoint_Delay(client);
	}
}

//---------------------------------------------------------------
//							回调函数
//---------------------------------------------------------------

Action OverRide_ObserveTarget(int client, const char[] command, int argc)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	if (IsPlayerAlive(client) || GetClientTeam(client) == 1 || !GetGameState())
	{
		return Plugin_Continue;
	}
	int team = C4S2Ghost_GetClientTeam(client);
	if (team == 3 && g_hGhosts.Length > 0)
	{
		if (g_iObserveIndex[client] >= g_hGhosts.Length)
		{
			g_iObserveIndex[client] = 0;
		}
		int	 target = g_hGhosts.Get(g_iObserveIndex[client]);
		char clientname[128];
		GetClientName(target, clientname, sizeof(clientname));
		FakeClientCommand(client, "spec_player \"%s\"", clientname);
		g_iObserveIndex[client]++;
	}
	else if (team == 2 && g_hSoldiers.Length > 0)
	{
		if (g_iObserveIndex[client] >= g_hSoldiers.Length)
		{
			g_iObserveIndex[client] = 0;
		}
		int	 target = g_hSoldiers.Get(g_iObserveIndex[client]);
		char clientname[128];
		GetClientName(target, clientname, sizeof(clientname));
		FakeClientCommand(client, "spec_player \"%s\"", clientname);
		g_iObserveIndex[client]++;
	}
	return Plugin_Handled;
}

Action AFK_CMD(int client, const char[] command, int argc)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	return Plugin_Handled;
}

Action JG_CMD(int client, int args)
{
	if (!g_bPluginEnable || !IsValidClientIndex(client)) return Plugin_Handled;
	if (InvalidPlayers(2) + InvalidPlayers(3) >= g_hMaxPlayer.IntValue)
	{
		CPrintToChat(client, "{green}已达到游戏允许的人数上限。");
		return Plugin_Handled;
	}
	ChangeClientTeam(client, 2);
	if (g_bRoundStart)
	{
		ForcePlayerSuicide(client);
	}
	else
	{
		L4D_RespawnPlayer(client);
	}
	return Plugin_Continue;
}

Action Repetitive_CMD(int args)
{
	if (args != 2)
	{
		PrintToServer("[SM] 用法: c4s2_respawn_repetitive <mapname> <int>");
	}
	MapCvar mc;
	GetCmdArg(1, mc.mapname, sizeof(mc.mapname));
	mc.value = GetCmdArgInt(2);
	g_hMapInfo.PushArray(mc);
}

Action Callvote(int iClient, int iArgs)
{
	if (!g_bPluginEnable) return Plugin_Handled;
	if (!GetGameState()) s_CallVote(iClient, "结束等待, 开始游戏?", GhostVote_Handler);
	return Plugin_Handled;
}

void GhostVote_Handler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if (IsVotePass(vote, num_votes, num_clients, client_info, num_items, item_info))
	{
		SetGameState(true);
		L4D2_Rematch();
	}
}

int PlayersHudHandler(Menu hMenu, MenuAction action, int param1, int param2)
{
	return 1;
}

//---------------------------------------------------------------
//							计时回调
//---------------------------------------------------------------

Action DrawPlayersToPanel(Handle timer)
{
	if (!g_bPluginEnable || GetGameState()) return Plugin_Continue;
	Panel g_hPanel = CreatePanel();
	SetPanelTitle(g_hPanel, "已加载到生还者队伍的玩家:", true);
	DrawPanelText(g_hPanel, "---------------------------------");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
		{
			char sname[128];
			GetClientName(i, sname, sizeof(sname));
			DrawPanelItem(g_hPanel, sname);
		}
	}
	DrawPanelText(g_hPanel, "---------------------------------");
	DrawPanelText(g_hPanel, "人数足够后, 请用!start投票开始游戏。");
	DrawPanelText(g_hPanel, "要对游戏进行调整, 请用!gvote打开调整面板。");
	char info[250];
	Format(info, sizeof(info), "总人数不超过%d时, 可用!jg加入游戏。", g_hMaxPlayer.IntValue);
	DrawPanelText(g_hPanel, info);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (BuiltinVote_IsVoteInProgress() && IsClientInBuiltinVotePool(i))
		{
			continue;
		}

		if (Game_IsVoteInProgress())
		{
			int voteteam = Game_GetVoteTeam();
			if (voteteam == -1 || voteteam == GetClientTeam(i))
			{
				continue;
			}
		}

		switch (GetClientMenu(i))
		{
			case MenuSource_External, MenuSource_Normal: continue;
		}
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			g_hPanel.Send(i, PlayersHudHandler, 1);
		}
	}
	delete g_hPanel;
	return Plugin_Continue;
}

Action ObserverTargetFix(Handle timer, int client)
{
	if (!IsValidClientIndex(client) || !IsClientInGame(client) || IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}
	int target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	if (IsValidClientIndex(target) && IsClientInGame(target) && GetClientTeam(client) != 1)
	{
		if (C4S2Ghost_GetClientTeam(client) != C4S2Ghost_GetClientTeam(target))
		{
			FakeClientCommand(client, "spec_next");
		}
	}
	return Plugin_Continue;
}

//---------------------------------------------------------------
//							事件回调
//---------------------------------------------------------------

void PlayerDeath_Event(Event e, const char[] n, bool b)
{
	int client = GetClientOfUserId(e.GetInt("userid"));
	if (IsValidClientIndex(client) && IsClientInGame(client))
	{
		CreateTimer(0.1, ObserverTargetFix, client, TIMER_REPEAT);
	}
}

//---------------------------------------------------------------
//							辅助方法
//---------------------------------------------------------------

void GetAllRespawnPoints()
{
	g_hRespawnPoints.Clear();
	for (int i = MAXPLAYERS + 1; i < GetEntityCount(); i++)
	{
		if (!IsValidEntity(i))
		{
			continue;
		}
		char sname[64];
		GetEntPropString(i, Prop_Data, "m_iName", sname, sizeof(sname));
		if (StrContains(sname, "SpawnPoint") > -1)
		{
			g_hRespawnPoints.Push(i);
		}
	}
}

void GroupPlayersIntoTeams()
{
	g_hAllPlayers.Clear();
	g_hGhosts.Clear();
	g_hSoldiers.Clear();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
		{
			g_hAllPlayers.Push(i);
		}
	}
	//游戏人数是奇数时，总是将多出来的一人移入幽灵队伍中。
	int ghosts = GetClientCountEx() > 1 ? RoundToFloor(GetClientCountEx() / 2 + 0.5) : 1;
	int ghostcount;
	//先抽取足够的幽灵
	while (ghostcount < ghosts && g_hAllPlayers.Length > 0)
	{
		int index  = GetRandomInt(0, g_hAllPlayers.Length - 1);
		int client = g_hAllPlayers.Get(index);
		if (IsFakeClient(client))
		{
			continue;
		}
		C4S2Ghost_SetClientTeam(client, 3);
		g_hGhosts.Push(client);
		ghostcount++;
		g_hAllPlayers.Erase(index);
	}
	//剩余的玩家成为生还
	for (int i = 0; i < g_hAllPlayers.Length; i++)
	{
		int client = g_hAllPlayers.Get(i);
		C4S2Ghost_SetClientTeam(client, 2);
		g_hSoldiers.Push(client);
	}
}

stock int GetClientCountEx()
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		count += IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 ? 1 : 0;
	}
	return count;
}

void TeleportPlayerToStartPoint_Delay(int client)
{
	if (g_hRespawnPoints.Length < 1)
	{
		CPrintToChatAll("{green}[!]检测到复活点位不足, 传送终止, 请管理员检查Stripper配置是否正确。");
		return;
	}
	int	  index = GetRandomInt(0, g_hRespawnPoints.Length - 1);
	int	  point = g_hRespawnPoints.Get(index);
	float pos[3];
	GetEntPropVector(point, Prop_Data, "m_vecAbsOrigin", pos);
	int nav = L4D_GetNearestNavArea(pos, 300.0, false, false, true);
	L4D_FindRandomSpot(nav, pos);
	TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
	if (g_bAllowRespawnRepetitve && IsClientInSoldier(client)) return;
	g_hRespawnPoints.Erase(index);
}

int InvalidPlayers(int team)
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 2)
		{
			continue;
		}
		if (C4S2Ghost_GetClientTeam(i) == team)
		{
			count++;
		}
	}
	return count;
}