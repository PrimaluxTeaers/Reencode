# Reencode / 视频转码

Reencode 是一个离线视频转码工具。它把码率、编码、容器、分辨率和音频放在同一张工作台上，适合批量处理手机里的视频。没有广告，没有统计，不联网，也不上传文件。

## 关于这个项目

Reencode / 视频转码 是免费开源的离线工具，任何人都可以免费使用、修改、分发和自行构建，只要遵守 GPL-3.0。也完全允许其他人基于它做同类软件或另起分支；比起复制一个成品，更希望这套代码能让人自己搭出能用的版本。项目由多个现成组件拼装而成，作者本人也是被“找不到能用的转码工具、专业软件又太贵”困住的人。测试设备有限，遇到 bug 请见谅，也欢迎提交问题。没有把 Reencode 和 Timbre 合并成一个大型项目的打算，两个都只是小工具；更新完全随缘，能走到 1.6 靠的是想把它们做完整一点的心。

Android 版只出 arm64-v8a，应用名显示为 **Reencode**，安装包文件名保留 `ARM64-v8a` 标识，包名 `com.teacers.reencode`。Windows 版随 1.6 一起构建，应用名为 **Reencode**，安装包命名为 `Reencode-WindowsX86-64`，只面向 Windows 10 / 11 x64；Windows 和 Android 共用仓库里同一套 Flutter 源码，Windows runner 由 GitHub Actions 的 x64 runner 生成并打包，和 Android APK 放在同一个 v1.6.0 发行版。

1.6 是当前基线。1.5 及更早的 Release、tag 和旧文档入口已经清理，旧版本不作为可用版本保留。

## 能做什么

- 容器：MP4、MKV、MOV、WebM。
- 视频编码：H.264、H.265 / HEVC、VP9、AV1、MPEG-4。
- 音频编码：AAC、Opus、MP3、原样复制。源文件有多条音轨时，转码会保留全部音轨；分离和合并只处理选中的那一条。
- 视频码率 1–100000 kbps。数字框精调，滑块只吸附固定档位（1 / 10 / 50 / 100 / 250 / 500 / 750 / 1000 / 1500 / 2000 / 3000 / 4000 / 6000 / 8000 / 10000 / 15000 / 20000 / 30000 / 50000 / 80000 / 100000），单位可在 kbps / Mbps 之间切换；低于 64 kbps 会标成实验性低码率。
- 分辨率：原始、4K（2160p）、2K（1440p）、1.5K（1220p，实验）、1080p、720p、480p，以及自定义宽×高。自定义直接写输出像素，宽高都要填、必须是偶数、单边 16–7680；超出范围自动卡到上下限，像素密度属于显示层，不写进视频。
- 位深：保留、8-bit、10-bit、12-bit。H.265 和 VP9 可保留 10-bit，H.265 额外开放 12-bit 实验项；H.264 和 MPEG-4 固定 8-bit。
- 帧率：跟随源或 CFR。正常范围是固定档 24 / 25 / 30 / 48 / 50 / 60，滑块只吸这些档，数字框只收 24–60；90 / 120 是下方独立实验档，点一下直接启用；144 需要连续点 120 四次并读完警告。CFR 只补重复帧或丢帧，不做插帧。
- 编码速度预设：快、均衡、慢、自定义。自定义可直接填 FFmpeg `-preset` 名。
- 编码详情：每个编码点一下先给用途，再进详情页看实现原理、标准组织、发明背景、典型用途和最大支持。

## 硬件加速

Android 的硬件编码走 MediaCodec。它调用 SoC 的专用视频单元，不是 GPU 着色器，也不是“纯 GPU 编码”。当前只对 H.264 / H.265 尝试 `h264_mediacodec` / `hevc_mediacodec`；设备没有可用编码器、参数被拒绝或任务失败时，任务回到 CPU，不把“自动”当成必然硬件加速。

AV1 只做软件编码，使用包内 `libaom-av1`。骁龙 8 Elite Gen 6 / Elite Extreme Gen 6 的官方规格只写 H.264、H.265 编码，解码包含 AV1；天玑 9600 Pro 只写 HEVC / AVC 编码，解码包含 AV1。两者都没有 AV1 硬件编码器，所以 UI 里没有 AV1 硬编开关。AV1 硬件解码作为实验项单独提供，探测不到就回退软件解码。

设置页顶部显示本机处理器、核心数、总内存、MediaCodec 编码器和 AV1 能力。读不到具体型号时显示“可用，但型号未知”并警告，不凭空命名芯片。GPU 信息放在下方展开栏；Android 的 GPU 相关路径全部按实验功能处理，不承诺所有机型一致。

## HDR 与音频

HDR10、HDR10+、杜比视界在界面和文档里统一叫 **HDR 保留**，再按具体类型说明能保留到什么程度。

- **HDR10 静态元数据**：H.265 重编码写入色彩标记、Mastering Display、MaxCLL / MaxFALL。AV1 只写色彩标记，不写 Mastering Display / MaxCLL。H.264、VP9、MPEG-4 不写这套。
- **HDR10+ 动态元数据**：只能“只换容器”原样保留。重编码注入需要 `hdr10plus_tool`，当前 APK 没有打包，检测到 HDR10+ 源会拦截重编码。
- **杜比视界**：只能流复制。重新编码会丢掉杜比视界层，预检会拦截。

开关打开不等于任何源都能保留。源里没有对应侧数据时，开关会灰掉并写明原因。

音频部分保留 AAC / MP4A、MP3、Opus、FLAC、WAV 这些常用格式，冷门格式不再放进主路径。改编码会重置上一组自定义参数；只调码率时保留当前自定义；改其他会改变编码语义的设置时，自定义按钮重新亮起并回到自定义，不沿用上一组参数。主页面会对这条规则做提示。

## 合并、分离、轻量音频

首页下方有独立入口，点进去是同一张编辑页，窄屏自动改上下排列。

- **分离**：把第一条视频流和选中的音频流拆成两个文件。视频和音频的格式、编码、码率都可以在分离前改；默认原样复制。
- **合并**：上面放视频文件，下面放音频文件。视频流可复制或改编码，音频可复制、改格式或改码率；可选择无损复制，或用码率 / 音量控制输出。容器按视频和音频编码选 MP4、MKV 或 WebM。
- **只要音频**：从视频或音频文件导出 M4A / AAC、MP3、Opus、FLAC、WAV，可调音频码率，视频流直接丢掉。

合并和分离共用同一套参数模型，改完可以退回重编，不把上一步输出锁死。

## Android 体验

- 转码在 Android 前台服务里跑，通知栏显示当前文件和进度。设置页打开“允许后台驻留”后，应用会申请 WakeLock，并按系统要求引导后台锁定和无限制电池；关掉后恢复普通前台限制。
- 后台驻留打开后可设线程上限 1–8 和内存软上限。线程 0 表示自动；1 线程会很慢，6–8 会抢前台资源，界面会警告。内存 0 表示不主动限制，暂定范围 512–4096 MB；这是应用侧软限制，只影响 FFmpeg 队列和缓冲，不阻止系统杀进程，也不主动占用厂商虚拟内存。
- 平板和折叠屏按可用宽度排版，内容最大宽度 840，底部操作栏不会被拉成横贯全屏的长条。
- 完成条会消失；结果卡过一会自动收成摘要，点一下立即收起或展开。
- 设置页可授权持久输出目录（Android SAF），重启后仍有效。授权后结果直接写进目标文件夹，结果卡只显示“已完成”。

## 文件选择

视频可以从文件管理器或系统相册添加。相册走 Android 13+ 的 Photo Picker；低版本回退到一次性内容选择。选中的 URI 只授权这一次，应用把它复制到缓存，不持久化路径，不形成路径依赖。音频只走文件管理器，不调用相册，也不申请全盘存储权限。

## 安装

到 [Releases](https://github.com/PrimaluxTeaers/Reencode/releases) 下载 `Reencode-AndroidARM64-v8a.apk`。最低 Android 7.0（API 24），没有上架应用商店。

只提供 arm64-v8a。armeabi-v7a、x86_64 和 32 位包都没有随包提供。APK 使用本项目自己的证书，和 Timbre 不共用，两个应用不能互相覆盖安装。

## 构建

需要 Flutter 3.50.0、Dart 3.14、JDK 17、Android SDK 36。

```bash
flutter pub get
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

FFmpegKit Flutter 包放在 `third_party/ffmpeg_kit_flutter_new`。这是上游 4.6.8 的副本，Dart 接口和原生代码没改，只改了 `android/build.gradle` 的 AGP 版本和仓库地址，让它在当前 Flutter / Gradle 组合里能构建。升级 Flutter、AGP 或 Gradle 前先检查这个文件。

Windows 构建由 `.github/workflows/windows-x64.yml` 在 `windows-latest` 上生成 `windows/` runner，并打包 `Reencode-WindowsX86-64-1.6.0.zip`；本地不交叉编译 Windows 产物。

## 许可

Reencode 按 **GPL-3.0** 分发。它使用 FFmpegKit Flutter 4.6.8 的 Full GPL 包，里面带 x264、x265、xvidcore、vid.stab 等 GPL 编码库，因此整体按 GPL-3.0 分发。

- 应用许可证全文：[LICENSE](LICENSE)
- 第三方组件、版本、许可证和链接：[THIRD_PARTY.md](THIRD_PARTY.md)
- 每个发行版附带源码包，内容就是构建该 APK 的代码。

## 隐私

Release APK 不申请 `INTERNET` 权限。没有广告 SDK，没有统计 SDK，不上传视频、文件名、设备标识或转换日志。文件只从你选择的路径读，只写到你选择的文件夹或应用缓存。Android 通知只在你主动开始转换后出现，内容只有当前文件名和进度。相册授权只用于本次选择，选中文件复制到缓存后不再保留路径授权。

## 已知边界

- 只处理第一条视频流和全部音频流。字幕、附件和多视频轨不复制。
- 章节和全局元数据在目标容器支持时会复制；复杂章节结构可能被 FFmpeg 简化。
- 10-bit / 12-bit 只表示像素位深，不等于 HDR。HDR10+ 动态元数据不注入，杜比视界不重编码，二者只能流复制保留。
- MediaCodec 硬件编码和硬件解码是实验路径。具体机型可能拒绝 10-bit、拒绝某些分辨率或直接失败，失败后回退 CPU。没有“纯 GPU 编码”或 GPU 滤镜。
- AV1 只有 `libaom-av1` 软件编码，速度很慢，1080p 比较现实，12-bit 会拦截；AV1 硬件解码取决于机型。H.266 / VVC 没有 `libvvenc`，不能编码，不进入稳定版。
- 插帧入口已删除，144fps 只补重复帧或丢帧；核心 APK 不含插帧算法，桌面端也不做插帧。
- 大文件在临时输出存在期间，大约需要相当于原文件两倍的剩余空间。
- 预检只拦明确不兼容的组合，最终能不能封装仍以 FFmpeg 的结果为准。

## 开发

```bash
flutter analyze lib test
flutter test
```

`lib/models.dart` 放媒体摘要、编码 / 容器枚举、配方和预检；`lib/command_builder.dart` 只生成 FFmpeg 参数；`lib/engine.dart` 负责 FFprobe、FFmpeg 执行、进度和取消；`lib/hardware_profile.dart` 放硬件能力读取；`lib/gallery_picker.dart` 放 Android 相册入口；`lib/media_tools.dart` 放合并、分离和轻量音频；`lib/bounded_number_field.dart` 管有上下限的整数输入，`lib/frame_rate_field.dart` 管帧率固定档和 144 解锁；`lib/codec_details.dart` 放编码详情文案。参数规则可以单独测试，不需要加载 native 库。Windows 与 Android 共用这些 `lib/` 文件；`windows/` runner 由 CI 用 `flutter create` 生成，不提交生成物。

---

# Reencode / Video Transcoder

Reencode is an offline video converter. Bitrate, codec, container, resolution and audio sit on one workbench, which makes batch work on a phone practical. There are no ads, no analytics, no network access and no uploads.

## About

Reencode / Video Transcoder is a free, open-source offline tool. Anyone may use, modify, redistribute and build it, provided the GPL-3.0 license is respected. Other people are free to make similar apps or fork this one; the point is not to ship one perfect binary, but to let people build their own working version. It is assembled from existing components, and the author is one of the people who could not find a usable transcoder and could not afford professional software. Testing has been limited to a small set of devices, so bugs are possible; reports are welcome. There is no plan to merge Reencode and Timbre into one large project. Both are small tools, updated irregularly; reaching 1.6 is simply the wish to make them a little more complete.

The Android build ships arm64-v8a only, shows **Reencode** as its name and uses `com.teacers.reencode`; only the installer filename keeps the `ARM64-v8a` tag. The Windows build uses the installer name `Reencode-WindowsX86-64` and targets Windows 10 / 11 x64 only. Windows and Android share the same Flutter source in this repository; the Windows runner is generated and packed on the `windows-latest` runner, then published in the same v1.6.0 release as the Android APK.

1.6 is the current baseline. Releases, tags and old documentation entry points from 1.5 and earlier were removed; older builds are not kept as usable versions.

## What it does

- Containers: MP4, MKV, MOV, WebM.
- Video codecs: H.264, H.265 / HEVC, VP9, AV1, MPEG-4.
- Audio codecs: AAC, Opus, MP3 and stream copy. Multiple source audio tracks are preserved when re-encoding; split and merge work on the selected track.
- Video bitrate from 1 to 100000 kbps. The exact field takes any whole value in range; the slider only snaps to fixed stops (1 / 10 / 50 / 100 / 250 / 500 / 750 / 1000 / 1500 / 2000 / 3000 / 4000 / 6000 / 8000 / 10000 / 15000 / 20000 / 30000 / 50000 / 80000 / 100000). A kbps / Mbps switch is available. Below 64 kbps is marked as experimental.
- Resolution: source, 4K (2160p), 2K (1440p), 1.5K (1220p, experimental), 1080p, 720p, 480p and a custom width × height. Custom writes exact pixels; both sides are required, odd values are rounded down to even, and out-of-range values are clamped to 16–7680 per side. Pixel density belongs to the display layer and is not written into the video.
- Bit depth: preserve, 8-bit, 10-bit, 12-bit. H.265 and VP9 can keep 10-bit; H.265 adds a 12-bit experimental option; H.264 and MPEG-4 stay at 8-bit.
- Frame rate: passthrough or CFR. The normal range uses fixed stops 24 / 25 / 30 / 48 / 50 / 60; the slider snaps to those stops and the number field accepts 24–60 only. 90 / 120 are independent experimental chips below the normal control and take effect on tap. 144 unlocks after four taps on 120 and the warning. CFR only drops or repeats frames; it does not interpolate.
- Encoder speed presets: fast, balanced, slow and custom. Custom accepts any FFmpeg `-preset` name.
- Codec details: tapping a codec gives a short use case first, then a detail page with implementation principle, standards body, origin, typical use and maximum support.

## Hardware acceleration

Android hardware encoding goes through MediaCodec, which uses the SoC's dedicated video unit rather than GPU shader cores; it is not "pure GPU encoding". Only H.264 / H.265 are attempted through `h264_mediacodec` / `hevc_mediacodec`. When the phone has no usable encoder, rejects the parameters or fails the job, the job returns to the CPU. "Auto" is not a guarantee of hardware acceleration.

AV1 is software-only through the bundled `libaom-av1`. The official Snapdragon 8 Elite Gen 6 / Elite Extreme Gen 6 specification lists H.264 and H.265 encoding with AV1 decode; the Dimensity 9600 Pro lists HEVC / AVC encoding with AV1 decode. Neither has an AV1 hardware encoder, so the UI has no AV1 hardware-encode switch. AV1 hardware decode is a separate experimental option and falls back to software when it is unavailable.

The top of Settings shows the processor, core count, total RAM, MediaCodec encoders and AV1 capability. If the exact model cannot be read, the app says "available, model unknown" and warns instead of inventing a chip name. GPU information sits in a collapsed section; Android GPU-related paths are experimental and are not promised to behave the same on every phone.

## HDR and audio

HDR10, HDR10+ and Dolby Vision are grouped as **HDR preservation** in the UI and docs, then explained by type.

- **HDR10 static metadata**: H.265 re-encoding writes colour tags, Mastering Display and MaxCLL / MaxFALL. AV1 writes colour tags only, without Mastering Display / MaxCLL. H.264, VP9 and MPEG-4 do not write this set.
- **HDR10+ dynamic metadata**: only remux preserves it. Injecting it after re-encoding needs `hdr10plus_tool`, which is not bundled, so an HDR10+ source blocks re-encoding.
- **Dolby Vision**: stream copy only. Re-encoding drops the Dolby Vision layer, so preflight blocks it.

A switch being on does not mean every source can keep that metadata. When the source has no matching side data, the switch is disabled and the reason is shown.

Common audio formats stay on the main path: AAC / MP4A, MP3, Opus, FLAC and WAV; rare formats are removed from the main path. Changing the codec resets the previous custom parameter set; changing only the bitrate keeps the current custom setting; changing another setting that alters codec semantics lights the custom control again and returns to custom without reusing the old set. The home screen states this rule.

## Merge, split and lightweight audio

A separate entry below the home screen opens one editor; narrow screens stack the columns.

- **Split**: pull the first video stream and the selected audio stream into two files. Video and audio format, codec and bitrate can be changed before splitting; the default is stream copy.
- **Merge**: a video file on top and an audio file below. Video can be copied or re-encoded; audio can be copied, re-formatted or re-encoded with a bitrate / volume choice. Lossless copy is available. The container follows the video and audio codecs: MP4, MKV or WebM.
- **Audio only**: export M4A / AAC, MP3, Opus, FLAC or WAV from a video or audio file with an adjustable audio bitrate; the video stream is discarded.

Merge and split share one parameter model, so you can go back and adjust without locking the previous output.

## Android behaviour

- Conversion runs in an Android foreground service; the notification shows the current file and progress. When "Keep working in background" is enabled in Settings, the app requests a WakeLock and guides you through the system background lock and unrestricted battery setting. Turning it off returns the app to normal foreground limits.
- With background mode on, the thread cap is 1–8 and the memory budget is a soft cap. Thread 0 is automatic; one thread is very slow, and 6–8 can starve the foreground, so the UI warns. Memory 0 means no app-side limit, with a provisional range of 512–4096 MB. This is an app-side soft limit that affects FFmpeg queues and buffers; it does not stop Android from killing the process and does not request vendor virtual RAM.
- Tablets and foldables lay out by available width. Content is capped at 840 logical pixels, and the bottom action bar is not stretched across the whole screen.
- The completion bar disappears; the result card collapses to a summary after a delay and expands or collapses immediately when tapped.
- Settings can grant a persistent output folder through Android's Storage Access Framework. The grant survives a restart, and results are written there directly with a "Done" card.

## File picking

A video can come from the file manager or the system gallery. The gallery uses the Android 13+ Photo Picker, with a one-shot content picker fallback on older versions. The selected URI is granted for this pick only; the app copies it into its cache without persisting the path, so there is no path dependency. Audio uses the file manager only, never the gallery, and the app does not request broad storage permission.

## Install

Download `Reencode-AndroidARM64-v8a.apk` from [Releases](https://github.com/PrimaluxTeaers/Reencode/releases). Minimum Android 7.0 (API 24). Not on any app store.

Only arm64-v8a is shipped. armeabi-v7a, x86_64 and 32-bit packages are not included. The APK uses this project's own signing key, not Timbre's; the two apps cannot overwrite each other.

## Build

Flutter 3.50.0, Dart 3.14, JDK 17 and Android SDK 36 are required.

```bash
flutter pub get
flutter test
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

The FFmpegKit Flutter package lives in `third_party/ffmpeg_kit_flutter_new`. It is a copy of upstream 4.6.8 with no changes to the Dart API or native code. Only `android/build.gradle` was changed: the AGP version and repository list, so it builds with the current Flutter / Gradle combination. Check that file before upgrading Flutter, AGP or Gradle.

The Windows build runs `.github/workflows/windows-x64.yml` on `windows-latest`, generating the `windows/` runner from the same repository and packing `Reencode-WindowsX86-64-1.6.0.zip`. There is no closed-source desktop module; FFmpeg binaries are fetched at build time so the repository stays text-only.

## License

Reencode is distributed under **GPL-3.0**. It uses the Full GPL build of FFmpegKit Flutter 4.6.8, which bundles x264, x265, xvidcore and vid.stab. Those are GPL codec libraries, so the combined application is distributed under GPL-3.0.

- Full application license: [LICENSE](LICENSE)
- Third-party components, versions, licenses and links: [THIRD_PARTY.md](THIRD_PARTY.md)
- Every release includes a source archive containing the code used to build that APK.

## Privacy

The release APK does not request the `INTERNET` permission. There is no ad SDK, no analytics SDK, and no upload of videos, filenames, device identifiers or conversion logs. Files are read from the path you pick and written to the folder you pick or to the app cache. The Android notification appears only after you start a conversion and contains only the current filename and progress. Gallery access is granted for that pick only; after the selected file is copied into the cache, the path grant is not retained.

## Known limits

- Only the first video stream and all audio streams are processed. Subtitles, attachments and multiple video tracks are not copied.
- Chapters and global metadata are copied when the target container supports them. Complex chapter layouts may be simplified by FFmpeg.
- 10-bit / 12-bit means pixel depth, not HDR. HDR10+ dynamic metadata is not injected, and Dolby Vision is not re-encoded; both survive only through stream copy.
- MediaCodec hardware encoding and hardware decoding are experimental. A phone may reject 10-bit, reject a resolution or fail outright, in which case the job returns to the CPU. There is no "pure GPU encoding" and no GPU filter path.
- AV1 is a real `libaom-av1` software encoder, with MP4, MKV and WebM output. It is very slow; 1080p is the practical target and 12-bit is blocked. AV1 hardware decode depends on the phone. H.266 / VVC has no `libvvenc`, cannot encode and stays out of the stable release.
- The frame-interpolation entry has been removed. 144 fps only duplicates or drops frames; neither the APK nor the desktop build interpolates.
- Large files need roughly twice their size in free space while the temporary output exists.
- Preflight catches clearly incompatible combinations. Whether the final mux succeeds is still decided by FFmpeg.
- Hardware capability detection is best-effort. A missing or wrong model name is shown as unknown and never silently replaced with a guessed chip.

## Development

```bash
flutter analyze lib test
flutter test
```

`lib/models.dart` holds media summaries, codec / container enums, recipes and preflight checks; `lib/command_builder.dart` only builds FFmpeg arguments; `lib/engine.dart` handles FFprobe, FFmpeg execution, progress and cancellation; `lib/hardware_profile.dart` holds hardware capability reads; `lib/gallery_picker.dart` holds the Android gallery entry; `lib/media_tools.dart` holds merge, split and lightweight audio; `lib/bounded_number_field.dart` owns bounded integer input and `lib/frame_rate_field.dart` owns the fixed frame-rate stops and 144 unlock; `lib/codec_details.dart` holds the codec detail copy. Windows and Android share these `lib/` files; the `windows/` runner is generated by `flutter create` in CI and is not committed as a generated tree.
