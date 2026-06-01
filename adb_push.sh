#!/bin/bash
# 用法: ./adb_push.sh <文件或目录> [手机目标目录]
# 默认传到 /sdcard/DCIM/，传完自动写入 MediaStore（抖音/小红书可见）

set -e

INPUT="$1"
DEST_DIR="${2:-/sdcard/DCIM}"

if [ -z "$INPUT" ]; then
    echo "用法: $0 <文件或目录> [目标目录]"
    echo "示例: $0 ~/Downloads/video.mp4"
    echo "示例: $0 ~/Documents/yt2xhs/output/videos/mAXgx9E1c0I"
    exit 1
fi

if [ ! -e "$INPUT" ]; then
    echo "错误: 路径不存在: $INPUT"
    exit 1
fi

# 检查设备连接
DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)
if [ "$DEVICES" -eq 0 ]; then
    echo "错误: 未检测到 Android 设备"
    echo "请确认："
    echo "  1. USB 线已连接"
    echo "  2. 手机已开启「USB 调试」（开发者选项）"
    echo "  3. 手机上已点击「允许 USB 调试」弹窗"
    exit 1
fi

push_file() {
    local FILE="$1"
    local FILENAME=$(basename "$FILE")
    local DEST_PATH="$DEST_DIR/$FILENAME"

    local EXT="${FILENAME##*.}"
    local EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

    local MIME MEDIA_URI
    case "$EXT_LOWER" in
        jpg|jpeg)
            MIME="image/jpeg"
            MEDIA_URI="content://media/external/images/media"
            ;;
        png|gif|bmp|webp|heic)
            MIME="image/$EXT_LOWER"
            MEDIA_URI="content://media/external/images/media"
            ;;
        mp4|mkv|avi|mov|wmv|3gp)
            MIME="video/mp4"
            MEDIA_URI="content://media/external/video/media"
            ;;
        *)
            MIME=""
            MEDIA_URI=""
            ;;
    esac

    echo "▶ 传输: $FILENAME"
    adb push "$FILE" "$DEST_PATH"

    if [ -n "$MEDIA_URI" ]; then
        local EXTRA_BINDS=""

        if [[ "$MIME" == video/* ]] && command -v ffprobe &>/dev/null; then
            local DURATION_S=$(ffprobe -v quiet -show_entries format=duration \
                -of csv=p=0 "$FILE" 2>/dev/null)
            local DURATION_MS=$(echo "$DURATION_S * 1000 / 1" | bc 2>/dev/null || echo "0")
            local WIDTH=$(ffprobe -v quiet -show_entries stream=width \
                -of csv=p=0 "$FILE" 2>/dev/null | head -1)
            local HEIGHT=$(ffprobe -v quiet -show_entries stream=height \
                -of csv=p=0 "$FILE" 2>/dev/null | head -1)
            [ -n "$DURATION_MS" ] && EXTRA_BINDS="$EXTRA_BINDS --bind \"duration:i:$DURATION_MS\""
            [ -n "$WIDTH" ]       && EXTRA_BINDS="$EXTRA_BINDS --bind \"width:i:$WIDTH\""
            [ -n "$HEIGHT" ]      && EXTRA_BINDS="$EXTRA_BINDS --bind \"height:i:$HEIGHT\""
        fi

        eval adb shell content insert --uri "$MEDIA_URI" \
            --bind "_data:s:$DEST_PATH" \
            --bind "_display_name:s:$FILENAME" \
            --bind "mime_type:s:$MIME" \
            $EXTRA_BINDS 2>/dev/null || \
        adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
            -d "file://$DEST_PATH" 2>/dev/null || true

        echo "  ✓ 已写入相册"
    else
        echo "  ✓ 传输完成"
    fi
}

if [ -f "$INPUT" ]; then
    push_file "$INPUT"
elif [ -d "$INPUT" ]; then
    FILES=$(find "$INPUT" -maxdepth 1 -type f \
        \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \
           -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
           -o -iname "*.heic" -o -iname "*.webp" \) | sort)

    COUNT=$(echo "$FILES" | grep -c . || true)
    echo "找到 $COUNT 个文件，开始传输..."
    echo ""

    while IFS= read -r FILE; do
        [ -z "$FILE" ] && continue
        push_file "$FILE"
        echo ""
    done <<< "$FILES"

    echo "全部完成！共传输 $COUNT 个文件。"
fi
