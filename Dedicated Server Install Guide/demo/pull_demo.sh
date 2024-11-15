#!/bin/bash

# 压缩后的demo路径
SERVERS=(
    "user@ip:port:/home/hana/versus/left4dead2/demo_zips"
    "user@ip:port:/home/hana/versus/left4dead2/demo_zips"
    "user@ip:port:/home/hana/versus/left4dead2/demo_zips"
)
LOCAL_PATH="/www/wwwroot/demo.hanacloud.site/demos"
LOG_FILE="/home/ubuntu/demo_pull.log"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

mkdir -p "$LOCAL_PATH"

for server in "${SERVERS[@]}"; do
    IFS=':' read -r user_host port remote_path <<< "$server"
    
    log_message "Starting pull from $user_host"
    
    file_count=$(ssh -p $port $user_host "ls -1 $remote_path/*.zip 2>/dev/null | wc -l")
    
    if [ "$file_count" -gt 0 ]; then
        temp_dir=$(mktemp -d)
        
        scp -P $port "$user_host:$remote_path/*.zip" "$temp_dir/" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            mv "$temp_dir"/*.zip "$LOCAL_PATH/"
            
            ssh -p $port $user_host "rm -f $remote_path/*.zip"
            
            log_message "Successfully pulled files from $user_host"
        else
            log_message "Failed to pull files from $user_host"
        fi
        
        rm -rf "$temp_dir"
    else
        log_message "No files to pull from $user_host"
    fi
done

if [ -d "$LOCAL_PATH" ]; then
    find "$LOCAL_PATH" -name "*.zip" -type f | while read file; do
        date_str=$(echo "$file" | grep -o '[0-9]\{8\}')
        if [ ! -z "$date_str" ]; then
            year=${date_str:0:4}
            month=${date_str:4:2}
            target_dir="$LOCAL_PATH/$year/$month"
            mkdir -p "$target_dir"
            mv "$file" "$target_dir/"
        fi
    done
fi
