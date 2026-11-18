# Reencode 1.6.0 — Android arm64-v8a

## 中文

安装包：`Reencode-AndroidARM64-v8a.apk`  
应用名：`Reencode`  
最低系统：Android 7.0（API 24）  
包名：`com.teacers.reencode`  
版本：1.6.0，versionCode 7600（arm64-v8a）
SHA-256：`55ac29bd3d1bf0ca9cc98ac6f2c4387fa7c889587170fb99e01194431bcebe28`，文件大小 30,748,074 字节

1.6 是新基线。1.5 及更早的 Release、tag 和旧文档入口已清理。

- 设置页顶部显示处理器、核心数、总内存、MediaCodec 编码器和 AV1 能力；型号读不到显示“可用，但型号未知”并警告。
- H.264 / H.265 可尝试 MediaCodec 硬件编码，检测不到或失败时回退 CPU。AV1 只做 `libaom-av1` 软件编码；AV1 硬件解码作为实验项单独提供。
- 帧率正常范围是固定档 24 / 25 / 30 / 48 / 50 / 60，滑块只吸档，数字框只收 24–60；90 / 120 是下方独立实验档，144 需连点 120 四次并确认。
- 自定义分辨率支持精确宽×高，宽高必须为偶数，单边 16–7680；超出范围自动卡到上下限，奇数自动减 1，像素密度属于显示层，不写入视频。
- 视频可从系统相册或文件管理器添加。Android 13+ 走 Photo Picker，低版本回退一次性选择；选中文件复制到缓存，不持久化路径。音频只走文件管理器。
- 后台驻留可引导后台锁定和无限制电池，打开后申请 WakeLock；线程上限 1–8，内存上限为软限制，通过 FFmpeg 队列和缓冲生效。
- HDR10、HDR10+、杜比视界统一按“HDR 保留”说明；HDR10+ 和杜比视界只能流复制保留。
- 合并/分离入口支持在拆分或合并前改视频、音频格式和编码，合并页上下分别放视频和音频。
- 完成条会消失，结果卡延迟收成摘要，点击立即收起或展开。

已知边界：MediaCodec 硬件路径未在本轮真机上验证；不同机型可能拒绝 10-bit 或某些分辨率。内存上限不阻止系统杀进程，也不主动占用厂商虚拟内存。只处理第一条视频流和全部音频流，字幕、附件、多视频轨不复制。

## English

Installer: `Reencode-AndroidARM64-v8a.apk`  
App name: `Reencode`  
Minimum Android 7.0 (API 24)  
Package: `com.teacers.reencode`  
Version: 1.6.0, versionCode 7600 (arm64-v8a).
SHA-256: `55ac29bd3d1bf0ca9cc98ac6f2c4387fa7c889587170fb99e01194431bcebe28`; 30,748,074 bytes.

1.6 is the new baseline. Releases, tags and old documentation entry points from 1.5 and earlier were removed.

- Settings starts with processor, cores, total RAM, MediaCodec encoders and AV1 capability. An unreadable model is shown as "available, model unknown" with a warning.
- H.264 / H.265 can try MediaCodec hardware encoding and fall back to the CPU when no encoder is found or the job fails. AV1 is software-only through `libaom-av1`; AV1 hardware decode is a separate experimental option.
- Frame rate uses fixed stops 24 / 25 / 30 / 48 / 50 / 60; the slider snaps to them and the number field accepts 24–60 only. 90 / 120 are independent experimental chips; 144 needs four taps on 120 and a confirmation.
- Custom resolution writes exact width × height. Both sides must be even and within 16–7680; out-of-range values are clamped, odd values become even, and pixel density stays out of the video.
- Video can come from the system gallery or file manager. Android 13+ uses the Photo Picker, older versions use a one-shot picker; the selected file is copied into the cache without persisting the path. Audio uses the file manager only.
- Background mode guides through the system background lock and unrestricted battery, then requests a WakeLock. Thread cap is 1–8; the memory cap is a soft limit applied through FFmpeg queues and buffers.
- HDR10, HDR10+ and Dolby Vision are documented under "HDR preservation"; HDR10+ and Dolby Vision survive through stream copy only.
- Merge and split can change video and audio format and codec before running; merge puts video on top and audio below.
- The completion bar disappears; the result card collapses to a summary after a delay and expands or collapses immediately when tapped.

Known limits: the MediaCodec hardware path has not been verified on a physical phone in this round; a phone may reject 10-bit or certain resolutions. The memory cap does not stop Android from killing the process and does not request vendor virtual RAM. Only the first video stream and all audio streams are processed; subtitles, attachments and multiple video tracks are not copied.
