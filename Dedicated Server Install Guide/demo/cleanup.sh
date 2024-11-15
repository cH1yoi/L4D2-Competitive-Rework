#!/bin/bash

DEMO_DIR="/www/wwwroot/sad/demos"
LOG_FILE="/home/ubuntu/cleanup.log"
DAYS_TO_KEEP=7

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

total_size=0
total_files=0

log_message "开始清理任务..."
log_message "检查目录: $DEMO_DIR"

while IFS= read -r file; do
    size=$(stat -f %z "$file" 2>/dev/null || stat -c %s "$file" 2>/dev/null)
    size_mb=$(echo "scale=2; $size/1024/1024" | bc)
    
    log_message "删除文件: $file (${size_mb}MB)"
    
    rm "$file"
    
    total_size=$((total_size + size))
    total_files=$((total_files + 1))
done < <(find "$DEMO_DIR" -type f -name "*.zip" -mtime +$DAYS_TO_KEEP)

total_size_mb=$(echo "scale=2; $total_size/1024/1024" | bc)

log_message "清理完成:"
log_message "- 删除文件数: $total_files"
log_message "- 释放空间: ${total_size_mb}MB"
log_message "----------------------------------------"

find "$DEMO_DIR" -type d -empty -delete 2>/dev/null

