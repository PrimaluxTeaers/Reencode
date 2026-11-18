# Changes

## 1.6.0 — 2026-11-17

### 中文

1.6 是新基线。1.5 及更早的 Release、tag 和旧文档入口已清理，仓库只保留 1.6 叙事。

- 版本号升到 1.6.0，versionCode 7600（arm64-v8a）；应用名显示为 `Reencode`，安装包文件名保留 `ARM64-v8a` 标识。
- 设置页顶部新增本机硬件面板：处理器、核心数、总内存、MediaCodec 编码器、AV1 解码/编码能力；型号读不到时显示“可用，但型号未知”并警告。
- GPU 信息放进下方展开栏；Android 的 GPU 相关路径按实验功能处理，不宣称纯 GPU 编码。
- 新增 MediaCodec 硬件编码路径：H.264 用 `h264_mediacodec`，H.265 用 `hevc_mediacodec`。检测不到编码器、参数被拒绝或任务失败时回退 CPU。
- AV1 只做软件编码 `libaom-av1`。骁龙 8 Elite Gen 6 / Elite Extreme Gen 6 与天玑 9600 Pro 官方都没有 AV1 硬件编码器，UI 明确写“AV1 可硬解、编码走软件”。
- 新增实验性硬件解码开关，走 MediaCodec；探测不到对应解码能力时回退软件。
- 分辨率新增自定义宽×高：宽高都要填、必须是偶数、单边 16–7680；超出范围自动卡到上下限，奇数自动减 1，像素密度不写进视频。
- 帧率改成固定档 24 / 25 / 30 / 48 / 50 / 60，滑块只吸档，数字框只收 24–60；90 / 120 是独立实验档，144 仍需连点 120 四次并确认。默认帧率设置页使用同一套控件。
- 后台驻留新增引导：后台锁定、无限制电池、回来确认；打开后申请 WakeLock。线程上限 1–8，1 线程和 6–8 线程有警告。
- 内存上限按软限制落地：0 表示不主动限制，暂定 512–4096 MB，通过 FFmpeg muxing 队列和缓冲生效，不阻止系统杀进程。
- 视频可以从系统相册或文件管理器添加。Android 13+ 走 Photo Picker，低版本回退一次性选择；选中文件复制到缓存，不持久化路径。音频只走文件管理器。
- 分离支持在拆分前改视频和音频格式/编码/码率；合并页上下分别放视频和音频，可复制或重编码，支持无损复制和码率/音量选择。
- HDR10、HDR10+、杜比视界统一归入“HDR 保留”说明；音频多轨在转码时保留，常用格式保留 AAC / MP4A、MP3、Opus、FLAC、WAV。
- 完成条会消失，结果卡延迟收成摘要，点击立即收起或展开。
- 应用图标换成新版的深青底、薄荷青双向箭头与胶片框；桌面、启动器和自适应前景使用同一张原图。
- 官方平台范围收窄到 Android：Windows 构建认真尝试过，受限于设备和验证条件，最终放弃；不再发布 Windows 包，仓库保留共享逻辑供他人自行适配。
- 测试增加到 30 项，覆盖自定义分辨率、奇数尺寸拒绝、硬件不可用回退和内存队列；arm64 APK 30,526,214 字节，SHA-256 `6a4c9af8b3507e25f2f1e03a0f86085404188098e2ab544d27ef11a56a643d66`。

### English

1.6 is the new baseline. Releases, tags and old documentation entry points from 1.5 and earlier were removed; the repository keeps the 1.6 narrative only.

- 版本是 1.6.0；arm64-v8a 的 versionCode 是 7600。应用名显示为 `Reencode`，只有安装包文件名保留 `ARM64-v8a`。
- Settings now starts with a device panel: processor, cores, total RAM, MediaCodec encoders and AV1 decode/encode capability. An unreadable model is shown as "available, model unknown" with a warning.
- GPU information sits in a collapsed section below. Android GPU-related paths are experimental; the app does not claim pure GPU encoding.
- Added MediaCodec encoding: `h264_mediacodec` for H.264 and `hevc_mediacodec` for H.265. When no encoder is found, parameters are rejected or the job fails, the job returns to the CPU.
- AV1 is software-only through `libaom-av1`. The official Snapdragon 8 Elite Gen 6 / Elite Extreme Gen 6 and Dimensity 9600 Pro specifications have no AV1 hardware encoder, so the UI states "AV1 hardware decode, software encode".
- Added an experimental hardware-decode switch through MediaCodec; when the matching decoder is unavailable, it falls back to software.
- Added custom width × height: both sides required, even, 16–7680 per side. Out-of-range values are clamped, odd values become even, and pixel density is not written into the video.
- Frame rate now uses fixed stops 24 / 25 / 30 / 48 / 50 / 60; the slider snaps to them and the number field accepts 24–60 only. 90 / 120 are independent experimental chips; 144 still needs four taps on 120 and a confirmation. The default-frame-rate setting uses the same control.
- Background mode now guides through the system background lock and unrestricted battery, then asks you to confirm; WakeLock is requested only while enabled. Thread cap is 1–8, with warnings at one thread and at 6–8.
- The memory budget is a soft cap: 0 means no app-side limit, with a provisional 512–4096 MB range applied through FFmpeg muxing queues and buffers. It does not stop Android from killing the process.
- Video can come from the system gallery or the file manager. Android 13+ uses the Photo Picker, older versions use a one-shot picker; the selected file is copied into the cache without persisting the path. Audio uses the file manager only.
- Split can change video and audio format, codec and bitrate before splitting. Merge puts video on top and audio below, supports copy or re-encode, lossless copy and bitrate / volume control.
- HDR10, HDR10+ and Dolby Vision are grouped under "HDR preservation". Multiple audio tracks are preserved when re-encoding; common formats keep AAC / MP4A, MP3, Opus, FLAC and WAV.
- The completion bar disappears; the result card collapses to a summary after a delay and expands or collapses immediately when tapped.
- The launcher icon now uses the new deep-teal artwork with mint bidirectional arrows and a film frame; desktop, launcher and adaptive foreground share the same source.
- Official platform support is Android only. The Windows build was attempted in earnest and dropped because the devices and verification conditions were not available; no Windows package is published, and the shared logic stays in the repository for others to adapt.
- Tests grew to 30, covering custom size, odd-size rejection, hardware fallback and the memory queue. The arm64 APK is 30,526,214 bytes, SHA-256 `6a4c9af8b3507e25f2f1e03a0f86085404188098e2ab544d27ef11a56a643d66`.
