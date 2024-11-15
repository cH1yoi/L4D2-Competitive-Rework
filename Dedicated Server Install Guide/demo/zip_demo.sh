#!/bin/bash

DEMO_PATH="/home/hana/versus/left4dead2/demo"
TEMP_PATH="/home/hana/versus/left4dead2/demo_zips"
LOG_FILE="/home/hana/demo_compress.log"

mkdir -p $TEMP_PATH

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

find $DEMO_PATH -name "*.dem" -type f -print0 | while IFS= read -r -d '' file; do
    filename=$(basename "$file" .dem)
    if [ ! -f "$TEMP_PATH/${filename}.zip" ]; then
        zip -j "$TEMP_PATH/${filename}.zip" "$file"
        if [ $? -eq 0 ]; then
            rm "$file"
            log_message "Compressed: ${filename}.dem"
        else
            log_message "Failed to compress: ${filename}.dem"
        fi
    fi
done
