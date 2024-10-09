#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <c4s2_ghost>

int	 g_iPlayerScream[MAXPLAYERS + 1];
bool g_bPluginEnable;

public Plugin myinfo =
{
	name		= "C4S2 Ghost - Sounds Control",
	author		= "Unknown",
	description = "幽灵模式附加插件 - 生还者语音控制。",
	version		= "1.0 - 2024.9.29",
	url			= "https://space.bilibili.com/436650372"
};

// Vocalize for Left 4 Dead2
static const char g_Coach[][] = {
	"scenes/coach/deathscream07.vcd", "scenes/coach/deathscream08.vcd", "scenes/coach/deathscream09.vcd"
};
static const char g_Ellis[][] = {
	"scenes/mechanic/deathscream04.vcd",
	"scenes/mechanic/deathscream05.vcd",
};
static const char g_Nick[][] = {
	"scenes/gambler/deathscream03.vcd", "scenes/gambler/deathscream05.vcd"
};
static const char g_Rochelle[][] = {
	"scenes/producer/deathscream01.vcd", "scenes/producer/hurtcritical03.vcd", "scenes/producer/hurtcritical04.vcd"
};

// Vocalize for Left 4 Dead
static const char g_Bill[][] = {
	"scenes/NamVet/FallShort03.vcd", "scenes/NamVet/FallShort02.vcd", "scenes/NamVet/FallShort01.vcd"
};
static const char g_Francis[][] = {
	"scenes/Biker/FallShort03.vcd", "scenes/Biker/FallShort02.vcd", "scenes/Biker/FallShort01.vcd"
};
static const char g_Louis[][] = {
	"scenes/Manager/FallShort03.vcd", "scenes/Manager/FallShort04.vcd", "scenes/Manager/FallShort01.vcd"
};
static const char g_Zoey[][] = {
	"scenes/TeenGirl/FallShort01.vcd", "scenes/TeenGirl/FallShort02.vcd", "scenes/TeenGirl/FallShort03.vcd"
};

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

public void OnPlayerKilled_Pre(int victim, int attacker, const char[] weaponname, bool headshot, bool backstab)
{
	if (!g_bPluginEnable) return;
	if (IsClientInSoldier(victim))
	{
		BroadcastDeathSound(victim);
	}
}

public void OnEntityCreated(int ent, const char[] sname)
{
	if (!g_bPluginEnable) return;
	if (StrEqual(sname, "instanced_scripted_scene"))
	{
		RequestFrame(NextFrame_EntityCheck, ent);
	}
}

void NextFrame_EntityCheck(int entity)
{
	if (!IsValidEntity(entity))
	{
		return;
	}
	int client = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	if (client <= 0)
	{
		return;
	}
	if (entity > MAXPLAYERS || entity != g_iPlayerScream[client])
	{
		AcceptEntityInput(entity, "Kill");
	}
	else
	{
		g_iPlayerScream[client] = -1;
	}
}

// ====================================================================================================
//					VOCALIZE SCENE
// ====================================================================================================
void BroadcastDeathSound(int client)
{
	static char model[40];

	// Get survivor model
	GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));

	switch (model[29])
	{
		case 'c': VocalizeScene(client, g_Coach[GetRandomInt(0, sizeof(g_Coach) - 1)]);
		case 'b': VocalizeScene(client, g_Nick[GetRandomInt(0, sizeof(g_Nick) - 1)]);
		case 'h': VocalizeScene(client, g_Ellis[GetRandomInt(0, sizeof(g_Ellis) - 1)]);
		case 'd': VocalizeScene(client, g_Rochelle[GetRandomInt(0, sizeof(g_Rochelle) - 1)]);
		case 'v': VocalizeScene(client, g_Bill[GetRandomInt(0, sizeof(g_Bill) - 1)]);
		case 'e': VocalizeScene(client, g_Francis[GetRandomInt(0, sizeof(g_Francis) - 1)]);
		case 'a': VocalizeScene(client, g_Louis[GetRandomInt(0, sizeof(g_Louis) - 1)]);
		case 'n': VocalizeScene(client, g_Zoey[GetRandomInt(0, sizeof(g_Zoey) - 1)]);
	}
}
void VocalizeScene(int client, const char[] scenefile)
{
	g_iPlayerScream[client] = CreateEntityByName("instanced_scripted_scene");
	DispatchKeyValue(g_iPlayerScream[client], "SceneFile", scenefile);
	DispatchSpawn(g_iPlayerScream[client]);
	SetEntPropEnt(g_iPlayerScream[client], Prop_Data, "m_hOwner", client);
	ActivateEntity(g_iPlayerScream[client]);
	AcceptEntityInput(g_iPlayerScream[client], "Start", client, client);
}