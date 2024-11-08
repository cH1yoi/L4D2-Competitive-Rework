#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required


#define CMD_LENGTH 128

// 颜色定义
#define COLOR_PREFIX     "\x01[\x04Aim Monitor\x01]"
#define COLOR_DEFAULT    "\x01"
#define COLOR_HIGHLIGHT  "\x04"
#define COLOR_PLAYER     "\x03"
#define COLOR_WARNING    "\x02"

public Plugin myinfo = {
    name = "Aim Monitor",
    author = "Hana",
    description = "Monitor player aim data",
    version = "1.3",
    url = "https://steamcommunity.com/profiles/76561197983870853/"
};

float g_PlayerAngles[MAXPLAYERS + 1][CMD_LENGTH][3];
float g_PlayerTimes[MAXPLAYERS + 1][CMD_LENGTH];
int g_PlayerButtons[MAXPLAYERS + 1][CMD_LENGTH];
int g_PlayerIndex[MAXPLAYERS + 1];
bool g_IsMonitored[MAXPLAYERS + 1];
int g_MonitoringAdmin[MAXPLAYERS + 1];
char g_LogPath[PLATFORM_MAX_PATH];

public void OnPluginStart() {
    RegAdminCmd("sm_monitor", Command_Monitor, ADMFLAG_GENERIC, "开始监控指定玩家");
    RegAdminCmd("sm_mt", Command_Monitor, ADMFLAG_GENERIC, "开始监控指定玩家");
    RegAdminCmd("sm_unmonitor", Command_Unmonitor, ADMFLAG_GENERIC, "停止监控指定玩家");
    RegAdminCmd("sm_unmt", Command_Unmonitor, ADMFLAG_GENERIC, "停止监控指定玩家");
    
    HookEvent("player_death", Event_PlayerDeath);
    
    BuildPath(Path_SM, g_LogPath, sizeof(g_LogPath), "logs/aim_monitor.log");
}

public void OnClientPutInServer(int client) {
    g_IsMonitored[client] = false;
    g_MonitoringAdmin[client] = 0;
    SDKHook(client, SDKHook_PostThinkPost, OnPlayerPostThinkPost);
}

public Action Command_Monitor(int client, int args) {
    if(args < 1) {
        PrintToChat(client, "%s %s用法: /monitor \"玩家\"", COLOR_PREFIX, COLOR_WARNING);
        return Plugin_Handled;
    }
    
    char arg[65];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true);
    if(target == -1)
        return Plugin_Handled;
        
    if(g_IsMonitored[target]) {
        PrintToChat(client, "%s %s玩家 %s%N %s已经在被监控中", COLOR_PREFIX, COLOR_DEFAULT, COLOR_PLAYER, target, COLOR_DEFAULT);
        return Plugin_Handled;
    }
    
    // 添加团队检查
    if(IsValidClient(target)) {
        int team = GetClientTeam(target);
        if(team != 2) { // 2 = 生还者团队
            PrintToChat(client, "%s %s只能监控生还者团队的玩家", COLOR_PREFIX, COLOR_WARNING);
            return Plugin_Handled;
        }
    }
    
    g_IsMonitored[target] = true;
    g_MonitoringAdmin[target] = client;
    
    PrintToChat(client, "%s %s开始监控玩家 %s%N", COLOR_PREFIX, COLOR_DEFAULT, COLOR_PLAYER, target);
    LogToFile(g_LogPath, "[监控开始] 管理员 %N 开始监控玩家 %N", client, target);
    
    return Plugin_Handled;
}

public Action Command_Unmonitor(int client, int args) {
    if(args < 1) {
        PrintToChat(client, "%s %s用法: /unmonitor \"玩家\"", COLOR_PREFIX, COLOR_WARNING);
        return Plugin_Handled;
    }
    
    char arg[65];
    GetCmdArg(1, arg, sizeof(arg));
    
    int target = FindTarget(client, arg, true);
    if(target == -1)
        return Plugin_Handled;
        
    if(!g_IsMonitored[target]) {
        PrintToChat(client, "%s %s玩家 %s%N %s未被监控", COLOR_PREFIX, COLOR_DEFAULT, COLOR_PLAYER, target, COLOR_DEFAULT);
        return Plugin_Handled;
    }
    
    g_IsMonitored[target] = false;
    g_MonitoringAdmin[target] = 0;
    
    PrintToChat(client, "%s %s停止监控玩家 %s%N", COLOR_PREFIX, COLOR_DEFAULT, COLOR_PLAYER, target);
    LogToFile(g_LogPath, "[监控结束] 管理员 %N 停止监控玩家 %N", client, target);
    
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
    float delta = 0.0, total_delta = 0.0;
    int ind, shotindex = -1;
    bool foundShot = false;
    int attackTicks = 0;
    
    // 获取目标信息
    char targetInfo[64];
    if(IsValidClient(victim)) {
        int zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        if(zombieClass >= 1 && zombieClass <= 6) { // 只处理特感
            char className[32];
            GetZombieClassName(zombieClass, className, sizeof(className));
            Format(targetInfo, sizeof(targetInfo), "%N(%s)", victim, className);
        } else {
            return; // 不是特感就返回
        }
    } else {
        return; // 不是玩家就返回
    }
    
    // 计算实际距离
    float clientPos[3], victimPos[3];
    GetClientAbsOrigin(client, clientPos);
    GetClientAbsOrigin(victim, victimPos);
    float distance = GetVectorDistance(clientPos, victimPos);
    
    // 计算射击tick和角度变化
    ind = g_PlayerIndex[client];
    for(int i = 0; i < time_to_ticks(1.0); i++) {
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
            float tdelta = GetAngleDelta(g_PlayerAngles[client][ind], g_PlayerAngles[client][ind+1]);
            if(tdelta > delta)
                delta = tdelta;
            total_delta += tdelta;
        }
    }
    
    int admin = g_MonitoringAdmin[client];
    if(!IsValidClient(admin))
        return;
        
    char shotType[32];
    if(attackTicks <= 1)
        Format(shotType, sizeof(shotType), "[1shot]%s", headshot ? "[爆头]" : "");
    else
        Format(shotType, sizeof(shotType), "%s", headshot ? "[爆头]" : "");
        
    // 只输出特感击杀信息到聊天
    PrintToChat(admin, "%s %s分析结果:", COLOR_PREFIX, COLOR_DEFAULT);
    PrintToChat(admin, "%s- 击杀目标: %s%s", COLOR_DEFAULT, COLOR_HIGHLIGHT, targetInfo);
    PrintToChat(admin, "%s- 使用武器: %s%s%s", COLOR_DEFAULT, COLOR_HIGHLIGHT, weapon, shotType);
    PrintToChat(admin, "%s- 击杀距离: %s%.1f 单位", COLOR_DEFAULT, COLOR_HIGHLIGHT, distance);
    PrintToChat(admin, "%s- 射击Tick: %s%d", COLOR_DEFAULT, COLOR_HIGHLIGHT, attackTicks);
    PrintToChat(admin, "%s- 最大角度: %s%.1f 度", COLOR_DEFAULT, COLOR_HIGHLIGHT, delta);
    PrintToChat(admin, "%s- 总角度变化: %s%.1f 度", COLOR_DEFAULT, COLOR_HIGHLIGHT, total_delta);
    PrintToChat(admin, "%s- 网络状态: %s%dms / %.1f%%丢包", COLOR_DEFAULT, COLOR_HIGHLIGHT,
        RoundToNearest(GetClientLatency(client, NetFlow_Both) * 1000.0),
        GetClientAvgLoss(client, NetFlow_Both) * 100.0);
    
    // 记录所有击杀信息到日志
    LogToFile(g_LogPath, 
        "[瞄准分析]玩家:%N |目标:%s |武器:%s%s |距离:%.1f单位|射击Tick:%d |最大角度:%.1f度|总角度:%.1f度|延迟:%dms |丢包:%.1f%%",
        client, targetInfo, weapon, shotType, distance, attackTicks, delta, total_delta,
        RoundToNearest(GetClientLatency(client, NetFlow_Both) * 1000.0),
        GetClientAvgLoss(client, NetFlow_Both) * 100.0);
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

int time_to_ticks(float time) {
    return RoundToNearest(time * (1.0 / GetTickInterval()));
}

public void OnMapStart() {
    // 地图开始时重置所有监控状态
    for(int i = 1; i <= MaxClients; i++) {
        g_IsMonitored[i] = false;
        g_MonitoringAdmin[i] = 0;
        g_PlayerIndex[i] = 0;
    }
}

public void OnClientDisconnect(int client) {
    // 玩家断开连接时清理监控状态
    g_IsMonitored[client] = false;
    g_MonitoringAdmin[client] = 0;
    g_PlayerIndex[client] = 0;
    
    // 如果这个玩家是管理员，清理所有被他监控的玩家
    for(int i = 1; i <= MaxClients; i++) {
        if(g_MonitoringAdmin[i] == client) {
            g_IsMonitored[i] = false;
            g_MonitoringAdmin[i] = 0;
        }
    }
}