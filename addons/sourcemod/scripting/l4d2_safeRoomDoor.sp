#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#define PLUGIN_VERSION "1.0"

/*----------------------------------------

Name: l4d2_safeRoomDoor.sp
Author: Pasu
Date: 17-Dec-2012
Version: 1.0
Description: To show player who open / close safe room door.

----------------------------------------*/

new Handle:pluginEnableHandle = INVALID_HANDLE;
new bool:pluginEnable;

public Plugin:myinfo = {
	name = "[L4D2] Open / Close Safe Room Door Displayer",
	author = "Pasu",
	description = "Show message for open / close safe room door.",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	pluginEnableHandle = CreateConVar("l4d2_safeRoomDoor_pluginEnable", "1", "Enable plugin?");
	HookConVarChange(pluginEnableHandle, loadConvar);
	
	HookEvent("door_open", Event_DoorOpen, EventHookMode_Pre);
	HookEvent("door_close", Event_DoorClose, EventHookMode_Pre);
	//AutoExecConfig(true, "l4d2_safeRoomDoor");
	loadConvar(INVALID_HANDLE, "", "");
}

public loadConvar(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	pluginEnable = GetConVarInt(pluginEnableHandle) > 0;
}

public Action:Event_DoorOpen(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (pluginEnable)
	{
		if (GetEventBool(event, "checkpoint"))
		{
			new user;
			user = GetClientOfUserId(GetEventInt(event, "userid"));
			PrintToChatAll("\x05%N \x01打开了安全门.", user);
	
		}
	}
	return Plugin_Continue;
}

public Action:Event_DoorClose(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (pluginEnable)
	{
		if (GetEventBool(event, "checkpoint"))
		{
			new user;
			user = GetClientOfUserId(GetEventInt(event, "userid"));
			PrintToChatAll("\x05%N \x01关上了安全门.", user);
		}
	}
	return Plugin_Continue;
}