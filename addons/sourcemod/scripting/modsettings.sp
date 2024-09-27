#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define PLUGIN_VERSION "1.0.4"

public Plugin myinfo =
{
	name = "L4D2 On/Off Mod Settings",
	author = "HoongDou",
	description = " Mod settings for convenience.",
	version = PLUGIN_VERSION,
	url = ""
};

//Plugin Cvars
ConVar l4d_on_mod;
//Game Cvars
ConVar l4d2_addons_eclipse, sv_consistency, sv_pure, sv_pure_kick_clients;
bool bL4d_on_mod;

public void OnPluginStart()
{
	l4d_on_mod				= CreateConVar("l4d_on_mod", "0", "0-Disabled Mod, 1-Enable Mod", FCVAR_NOTIFY, true, 0.0, true, 1.0 );
	
	bL4d_on_mod				= GetConVarBool(l4d_on_mod);
	
	HookConVarChange(l4d_on_mod, l4d_on_mod_ValueChanged);
	
	l4d2_addons_eclipse 	= FindConVar("l4d2_addons_eclipse");
	sv_consistency 			= FindConVar("sv_consistency");
	sv_pure					= FindConVar("sv_pure");
	sv_pure_kick_clients 	= FindConVar("sv_pure_kick_clients");
}	
	
public int l4d_on_mod_ValueChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	bL4d_on_mod = GetConVarBool(l4d_on_mod);
	if ((bL4d_on_mod))
	{
		l4d2_addons_eclipse.SetBool(true);
		sv_consistency.SetBool(false);
		sv_pure.SetBool(false);
		sv_pure_kick_clients.SetBool(false);
	}
	else
	{
		l4d2_addons_eclipse.SetBool(false);
		sv_consistency.SetBool(true);
		sv_pure.SetBool(true);
		sv_pure_kick_clients.SetBool(true);
	}
}

