#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <colors>
#include <builtinvotes>
#include "simplevote.sp"
#undef REQUIRE_PLUGIN
#include <c4s2_ghost>

char g_sBuffer[2][128];
bool g_bPluginEnable;
ConVar
	g_hGhostAttackSpeed,
	g_hGhostBuff,
	g_hGhostRun,
	g_hRandommelee;

public Plugin myinfo =
{
	name		= "C4S2 Ghost - Votes",
	author		= "Nepkey",
	description = "幽灵模式附加插件 - 投票系统。",
	version		= "1.0 - 2024.9.29",
	url			= "https://space.bilibili.com/436650372"
};

public void OnAllPluginsLoaded()
{
	g_bPluginEnable		= LibraryExists("c4s2_ghost");
	g_hGhostAttackSpeed = FindConVar("c4s2_ghost_attackspeed");
	g_hGhostBuff		= FindConVar("c4s2_ghost_vampirism");
	g_hGhostRun			= FindConVar("c4s2_ghost_run_stealth");
	g_hRandommelee		= FindConVar("c4s2_ghost_random_melee");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "c4s2_ghost")) g_bPluginEnable = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "c4s2_ghost")) g_bPluginEnable = false;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_gvote", GVote_CMD);
}

Action GVote_CMD(int client, int args)
{
	GhostVoteMenu(client);
}

void GhostVoteMenu(int client)
{
	if (!g_bPluginEnable) return;
	Menu menu = new Menu(GhostVoteMenuHandler);
	menu.SetTitle("幽灵模式投票面板");
	menu.AddItem("0", "更改游戏总局数");
	menu.AddItem("1", "修改回合隐身时间");
	char iteam[64];
	Format(iteam, sizeof(iteam), "%s", g_hGhostAttackSpeed.FloatValue == 1.6 ? "禁用幽灵高攻速" : "启用幽灵高攻速");
	menu.AddItem("2", iteam);
	Format(iteam, sizeof(iteam), "%s", g_hGhostBuff.BoolValue ? "禁用幽灵杀敌回血" : "启用幽灵杀敌回血");
	menu.AddItem("3", iteam);
	Format(iteam, sizeof(iteam), "%s", g_hGhostRun.BoolValue ? "禁用幽灵全速隐身" : "启用幽灵全速隐身");
	menu.AddItem("4", iteam);
	Format(iteam, sizeof(iteam), "%s", g_hRandommelee.BoolValue ? "禁用幽灵随机近战" : "启用幽灵随机近战");
	menu.AddItem("5", iteam);
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return;
}

public int GhostVoteMenuHandler(Menu menu, MenuAction action, int iClient, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0:
					ChangeTotalRoundNum(iClient);
				case 1:
					ChangeGhostStealthTime(iClient);
				case 2:
					ChangeGhostAttackSpeed(iClient);
				case 3:
					ChangeGhostVampirism(iClient);
				case 4:
					ChangeGhostRun(iClient);
				case 5:
					ChangeGhostRandomMelee(iClient);
			}
		}
	}
}

void ChangeTotalRoundNum(int client)
{
	Menu menu = new Menu(RoundNumMenuHandler);
	menu.SetTitle("希望将游戏修改至最多多少局?");
	menu.AddItem("9", "9");
	menu.AddItem("11", "11");
	menu.AddItem("13", "13");
	menu.AddItem("15", "15");
	menu.AddItem("17", "17");
	menu.AddItem("19", "19");
	menu.AddItem("21", "21");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return;
}

int RoundNumMenuHandler(Menu menu, MenuAction action, int iClient, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				GhostVoteMenu(iClient);
		}
		case MenuAction_Select:
		{
			char info[16];
			if (menu.GetItem(param2, info, sizeof(info)))
			{
				char oname[128];
				GetClientOriginalName(iClient, oname, sizeof(oname));
				Format(g_sBuffer[0], 128, "c4s2_total_roundnum %s", info);
				Format(g_sBuffer[1], 128, "已将游戏总局数修改至 %s 局", info);
				char title[128];
				Format(title, sizeof(title), "%s: 将游戏总局数修改为 %s 局?", oname, info);
				s_CallVote(iClient, title, VoteResult);
			}
		}
	}
}

// -------------------------------------

void ChangeGhostStealthTime(int client)
{
	Menu menu = new Menu(GhostStealthTimeMenuHandler);
	menu.SetTitle("希望将回合隐身时间设置多少秒?");
	menu.AddItem("200", "200");
	menu.AddItem("225", "225");
	menu.AddItem("250", "250");
	menu.AddItem("275", "275");
	menu.AddItem("300", "300");
	menu.AddItem("325", "325");
	menu.AddItem("350", "350");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return;
}

int GhostStealthTimeMenuHandler(Menu menu, MenuAction action, int iClient, int param2)
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				GhostVoteMenu(iClient);
		}
		case MenuAction_Select:
		{
			char info[16];
			if (menu.GetItem(param2, info, sizeof(info)))
			{
				char oname[128];
				GetClientOriginalName(iClient, oname, sizeof(oname));
				Format(g_sBuffer[0], 128, "c4s2_stealth_time %s", info);
				Format(g_sBuffer[1], 128, "已将回合隐身时间修改至 %s 秒", info);
				char title[128];
				Format(title, sizeof(title), "%s: 将回合隐身时间修改为 %s 秒?", oname, info);
				s_CallVote(iClient, title, VoteResult);
			}
		}
	}
}

// -------------------------

void ChangeGhostAttackSpeed(int client)
{
	char oname[128];
	GetClientOriginalName(client, oname, sizeof(oname));
	if (g_hGhostAttackSpeed.FloatValue == 1.6)
	{
		Format(g_sBuffer[0], 128, "c4s2_ghost_attackspeed 1.0");
		Format(g_sBuffer[1], 128, "已禁用幽灵高攻速。");
		char title[128];
		Format(title, sizeof(title), "%s: 禁用幽灵高攻速?", oname);
		s_CallVote(client, title, VoteResult);
	}
	else
	{
		Format(g_sBuffer[0], 128, "c4s2_ghost_attackspeed 1.6");
		Format(g_sBuffer[1], 128, "已启用幽灵高攻速。");
		char title[128];
		Format(title, sizeof(title), "%s: 启用幽灵高攻速?", oname);
		s_CallVote(client, title, VoteResult);
	}
}

// --------------------------

void ChangeGhostVampirism(int client)
{
	char oname[128];
	GetClientOriginalName(client, oname, sizeof(oname));
	if (g_hGhostBuff.BoolValue)
	{
		Format(g_sBuffer[0], 128, "c4s2_ghost_vampirism 0");
		Format(g_sBuffer[1], 128, "已禁用幽灵杀敌回血。");

		char title[128];
		Format(title, sizeof(title), "%s:  禁用幽灵杀敌回血?", oname);
		s_CallVote(client, title, VoteResult);
	}
	else
	{
		Format(g_sBuffer[0], 128, "c4s2_ghost_vampirism 1");
		Format(g_sBuffer[1], 128, "已启用幽灵杀敌回血。");
		char title[128];
		Format(title, sizeof(title), "%s: 启用幽灵杀敌回血?", oname);
		s_CallVote(client, title, VoteResult);
	}
}

// --------------------------

void ChangeGhostRun(int client)
{
	char oname[128];
	GetClientOriginalName(client, oname, sizeof(oname));
	if (g_hGhostRun.BoolValue)
	{
		Format(g_sBuffer[0], 128, "c4s2_ghost_run_stealth 0");
		Format(g_sBuffer[1], 128, "已禁用幽灵全速隐身。");
		char title[128];
		Format(title, sizeof(title), "%s: 禁用幽灵全速隐身?", oname);
		s_CallVote(client, title, VoteResult);
	}
	else
	{
		Format(g_sBuffer[0], 128, "c4s2_ghost_run_stealth 1");
		Format(g_sBuffer[1], 128, "已启用幽灵全速隐身。");
		char title[128];
		Format(title, sizeof(title), "%s: 启用幽灵全速隐身?", oname);
		s_CallVote(client, title, VoteResult);
	}
}

// --------------------------

void ChangeGhostRandomMelee(int client)
{
	char oname[128];
	GetClientOriginalName(client, oname, sizeof(oname));
	if (g_hRandommelee.BoolValue)
	{
		Format(g_sBuffer[0], 128, "c4s2_ghost_random_melee 0");
		Format(g_sBuffer[1], 128, "已禁用幽灵随机近战。");
		char title[128];
		Format(title, sizeof(title), "%s: 禁用幽灵随机近战?", oname);
		s_CallVote(client, title, VoteResult);
	}
	else
	{
		Format(g_sBuffer[0], 128, "c4s2_ghost_random_melee 1");
		Format(g_sBuffer[1], 128, "已启用幽灵随机近战。");
		char title[128];
		Format(title, sizeof(title), "%s: 启用幽灵随机近战?", oname);
		s_CallVote(client, title, VoteResult);
	}
}
// ----------这里是结果函数

void VoteResult(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if (IsVotePass(vote, num_votes, num_clients, client_info, num_items, item_info))
	{
		ServerCommand("%s", g_sBuffer[0]);
		CPrintToChatAll("{green}%s", g_sBuffer[1]);
	}
}
