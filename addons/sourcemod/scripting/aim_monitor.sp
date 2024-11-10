#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define CMD_LENGTH 128

enum struct KillData {
    int client;
    int victim;
    bool headshot;
    char weapon[32];
    float distance;
    int attackTicks;
    float delta;
    float total_delta;
    float killPos[3];
    float victimPos[3];
    char targetInfo[64];
    float latency;
    float packetLoss;
    char shotType[32];
}

public Plugin myinfo = {
    name = "Aim Monitor",
    author = "Hana",
    description = "Monitor player aim data",
    version = "1.4",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

float g_PlayerAngles[MAXPLAYERS + 1][CMD_LENGTH][3];
float g_PlayerTimes[MAXPLAYERS + 1][CMD_LENGTH];
int g_PlayerButtons[MAXPLAYERS + 1][CMD_LENGTH];
int g_PlayerIndex[MAXPLAYERS + 1];
bool g_IsMonitored[MAXPLAYERS + 1];
int g_MonitoringAdmin[MAXPLAYERS + 1];

public void OnPluginStart() {
    RegAdminCmd("sm_monitor", Command_Monitor, ADMFLAG_GENERIC, "开始监控指定玩家");
    RegAdminCmd("sm_mt", Command_Monitor, ADMFLAG_GENERIC, "开始监控指定玩家");
    RegAdminCmd("sm_unmonitor", Command_Unmonitor, ADMFLAG_GENERIC, "停止监控指定玩家");
    RegAdminCmd("sm_unmt", Command_Unmonitor, ADMFLAG_GENERIC, "停止监控指定玩家");
    
    HookEvent("player_death", Event_PlayerDeath);   // 监听玩家死亡事件
}

public void OnMapStart() {
    for(int i = 1; i <= MaxClients; i++) {
        if(g_IsMonitored[i] && IsValidClient(g_MonitoringAdmin[i])) {
            PrintToChat(g_MonitoringAdmin[i], "\x01[\x04Aim Monitor\x01] \x01由于更换地图，停止监控玩家 \x03%N", i);
        }
        g_IsMonitored[i] = false;
        g_MonitoringAdmin[i] = 0;
        g_PlayerIndex[i] = 0;
    }
}

public void OnClientDisconnect(int client) {
    if(g_IsMonitored[client] && IsValidClient(g_MonitoringAdmin[client])) {
        PrintToChat(g_MonitoringAdmin[client], "\x01[\x04Aim Monitor\x01] \x01玩家 \x03%N \x01断开连接，停止监控", client);
    }
    g_IsMonitored[client] = false;
    g_MonitoringAdmin[client] = 0;
    g_PlayerIndex[client] = 0;
    
    for(int i = 1; i <= MaxClients; i++) {
        if(g_MonitoringAdmin[i] == client) {
            g_IsMonitored[i] = false;
            g_MonitoringAdmin[i] = 0;
        }
    }
}

public void OnClientPutInServer(int client) {
    g_IsMonitored[client] = false;
    g_MonitoringAdmin[client] = 0;
    SDKHook(client, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
}

public Action Command_Monitor(int client, int args) {
    if(args < 1) {
        PrintToChat(client, "\x01[\x04Aim Monitor\x01] \x02用法: /monitor \"玩家\"");
        return Plugin_Handled;
    }
    
    char arg[65];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true);
    if(target == -1)
        return Plugin_Handled;
        
    if(g_IsMonitored[target]) {
        PrintToChat(client, "\x01[\x04Aim Monitor\x01] \x01玩家 \x03%N \x01已经在被监控中", target);
        return Plugin_Handled;
    }
    
    if(IsValidClient(target)) {
        int team = GetClientTeam(target);
        if(team != 2) {
            PrintToChat(client, "\x01[\x04Aim Monitor\x01] \x02只能监控生还者团队的玩家");
            return Plugin_Handled;
        }
    }
    
    g_IsMonitored[target] = true;
    g_MonitoringAdmin[target] = client;
    
    PrintToChat(client, "\x01[\x04Aim Monitor\x01] \x01开始监控玩家 \x03%N", target);
    
    return Plugin_Handled;
}

public Action Command_Unmonitor(int client, int args) {
    if(args < 1) {
        PrintToChat(client, "\x01[\x04Aim Monitor\x01] \x02用法: /unmonitor \"玩家\"");
        return Plugin_Handled;
    }
    
    char arg[65];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true);
    if(target == -1)
        return Plugin_Handled;
        
    if(!g_IsMonitored[target]) {
        PrintToChat(client, "\x01[\x04Aim Monitor\x01] \x01玩家 \x03%N \x01未被监控", target);
        return Plugin_Handled;
    }
    
    g_IsMonitored[target] = false;
    g_MonitoringAdmin[target] = 0;
    
    PrintToChat(client, "\x01[\x04Aim Monitor\x01] \x01停止监控玩家 \x03%N", target);
    
    return Plugin_Handled;
}

public Action OnPlayerPostThinkPost(int client) {
    // 添加额外的有效性检查
    if(!IsValidClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2)
        return Plugin_Continue;
        
    if(!g_IsMonitored[client])
        return Plugin_Continue;
        
    // 检查监控管理员是否仍在游戏中
    int admin = g_MonitoringAdmin[client];
    if(!IsValidClient(admin)) {
        g_IsMonitored[client] = false;
        g_MonitoringAdmin[client] = 0;
        return Plugin_Continue;
    }
    
    float angles[3];
    GetClientEyeAngles(client, angles);
    
    int index = g_PlayerIndex[client];
    g_PlayerAngles[client][index] = angles;
    g_PlayerTimes[client][index] = GetGameTime();
    g_PlayerButtons[client][index] = GetClientButtons(client);
    
    if(++index >= CMD_LENGTH)
        index = 0;
    g_PlayerIndex[client] = index;
    
    return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    bool headshot = event.GetBool("headshot");
    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    
    if(!IsValidClient(attacker) || !IsValidClient(victim))
        return;
        
    if(GetClientTeam(attacker) != 2) // 确保只处理生还者的击杀
        return;
        
    ProcessKill(attacker, victim, headshot, weapon);
}

void ProcessKill(int client, int victim, bool headshot, const char[] weapon) {
    // 忽略自杀和world击杀
    if (StrEqual(weapon, "world", false) || client == victim) {
        return;
    }
    
    // 记录击杀位置
    float killpos[3], victimpos[3];
    GetClientEyePosition(client, killpos);
    GetClientEyePosition(victim, victimpos);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(GetClientUserId(victim));
    pack.WriteCell(headshot);
    pack.WriteString(weapon);
    pack.WriteCell(g_PlayerIndex[client]); // 记录当前index作为fallback
    
    // 记录位置信息
    pack.WriteFloat(killpos[0]);
    pack.WriteFloat(killpos[1]);
    pack.WriteFloat(killpos[2]);
    pack.WriteFloat(victimpos[0]);
    pack.WriteFloat(victimpos[1]);
    pack.WriteFloat(victimpos[2]);
    
    CreateTimer(0.1, Timer_ProcessKill, pack);
}

public Action Timer_ProcessKill(Handle timer, DataPack pack) {
    pack.Reset();
    
    int client = GetClientOfUserId(pack.ReadCell());
    int victim = GetClientOfUserId(pack.ReadCell());
    bool headshot = pack.ReadCell();
    
    char weapon[32];
    pack.ReadString(weapon, sizeof(weapon));
    
    int fallback_index = pack.ReadCell();
    
    float killpos[3], victimpos[3];
    killpos[0] = pack.ReadFloat();
    killpos[1] = pack.ReadFloat();
    killpos[2] = pack.ReadFloat();
    victimpos[0] = pack.ReadFloat();
    victimpos[1] = pack.ReadFloat();
    victimpos[2] = pack.ReadFloat();
    
    delete pack;

    // 有效性检查
    if(!IsValidClient(client) || !IsValidClient(victim)) {
        return Plugin_Stop;
    }
    
    float delta = 0.0, total_delta = 0.0;
    int ind, shotindex = -1;
    bool foundShot = false;
    int attackTicks = 0;
    
    // 获取目标信息
    char targetInfo[64];
    int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
    if(zombieClass < 1 || zombieClass > 6) {
        return Plugin_Stop;
    }
    
    char className[32];
    GetZombieClassName(zombieClass, className, sizeof(className));
    Format(targetInfo, sizeof(targetInfo), "%N(%s)", victim, className);
    
    // 计算实际距离
    float distance = GetVectorDistance(killpos, victimpos);
    
    // 使用实际tick rate
    float tickInterval = GetTickInterval();
    int ticksPerSecond = RoundToCeil(1.0 / tickInterval);
    
    // 计算射击tick和角度变化
    ind = g_PlayerIndex[client];
    for(int i = 0; i < ticksPerSecond; i++) {
        if(--ind < 0)
            ind = CMD_LENGTH - 1;
            
        if(GetGameTime() - g_PlayerTimes[client][ind] > 1.0)
            break;
            
        if(g_PlayerButtons[client][ind] & IN_ATTACK) {
            foundShot = true;
            attackTicks++;
            
            if(shotindex == -1)
                shotindex = ind;
        }
        else if(foundShot) {
            break;
        }
        
        if(i > 0 && shotindex != -1) {
            int nextInd = (ind + 1) % CMD_LENGTH;
            float tdelta = GetAngleDelta(g_PlayerAngles[client][ind], g_PlayerAngles[client][nextInd]);
            if(tdelta > delta)
                delta = tdelta;
            total_delta += tdelta;
        }
    }
    
    // 如果没找到射击记录,使用fallback index
    if(shotindex == -1) {
        shotindex = fallback_index;
    }

    KillData data;
    data.client = client;
    data.victim = victim;
    data.headshot = headshot;
    strcopy(data.weapon, sizeof(data.weapon), weapon);
    data.distance = distance;
    data.attackTicks = attackTicks;
    data.delta = delta;
    data.total_delta = total_delta;
    data.killPos = killpos;
    data.victimPos = victimpos;
    strcopy(data.targetInfo, sizeof(data.targetInfo), targetInfo);
    data.latency = GetClientLatency(client, NetFlow_Both);
    data.packetLoss = GetClientAvgLoss(client, NetFlow_Both);

     // 设置shotType
    if(attackTicks <= 1)
        Format(data.shotType, sizeof(data.shotType), "[1shot]%s", headshot ? "[爆头]" : "");
    else
        Format(data.shotType, sizeof(data.shotType), "%s", headshot ? "[爆头]" : "");

    // 输出聊天信息
    int admin = g_MonitoringAdmin[client];
    if(!IsValidClient(admin))
        return Plugin_Stop;
        
    PrintToChat(admin, "\x01[\x04Aim Monitor\x01] \x01分析结果:");
    PrintToChat(admin, "\x01- 击杀目标: \x04%s", data.targetInfo);
    PrintToChat(admin, "\x01- 使用武器: \x04%s%s", data.weapon, data.shotType);
    PrintToChat(admin, "\x01- 击杀距离: \x04%.1f \x01单位", data.distance);
    PrintToChat(admin, "\x01- 射击Tick: \x04%d", data.attackTicks);
    PrintToChat(admin, "\x01- 最大角度: \x04%.1f \x01度", data.delta);
    PrintToChat(admin, "\x01- 总角度变化: \x04%.1f \x01度", data.total_delta);
    PrintToChat(admin, "\x01- 网络状态: \x04%dms \x01/ \x04%.1f%%\x01丢包",
        RoundToNearest(data.latency * 1000.0),
        data.packetLoss);
    
    LogKillData(data);
    
    return Plugin_Stop;
}

void LogKillData(KillData data) {
    char logFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logFile, sizeof(logFile), "logs/aim_monitor.log");
    
    File file = OpenFile(logFile, "a");
    if (file != null) {
        char timeStamp[32];
        FormatTime(timeStamp, sizeof(timeStamp), "%Y/%m/%d - %H:%M:%S", GetTime());
        
        file.WriteLine("< [%s] [%N] 击杀数据 >", timeStamp, data.client);
        file.WriteLine("击杀玩家: %N", data.client);
        file.WriteLine("击杀目标: %s", data.targetInfo);
        file.WriteLine("使用武器: %s%s", data.weapon, data.shotType);
        file.WriteLine("击杀距离: %.1f 单位", data.distance);
        file.WriteLine("射击Tick: %d", data.attackTicks);
        file.WriteLine("最大角度: %.1f 度", data.delta);
        file.WriteLine("总角度变化: %.1f 度", data.total_delta);
        file.WriteLine("击杀位置: (%.1f, %.1f, %.1f)", 
            data.killPos[0], data.killPos[1], data.killPos[2]);
        file.WriteLine("目标位置: (%.1f, %.1f, %.1f)", 
            data.victimPos[0], data.victimPos[1], data.victimPos[2]);
        file.WriteLine("网络状态: %dms / %.1f%%丢包", 
            RoundToNearest(data.latency * 1000.0), data.packetLoss);
        file.WriteLine("===========================================");
        delete file;
    }
}

void GetZombieClassName(int zombieClass, char[] buffer, int maxlen) {
    switch(zombieClass) {
        case 1: strcopy(buffer, maxlen, "Smoker");
        case 2: strcopy(buffer, maxlen, "Boomer");
        case 3: strcopy(buffer, maxlen, "Hunter");
        case 4: strcopy(buffer, maxlen, "Spitter");
        case 5: strcopy(buffer, maxlen, "Jockey");
        case 6: strcopy(buffer, maxlen, "Charger");
        case 7: strcopy(buffer, maxlen, "Witch");
        case 8: strcopy(buffer, maxlen, "Tank");
        default: strcopy(buffer, maxlen, "Unknown");
    }
}

float GetAngleDelta(float angles1[3], float angles2[3]) {
    float p1[3], p2[3], delta;
    
    p1[0] = angles1[0];
    p2[0] = angles2[0];
    p1[1] = angles1[1];
    p2[1] = angles2[1];
    
    p1[2] = 0.0;
    p2[2] = 0.0;
    
    delta = GetVectorDistance(p1, p2);
    
    int normal = 5;
    while(delta > 180.0 && normal > 0) {
        normal--;
        delta = FloatAbs(delta - 360.0);
    }
    
    return delta;
}

bool IsValidClient(int client) {
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}
