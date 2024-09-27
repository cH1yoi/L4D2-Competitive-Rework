#if defined _kether_spechud_included
 #endinput
#endif
#define _kether_spechud_included

//extended tankhud cvars
char Tank_UpTime[64];
int UpTime;

Handle punch_count_store = INVALID_HANDLE;
Handle rock_count_store = INVALID_HANDLE;
Handle prop_count_store = INVALID_HANDLE;
Handle damage_value_store = INVALID_HANDLE;
ArrayList whoHadTankNicknames = INVALID_HANDLE;
ArrayList whoHadTankSteamIDs = INVALID_HANDLE;
int dmgBeforeIncap[MAXPLAYERS+1];

bool g_bIsTankInPlay = false;            // Whether or not the tank is active
bool g_bAnnounceTankDamage = false;            // Whether or not tank damage should be announced

public void PrintTankDamage()
{
	CreateTimer(4.0, delayedTankStatsPrint);
}

public void OnTankDeath()
{
	PrintTankDamage();
}

public Action delayedTankStatsPrint(Handle timer)
{
	if(g_bAnnounceTankDamage){
		UpdateTankUpTime();
		//CPrintToChatAll("{orange}坦克共存活: {red}%s", Tank_UpTime);
		//for each tank player
		for(int x=0; x<whoHadTankSteamIDs.Length; x++){
			//int clientID = GetArrayCell(whoHadTankClientIDs, x);
			char steamID[64] = "UNDEFINED";
			GetArrayString(whoHadTankSteamIDs, x, steamID, sizeof(steamID) );
			//int clientID = GetPlayerBySteamID(steamID);
			char playerName[128] = "NOT_FOUND";
			GetArrayString(whoHadTankNicknames, x, playerName, sizeof(playerName) );
			// char userNickname[120] = "None";
			// GetArrayString(whoHadTankNicknames, x, userNickname, sizeof(userNickname) );
			//let's load tries
			char punch_Count_Key[120];
			char rock_Count_Key[120];
			char prop_Count_Key[120];
			char total_Damage_Value_Key[120];
			Format(punch_Count_Key, sizeof(punch_Count_Key), "%s_punch", steamID);
			Format(rock_Count_Key, sizeof(rock_Count_Key), "%s_rock", steamID);
			Format(prop_Count_Key, sizeof(prop_Count_Key), "%s_prop", steamID);
			Format(total_Damage_Value_Key, sizeof(total_Damage_Value_Key), "%s_total_dmg", steamID);

			int punchCount;
			GetTrieValue(punch_count_store, punch_Count_Key, punchCount);
			int rockCount;
			GetTrieValue(rock_count_store, rock_Count_Key, rockCount);
			int propCount;
			GetTrieValue(prop_count_store, prop_Count_Key, propCount);
			int totalDamage;
			GetTrieValue(damage_value_store, total_Damage_Value_Key, totalDamage);
			if(totalDamage > 0){
				//CPrintToChatAll("[{darkred}Tank: {red}%s{default}] {orange}伤害: {olive}%d {default}| {orange}拳: {olive}%d {default}| {orange}饼: {olive}%d {default}| {orange}铁: {olive}%d", playerName, totalDamage, punchCount, rockCount, propCount);
			}
		}
		ClearTankDamage();
	}
	return Plugin_Continue;
}

public int GetPlayerBySteamId(const char[] steamId) 
{
    char tmpSteamId[64];
   
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IsClientInGame(i))
            continue;
        
        GetClientAuthId(i, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));     
        
        if (strcmp(steamId, tmpSteamId) == 0)
            return i;
    }
    
    return -1;
}

public void TP_OnTankPass(){
	CreateTimer(1.0, delayedTankCheck);
}

public Action delayedTankCheck(Handle timer)
{
	int client = FindTankClient(0);
	char playerName[128] = "AI";

	if(client && IsClientInGame(client) && !IsFakeClient(client)){
		GetClientName(client, playerName, sizeof(playerName) );
	}

	char steamID[64] = "UNDEFINED";
	bool foundPlayer = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));   
	if(!foundPlayer){
		steamID = "AI";
	}  

	int indexInArraySteamID = FindStringInArray(whoHadTankSteamIDs, steamID);
	if(indexInArraySteamID == -1){
		PushArrayString(whoHadTankNicknames, playerName);
		PushArrayString(whoHadTankSteamIDs, steamID);
	}
}

public Action Event_TankSpawn(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	//let's firstly check if we have that tank in our array. If not, let's add it.

	char playerName[128] = "AI";
	if(client && IsClientInGame(client) && !IsFakeClient(client)){
		GetClientName(client, playerName, sizeof(playerName) );
	}

	char steamID[64] = "UNDEFINED";
	bool foundPlayer = GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));   
	if(!foundPlayer){
		steamID = "AI";
	}  

	int indexInArraySteamID = FindStringInArray(whoHadTankSteamIDs, steamID);
	if(indexInArraySteamID == -1){
		PushArrayString(whoHadTankNicknames, playerName);
		PushArrayString(whoHadTankSteamIDs, steamID);
	}

	if (g_bIsTankInPlay) return; // Tank passed
	UpTime = GetTime();
	g_bAnnounceTankDamage = true;
	// New tank, damage has not been announced
	g_bIsTankInPlay = true;
}

public Action Event_PlayerIncapacitatedBefore(Handle event, const char[] name, bool dontBroadcast){
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int entityID = GetEventInt(event, "attackerentid");
	char steamUsername[64] = "NOT_FOUND";

	dmgBeforeIncap[victim] = GetSurvivorPermanentHealth(victim) + GetSurvivorTemporaryHealth(victim);
    return Plugin_Continue;
}

public Action Event_PlayerIncapacitated(Handle event, const char[] name, bool dontBroadcast){
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int entityID = GetEventInt(event, "attackerentid");
	char steamUsername[64] = "NOT_FOUND";
    if (!attacker || !victim) {
        return Plugin_Continue;
    }

	if (victim == attacker) {
        return Plugin_Continue;
    }

	if(GetClientTeam(attacker) != L4D2Team_Infected || GetClientTeam(victim) != L4D2Team_Survivor){
		return Plugin_Continue;
	}

	if(!IsTank(attacker)){
		return Plugin_Continue;
	}

	bool foundPlayer = GetClientAuthId(attacker, AuthId_Steam2, steamUsername, sizeof(steamUsername));
	if(!foundPlayer){
		steamUsername = "AI";
	}

	//let's load tries
	char punch_Count_Key[120];
	char rock_Count_Key[120];
	char prop_Count_Key[120];
	char total_Damage_Value_Key[120];
    Format(punch_Count_Key, sizeof(punch_Count_Key), "%s_punch", steamUsername);
    Format(rock_Count_Key, sizeof(rock_Count_Key), "%s_rock", steamUsername);
    Format(prop_Count_Key, sizeof(prop_Count_Key), "%s_prop", steamUsername);
    Format(total_Damage_Value_Key, sizeof(total_Damage_Value_Key), "%s_total_dmg", steamUsername);

	int punchCount;
	bool foundPunch = GetTrieValue(punch_count_store, punch_Count_Key, punchCount);
	int rockCount;
	bool foundRock = GetTrieValue(rock_count_store, rock_Count_Key, rockCount);
	int propCount;
	bool foundProp = GetTrieValue(prop_count_store, prop_Count_Key, propCount);
	int totalDamage;
	bool foundDMG = GetTrieValue(damage_value_store, total_Damage_Value_Key, totalDamage);

	if(!foundPunch){punchCount=0;}
	if(!foundRock){rockCount=0;}
	if(!foundProp){propCount=0;}
	if(!foundDMG){totalDamage=0;}
	
	//increase values
	totalDamage += dmgBeforeIncap[victim];
	dmgBeforeIncap[victim] = 0;
    char weapon[16];
    GetEventString(event, "weapon", weapon, sizeof(weapon));
	if (StrEqual(weapon, "tank_claw")) {
		punchCount += 1;
	} else if (StrEqual(weapon, "tank_rock")) {
		rockCount += 1;
	} else {
		propCount += 1;
	}

	//update tries
	SetTrieValue(punch_count_store, punch_Count_Key, punchCount);
	SetTrieValue(rock_count_store, rock_Count_Key, rockCount);
	SetTrieValue(prop_count_store, prop_Count_Key, propCount);
	SetTrieValue(damage_value_store, total_Damage_Value_Key, totalDamage);
    return Plugin_Continue;
}

public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int dmg = GetEventInt(event, "dmg_health");
	char steamUsername[64] = "NOT_FOUND";

    if (!attacker || !victim) {
        return Plugin_Continue;
    }

	if (victim == attacker) {
        return Plugin_Continue;
    }

	if(GetClientTeam(attacker) != L4D2Team_Infected || GetClientTeam(victim) != L4D2Team_Survivor){
		return Plugin_Continue;
	}

	if(!IsTank(attacker)){
		return Plugin_Continue;
	}

	bool foundPlayer = GetClientAuthId(attacker, AuthId_Steam2, steamUsername, sizeof(steamUsername));
	if(!foundPlayer){
		steamUsername = "AI";
	}

	//let's load tries
	char punch_Count_Key[120];
	char rock_Count_Key[120];
	char prop_Count_Key[120];
	char total_Damage_Value_Key[120];
    Format(punch_Count_Key, sizeof(punch_Count_Key), "%s_punch", steamUsername);
    Format(rock_Count_Key, sizeof(rock_Count_Key), "%s_rock", steamUsername);
    Format(prop_Count_Key, sizeof(prop_Count_Key), "%s_prop", steamUsername);
    Format(total_Damage_Value_Key, sizeof(total_Damage_Value_Key), "%s_total_dmg", steamUsername);

	int punchCount;
	bool foundPunch = GetTrieValue(punch_count_store, punch_Count_Key, punchCount);
	int rockCount;
	bool foundRock = GetTrieValue(rock_count_store, rock_Count_Key, rockCount);
	int propCount;
	bool foundProp = GetTrieValue(prop_count_store, prop_Count_Key, propCount);
	int totalDamage;
	bool foundDMG = GetTrieValue(damage_value_store, total_Damage_Value_Key, totalDamage);

	if(!foundPunch){punchCount=0;}
	if(!foundRock){rockCount=0;}
	if(!foundProp){propCount=0;}
	if(!foundDMG){totalDamage=0;}
	
	//increase values
    char weapon[16];
    GetEventString(event, "weapon", weapon, sizeof(weapon));
	totalDamage += dmg;
	if (StrEqual(weapon, "tank_claw")) {
		punchCount += 1;
	} else if (StrEqual(weapon, "tank_rock")) {
		rockCount += 1;
	} else {
		propCount += 1;
	}

	//update tries
	SetTrieValue(punch_count_store, punch_Count_Key, punchCount);
	SetTrieValue(rock_count_store, rock_Count_Key, rockCount);
	SetTrieValue(prop_count_store, prop_Count_Key, propCount);
	SetTrieValue(damage_value_store, total_Damage_Value_Key, totalDamage);

    return Plugin_Continue;
}

void ClearTankDamage()
{
	ClearTrie(punch_count_store);
	ClearTrie(rock_count_store);
	ClearTrie(prop_count_store);
	ClearTrie(damage_value_store);
	ClearArray(whoHadTankNicknames);
	ClearArray(whoHadTankSteamIDs);
	for(int x=1;x<MAXPLAYERS+1; x++){
		dmgBeforeIncap[x] = 0;
	}
	g_bAnnounceTankDamage = false;
	g_bIsTankInPlay = false;
}

stock void UpdateTankUpTime() {
    char str_uptime_temp[8];
    int Current_UpTime = GetTime() - UpTime;
    int Days = RoundToFloor(Current_UpTime / 86400.0);
    Current_UpTime -= Days * 86400;
    Tank_UpTime = "";
    int Hours = RoundToFloor(Current_UpTime / 3600.0);
    Current_UpTime -= Hours * 3600;
    FormatTime(str_uptime_temp, sizeof(str_uptime_temp), "%M:%S", Current_UpTime);
    StrCat(view_as < char > (Tank_UpTime), sizeof(Tank_UpTime), str_uptime_temp);
}

stock bool IsValidClient(int client)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client)) return false; 
    return true;
}