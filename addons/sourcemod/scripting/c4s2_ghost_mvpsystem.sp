#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#undef REQUIRE_PLUGIN
#include <left4dhooks>
#include <c4s2_ghost>

float g_fDamageCountInRound[MAXPLAYERS + 1];
bool  g_bPluginEnable;
int
	g_iKillCount[MAXPLAYERS + 1],
	g_iKillCountInRound[MAXPLAYERS + 1];
ArrayList
	g_hGhosts,
	g_hSoilders;

public Plugin myinfo =
{
	name		= "C4S2 Ghost - MVP System",
	author		= "Nepkey",
	description = "幽灵模式附加插件 - MVP播报",
	version		= "1.1 - 2024.10.8",
	url			= "https://space.bilibili.com/436650372"
};

//注：这个插件还可以优化。
//---------------------------------------------------------------
//							基础设置
//---------------------------------------------------------------
public void OnPluginStart()
{
	g_hGhosts	= new ArrayList();
	g_hSoilders = new ArrayList();
	RegServerCmd("sm_printgamemvp", PrintGameMvp);
	RegConsoleCmd("sm_mvp", PrintMVPToClient);
	HookEvent("player_disconnect", Disconnect_Event, EventHookMode_Pre);
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
	C4S2_OnGameover();
}

public void OnPlayerSpawn_Post(int client, bool gamestart)
{
	if (!g_bPluginEnable || !IsValidClientIndex(client) || !IsClientInGame(client))
	{
		return;
	}
	if (gamestart)
	{
		g_iKillCountInRound[client]	  = 0;
		g_fDamageCountInRound[client] = 0.0;
		if (IsClientInGhost(client) && g_hGhosts.FindValue(client) == -1)
		{
			g_hGhosts.Push(client);
		}
		if (IsClientInSoldier(client) && g_hSoilders.FindValue(client) == -1)
		{
			g_hSoilders.Push(client);
		}
	}
}

public void OnPlayerHurt_Post(int victim, int attacker, float dmg)
{
	if (!g_bPluginEnable) return;
	if ((IsClientInSoilderEx(attacker) && IsClientInGhostEx(victim)) || (IsClientInSoilderEx(victim) && IsClientInGhostEx(attacker)))
	{
		g_fDamageCountInRound[attacker] += dmg;
	}
	if ((IsClientInSoilderEx(attacker) && IsClientInSoilderEx(victim)))
	{
		CPrintToChat(attacker, "{green}你对{blue}队友 %N {green}造成了 {blue}%d {green}点伤害。", victim, RoundFloat(dmg));
		CPrintToChat(victim, "{blue}队友 %N 对你造成了 {blue}%d {green}点伤害。", attacker, RoundFloat(dmg));
	}
}

public void OnPlayerKilled_Post(int victim, int attacker, const char[] weaponname, bool headshot, bool backstab)
{
	if (!g_bPluginEnable) return;
	if ((IsClientInSoilderEx(attacker) && IsClientInGhostEx(victim)) || (IsClientInSoilderEx(victim) && IsClientInGhostEx(attacker)))
	{
		g_iKillCountInRound[attacker] += 1;
		g_iKillCount[attacker] += 1;
		char attackername[128];
		char victimname[128];
		char info[512];
		Format(info, sizeof(info), "[attackercolor] [attacker] {green}[way]击杀了 [victimcolor] [victim] {green}, 获得 {blue}[point] {green}分。");
		GetClientOriginalName(attacker, attackername, sizeof(attackername));
		GetClientOriginalName(victim, victimname, sizeof(victimname));
		if (IsClientInGhostEx(attacker))
		{
			ReplaceString(info, sizeof(info), "[attackercolor]", "{olive}幽灵");
			ReplaceString(info, sizeof(info), "[attacker]", attackername);
			if (headshot)
			{
				ReplaceString(info, sizeof(info), "[way]", "以斩首");
			}
			else if (backstab)
			{
				ReplaceString(info, sizeof(info), "[way]", "以背刺");
			}
			else
			{
				ReplaceString(info, sizeof(info), "[way]", "");
			}
			ReplaceString(info, sizeof(info), "[victimcolor]", "{blue}人类");
			ReplaceString(info, sizeof(info), "[victim]", victimname);
			ReplaceString(info, sizeof(info), "[point]", "1");
			CPrintToChatAll(info);
		}
		if (IsClientInSoilderEx(attacker))
		{
			ReplaceString(info, sizeof(info), "[attackercolor]", "{blue}人类");
			ReplaceString(info, sizeof(info), "[attacker]", attackername);
			if (headshot)
			{
				ReplaceString(info, sizeof(info), "[way]", "以致命一击");
			}
			else
			{
				ReplaceString(info, sizeof(info), "[way]", "开枪");
			}
			ReplaceString(info, sizeof(info), "[victimcolor]", "{olive}幽灵");
			ReplaceString(info, sizeof(info), "[victim]", victimname);
			ReplaceString(info, sizeof(info), "[point]", "1");
			CPrintToChatAll(info);
		}
	}
	if ((IsClientInSoilderEx(attacker) && IsClientInSoilderEx(victim)))
	{
		if (attacker == victim || attacker > MaxClients)
		{
			char sname[32];
			GetClientOriginalName(victim, sname, sizeof(sname));
			CPrintToChatAll("{blue}%s {green}意外身亡。", sname);
		}
		else
		{
			CPrintToChatAll("{blue}%N {green}误杀{blue} 队友 %N {green}。", attacker, victim);
		}
	}
}

public void C4S2Ghost_OnRoundStart_Post(bool gamestart)
{
	if (gamestart)
	{
		g_hGhosts.Clear();
		g_hSoilders.Clear();
	}
}

public void C4S2Ghost_OnRoundEnd_Post()
{
	CreateTimer(0.5, PrintRoundData_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

//此回调来自gamerule
public void C4S2_OnGameover()
{
}

//---------------------------------------------------------------
//							事件回调
//---------------------------------------------------------------

void Disconnect_Event(Event e, const char[] n, bool b)
{
	int client = GetClientOfUserId(e.GetInt("userid"));
	if (IsValidClientIndex(client) && !IsFakeClient(client))
	{
		g_iKillCountInRound[client]	  = 0;
		g_iKillCount[client]		  = 0;
		g_fDamageCountInRound[client] = 0.0;
	}
}

//---------------------------------------------------------------
//						回调函数+计时回调
//---------------------------------------------------------------

Action PrintRoundData_Delay(Handle timer)
{
	PrintRoundData(-1, true);
}

Action PrintGameMvp(int args)
{
	PrintGameMVPAll();
}
Action PrintMVPToClient(int client, int args)
{
	PrintRoundData(client, false);
}

Action WipeData_Delay(Handle timer)
{
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		g_iKillCount[i]			 = 0;
		g_iKillCountInRound[i]	 = 0;
		g_fDamageCountInRound[i] = 0.0;
	}
}

//---------------------------------------------------------------
//							辅助方法
//---------------------------------------------------------------

void PrintRoundData(int caller, bool all)
{
	if (all)
	{
		CPrintToChatAll("{green}本回合{olive}幽灵{green}的数据:");
	}
	else
	{
		CPrintToChat(caller, "{green}本回合{olive}幽灵{green}的数据:");
	}
	if (g_hGhosts.Length < 1)
	{
		CPrintToChat(caller, "{green}(服务器内没有{olive}幽灵{green})");
	}
	for (int i = 0; i < g_hGhosts.Length; i++)
	{
		int client = g_hGhosts.Get(i);
		if (!IsValidClientIndex(client) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		{
			continue;
		}
		char info[250];
		char oname[128];
		GetClientOriginalName(client, oname, sizeof(oname));
		Format(info, sizeof(info), "{olive}%s幽灵 %s {default}- {green}总分数: {olive}%d {default}- {green}本回合分数: {olive}%d {default}- {green}有效伤害: {olive}%d", IsPlayerAlive(client) ? "[存活]" : "[死亡]", oname, g_iKillCount[client], g_iKillCountInRound[client], RoundFloat(g_fDamageCountInRound[client]));

		if (all)
		{
			CPrintToChatAll(info);
		}
		else
		{
			CPrintToChat(caller, info);
		}
	}
	if (all)
	{
		CPrintToChatAll("{green}本回合{blue}人类{green}的数据:");
	}
	else
	{
		CPrintToChat(caller, "{green}本回合{blue}人类{green}的数据:");
	}
	if (g_hGhosts.Length < 1)
	{
		CPrintToChat(caller, "{green}(服务器内没有{blue}人类{green})");
	}
	for (int i = 0; i < g_hSoilders.Length; i++)
	{
		int client = g_hSoilders.Get(i);
		if (!IsValidClientIndex(client) || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		{
			continue;
		}
		char info[250];
		char oname[128];
		GetClientOriginalName(client, oname, sizeof(oname));
		Format(info, sizeof(info), "{blue}%s人类 %s {default}- {green}总分数: {blue}%d {default}- {green}本回合分数: {blue}%d {default}- {green}有效伤害: {blue}%d", IsPlayerAlive(client) ? "[存活]" : "[死亡]", oname, g_iKillCount[client], g_iKillCountInRound[client], RoundFloat(g_fDamageCountInRound[client]));
		if (all)
		{
			CPrintToChatAll(info);
		}
		else
		{
			CPrintToChat(caller, info);
		}
	}
}

void PrintGameMVPAll()
{
	int survivor_index = -1;
	int survivor_clients[MAXPLAYERS + 1];
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || GetClientTeam(client) != 2) continue;
		survivor_index++;
		survivor_clients[survivor_index] = client;
	}
	SortCustom1D(survivor_clients, sizeof(survivor_clients), SortByScore);
	for (int i = 0; i < sizeof(survivor_clients); i++)
	{
		int client = survivor_clients[i];
		if (IsValidClientIndex(client) && IsClientInGame(client) && IsClientInGame(client))
		{
			char oname[128];
			GetClientOriginalName(client, oname, sizeof(oname));
			CPrintToChatAll("{green}#%d {blue}%s {green}总分数：{blue}%d", i + 1, oname, g_iKillCount[client]);
		}
	}
	CreateTimer(2.0, WipeData_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

int SortByScore(int elem1, int elem2, const array[], Handle hndl)
{
	if (g_iKillCount[elem1] > g_iKillCount[elem2]) return -1;
	else if (g_iKillCount[elem2] > g_iKillCount[elem1]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
}

bool IsClientInGhostEx(int client)
{
	return g_hGhosts.FindValue(client) > -1;
}

bool IsClientInSoilderEx(int client)
{
	return g_hSoilders.FindValue(client) > -1;
}