#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <colors>
#include <left4dhooks>


public Plugin myinfo = {
    name        = "TankAnnounce",
    author      = "Visor, Forgetest, xoxo, Griffin and Blade, Sir, TouchMe",
    description = "Announce damage dealt to tanks by survivors",
    version     = "build_0002",
    url         = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
}


#define SHORT_NAME_LENGTH      18

/*
 *
 */
#define WORLD_INDEX            0

/*
 * Infected Class.
 */
#define SI_CLASS_TANK           8

/*
 * Team.
 */
#define TEAM_NONE               0
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define TRANSLATIONS            "tank_announce.phrases"


#define BOT_NAME                "AI"

/**
 * Entity-Relationship: UserVector(Userid, ...)
 */
methodmap UserVector < ArrayList {
    public UserVector(int iBlockSize = 1) {
        return view_as<UserVector>(new ArrayList(iBlockSize + 1, 0)); // extended by 1 cell for userid field
    }

    public any Get(int iIdx, int iType) {
        return GetArrayCell(this, iIdx, iType + 1);
    }

    public void Set(int iIdx, any val, int iType) {
        SetArrayCell(this, iIdx, val, iType + 1);
    }

    public int User(int iIdx) {
        return GetArrayCell(this, iIdx, 0);
    }

    public int Push(any val) {
        int iBlockSize = this.BlockSize;

        any[] array = new any[iBlockSize];
        array[0] = val;
        for (int i = 1; i < iBlockSize; i++) {
            array[i] = 0;
        }

        return this.PushArray(array);
    }

    public bool UserIndex(int iUserId, int &iIdx, bool bCreate = false) {
        if (this == null)
            return false;

        iIdx = this.FindValue(iUserId, 0);
        if (iIdx == -1) {
            if (!bCreate)
                return false;

            iIdx = this.Push(iUserId);
        }

        return true;
    }

    public bool UserReplace(int iUserId, int replacer) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, false))
            return false;

        SetArrayCell(this, iIdx, replacer, 0);
        return true;
    }

    public bool UserGet(int iUserId, int iType, any &val) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, false))
            return false;

        val = this.Get(iIdx, iType);
        return true;
    }

    public bool UserSet(int iUserId, int iType, any val, bool bCreate = false) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, bCreate))
            return false;

        this.Set(iIdx, val, iType);
        return true;
    }

    public bool UserAdd(int iUserId, int iType, any amount, bool bCreate = false) {
        int iIdx;
        if (!this.UserIndex(iUserId, iIdx, bCreate))
            return false;

        int val = this.Get(iIdx, iType);
        this.Set(iIdx, val + amount, iType);
        return true;
    }
}

enum {
    eDmgDone,           // Damage to Tank
    eTeamIdx,           // Team color
    ePunch,             // Punch hits
    eRock,              // Rock hits
    eHittable,          // Hittable hits
    eDamageReceived,    // Damage from Tank
    eDamagerInfoSize
};

enum {
    eTankIndex,             // Serial number of Tanks spawned on this map
    eIncap,                 // Total Survivor incaps
    eDeath,                 // Total Survivor death
    eTotalDamage,           // Total damage done to Survivors
    eAliveSince,            // Initial spawn time
    eTankLastHealth,        // Last HP after hit
    eLastControlUserId,     // Last human control
    eTankMaxHealth,         // Max HP
    eDamagerInfoVector,     // UserVector storing info described above
    eTankInfoSize
};

int  g_iTankIdx = 0;                        // Used to index every Tank
int  g_iPlayerLastHealth[MAXPLAYERS + 1];   // Used for Tank damage record
bool g_bIsTankInPlay = false;               // Whether or not the tank is active
bool g_bRoundEnd = false;

UserVector g_aTankInfo;      // Every Tank has a slot here along with relationships.
StringMap  g_smUserNames;    // Simple map from userid to player names.


public APLRes AskPluginLoad2(Handle hPlugin, bool bLate, char[] szError, int iErrMax)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(szError, iErrMax, "Plugin only supports Left 4 Dead 2.");
        return APLRes_SilentFailure;
    }

    CreateNative("TA_Punches",   Native_Punches);
    CreateNative("TA_Rocks",     Native_Rocks);
    CreateNative("TA_Hittables", Native_Hittables);
    CreateNative("TA_TotalDmg",  Native_TotalDamage);
    CreateNative("TA_UpTime",    Native_UpTime);

    RegPluginLibrary("tank_announce");
    return APLRes_Success;
}

any Native_Punches(Handle hPlugin, int iNumParams)
{
    int iClient = GetNativeCell(1);
    if (!IsValidClient(iClient)) {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    }

    int iUserId = GetClientUserId(iClient);
    UserVector uDamagerVector;
    if (!g_aTankInfo.UserGet(iUserId, eDamagerInfoVector, uDamagerVector))
        return 0;

    int iSum = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++) {
        iSum += uDamagerVector.Get(i, ePunch);
    }

    return iSum;
}

any Native_Rocks(Handle hPlugin, int iNumParams)
{
    int iClient = GetNativeCell(1);
    if (!IsValidClient(iClient)) {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    }

    int iUserId = GetClientUserId(iClient);
    UserVector uDamagerVector;
    if (!g_aTankInfo.UserGet(iUserId, eDamagerInfoVector, uDamagerVector))
        return 0;

    int iSum = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++) {
        iSum += uDamagerVector.Get(i, eRock);
    }

    return iSum;
}

any Native_Hittables(Handle hPlugin, int iNumParams)
{
    int iClient = GetNativeCell(1);
    if (!IsValidClient(iClient)) {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    }

    int iUserId = GetClientUserId(iClient);
    UserVector uDamagerVector;
    if (!g_aTankInfo.UserGet(iUserId, eDamagerInfoVector, uDamagerVector)) {
        return 0;
    }

    int iSum = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++) {
        iSum += uDamagerVector.Get(i, eHittable);
    }

    return iSum;
}

any Native_TotalDamage(Handle hPlugin, int iNumParams)
{
    int iClient = GetNativeCell(1);
    if (!IsValidClient(iClient)) {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    }

    int iUserId = GetClientUserId(iClient);
    int iValue  = 0;
    g_aTankInfo.UserGet(iUserId, eTotalDamage, iValue);
    return iValue;
}

any Native_UpTime(Handle plugin, int numParams) {
    int iClient = GetNativeCell(1);
    if (!IsValidClient(iClient)) {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
    }

    int   iUserId = GetClientUserId(iClient);
    float fValue  = -1.0;
    if (g_aTankInfo.UserGet(iUserId, eAliveSince, fValue)) {
        fValue = GetGameTime() - fValue;
    }

    return RoundToFloor(fValue);
}

public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);

    HookEvent("round_start",          Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end",            Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("player_bot_replace",   Event_PlayerBotReplace);
    HookEvent("bot_player_replace",   Event_BotPlayerReplace);
    HookEvent("player_hurt",          Event_PlayerHurt);
    HookEvent("player_incapacitated", Event_PlayerIncap);
    HookEvent("player_death",         Event_PlayerKilled);

    g_aTankInfo   = new UserVector(eTankInfoSize);
    g_smUserNames = new StringMap();

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient)) {
            continue;
        }

        OnClientPutInServer(iClient);
    }
}

public void OnClientPutInServer(int iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamagePost, SDK_OnTakeDamagePost);
}

public void OnClientDisconnect(int iClient)
{
    int iUserId = GetClientUserId(iClient);

    char szKey[16];
    IntToString(iUserId, szKey, sizeof(szKey));

    char szClientName[MAX_NAME_LENGTH];
    GetClientName(iClient, szClientName, sizeof(szClientName));
    g_smUserNames.SetString(szKey, szClientName);

    if (!IsFakeClient(iClient)) {
        return;
    }

    Timer_CheckTank(null, GetClientUserId(iClient));
}

void SDK_OnTakeDamagePost(int iVictim, int iAttacker, int iInflictor, float fDamage, int iDamageType)
{
    if (!g_bIsTankInPlay) {
        return;
    }

    if (!IsValidEntity(iVictim)) {
        return;
    }

    if (!IsValidEntity(iAttacker)) {
        return;
    }

    if (!IsValidEdict(iInflictor)) {
        return;
    }

    if (!IsValidClient(iAttacker)) {
        return;
    }

    if (!IsClientSurvivor(iVictim)) {
        return;
    }

    if (!IsClientInfected(iAttacker) || !IsClientTank(iAttacker)) {
        return;
    }

    /* Store HP only when the damage is greater than this, so we can turn to IncapStart for Damage record */
    int iPlayerHealth = GetClientHealth(iVictim) + RoundToCeil(L4D_GetTempHealth(iVictim));
    g_iPlayerLastHealth[iVictim] = iPlayerHealth;
}

/**
 * Events
 */
public void L4D_OnSpawnTank_Post(int iClient, const float vPos[3], const float vAng[3])
{
    if (iClient <= 0) {
        return;
    }

    int iUserId = GetClientUserId(iClient);
    g_iTankIdx++;

    g_bIsTankInPlay = true;

    int iHealth = GetEntProp(iClient, Prop_Send, "m_iHealth", 4, 0);
    g_aTankInfo.UserSet(iUserId, eDamagerInfoVector, new UserVector(eDamagerInfoSize), true);
    g_aTankInfo.UserSet(iUserId, eAliveSince,     GetGameTime());
    g_aTankInfo.UserSet(iUserId, eTankLastHealth, iHealth);
    g_aTankInfo.UserSet(iUserId, eTankMaxHealth,  iHealth);
    g_aTankInfo.UserSet(iUserId, eTankIndex,      g_iTankIdx);
}

void Event_RoundStart(Event event, const char[] szEventName, bool bDontBroadcast)
{
    g_bRoundEnd = false;
    g_iTankIdx = 0;
    g_bIsTankInPlay = false;

    while (g_aTankInfo.Length)
    {
        UserVector uDamagerVector = g_aTankInfo.Get(0, eDamagerInfoVector);
        delete uDamagerVector;

        g_aTankInfo.Erase(0);
    }

    g_smUserNames.Clear();
}

// When survivors wipe or juke tank, announce damage
void Event_RoundEnd(Event event, const char[] szEventName, bool bDontBroadcast)
{
    // But only if a tank that hasn't been killed exists
    if (!g_bRoundEnd)
    {
        int iUserId;

        while (g_aTankInfo.Length)
        {
            iUserId = g_aTankInfo.User(0);
            PrintTankInfo(iUserId);
            ClearTankInfo(iUserId);
        }
    }

    g_bRoundEnd = true;
}

void Event_PlayerBotReplace(Event event, const char[] szEventName, bool bDontBroadcast) {
    HandlePlayerReplace(GetEventInt(event, "bot"), GetEventInt(event, "player"));
}

void Event_BotPlayerReplace(Event event, const char[] szEventName, bool bDontBroadcast) {
    HandlePlayerReplace(GetEventInt(event, "player"), GetEventInt(event, "bot"));
}

// Tank passing between players
public void L4D_OnReplaceTank(int iOldTank, int iNewTank)
{
    if (iOldTank <= 0 || iNewTank <= 0 || iOldTank == iNewTank) {
        return;
    }

    // A pre-hook here so make sure the replace actually happens via a delayed check.
    DataPack hPack = new DataPack();
    hPack.WriteCell(GetClientUserId(iOldTank));
    hPack.WriteCell(GetClientUserId(iNewTank));
    RequestFrame(Frame_HandlePlayerReplace, hPack);
}

void Frame_HandlePlayerReplace(DataPack hPack)
{
    int iOldTank, iNewTank;

    hPack.Reset();
    iOldTank = hPack.ReadCell();
    iNewTank = hPack.ReadCell();
    delete hPack;

    HandlePlayerReplace(iNewTank, iOldTank);
}

void HandlePlayerReplace(int iReplacer, int iReplacee)
{
    int iClient = GetClientOfUserId(iReplacer);
    if (iClient <= 0 || !IsClientInGame(iClient)) {
        return;
    }

    if (!IsClientInfected(iClient) || !IsClientTank(iClient)) {
        return;
    }

    g_aTankInfo.UserReplace(iReplacee, iReplacer);
    iClient = GetClientOfUserId(iReplacee);
    if (iClient <= 0 || !IsClientInGame(iClient) || !IsFakeClient(iClient)) {
        g_aTankInfo.UserSet(iReplacer, eLastControlUserId, iReplacee);
    }
}

void Event_PlayerHurt(Event event, const char[] szEventName, bool bDontBroadcast)
{
    if (g_bRoundEnd) return;
    
    int iVictim = GetClientOfUserId(event.GetInt("userid"));
    // 修改判断条件，移除 IsFakeClient 检查
    if (!IsClientTank(iVictim)) return;

    // ...existing code...
}

void Event_PlayerIncap(Event event, const char[] szEventName, bool bDontBroadcast)
{
    if (!g_bIsTankInPlay) {
        return;
    }

    int iVictimId = GetEventInt(event, "userid");
    int iVictim = GetClientOfUserId(iVictimId);
    if (iVictim <= 0 || !IsClientInGame(iVictim)) {
        return;
    }

    if (IsClientSurvivor(iVictim))
    {
        int iAttackerId = GetEventInt(event, "attacker");
        int iAttacker = GetClientOfUserId(iAttackerId);
        if (iAttacker <= 0 || !IsClientInGame(iAttacker)) {
            return;
        }

        if (!IsClientInfected(iAttacker) || !IsClientTank(iAttacker)) {
            return;
        }

        UserVector uDamagerVector;
        g_aTankInfo.UserGet(iAttackerId, eDamagerInfoVector, uDamagerVector);

        char szWeapon[64];
        GetEventString(event, "weapon", szWeapon, sizeof(szWeapon));

        if      (strcmp(szWeapon, "tank_claw") == 0) uDamagerVector.UserAdd(iVictimId, ePunch,    1, true);
        else if (strcmp(szWeapon, "tank_rock") == 0) uDamagerVector.UserAdd(iVictimId, eRock,     1, true);
        else                                         uDamagerVector.UserAdd(iVictimId, eHittable, 1, true);

        uDamagerVector.UserAdd(iVictimId, eDamageReceived, g_iPlayerLastHealth[iVictim]);
        g_aTankInfo.UserAdd(iAttackerId, eIncap, 1);
        g_aTankInfo.UserAdd(iAttackerId, eTotalDamage, g_iPlayerLastHealth[iVictim]);
    }
}

void Event_PlayerKilled(Event event, const char[] szEventName, bool bDontBroadcast)
{
    if (g_bRoundEnd) return;

    int iVictim = GetClientOfUserId(event.GetInt("userid"));
    // 修改判断条件，移除 IsFakeClient 检查
    if (!IsClientTank(iVictim)) return;

    // 统计并显示坦克数据
    int iUserId = GetClientUserId(iVictim);
    PrintTankInfo(iUserId);
    ClearTankInfo(iUserId);

    g_bIsTankInPlay = false;
}

Action Timer_CheckTank(Handle hTimer, int iUserId)
{
    int iTmp;
    // straight searching for the index, if success it indicates no replace has happened
    // so the user is the final control of the Tank
    if (g_aTankInfo.UserIndex(iUserId, iTmp, false))
    {
        PrintTankInfo(iUserId);
        ClearTankInfo(iUserId);
    }

    g_bIsTankInPlay = g_aTankInfo.Length > 0;

    return Plugin_Stop;
}

bool FindTankControlName(int iUserId, char[] szClientName, int iMaxLen)
{
    int iClient = GetClientOfUserId(iUserId);
    if (!IsFakeClient(iClient)) {
        return GetClientNameFixed(iClient, szClientName, iMaxLen, SHORT_NAME_LENGTH);
    }

    int iLastControlUserid;
    if (g_aTankInfo.UserGet(iUserId, eLastControlUserId, iLastControlUserid) && iLastControlUserid) {
        return GetClientNameFromUserId(iLastControlUserid, szClientName, iMaxLen);
    }

    GetClientName(iClient, szClientName, iMaxLen);
    return false;
}

void PrintTankInfo(int iUserId)
{
    static const char szTeamColor[][] = {
        "{olive}",
        "{olive}",
        "{blue}",
        "{red}"
    };

    int iLength = g_aTankInfo.Length;
    if (!iLength) {
        return;
    }

    int iIdx = 0;
    if (!g_aTankInfo.UserIndex(iUserId, iIdx, false)) {
        return;
    }

    int iClient = GetClientOfUserId(iUserId);

    if (iClient <= 0) {
        return;
    }

    char szTankName[MAX_NAME_LENGTH];
    bool bHumanControlled = FindTankControlName(iUserId, szTankName, sizeof(szTankName));
    int  iLastHealth      = g_aTankInfo.Get(iIdx, eTankLastHealth);
    int  iMaxHealth       = g_aTankInfo.Get(iIdx, eTankMaxHealth);
    int  iTankIdx         = g_aTankInfo.Get(iIdx, eTankIndex);

    UserVector uDamagerVector = g_aTankInfo.Get(iIdx, eDamagerInfoVector);
    uDamagerVector.SortCustom(SortAdtDamageDesc);

    int iDmgTtl = 0, iPctTtl = 0, iSize = uDamagerVector.Length;
    for (int i = 0; i < iSize; i++)
    {
        int iDamage = uDamagerVector.Get(i, eDmgDone);

        if (iDamage <= 0)
        {
            uDamagerVector.Erase(i);
            continue;
        }

        iDmgTtl += iDamage;
        iPctTtl += GetDamageAsPercent(iDamage, iMaxHealth);
    }

    char szIdx[8];
    if (g_iTankIdx > 1) {
        FormatEx(szIdx, sizeof(szIdx), "#%d", iTankIdx);
    }

    if (IsFakeClient(iClient))
    {
        if (bHumanControlled)
        {
            char szLastTankName[MAX_NAME_LENGTH];
            strcopy(szLastTankName, sizeof(szLastTankName), szTankName);
            FormatEx(szTankName, sizeof(szTankName), "%s[%s]", BOT_NAME, szLastTankName);
        }
        else
        {
            strcopy(szTankName, sizeof(szTankName), BOT_NAME);
        }
    }

    if (IsPlayerAlive(iClient))
    {
        if (iDmgTtl > 0) {
            CPrintToChatAll("%t%t%t", "BRACKET_START", "TAG", "ALIVE", szIdx, szTankName, iLastHealth);
        } else {
            CPrintToChatAll("%t%t", "TAG", "ALIVE_WITHOUT_DAMAGE", szIdx, szTankName, iLastHealth); 
        }
    }
    else
    {
        if (iDmgTtl > 0) {
            CPrintToChatAll("%t%t%t", "BRACKET_START", "TAG", "DEAD", szIdx, szTankName);
        } else {
            CPrintToChatAll("%t%t", "TAG", "DEAD_WITHOUT_DAMAGE", szIdx, szTankName);
        }
    }

    char szClientName[MAX_NAME_LENGTH];
    int  iDmg, iPct, iTeamIdx;

    int iPctAdjustment;
    if (iPctTtl < 100 && float(iDmgTtl) > (iMaxHealth - (iMaxHealth / 200))) {
        iPctAdjustment = 100 - iPctTtl;
    }

    int iLastPct = 100;
    int iAdjustedPctDmg;
    char szDmgSpace[16], szPrcntSpace[16];
    for (int iAttacker = 0; iAttacker < iSize; iAttacker++)
    {
        // generally needed
        GetClientNameFromUserId(uDamagerVector.User(iAttacker), szClientName, sizeof(szClientName));

        // basic tank damage announce
        iTeamIdx = uDamagerVector.Get(iAttacker, eTeamIdx);
        iDmg     = uDamagerVector.Get(iAttacker, eDmgDone);
        iPct     = GetDamageAsPercent(iDmg, iMaxHealth);

        if (iPctAdjustment != 0 && iDmg > 0 && !IsExactPercent(iIdx, iDmg))
        {
            iAdjustedPctDmg = iPct + iPctAdjustment;

            if (iAdjustedPctDmg <= iLastPct)
            {
                iPct = iAdjustedPctDmg;
                iPctAdjustment = 0;
            }
        }

        FormatEx(szDmgSpace, sizeof(szDmgSpace), "%s",
        iDmg < 10 ? "      " : iDmg < 100 ? "    " : iDmg < 1000 ? "  " : "");

        FormatEx(szPrcntSpace, sizeof(szPrcntSpace), "%s",
        iPct < 10 ? "  " : iPct < 100 ? " " : "");
        // "{olive}%s%d {green}|%s{default}%d%%{green}%s|{default}: %s%s"
        CPrintToChatAll("%t%t", (iAttacker + 1) == iSize ? "BRACKET_END" : "BRACKET_MIDDLE", "DAMAGE", szDmgSpace, iDmg, szPrcntSpace, iPct, szPrcntSpace, szTeamColor[iTeamIdx], szClientName);
    }
}

void ClearTankInfo(int iUserId)
{
    int iIdx = 0;
    if (!g_aTankInfo.UserIndex(iUserId, iIdx, false)) {
        return;
    }

    UserVector uDamagerVector = g_aTankInfo.Get(iIdx, eDamagerInfoVector);
    delete uDamagerVector;

    g_aTankInfo.Erase(iIdx);
}

// utilize our map g_smUserNames
bool GetClientNameFromUserId(int iUserId, char[] szClientName, int iMaxLen)
{
    if (iUserId == WORLD_INDEX) {
        FormatEx(szClientName, iMaxLen, "World");
        return true;
    }

    int iClient = GetClientOfUserId(iUserId);
    if (iClient && IsClientInGame(iClient)) {
        return GetClientNameFixed(iClient, szClientName, iMaxLen, SHORT_NAME_LENGTH);
    }

    char szKey[16];
    IntToString(iUserId, szKey, sizeof(szKey));
    return g_smUserNames.GetString(szKey, szClientName, iMaxLen);
}

int SortAdtDamageDesc(int iIdx1, int iIdx2, Handle hArray, Handle hHndl)
{
    UserVector uDamagerVector = view_as<UserVector>(hArray);
    int iDmg1 = uDamagerVector.Get(iIdx1, eDmgDone);
    int iDmg2 = uDamagerVector.Get(iIdx2, eDmgDone);
    if      (iDmg1 > iDmg2) return -1;
    else if (iDmg1 < iDmg2) return  1;
    return 0;
}

int GetDamageAsPercent(int iDmg, int iMaxHealth) {
    return RoundToFloor((float(iDmg) / iMaxHealth) * 100.0);
}

bool IsExactPercent(int iDmg, int iMaxHealth) {
    return (FloatAbs(float(GetDamageAsPercent(iDmg, iMaxHealth)) - ((float(iDmg) / iMaxHealth) * 100.0)) < 0.001) ? true : false;
}

/**
 *
 */
bool GetClientNameFixed(int iClient, char[] szClientName, int iLength, int iMaxSize)
{
    if (!GetClientName(iClient, szClientName, iLength)) {
        return false;
    }

    if (strlen(szClientName) > iMaxSize)
    {
        szClientName[iMaxSize - 3] = szClientName[iMaxSize - 2] = szClientName[iMaxSize - 1] = '.';
        szClientName[iMaxSize] = '\0';
    }

    return true;
}

/**
 * Returns whether an entity is a player.
 */
bool IsValidClient(int iClient) {
    return (iClient > 0 && iClient <= MaxClients);
}

/**
 * Returns whether the player is survivor.
 */
bool IsClientSurvivor(int iClient) {
    return (IsClientInGame(iClient) && GetClientTeam(iClient) == TEAM_SURVIVOR);
}

/**
 * Returns whether the player is infected.
 */
bool IsClientInfected(int iClient) {
    return (GetClientTeam(iClient) == TEAM_INFECTED);
}

/**
 * Gets the client L4D1/L4D2 zombie class id.
 *
 * @param iClient    Client index.
 * @return L4D1      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=WITCH, 5=TANK, 6=NOT INFECTED
 * @return L4D2      1=SMOKER, 2=BOOMER, 3=HUNTER, 4=SPITTER, 5=JOCKEY, 6=CHARGER, 7=WITCH, 8=TANK, 9=NOT INFECTED
 */
int GetInfectedClass(int iClient) {
    return GetEntProp(iClient, Prop_Send, "m_zombieClass");
}

/**
 * Returns true if the player is incapacitated.
 *
 * @param iClient    Client index.
 * @return           bool
 */
bool IsClientIncapacitated(int iClient) {
	return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated", true));
}

/**
 * @param iClient    Client index.
 * @return           bool
 */
bool IsClientTank(int iClient) {
    return (IsClientInGame(iClient) && 
            GetClientTeam(iClient) == TEAM_INFECTED && 
            GetEntProp(iClient, Prop_Send, "m_zombieClass") == SI_CLASS_TANK);
}
