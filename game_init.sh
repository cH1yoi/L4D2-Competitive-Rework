#!/bin/bash

clear

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
NC='\e[0m'

cat << 'EOF'
==============================================
       L4D2 Server Installation Script
==============================================
**Warning: This script needs to be run after the dependency installation is completed and you have a certain Linux foundation.**
**警告: 本脚本需要建立在已完成依赖安装后运行,并且您具备一定的Linux基础**

This script will help you:
1. Install L4D2 Dedicated Server
2. Download and install plugins
3. Create management scripts for easier management
4. Customize server with a daily restart schedule
5. Support multiple server management

本脚本将帮助您：
1. 安装Left 4 Dead 2 服务端
2. 下载并安装插件
3. 创建方便管理的脚本
4. 自定义服务器的每日重启计划
5. 支持多服务器管理

Created by: HANA
==============================================
EOF

LANGUAGE="en"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SERVER_PATHS=()

check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}This script should NOT be run as root.${NC}"
        echo -e "${RED}Please run as a normal user (preferably the steam user).${NC}"
        echo -e "${RED}不要使用root权限运行此脚本。${NC}"
        echo -e "${RED}请使用普通用户（最好是steam用户）运行。${NC}"
        exit 1
    fi
}

confirm() {
    local response
    read -r response
    case "$response" in
        [Yy]|[Yy][Ee][Ss]|"") return 0 ;;
        *) return 1 ;;
    esac
}

echo -e "\e[1;36m=== Language Selection ===\e[0m"
echo -e "\e[1;33m1. English\e[0m"
echo -e "\e[1;33m2. 中文\e[0m"
read -p "Enter your choice (1 or 2): " lang_choice

if [ "$lang_choice" == "2" ]; then
    LANGUAGE="zh"
fi

function echo_lang() {
    local en_msg=$1
    local zh_msg=$2
    if [ "$LANGUAGE" == "en" ]; then
        echo -e "\e[1;32m$en_msg\e[0m"
    else
        echo -e "\e[1;32m$zh_msg\e[0m"
    fi
}

function echo_section() {
    local en_msg=$1
    local zh_msg=$2
    echo -e "\n\e[1;36m=== $en_msg / $zh_msg ===\e[0m"
}

echo_section "Server Configuration" "服务器配置"
echo_lang "Do you want to set up multiple servers? [Y/n]" "是否要设置多个服务器？[Y/n]"
if confirm; then
    echo_lang "How many servers do you want to set up?" "您想设置多少个服务器？"
    read -r server_count
    for ((i=1; i<=server_count; i++)); do
        echo_lang "Enter installation path for server $i (e.g., /home/hana/l4d2_$i):" "请输入服务器 $i 的安装路径（例如 /home/hana/l4d2_$i）:"
        read -r server_path
        SERVER_PATHS+=("$(realpath "$server_path")")
        mkdir -p "$server_path"
    done
else
    echo_lang "Please enter the installation path (e.g., /home/hana/l4d2):" "请输入安装路径（例如 /home/hana/l4d2）:"
    read -r INSTALL_PATH
    SERVER_PATHS+=("$(realpath "$INSTALL_PATH")")
    mkdir -p "$INSTALL_PATH"
fi

for path in "${SERVER_PATHS[@]}"; do
    echo_lang "Installation path set to: $path" "安装路径设置为: $path"
done

function setup_steamcmd() {
    echo_section "SteamCMD Setup" "SteamCMD 设置"
    
    STEAMCMD_DIR="$HOME/steamcmd"
    if [ ! -d "$STEAMCMD_DIR" ]; then
        mkdir -p "$STEAMCMD_DIR"
        cd "$STEAMCMD_DIR" || exit 1
        
        echo_lang "Downloading SteamCMD..." "正在下载 SteamCMD..."
        curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
    else
        echo_lang "SteamCMD already installed, skipping download." "SteamCMD 已安装，跳过下载。"
    fi
}

function setup_server() {
    echo_section "Server Installation" "服务端安装"
    
    setup_steamcmd
    STEAMCMD_DIR="$HOME/steamcmd"
    
    for server_path in "${SERVER_PATHS[@]}"; do
        echo_lang "Installing L4D2 Server to: $server_path" "正在安装 L4D2 服务端到: $server_path"
        
        echo_lang "Creating installation script..." "正在创建安装脚本..."
        cat << STEAMCMD_EOF > "$STEAMCMD_DIR/Left4Dead2_Server.txt"
force_install_dir $server_path
login anonymous
@sSteamCmdForcePlatformType windows
app_update 222860 validate
@sSteamCmdForcePlatformType linux
app_update 222860 validate
quit
STEAMCMD_EOF

        cd "$STEAMCMD_DIR" || exit 1
        ./steamcmd.sh +runscript "$STEAMCMD_DIR/Left4Dead2_Server.txt"
        
        echo_lang "Server installation completed for: $server_path" "服务端安装完成：$server_path"
    done
}

function download_plugins() {
    echo_section "Plugin Installation" "插件安装"
    
    echo_lang "Do you want to download plugins? [Y/n]" "是否下载插件？[Y/n]"
    if confirm; then
        echo_lang "Please select a plugin repository:" "请选择一个插件库:"
        echo_lang "1. Hana Competitive" "1. Hana Competitive"
        echo_lang "2. Sir.P 0721 Server" "2. Sir.P 的0721服务器"
        echo_lang "3. Default Competitive" "3. 默认的Zonemod"
        echo_lang "4. Not0721 Coop" "4. Not0721 战役"
        echo_lang "5. Anne's Coop" "5. Anne 药役"
        echo_lang "6. Custom repository" "6. 自定义"
        read -p "Enter your choice (1-6): " plugin_choice

        case $plugin_choice in
            1)
                PLUGIN_REPO_URL="https://github.com/cH1yoi/L4D2-Competitive-Rework.git"
                ;;
            2)
                PLUGIN_REPO_URL="https://github.com/PencilMario/L4D2-Competitive-Rework.git"
                ;;
            3)
                PLUGIN_REPO_URL="https://github.com/SirPlease/L4D2-Competitive-Rework.git"
                ;;
            4)
                PLUGIN_REPO_URL="https://github.com/PencilMario/L4D2-Not0721Here-CoopSvPlugins.git"
                ;;
            5)
                PLUGIN_REPO_URL="https://github.com/fantasylidong/CompetitiveWithAnne.git"
                ;;
            6)
                echo_lang "Please enter the custom repository URL:" "请输入自定义库地址:"
                read -r PLUGIN_REPO_URL
                ;;
            *)
                echo_lang "Invalid choice, skipping plugin download." "无效选择，跳过插件下载。"
                return
                ;;
        esac

        REPO_NAME=$(basename "$PLUGIN_REPO_URL" .git)
        echo_lang "Downloading plugins..." "正在下载插件..."
        cd "$SCRIPT_DIR" || exit 1
        git clone "$PLUGIN_REPO_URL" "$REPO_NAME"

        if [ -d "$REPO_NAME" ]; then
            for server_path in "${SERVER_PATHS[@]}"; do
                mkdir -p "$server_path/left4dead2"
                chmod 775 -R "$server_path/left4dead2"
                
                cp -r "$REPO_NAME"/* "$server_path/left4dead2/"
                
                echo_lang "Plugins installed successfully for: $server_path" "插件安装成功：$server_path"
            done

            create_plugin_update_script
            
            echo_lang "Plugin update script created successfully." "插件更新脚本创建成功。"
        else
            echo_lang "Failed to clone the repository." "克隆仓库失败。"
        fi
    fi
}

function create_plugin_update_script() {
    echo_lang "Creating plugin update script..." "正在创建插件更新脚本..."
    
    cat << 'PLUGIN_UPDATE_EOF' > "$SCRIPT_DIR/update_plugins.sh"
#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/server_config.sh"

# 颜色定义
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m'

echo -e "${BLUE}==================Plugin Update Time==================${NC}"
TZ=UTC-8 date
echo -e "${BLUE}==================Starting Update==================${NC}"

if [ -z "$PLUGIN_REPO_URL" ] || [ -z "$REPO_NAME" ]; then
    echo -e "${RED}Error: Repository information is missing in server_config.sh${NC}"
    echo -e "${RED}Please check your configuration file.${NC}"
    exit 1
fi

USER_HOME="$HOME"
USER_REPO_DIR="$USER_HOME/$REPO_NAME"

if [ ! -d "$USER_REPO_DIR" ]; then
    echo -e "${YELLOW}Cloning repository to $USER_REPO_DIR...${NC}"
    git clone "$PLUGIN_REPO_URL" "$USER_REPO_DIR" || {
        echo -e "${RED}ERROR: Failed to clone repository.${NC}"
        exit 1
    }
else
    echo -e "${YELLOW}Updating repository in $USER_REPO_DIR...${NC}"
    cd "$USER_REPO_DIR" || {
        echo -e "${RED}ERROR: Cannot enter repository directory.${NC}"
        exit 1
    }
    
    OLD_COMMIT=$(git rev-parse HEAD)
    
    git pull --rebase || {
        echo -e "${RED}ERROR: Failed to update repository.${NC}"
        exit 1
    }
    
    NEW_COMMIT=$(git rev-parse HEAD)
    
    if [ "$OLD_COMMIT" == "$NEW_COMMIT" ]; then
        echo -e "${GREEN}Already up to date. No updates detected.${NC}"
    fi
fi

# 要特殊处理的文件夹
SPECIAL_FOLDERS=("data" "configs" "gamedata")

check_special_folders() {
    local repo_dir=$1
    local server_dir=$2
    local temp_dir=$3
    
    echo -e "${YELLOW}Checking special folders...${NC}"
    
    for folder in "${SPECIAL_FOLDERS[@]}"; do
        REPO_FOLDER="$repo_dir/addons/sourcemod/$folder"
        SERVER_FOLDER="$server_dir/addons/sourcemod/$folder"
        
        if [ -d "$REPO_FOLDER" ]; then
            if [ ! -d "$SERVER_FOLDER" ]; then
                echo -e "${GREEN}Folder $folder does not exist in server, creating...${NC}"
                mkdir -p "$SERVER_FOLDER"
                rsync -a "$REPO_FOLDER/" "$SERVER_FOLDER/"
            else
                mkdir -p "$temp_dir/repo/$folder" "$temp_dir/server/$folder"
                rsync -a "$REPO_FOLDER/" "$temp_dir/repo/$folder/"
                rsync -a "$SERVER_FOLDER/" "$temp_dir/server/$folder/"
                
                if ! diff -r "$temp_dir/repo/$folder" "$temp_dir/server/$folder" &>/dev/null; then
                    echo -e "${YELLOW}Folder $folder has updates in repository, syncing changes...${NC}"
                    rsync -a --update "$REPO_FOLDER/" "$SERVER_FOLDER/"
                else
                    echo -e "${GREEN}Folder $folder has no changes, keeping as is${NC}"
                fi
            fi
        fi
    done
}

backup_special_folders() {
    local server_dir=$1
    local temp_dir=$2
    
    echo -e "${YELLOW}Backing up special folders...${NC}"
    
    for folder in "${SPECIAL_FOLDERS[@]}"; do
        local source_dir="$server_dir/addons/sourcemod/$folder"
        if [ -d "$source_dir" ]; then
            echo -e "${GREEN}Backing up $folder folder...${NC}"
            mkdir -p "$temp_dir/backup/$folder"
            rsync -a "$source_dir/" "$temp_dir/backup/$folder/"
        fi
    done
}

for server_path in "${SERVER_PATHS[@]}"; do
    L4D2_DIR="$server_path/left4dead2"
    
    if [ ! -d "$server_path" ]; then
        echo -e "${RED}Error: Server directory $server_path does not exist${NC}"
        echo -e "${RED}Skipping this server...${NC}"
        continue
    fi
    
    echo -e "\n${BLUE}==================Processing Server: $server_path==================${NC}"
    
    if [ ! -d "$L4D2_DIR" ]; then
        echo -e "${YELLOW}Creating left4dead2 directory...${NC}"
        mkdir -p "$L4D2_DIR"
    fi
    
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    backup_special_folders "$L4D2_DIR" "$TEMP_DIR"
    
    if [ -f "$L4D2_DIR/cfg/server.cfg" ]; then
        echo -e "${GREEN}Backing up server.cfg...${NC}"
        mkdir -p "$TEMP_DIR"
        cp "$L4D2_DIR/cfg/server.cfg" "$TEMP_DIR/server.cfg.backup"
    fi
    
    echo -e "${YELLOW}Cleaning up old files...${NC}"
    
    mkdir -p "$L4D2_DIR/addons/sourcemod"
    mkdir -p "$L4D2_DIR/cfg"
    
    if [ -d "$L4D2_DIR/addons/sourcemod" ]; then
        for dir in "bin" "extensions" "plugins" "scripting" "translations"; do
            if [ -d "$L4D2_DIR/addons/sourcemod/$dir" ]; then
                echo -e "${YELLOW}Removing directory: addons/sourcemod/$dir${NC}"
                rm -rf "$L4D2_DIR/addons/sourcemod/$dir"
            fi
        done
    fi
    
    for item in "metamod" "stripper" "l4dtoolz.dll" "l4dtoolz.so" "tickrate_enabler.dll" "tickrate_enabler.so" "tickrate_enabler.vdf" "l4dtoolz.vdf" "metamod.vdf"; do
        if [ -e "$L4D2_DIR/addons/$item" ]; then
            echo -e "${YELLOW}Removing: addons/$item${NC}"
            rm -rf "$L4D2_DIR/addons/$item"
        fi
    done
    
    for dir in "cfgogl" "mixmap" "sourcemod" "spcontrol_server" "stripper"; do
        if [ -d "$L4D2_DIR/cfg/$dir" ]; then
            echo -e "${YELLOW}Removing directory: cfg/$dir${NC}"
            rm -rf "$L4D2_DIR/cfg/$dir"
        fi
    done
    
    echo -e "${GREEN}Copying addons folder...${NC}"
    if [ -d "$USER_REPO_DIR/addons" ]; then
        mkdir -p "$L4D2_DIR/addons"
        rsync -a --exclude="sourcemod/configs" --exclude="sourcemod/data" --exclude="sourcemod/gamedata" "$USER_REPO_DIR/addons/" "$L4D2_DIR/addons/" || {
            echo -e "${RED}Failed to copy addons folder${NC}"
        }
    else
        echo -e "${RED}Warning: addons folder not found in repository${NC}"
    fi
    
    check_special_folders "$USER_REPO_DIR" "$L4D2_DIR" "$TEMP_DIR"
    
    echo -e "${GREEN}Copying cfg folder...${NC}"
    if [ -d "$USER_REPO_DIR/cfg" ]; then
        rsync -a "$USER_REPO_DIR/cfg/" "$L4D2_DIR/cfg/" || {
            echo -e "${RED}Failed to copy cfg folder${NC}"
        }
    else
        echo -e "${RED}Warning: cfg folder not found in repository${NC}"
    fi
    
    # 恢复原来的 server.cfg
    if [ -f "$TEMP_DIR/server.cfg.backup" ]; then
        echo -e "${GREEN}Restoring server.cfg...${NC}"
        cp "$TEMP_DIR/server.cfg.backup" "$L4D2_DIR/cfg/server.cfg"
    fi
    
    echo -e "${GREEN}Copying scripts folder...${NC}"
    if [ -d "$USER_REPO_DIR/scripts" ]; then
        mkdir -p "$L4D2_DIR/scripts"
        rsync -a "$USER_REPO_DIR/scripts/" "$L4D2_DIR/scripts/" || {
            echo -e "${RED}Failed to copy scripts folder${NC}"
        }
    else
        echo -e "${YELLOW}Note: scripts folder not found in repository, skipping${NC}"
    fi
    
    echo -e "${GREEN}Copying sound folder...${NC}"
    if [ -d "$USER_REPO_DIR/sound" ]; then
        mkdir -p "$L4D2_DIR/sound"
        rsync -a "$USER_REPO_DIR/sound/" "$L4D2_DIR/sound/" || {
            echo -e "${RED}Failed to copy sound folder${NC}"
        }
    else
        echo -e "${YELLOW}Note: sound folder not found in repository, skipping${NC}"
    fi
    
    for extra_folder in "materials" "models"; do
        if [ -d "$USER_REPO_DIR/$extra_folder" ]; then
            echo -e "${GREEN}Copying $extra_folder folder...${NC}"
            mkdir -p "$L4D2_DIR/$extra_folder"
            rsync -a "$USER_REPO_DIR/$extra_folder/" "$L4D2_DIR/$extra_folder/" || {
                echo -e "${RED}Failed to copy $extra_folder folder${NC}"
            }
        fi
    done
    
    echo -e "${GREEN}Copying configuration files...${NC}"
    for file in "hana_host.txt" "hana_motd.txt" "whitelist.cfg"; do
        if [ -f "$USER_REPO_DIR/$file" ]; then
            echo -e "${GREEN}Copying $file...${NC}"
            cp "$USER_REPO_DIR/$file" "$L4D2_DIR/" || {
                echo -e "${RED}Failed to copy $file${NC}"
            }
        fi
    done
    
    echo -e "${YELLOW}Setting permissions...${NC}"
    chmod -R 775 "$L4D2_DIR/"
    
    echo -e "${GREEN}Update complete for server: $server_path${NC}"
done

echo -e "${BLUE}==================Current Commit==================${NC}"
cd "$USER_REPO_DIR" || exit 1
git log -1
echo -e "${BLUE}==================Update Complete==================${NC}"
PLUGIN_UPDATE_EOF
    chmod +x "$SCRIPT_DIR/update_plugins.sh"
}

function create_game_update_script() {
    echo_lang "Creating update scripts..." "正在创建更新脚本..."
    
    cat << 'GAME_UPDATE_EOF' > "$SCRIPT_DIR/update_game.sh"
#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/server_config.sh"

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
NC='\e[0m'

echo -e "${BLUE}==================Game Update Time==================${NC}"
TZ=UTC-8 date
echo -e "${BLUE}==================Starting Update==================${NC}"

# 使用当前用户的home目录
USER_HOME="$HOME"
STEAMCMD_DIR="$USER_HOME/steamcmd"

if [ ! -d "$STEAMCMD_DIR" ]; then
    echo -e "${YELLOW}SteamCMD not found, installing...${NC}"
    mkdir -p "$STEAMCMD_DIR"
    cd "$STEAMCMD_DIR" || exit 1
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
fi

for server_path in "${SERVER_PATHS[@]}"; do
    if [ ! -d "$server_path" ]; then
        echo -e "${RED}Error: Server directory $server_path does not exist${NC}"
        echo -e "${RED}Skipping this server...${NC}"
        continue
    fi
    
    echo -e "${GREEN}Updating server: $server_path${NC}"
    cd "$STEAMCMD_DIR" || exit 1
    ./steamcmd.sh +login anonymous +force_install_dir "$server_path" +app_update 222860 validate +quit
done

echo -e "${BLUE}==================Update Complete==================${NC}"
GAME_UPDATE_EOF
    chmod +x "$SCRIPT_DIR/update_game.sh"
}

function create_server_config() {
    echo_lang "Creating server configuration..." "正在创建服务器配置..."
    
    echo_lang "Enter the hour (0-23) for daily restart:" "请输入每日重启的小时（0-23）:"
    read -r RESTART_HOUR
    
    if ! [[ "$RESTART_HOUR" =~ ^[0-9]+$ ]] || [ "$RESTART_HOUR" -lt 0 ] || [ "$RESTART_HOUR" -gt 23 ]; then
        echo_lang "Invalid hour, setting default to 4" "无效的小时数，设置默认值为4点"
        RESTART_HOUR=4
    fi
    
    if [ -z "$PLUGIN_REPO_URL" ] || [ -z "$REPO_NAME" ]; then
        PLUGIN_REPO_URL="https://github.com/cH1yoi/L4D2-Competitive-Rework.git"
        REPO_NAME="L4D2-Competitive-Rework"
    fi
    
    cat << EOF > "$SCRIPT_DIR/server_config.sh"
#!/bin/bash

# ==================================================================
# L4D2服务器配置文件 / L4D2 Server Configuration File
# ==================================================================
# 使用说明 / Instructions:
# 1. 修改服务器实例配置 / Modify server instance configuration
# 2. 保存文件后重启服务器 / Save and restart servers after modification
# 3. 使用 ./start_servers.sh 管理服务器 / Use ./start_servers.sh to manage servers
# ==================================================================

# 语言设置 / Language setting (en/zh)
LANGUAGE="${LANGUAGE}"

# 插件仓库信息 / Plugin repository information
PLUGIN_REPO_URL="${PLUGIN_REPO_URL}"
REPO_NAME="${REPO_NAME}"

# 服务器路径配置 / Server paths configuration
SERVER_PATHS=(
EOF

    for path in "${SERVER_PATHS[@]}"; do
        echo "    \"$path\"" >> "$SCRIPT_DIR/server_config.sh"
    done

    cat << 'EOF' >> "$SCRIPT_DIR/server_config.sh"
)

# ==================================================================
# 服务器实例配置 / Server Instance Configuration
# ==================================================================
# 格式说明 / Format description:
# ["端口"]="实例名称:服务器路径"
# ["port"]="instance_name:server_path"
# ==================================================================

declare -A SERVERS=(
    # 示例配置 / Example configurations:
    
    # 对抗服务器示例 / Versus server examples
    #["27015"]="versus1:/home/hana/versus"    # 对抗服务器1 / Versus server 1
    #["27016"]="coop1:/home/hana/coop"        # 对抗服务器2 / Versus server 2
    
    
    # 当前配置 / Current configuration
EOF

    local port=27015
    for path in "${SERVER_PATHS[@]}"; do
        local basename=$(basename "$path")
        echo "    [\"$port\"]=\"${basename}1:$path\"    # ${basename} 实例1" >> "$SCRIPT_DIR/server_config.sh"
        ((port++))
    done

    cat << EOF >> "$SCRIPT_DIR/server_config.sh"
)

# ==================================================================
# 启动参数配置 / Startup Parameters Configuration
# ==================================================================
# 可根据需要修改以下参数 / Modify these parameters as needed

# 基础启动参数 / Basic startup parameters
BASE_PARAMS="-game left4dead2 -sv_lan 0 +sv_clockcorrection_msecs 25 -timeout 10 -tickrate 100 -maxplayers 32 +sv_setmax 32 +map c2m1_highway +servercfgfile server.cfg"

# ==================================================================
# 自动重启配置 / Auto Restart Configuration
# ==================================================================
# 每日重启时间（24小时制）/ Daily restart time (24-hour format)
# 可以修改此值来更改重启时间（0-23）/ You can modify this value to change restart time (0-23)
# 例如：RESTART_HOUR=4  表示每天凌晨4点重启 / Example: RESTART_HOUR=4 means restart at 4 AM
# 修改后需要重新运行脚本以更新crontab / After modification, re-run the script to update crontab
RESTART_HOUR=${RESTART_HOUR}
EOF

    chmod +x "$SCRIPT_DIR/server_config.sh"

    echo_lang "Setting up automatic daily restart..." "正在设置每日自动重启..."
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/start_servers.sh restart"; echo "0 $RESTART_HOUR * * * $SCRIPT_DIR/start_servers.sh restart # L4D2_AUTO_RESTART_$(whoami)") | crontab -

    if [ "$LANGUAGE" == "zh" ]; then
        echo -e "${GREEN}配置文件已生成：$SCRIPT_DIR/server_config.sh${NC}"
        echo -e "${YELLOW}请编辑此文件来配置您的服务器实例${NC}"
        echo -e "${YELLOW}文件中包含了详细的配置示例和说明${NC}"
        echo -e "${YELLOW}如需修改重启时间，请修改 RESTART_HOUR 的值（0-23）${NC}"
        echo -e "${YELLOW}配置完成后使用 ./start_servers.sh 来管理服务器${NC}"
    else
        echo -e "${GREEN}Configuration file generated: $SCRIPT_DIR/server_config.sh${NC}"
        echo -e "${YELLOW}Please edit this file to configure your server instances${NC}"
        echo -e "${YELLOW}The file includes detailed examples and instructions${NC}"
        echo -e "${YELLOW}To change restart time, modify the RESTART_HOUR value (0-23)${NC}"
        echo -e "${YELLOW}After configuration, use ./start_servers.sh to manage servers${NC}"
    fi
}

function create_server_start_script() {
    echo_lang "Creating server start script..." "正在创建服务器启动脚本..."
    
    cat << 'SERVER_START_EOF' > "$SCRIPT_DIR/start_servers.sh"
#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/server_config.sh"

RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
NC='\e[0m'


function start_server() {
    local PORT=$1
    local NAME="$(echo "${SERVERS[$PORT]}" | cut -d: -f1)"
    local DIR=$(echo "${SERVERS[$PORT]}" | cut -d: -f2)
    
    if ! screen -ls | grep -q "$NAME"; then
        echo -e "${GREEN}Starting L4D2 $NAME on port $PORT${NC}"
        cd "$DIR" || exit 1
        screen -dmS "$NAME" ./srcds_run $BASE_PARAMS -port "$PORT"
    else
        echo -e "${YELLOW}$NAME is already running!${NC}"
    fi
}

function stop_server() {
    local NAME=$1
    if screen -ls | grep -q "$NAME"; then
        echo -e "${YELLOW}Stopping $NAME${NC}"
        screen -X -S "$NAME" quit
    else
        echo -e "${RED}$NAME is not running${NC}"
    fi
}

function restart_server() {
    local PORT=$1
    local NAME="$(echo "${SERVERS[$PORT]}" | cut -d: -f1)"
    stop_server "$NAME"
    sleep 2
    start_server "$PORT"
}

function show_status() {
    echo -e "${YELLOW}Server Status:${NC}"
    for PORT in "${!SERVERS[@]}"; do
        local NAME=$(echo "${SERVERS[$PORT]}" | cut -d: -f1)
        local DIR=$(echo "${SERVERS[$PORT]}" | cut -d: -f2)
        echo -e "\nServer: ${GREEN}$(basename "$DIR")${NC}"
        echo -e "Instance: ${YELLOW}$NAME${NC}"
        echo -e "Port: ${YELLOW}$PORT${NC}"
        if screen -ls | grep -q "$NAME"; then
            echo -e "Status: ${GREEN}RUNNING${NC}"
        else
            echo -e "Status: ${RED}STOPPED${NC}"
        fi
    done
}

function show_help() {
    if [ "$LANGUAGE" == "zh" ]; then
        echo "用法: $0 {命令} [端口]"
        echo
        echo "命令:"
        echo "  start [端口]     启动指定端口的服务器，不指定则启动所有"
        echo "  stop [端口]       停止指定端口的服务器，不指定则停止所有"
        echo "  restart [端口]    重启指定端口的服务器，不指定则重启所有"
        echo "  status          显示所有服务器状态"
        echo
        echo "当前配置的服务器:"
        for PORT in "${!SERVERS[@]}"; do
            local NAME=$(echo "${SERVERS[$PORT]}" | cut -d: -f1)
            local DIR=$(echo "${SERVERS[$PORT]}" | cut -d: -f2)
            echo "  端口: $PORT, 名称: $NAME, 目录: $DIR"
        done
    else
        echo "Usage: $0 {command} [port]"
        echo
        echo "Commands:"
        echo "  start [port]     Start server on specified port, or all if not specified"
        echo "  stop [port]      Stop server on specified port, or all if not specified"
        echo "  restart [port]   Restart server on specified port, or all if not specified"
        echo "  status          Show status of all servers"
        echo
        echo "Configured servers:"
        for PORT in "${!SERVERS[@]}"; do
            local NAME=$(echo "${SERVERS[$PORT]}" | cut -d: -f1)
            local DIR=$(echo "${SERVERS[$PORT]}" | cut -d: -f2)
            echo "  Port: $PORT, Name: $NAME, Dir: $DIR"
        done
    fi
}

case "$1" in
    start)
        if [ -n "$2" ]; then
            if [ -n "${SERVERS[$2]}" ]; then
                start_server "$2"
            else
                echo -e "${RED}Invalid port: $2${NC}"
                show_help
            fi
        else
            for PORT in "${!SERVERS[@]}"; do
                start_server "$PORT"
            done
        fi
        ;;
    stop)
        if [ -n "$2" ]; then
            if [ -n "${SERVERS[$2]}" ]; then
                stop_server "$(echo "${SERVERS[$2]}" | cut -d: -f1)"
            else
                echo -e "${RED}Invalid port: $2${NC}"
                show_help
            fi
        else
            for PORT in "${!SERVERS[@]}"; do
                stop_server "$(echo "${SERVERS[$PORT]}" | cut -d: -f1)"
            done
        fi
        ;;
    restart)
        if [ -n "$2" ]; then
            if [ -n "${SERVERS[$2]}" ]; then
                restart_server "$2"
            else
                echo -e "${RED}Invalid port: $2${NC}"
                show_help
            fi
        else
            for PORT in "${!SERVERS[@]}"; do
                restart_server "$PORT"
            done
        fi
        ;;
    status)
        show_status
        ;;
    *)
        show_help
        exit 1
        ;;
esac

exit 0
SERVER_START_EOF
    chmod +x "$SCRIPT_DIR/start_servers.sh"
}

function show_final_message() {
    echo_section "Installation Complete" "安装完成"
    
    if [ "$LANGUAGE" == "zh" ]; then
        echo -e "${GREEN}安装已完成！${NC}"
        echo -e "${YELLOW}请按照以下步骤操作：${NC}"
        echo "1. 编辑 server_config.sh 配置服务器实例"
        echo "2. 使用 start_servers.sh 管理服务器"
        echo -e "${YELLOW}以下辅助脚本已生成：${NC}"
        echo "- update_plugins.sh：更新服务器插件"
        echo "- update_game.sh：更新游戏文件"
    else
        echo -e "${GREEN}Installation completed!${NC}"
        echo -e "${YELLOW}Please follow these steps:${NC}"
        echo "1. Edit server_config.sh to configure server instances"
        echo "2. Use start_servers.sh to manage servers"
        echo -e "${YELLOW}The following utility scripts have been generated:${NC}"
        echo "- update_plugins.sh: Update server plugins"
        echo "- update_game.sh: Update game files"
    fi
}

check_root
setup_server
create_server_config
create_game_update_script
create_server_start_script
download_plugins
show_final_message