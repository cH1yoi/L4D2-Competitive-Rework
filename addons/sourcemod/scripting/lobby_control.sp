#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>
#include <left4dhooks>


public Plugin myinfo = {
	name = "LobbyControl",
	author = "TouchMe",
	description = "The plugin allows you to delete the lobby and restore it",
	version = "build_0001",
	url = "https://github.com/TouchMe-Inc/l4d2_lobby_control"
};


char g_sReservation[20];


ConVar
	g_cvAutoLobbyRemove = null, /*< sm_auto_lobby_remove */
	g_cvAllowLobbyConnectOnly = null /*< sv_allow_lobby_connect_only */
; 

/**
 *
 */
public void OnPluginStart()
{
	g_cvAutoLobbyRemove = CreateConVar("sm_auto_lobby_remove", "0", "Automatically delete lobbies", _, true, 0.0, true, 1.0);

	g_cvAllowLobbyConnectOnly = FindConVar("sv_allow_lobby_connect_only");
}

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

	// Natives.
	CreateNative("IsLobbyReserved", Native_IsLobbyReserved);
	CreateNative("DeleteLobbyReservation", Native_DeleteLobbyReservation);
	CreateNative("RestoreLobbyReservation", Native_RestoreLobbyReservation);

	// Library.
	RegPluginLibrary("lobby_control");

	return APLRes_Success;
}

public void OnConfigsExecuted()
{
	if (CanRestoreLobby()
	|| (GetConVarBool(g_cvAutoLobbyRemove) && DeleteLobbyReservation() == 0)
	) {
		SetConVarInt(g_cvAllowLobbyConnectOnly, 0);
	}
}

int Native_IsLobbyReserved(Handle plugin, int numParams)
{
	if (L4D_LobbyIsReserved()) {
		return 1;
	}

	if (!CanRestoreLobby()) {
		return -1;
	}

	return 0;
}

int Native_RestoreLobbyReservation(Handle plugin, int numParams)
{
	if (L4D_LobbyIsReserved()) {
		return 0;
	}

	if (!CanRestoreLobby()) {
		return -1;
	}

	L4D_SetLobbyReservation(g_sReservation);

	SetConVarInt(g_cvAllowLobbyConnectOnly, 1);

	g_sReservation[0] = '\0';

	return 1;
}

int Native_DeleteLobbyReservation(Handle plugin, int numParams) {
	return DeleteLobbyReservation();
}

bool CanRestoreLobby() {
	return g_sReservation[0] != '\0';
}

int DeleteLobbyReservation()
{
	if (!L4D_LobbyIsReserved()) {
		return 0;
	}

	L4D_GetLobbyReservation(g_sReservation, sizeof(g_sReservation));

	L4D_LobbyUnreserve();

	SetConVarInt(g_cvAllowLobbyConnectOnly, 0);

	return 1;
}
