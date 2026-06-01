# mac-tools

Mac 实用脚本集合。

---

## adb_push.sh

通过 USB 有线将文件从 Mac 传输到 Android 手机，传完自动写入媒体库，抖音、小红书等 App 可直接看到。

### 环境准备

**Mac 端**

```bash
brew install android-platform-tools ffmpeg exiftool
```

**手机端（一次性设置）**

1. 进入「设置 → 关于手机」，连续点击「版本号」7 次，开启开发者模式
2. 「设置 → 开发者选项」→ 开启「USB 调试」
3. 用 USB 线连接 Mac，手机上弹出「允许 USB 调试」→ 点允许

### 安装脚本

```bash
curl -o /usr/local/bin/adb_push https://raw.githubusercontent.com/hyZhang0701/mac-tools/main/adb_push.sh
chmod +x /usr/local/bin/adb_push
```

安装后可在任意位置直接使用 `adb_push` 命令。

### 使用方法

**检查环境是否就绪**

```bash
adb_push --check
```

**传单个文件**

```bash
adb_push ~/Downloads/video.mp4
```

**传整个目录（支持批量）**

```bash
adb_push ~/Documents/videos/my_video_folder
```

**查看帮助**

```bash
adb_push --help
```

支持的文件格式：`mp4 / mov / mkv / avi / wmv / 3gp / jpg / jpeg / png / gif / bmp / webp / heic`

默认传到手机的 `/sdcard/DCIM/` 目录，也可以指定目标路径：

```bash
adb_push ~/Downloads/photo.jpg /sdcard/Pictures
```

### 说明

- 视频文件会自动读取时长、分辨率并写入 MediaStore，确保抖音等 App 能正常显示
- 图片文件直接写入 MediaStore，相册立即可见
- 依赖 `ffprobe`（随 ffmpeg 安装）提取视频元数据，确保抖音等 App 可见
- 依赖 `exiftool` 为图片写入当前时间的 EXIF，确保相册时间轴位置正确（鸿蒙 4.x）
