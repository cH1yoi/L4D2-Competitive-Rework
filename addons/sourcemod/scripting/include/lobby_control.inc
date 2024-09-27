#if defined  _lobby_control_included_
 #endinput
#endif
#define _lobby_control_included_

native int IsLobbyReserved();

native int DeleteLobbyReservation();

native int RestoreLobbyReservation();


public SharedPlugin __pl_lobby_control =
{
	name = "lobby_control",
	file = "lobby_control.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_lobby_control_SetNTVOptional()
{
	MarkNativeAsOptional("IsLobbyReserved");
	MarkNativeAsOptional("DeleteLobbyReservation");
	MarkNativeAsOptional("RestoreLobbyReservation");
}
#endif
