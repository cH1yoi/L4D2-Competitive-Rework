#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <c4s2_ghost>
#include <colors>

//不需要太多的宏, 已精简。
#define HUD_FLAG_ALIGN_CENTER (1 << 9)	   //	Center justify this text
#define HUD_FLAG_TEXT		  (1 << 13)	   //	?
#define HUD_FLAG_NOTVISIBLE	  (1 << 14)	   //	if you want to keep the slot data but keep it from displaying

int	  g_iRoundNum;
float g_fStealthEndTime;
bool
	g_bPluginEnable,
	g_bRoundAlive;
ConVar
	g_hTotalRound,
	g_hGhostStealth;
Handle g_hOnGameOver;

public Plugin myinfo =
{
	name		= "C4S2 Ghost - Game Rule",
	author		= "Nepkey",
	description = "幽灵模式附加插件 - 设置回合轮换及相关UI。",
	version		= "1.0 - 2024.9.29",
	url			= "https://space.bilibili.com/436650372"
};

//---------------------------------------------------------------
//							基础设置
//---------------------------------------------------------------
public void OnPluginStart()
{
	g_hTotalRound = CreateConVar("c4s2_total_roundnum", "15");
	CreateTimer(1.0, GameTimerUI, _, TIMER_REPEAT);
	//转发给mvp插件
	g_hOnGameOver = new GlobalForward("C4S2_OnGameover", ET_Ignore);
}

public void OnAllPluginsLoaded()
{
	g_hGhostStealth = FindConVar("c4s2_stealth_time");
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
//							全局设置
//---------------------------------------------------------------
public void OnMapStart()
{
	if (!g_bPluginEnable) return;
	//如果切换地图, 重置回合数。
	g_iRoundNum = 0;
	GameRules_SetProp("m_bChallengeModeActive", true, _, _, true);
}

public void C4S2Ghost_OnRoundStart_Post(bool gamestart)
{
	if (!g_bPluginEnable) return;
	if (gamestart)
	{
		g_bRoundAlive = true;
		g_iRoundNum++;
		if (g_hGhostStealth != null)
		{
			g_fStealthEndTime = GetGameTime() + g_hGhostStealth.IntValue;
		}
		else
		{
			g_fStealthEndTime = GetGameTime() + 300.0;
			PrintToServer("警告: 检测到Convar c4s2_stealth_time 无效, 已使用默认值300.0。");
		}
	}
	else
	{
		g_iRoundNum = 0;
	}
	RemoveHUD(0);
	HUDPlace(0, 0.25, 0.00, 0.5, 0.03);
}

public void C4S2Ghost_OnRoundEnd_Post(int winteam, const char[] info)
{
	if (!g_bPluginEnable) return;
	g_bRoundAlive = false;
	//输出提示信息。
	CPrintToChatAll("{green}%s", info);
	PrintHintTextToAll(info);
	//如果回合数未打到预设值，将在10秒后重启游戏，否则冻结游戏进程并输出MVP信息。
	if (g_iRoundNum < g_hTotalRound.IntValue)
	{
		CreateTimer(10.0, Rematch_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		Call_StartForward(g_hOnGameOver);
		Call_Finish();
		SetGameState(false);
		g_iRoundNum = 0;
		PrintHintTextToAll("游戏结束, 请在左下角聊天框查看排名信息。", info);
		CreateTimer(2.0, PrinMvpToAll_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

//---------------------------------------------------------------
//							计时回调
//---------------------------------------------------------------

Action PrinMvpToAll_Delay(Handle timer)
{
	//交由mvp插件输出信息。
	ServerCommand("sm_printgamemvp");
}

Action GameTimerUI(Handle timer)
{
	if (!g_bPluginEnable) return Plugin_Continue;
	char  label[256];
	float lefttime = g_fStealthEndTime - GetGameTime();
	if (!GetGameState())
	{
		Format(label, sizeof(label), "正在等待游戏开始。");
	}
	else if (!g_bRoundAlive)
	{
		Format(label, sizeof(label), "正在等待下一回合。");
	}
	else if (lefttime > 0)
	{
		Format(label, sizeof(label), "第%d回合 |幽灵隐身剩余:%d秒 | 幽灵:%d 人 | 生还:%d人", g_iRoundNum, RoundFloat(lefttime), AlivePlayers(3), AlivePlayers(2));
	}
	else
	{
		Format(label, sizeof(label), "第%d回合 |幽灵已失去隐身能力 | 幽灵:%d 人 | 生还:%d人", g_iRoundNum, AlivePlayers(3), AlivePlayers(2));
		PrintHintTextToAll("时间已耗尽, 幽灵失去隐身能力。");
	}
	HUDSetLayout(0, HUD_FLAG_TEXT | HUD_FLAG_ALIGN_CENTER, label);
	return Plugin_Continue;
}

//---------------------------------------------------------------
//							辅助方法
//---------------------------------------------------------------

// 设置UI输出
void HUDSetLayout(int slot, int flags, const char[] dataval, any...)
{
	static char str[128];
	VFormat(str, sizeof str, dataval, 4);
	GameRules_SetProp("m_iScriptedHUDFlags", flags, _, slot, true);
	GameRules_SetPropString("m_szScriptedHUDStringSet", str, true, slot);
}

/**
 * Note:HUDPlace(slot,x,y,w,h): moves the given HUD slot to the XY position specified, with new W and H.
 * This is for doing occasional highlight/make a point type things,
 * or small changes to layout w/o having to build a new .res to put in a VPK.
 * We suspect if you want to do a super fancy HUD you will want to create your own hudscriptedmode.res file,
 * just making sure to use the same element naming conventions so you can still talk to them from script.
 * x,y,w,h are all 0.0-1.0 screen relative coordinates (actually, a bit smaller than the screen, but anyway).
 * So a box near middle might be set as (0.4,0.45,0.2,0.1) or so.
 */
/**
 * Place a slot in game.
 *
 * @param slot			HUD slot.
 * @param x				screen x position.
 * @param y				screen y position.
 * @param width			screen slot width.
 * @param height		screen slot height.
 * @noreturn
 * @error				Invalid HUD slot.
 */
void HUDPlace(int slot, float x, float y, float width, float height)
{
	GameRules_SetPropFloat("m_fScriptedHUDPosX", x, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", y, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", width, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", height, slot, true);
}

/**
 * Removes a slot from game.
 *
 * @param slot			HUD slot.
 * @noreturn
 * @error				Invalid HUD slot.
 */
void RemoveHUD(int slot)
{
	GameRules_SetProp("m_iScriptedHUDInts", 0, _, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDFloats", 0.0, slot, true);
	GameRules_SetProp("m_iScriptedHUDFlags", HUD_FLAG_NOTVISIBLE, _, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosX", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", 0.0, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", 0.0, slot, true);
	GameRules_SetPropString("m_szScriptedHUDStringSet", "", true, slot);
}

int AlivePlayers(int team)
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i))
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

Action Rematch_Delay(Handle timer)
{
	L4D2_Rematch();
}