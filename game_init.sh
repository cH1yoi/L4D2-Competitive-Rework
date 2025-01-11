#!/bin/bash

clear

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

本脚本将帮助您：
1. 安装Left 4 Dead 2 服务端
2. 下载并安装插件
3. 创建方便管理的脚本
4. 自定义服务器的每日重启计划

Created by: HANA
==============================================
EOF

LANGUAGE="en"

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

echo_section "Installation Path" "安装路径"
echo_lang "Please enter the installation path (e.g., /home/hana/l4d2):" "请输入安装路径（例如 /home/hana/l4d2）:"
read INSTALL_PATH
export INSTALL_PATH=$(realpath "$INSTALL_PATH")

mkdir -p "$INSTALL_PATH"
echo_lang "Installation path set to: $INSTALL_PATH" "安装路径设置为: $INSTALL_PATH"

function setup_server() {
    echo_section "Server Installation" "服务端安装"
    
    mkdir -p ~/steamcmd
    cd ~/steamcmd

    echo_lang "Downloading SteamCMD..." "正在下载 SteamCMD..."
    wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
    tar -xvzf steamcmd_linux.tar.gz
    rm steamcmd_linux.tar.gz

    echo_lang "Creating installation script..." "正在创建安装脚本..."
    cat << STEAMCMD_EOF > ~/steamcmd/Left4Dead2_Server.txt
force_install_dir $INSTALL_PATH
login anonymous
@sSteamCmdForcePlatformType windows
app_update 222860 validate
@sSteamCmdForcePlatformType linux
app_update 222860 validate
quit
STEAMCMD_EOF

    echo_lang "Installing L4D2 Server..." "正在安装 L4D2 服务端..."
    ./steamcmd.sh +runscript ~/steamcmd/Left4Dead2_Server.txt

    echo_lang "Server installation completed!" "服务端安装完成！"
}

function download_plugins() {
    echo_section "Plugin Installation" "插件安装"
    
    echo_lang "Do you want to download plugins? (y/n)" "是否下载插件？(y/n)"
    read DOWNLOAD_PLUGINS

    if [ "$DOWNLOAD_PLUGINS" == "y" ]; then
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
                read PLUGIN_REPO_URL
                ;;
            *)
                echo_lang "Invalid choice, skipping plugin download." "无效选择，跳过插件下载。"
                return
                ;;
        esac

        REPO_NAME=$(basename "$PLUGIN_REPO_URL" .git)
        echo_lang "Downloading plugins..." "正在下载插件..."
        cd "$SCRIPT_DIR"
        git clone "$PLUGIN_REPO_URL" "$REPO_NAME"

        if [ -d "$REPO_NAME" ]; then
            mkdir -p "$INSTALL_PATH/left4dead2"
            chmod 777 -R "$INSTALL_PATH/left4dead2"
            
            cp -r "$REPO_NAME"/* "$INSTALL_PATH/left4dead2/"
            
            echo_lang "Plugins installed successfully." "插件安装成功。"

            create_plugin_update_script
            
            echo_lang "Plugin update script created successfully." "插件更新脚本创建成功。"
        else
            echo_lang "Failed to clone the repository, please check the repository URL and permissions." "克隆仓库失败，请检查仓库地址和权限。"
        fi
    fi
}

function create_plugin_update_script() {
    echo_lang "Creating update scripts..." "正在创建更新脚本..."
    
    cat << PLUGIN_UPDATE_EOF > "$SCRIPT_DIR/update_plugins.sh"
#!/bin/bash
echo "==================Plugin Update Time=================="
TZ=UTC-8 date
echo "==================Starting Update=================="

PLUGIN_REPO_URL="$PLUGIN_REPO_URL"
REPO_NAME=\$(basename "\$PLUGIN_REPO_URL" .git)

directories=("$INSTALL_PATH/left4dead2")

if [ ! -d "$INSTALL_PATH/\$REPO_NAME" ]; then
    echo "克隆仓库..."
    git clone "\$PLUGIN_REPO_URL" "$INSTALL_PATH/\$REPO_NAME"
else
    echo "更新仓库..."
    cd "$INSTALL_PATH/\$REPO_NAME" || { echo "无法进入目录"; exit 1; }
    git pull --rebase
fi

for dir in "\${directories[@]}"; do
    if [ -d "\$dir" ]; then
        echo "更新目录 | \$dir"
        
        echo "清理旧文件..."
        
        # 删除 sourcemod 特定目录
        rm -rf "\$dir/addons/sourcemod/bin"
        rm -rf "\$dir/addons/sourcemod/extensions"
        rm -rf "\$dir/addons/sourcemod/plugins"
        rm -rf "\$dir/addons/sourcemod/scripting"
        rm -rf "\$dir/addons/sourcemod/translations"
        
        # 删除 addons 下的文件和目录
        rm -rf "\$dir/addons/metamod"
        rm -rf "\$dir/addons/stripper"
        rm -f "\$dir/addons/l4dtoolz.dll"
        rm -f "\$dir/addons/l4dtoolz.so"
        rm -f "\$dir/addons/tickrate_enabler.dll"
        rm -f "\$dir/addons/tickrate_enabler.so"
        rm -f "\$dir/addons/tickrate_enabler.vdf"
        rm -f "\$dir/addons/l4dtoolz.vdf"
        rm -f "\$dir/addons/metamod.vdf"
        
        # 删除 cfg 目录下的所有指定内容
        rm -rf "\$dir/cfg/cfgogl"
        rm -rf "\$dir/cfg/mixmap"
        rm -rf "\$dir/cfg/sourcemod"
        rm -rf "\$dir/cfg/spcontrol_server"
        rm -rf "\$dir/cfg/stripper"
        
        cp -r "$INSTALL_PATH/\$REPO_NAME"/* "\$dir/"
        
        chmod -R 777 "\$dir/"
        
        echo "更新完成 | \$dir"
    else
        echo "不存在 | \$dir"
    fi
done

echo "==================当前commit=================="
cd "$INSTALL_PATH/\$REPO_NAME" || exit 1
git log -1
echo "================== 运行结束 =================="
PLUGIN_UPDATE_EOF
    chmod +x "$SCRIPT_DIR/update_plugins.sh"
}

function create_game_update_script() {
    echo_lang "Creating update scripts..." "正在创建更新脚本..."
    
    cat << GAME_UPDATE_EOF > "$SCRIPT_DIR/update_game.sh"
#!/bin/bash
echo "==================Game Update Time=================="
TZ=UTC-8 date
echo "==================Starting Update=================="

cd ~/steamcmd
./steamcmd.sh +runscript ~/steamcmd/Left4Dead2_Server.txt

echo "==================Update Complete=================="
GAME_UPDATE_EOF
    chmod +x "$SCRIPT_DIR/update_game.sh"
}

function create_server_start_script() {
    echo_lang "Creating server start script..." "正在创建服务器启动脚本..."
    
    cat << SERVER_START_EOF > "$SCRIPT_DIR/start_servers.sh"
#!/bin/bash

DIR="$INSTALL_PATH"
DAEMON="\$DIR/srcds_run"

# 本脚本支持一端多开,自行添加or减少
declare -A SERVERS=(
    ["20721"]="Server1"
    ["30721"]="Server2"
)

# 基础启动参数
BASE_PARAMS="-game left4dead2 -sv_lan 0 +sv_clockcorrection_msecs 25 -timeout 10 -tickrate 100 -maxplayers 32 +sv_setmax 32 +map c2m1_highway +servercfgfile server.cfg"

function start_server() {
    local PORT=\$1
    local NAME=\$2
    if ! screen -ls | grep -q "\$NAME"; then
        echo "Starting L4D2 \$NAME on port \$PORT"
        cd \$DIR
        screen -dmS \$NAME \$DAEMON \$BASE_PARAMS -port \$PORT
    else
        echo "\$NAME is already running!"
    fi
}

function stop_server() {
    local NAME=\$1
    if screen -ls | grep -q "\$NAME"; then
        echo "Stopping \$NAME"
        screen -X -S \$NAME quit
    else
        echo "\$NAME is not running"
    fi
}

function restart_server() {
    local PORT=\$1
    local NAME=\$2
    stop_server "\$NAME"
    sleep 2
    start_server "\$PORT" "\$NAME"
}

case "\$1" in
    start)
        for PORT in "\${!SERVERS[@]}"; do
            start_server "\$PORT" "\${SERVERS[\$PORT]}"
        done
        ;;
    stop)
        for NAME in "\${SERVERS[@]}"; do
            stop_server "\$NAME"
        done
        ;;
    restart)
        for PORT in "\${!SERVERS[@]}"; do
            restart_server "\$PORT" "\${SERVERS[\$PORT]}"
        done
        ;;
    status)
        echo "Server Status:"
        for NAME in "\${SERVERS[@]}"; do
            if screen -ls | grep -q "\$NAME"; then
                echo "\$NAME is RUNNING"
            else
                echo "\$NAME is STOPPED"
            fi
        done
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
SERVER_START_EOF
    chmod +x "$SCRIPT_DIR/start_servers.sh"

    echo_lang "Do you want to set up automatic daily restart? (y/n)" "是否设置每日自动重启？(y/n)"
    read AUTO_RESTART

    if [ "$AUTO_RESTART" == "y" ]; then
        echo_lang "Enter the hour (0-23) for daily restart:" "请输入每日重启的小时（0-23）:"
        read RESTART_HOUR
        
        if [[ "$RESTART_HOUR" =~ ^[0-9]+$ ]] && [ "$RESTART_HOUR" -ge 0 ] && [ "$RESTART_HOUR" -le 23 ]; then
            echo_lang "Setting up automatic restart..." "正在设置自动重启..."
            (crontab -l 2>/dev/null | grep -v "$SCRIPT_DIR/start_servers.sh restart"; echo "0 $RESTART_HOUR * * * $SCRIPT_DIR/start_servers.sh restart") | crontab -
            echo_lang "Automatic restart set to $RESTART_HOUR:00 daily." "自动重启设置为每天 $RESTART_HOUR:00。"
        else
            echo_lang "Invalid hour, automatic restart will not be set." "无效的小时数，自动重启未设置。"
        fi
    else
        echo_lang "Automatic restart will not be set." "未设置自动重启。"
    fi
}

setup_server
create_game_update_script
create_server_start_script
download_plugins

echo_section "Installation Complete" "安装完成"
echo_lang "All tasks completed successfully!" "所有任务已完成！"
echo_lang "You can now use the following scripts:" "您现在可以使用以下脚本："
echo -e "\e[1;33m- ./update_game.sh\e[0m    (Update game files / 更新游戏文件)"
if [ "$DOWNLOAD_PLUGINS" == "y" ]; then
    echo -e "\e[1;33m- ./update_plugins.sh\e[0m  (Update plugins / 更新插件)"
fi
echo -e "\e[1;33m- ./start_servers.sh\e[0m   (Manage servers / 管理服务器)"
echo

if [ "$AUTO_RESTART" == "y" ] && [ -n "$RESTART_HOUR" ]; then
    echo_lang "Server will automatically restart at $RESTART_HOUR:00 every day." "服务器将在每天 $RESTART_HOUR:00 自动重启。"
fi