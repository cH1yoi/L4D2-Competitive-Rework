#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>


public Plugin myinfo = {
	name = "AuthoHibernate",
	author = "TouchMe",
	description = "N/a",
	version = "build_0000",
	url = "https://github.com/TouchMe-Inc/l4d2_lobby_control"
};


ConVar g_cvAllBotGame = null;

float g_fLastDisconnectTime  = -1.0;

/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvAllBotGame = FindConVar("sb_all_bot_game");

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnClientConnected(int iClient)
{
	if (IsFakeClient(iClient)) {
		return;
	}

	if (!GetConVarBool(g_cvAllBotGame)) {
		SetConVarBool(g_cvAllBotGame, true, .notify = false);
	}
}

void Event_PlayerDisconnect(Event event, const char[] sName, bool bDontBroadcast)
{
	if (!GetConVarBool(g_cvAllBotGame)) {
		return;
	}

	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!iClient || !IsClientConnected(iClient) || IsFakeClient(iClient)) {
		return;
	}

	float fDisconnectTime = GetGameTime();
	if (g_fLastDisconnectTime == fDisconnectTime) {
		return;
	}

	g_fLastDisconnectTime = fDisconnectTime;

	CreateTimer(15.0, Timer_HibernateServer, fDisconnectTime, .flags = TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_HibernateServer(Handle hTimer, float fDisconnectTime)
{
	if (fDisconnectTime != -1.0 && fDisconnectTime != g_fLastDisconnectTime) {
		return Plugin_Stop;
	}

	if (!IsEmptyServer()) {
		return Plugin_Stop;
	}

	SetConVarBool(g_cvAllBotGame, false, .notify = false);

	return Plugin_Stop;
}

bool IsEmptyServer()
{
	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (IsClientConnected(iClient) && !IsFakeClient(iClient)) {
			return false;
		}
	}

	return true;
}
