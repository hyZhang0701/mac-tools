#!/bin/bash
# 用法: ./adb_push.sh <文件或目录> [手机目标目录]
# 默认传到 /sdcard/DCIM/，传完自动写入 MediaStore（抖音/小红书可见）

set -e

VERSION="1.1.1"

cmd_help() {
    cat <<EOF
用法: adb_push <文件或目录> [目标目录]
      adb_push --check
      adb_push --help

参数:
  <文件或目录>    要传输的文件或目录（目录会批量传输所有媒体文件）
  [目标目录]      手机上的目标路径，默认 /sdcard/DCIM

选项:
  --check         检查运行环境（adb、ffprobe、设备连接）
  -v, --version   显示版本号
  --help, -h      显示此帮助

示例:
  adb_push ~/Downloads/video.mp4
  adb_push ~/Documents/videos/my_folder
  adb_push ~/Downloads/photo.jpg /sdcard/Pictures

支持格式: mp4 / mov / mkv / avi / wmv / 3gp / jpg / jpeg / png / gif / bmp / webp / heic
EOF
}

cmd_check() {
    echo "=== 环境检查 ==="
    echo ""

    # adb
    if command -v adb &>/dev/null; then
        echo "✓ adb      $(adb --version | head -1)"
    else
        echo "✗ adb      未安装 → brew install android-platform-tools"
    fi

    # ffprobe
    if command -v ffprobe &>/dev/null; then
        echo "✓ ffprobe  $(ffprobe -version 2>&1 | head -1)"
    else
        echo "✗ ffprobe  未安装（视频元数据缺失，抖音可能无法显示）→ brew install ffmpeg"
    fi

    # 设备连接
    echo ""
    DEVICES=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device$" | wc -l | tr -d ' ')
    if [ "$DEVICES" -gt 0 ]; then
        echo "✓ Android 设备已连接（共 ${DEVICES} 台）"
        adb devices | grep "device$" | awk '{print "    " $1}'
    else
        echo "✗ 未检测到 Android 设备"
        echo "  请确认："
        echo "    1. USB 线已连接"
        echo "    2. 手机已开启「USB 调试」（开发者选项）"
        echo "    3. 手机上已点击「允许 USB 调试」弹窗"
    fi
    echo ""
}

INPUT="$1"
DEST_DIR="${2:-/sdcard/DCIM}"

case "$INPUT" in
    --help|-h)
        cmd_help; exit 0 ;;
    --check)
        cmd_check; exit 0 ;;
    -v|--version)
        echo "adb_push v$VERSION"; exit 0 ;;
esac

if [ -z "$INPUT" ]; then
    cmd_help; exit 1
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
        local NOW_S=$(date +%s)
        local NOW_MS=$((NOW_S * 1000))
        local EXTRA_BINDS="--bind \"date_added:i:$NOW_S\" --bind \"date_taken:l:$NOW_MS\""

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
