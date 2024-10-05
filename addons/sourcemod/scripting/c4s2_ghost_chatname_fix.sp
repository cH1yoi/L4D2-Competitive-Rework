#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <colors>
#undef REQUIRE_PLUGIN
#include <c4s2_ghost>

bool g_bPluginEnable;

public Plugin myinfo =
{
	name		= "C4S2 Ghost - Fix Chat Name",
	author		= "Nepkey",
	description = "幽灵模式附加插件 - 修复聊天名字, 聊天分组及语音分组",
	version		= "1.0 - 2024.9.29",
	url			= "https://space.bilibili.com/436650372"
};

//---------------------------------------------------------------
//							基础设置
//---------------------------------------------------------------
public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("SayText2"), Hook_SayText2, true);
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
public void C4S2Ghost_OnRoundStart_Post(bool gamestart)
{
	if (!g_bPluginEnable) return;
	if (gamestart)
	{
		CreateTimer(3.0, SetAllClientSpeak, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	if (sArgs[0] == '!' || sArgs[0] == '/')
	{
		return Plugin_Continue;
	}
	if (StrEqual(command, "say"))
	{
		OnSayToAll(client, sArgs);
		return Plugin_Stop;
	}
	else if (StrEqual(command, "say_team"))
	{
		OnSayToTeam(client, sArgs);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

//---------------------------------------------------------------
//							回调函数
//---------------------------------------------------------------

Action Hook_SayText2(UserMsg msg_id, any msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	if (GetUserMessageType() == UM_BitBuf)
	{
		char   sMessage[64];
		BfRead bfMsg = msg;
		bfMsg.ReadEntity();
		bfMsg.ReadByte();
		bfMsg.ReadString(sMessage, 24, false);
		//拦截改名消息。
		if (StrEqual(sMessage, "Cstrike_Name_Change"))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

//---------------------------------------------------------------
//							计时回调
//---------------------------------------------------------------

Action SetAllClientSpeak(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		SetClientSpeak(i);
	}
	return Plugin_Stop;
}

//---------------------------------------------------------------
//							辅助方法
//---------------------------------------------------------------

void OnSayToAll(int client, const char[] sArgs)
{
	char sInfo[250];
	char oname[128];
	GetClientOriginalName(client, oname, sizeof(oname));
	if (GetClientTeam(client) == 1)
	{
		Format(sInfo, sizeof(sInfo), "*旁观者* {green}%s{default}：%s", oname, sArgs);
	}
	else if (IsClientInGhost(client))
	{
		Format(sInfo, sizeof(sInfo), "{blue}%s{default}：%s", oname, sArgs);
	}
	else if (IsClientInSoldier(client))
	{
		Format(sInfo, sizeof(sInfo), "{blue}%s{default}：%s", oname, sArgs);
	}
	CPrintToChatAll(sInfo);
	PrintToServer("%s: %s", oname, sArgs);
}

void OnSayToTeam(int client, const char[] sArgs)
{
	char sInfo[250];
	char oname[128];
	GetClientOriginalName(client, oname, sizeof(oname));
	if (GetClientTeam(client) == 1)
	{
		Format(sInfo, sizeof(sInfo), "(旁观者) {green}%s{default}：%s", oname, sArgs);
	}
	else if (IsClientInGhost(client))
	{
		Format(sInfo, sizeof(sInfo), "{default}({green}幽灵{default}) {green}%s{default}：%s", oname, sArgs);
	}
	else if (IsClientInSoldier(client))
	{
		Format(sInfo, sizeof(sInfo), "{default}({blue}人类{default}) {blue}%s{default}：%s", oname, sArgs);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || C4S2Ghost_GetClientTeam(i) != C4S2Ghost_GetClientTeam(client))
		{
			continue;
		}
		CPrintToChat(i, sInfo);
	}
	ReplaceColorCode(sInfo, sizeof(sInfo));
	PrintToServer(sInfo);
}

void SetClientSpeak(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || i == client)
		{
			continue;
		}
		if (C4S2Ghost_GetClientTeam(client) == C4S2Ghost_GetClientTeam(i))
		{
			SetListenOverride(client, i, Listen_Yes);
			SetListenOverride(i, client, Listen_Yes);
		}
		else
		{
			SetListenOverride(client, i, Listen_No);
			SetListenOverride(i, client, Listen_No);
		}
	}
}

void ReplaceColorCode(char[] string, int maxlength)
{
	ReplaceString(string, maxlength, "{blue}", "", true);
	ReplaceString(string, maxlength, "{green}", "", true);
	ReplaceString(string, maxlength, "{olive}", "", true);
	ReplaceString(string, maxlength, "{default}", "", true);
}