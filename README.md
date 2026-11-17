# Reencode

Android 视频转码工具。离线运行，没有广告，没有统计，也不上传文件。主页把码率、编码、容器和音频放在同一张工作台上，适合批量处理手机里的视频。

Android 版只提供 arm64-v8a，应用名显示为 **Reencode 64 位**。Windows 版另行构建，名称为 **Reencode x86-64**，只支持 Windows 10 / 11 x64。

## 功能

- 容器：MP4、MKV、MOV、WebM。
- 视频编码：H.264、H.265 / HEVC、VP9、AV1、MPEG-4。AV1 和 MPEG-4 都直接列在首页，不藏在二级菜单。
- 音频：AAC、Opus、MP3、原样复制。
- 视频码率 1–100000 kbps，最高等效 100 Mbps。数字框精调，滑块粗调，点单位在 kbps / Mbps 之间切换；低于 64 kbps 会标成实验性低码率。
- 分辨率：原始、4K（2160p）、2K（1440p）、1.5K（1220p，实验）、1080p、720p、480p。只改输出尺寸，不会把原片没有的细节补回来。
- 位深：保留、8-bit、10-bit、12-bit。H.265 / VP9 可保留 10-bit，H.265 额外开放 12-bit 实验项；H.264 和 MPEG-4 固定 8-bit。
- 帧率：跟随源或 CFR。24–60 连续可调；90 / 120 要在设置页打开实验功能；144 需要连续点 120 四次并读完警告。CFR 只丢帧或补重复帧，不做插帧。
- 编码速度预设：快、均衡、慢、自定义。自定义可以直接填 FFmpeg 的 `-preset` 名，例如 `veryslow`。
- 编码详情：每个编码点一下先给一句用途，再进详情页看实现原理、标准组织、发明背景、典型用途和最大支持。
- 更多设置：HDR、元数据、章节、faststart 都是单独开关，不再写死在命令里。

## HDR

源文件带 HDR 时，更多设置里会出现对应开关。

- **HDR10 静态元数据**：H.265 重编码时写入色彩标记、Mastering Display 和 MaxCLL / MaxFALL。AV1 只写色彩标记，不写 Mastering Display / MaxCLL。H.264、VP9、MPEG-4 不写这套。
- **HDR10+ 动态元数据**：这一版只能“只换容器”原样保留。重编码后注入 HDR10+ 需要 `hdr10plus_tool`，当前 APK 没有打包，检测到 HDR10+ 源时会拦住重编码。
- **杜比视界**：只能“只换容器”流复制。重新编码会丢掉杜比视界层，所以同样在预检阶段拦截。

开关打开不等于任何源都能保留。源里没有对应侧数据时，开关会灰掉，并写明原因。

## 合并、分离、音频

首页下方有独立入口，点进去是同一张编辑页，左右两栏分别是合并和分离，窄屏自动改成上下排列。

- **分离**：把第一条视频流和第一条音频流拆成两个文件。视频流原样复制，音频流原样复制；输出扩展名按源编码选，视频用 MP4 或 WebM，音频用 M4A、MP3、Opus、FLAC 或 WAV。
- **合并**：选一个视频文件和一个音频文件，视频流复制，音频可选原样复制或重新编码成 AAC。输出容器按视频和音频编码选 MP4、MKV 或 WebM。
- **只要音频**：从视频或音频文件里导出 M4A / AAC、MP3、Opus、FLAC、WAV，可调音频码率，视频流直接丢掉。

合并和分离共用同一套参数模型，改完可以退回重编，不会把上一步的输出锁死。

## 插帧

插帧是可选独立包，不塞进主 APK，入口放在更多设置里，未安装时只显示状态。电脑端不重复做这件事：桌面已有成熟的独立插帧工具，再塞进转码器只会让安装包变臃肿。

## Android 体验

- 转码在 Android 前台服务里跑，通知栏显示当前文件和整体进度，退到后台不会静默中断。
- 平板和折叠屏按可用宽度排版，内容最大宽度 840，底部操作栏不会被拉成一条横贯全屏的长条。
- 完成提示留在页面上，不会几秒后自己消失；页面切换、按钮状态和底部栏都有过渡动画。
- 设置页可授权持久输出目录（Android SAF），重启后仍然有效。授权后结果直接写进目标文件夹，结果卡只显示“已完成”。

## 安装

到 [Releases](https://github.com/PrimaluxTeaers/Reencode/releases) 下载 Android arm64-v8a APK。最低 Android 7.0（API 24），没有上架应用商店。

只提供 arm64-v8a。armeabi-v7a、x86_64 和 32 位包都没有随包提供。

包名 `com.teacers.reencode`，签名使用本项目自己的证书，和 Timbre 不共用。两个应用不能互相覆盖安装。

## 构建

需要 Flutter 3.50.0、Dart 3.14、JDK 17、Android SDK 36。

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

FFmpegKit Flutter 包放在 `third_party/ffmpeg_kit_flutter_new`。这是上游 4.6.8 的副本，Dart 接口和原生代码没改，只改了 `android/build.gradle` 的 AGP 版本和仓库地址，让它在当前 Flutter / Gradle 组合里能构建。升级 Flutter、AGP 或 Gradle 前先检查这个文件。

## 许可

Reencode 按 **GPL-3.0** 分发。

它使用 FFmpegKit Flutter 4.6.8 的 Full GPL 包，里面带 x264、x265、xvidcore、vid.stab 等 GPL 编码库。应用包含这些库，整体按 GPL-3.0 分发。这样做是为了在没有硬件编码器或硬件编码器不可靠的设备上，仍然能用 H.264 / H.265 软件编码。

- 应用许可证全文：[LICENSE](LICENSE)
- 第三方组件、版本、许可证和链接：[THIRD_PARTY.md](THIRD_PARTY.md)
- 每个发行版附带源码包，内容就是构建该 APK 的代码。

## 隐私

Release APK 不申请 `INTERNET` 权限。没有广告 SDK，没有统计 SDK，不上传视频、文件名、设备标识或转换日志。文件只从你选择的路径读，只写到你选择的文件夹或应用缓存。Android 通知只在你主动开始转换后出现，内容只有当前文件名和进度。

## 已知边界

- 只处理第一条视频流和全部音频流。字幕、附件和多视频轨不复制。
- 章节和全局元数据在目标容器支持时会复制；复杂章节结构可能被 FFmpeg 简化。
- 10-bit / 12-bit 只表示像素位深，不等于 HDR。HDR10+ 动态元数据不注入，杜比视界不重编码，二者只能流复制保留。
- 没有开放 MediaCodec 硬件编码，也没有 GPU 编码或 GPU 滤镜。当前走 FFmpeg 软件路径。
- AV1 的 `libaom-av1` 已接进 UI，可输出 MP4、MKV、WebM；软件编码很慢，1080p 比较现实，12-bit 会拦截。H.266 / VVC 没有 `libvvenc`，不能编码，不进入稳定版。
- 插帧只保留入口和独立包说明，核心 APK 不含插帧算法。
- 大文件在临时输出存在期间，大约需要相当于原文件两倍的剩余空间。
- 预检只拦明确不兼容的组合，最终能不能封装仍以 FFmpeg 的结果为准。

## 开发

```bash
flutter analyze lib test
flutter test
```

`lib/models.dart` 放媒体摘要、编码 / 容器枚举、配方和预检；`lib/command_builder.dart` 只生成 FFmpeg 参数；`lib/engine.dart` 负责 FFprobe、FFmpeg 执行、进度和取消；`lib/media_tools.dart` 放合并、分离和轻量音频；`lib/codec_details.dart` 放编码详情文案。参数规则可以单独测试，不需要加载 native 库。

---

# Reencode

An Android video converter that runs offline, with no ads, no analytics and no uploads. The home screen puts bitrate, codec, container and audio on one workbench, which makes batch work on a phone practical.

The Android build ships arm64-v8a only and shows **Reencode 64-bit** as its name. The Windows build is produced separately as **Reencode x86-64** and supports Windows 10 / 11 x64 only.

## Features

- Containers: MP4, MKV, MOV, WebM.
- Video codecs: H.264, H.265 / HEVC, VP9, AV1, MPEG-4. AV1 and MPEG-4 both sit on the home row, not hidden in a submenu.
- Audio: AAC, Opus, MP3, stream copy.
- Video bitrate from 1 to 100000 kbps, up to the equivalent of 100 Mbps. Type an exact value, drag the slider for a rough value, and tap the unit to switch between kbps and Mbps. Below 64 kbps is marked as the experimental low-bitrate range.
- Resolution: source, 4K (2160p), 2K (1440p), 1.5K (1220p, experimental), 1080p, 720p, 480p. This only changes output dimensions; it does not restore detail the source never had.
- Bit depth: preserve, 8-bit, 10-bit, 12-bit. H.265 and VP9 can keep 10-bit; H.265 adds a 12-bit experimental option; H.264 and MPEG-4 are fixed at 8-bit.
- Frame rate: passthrough or constant frame rate (CFR). 24–60 is continuous. 90 / 120 appear after Experimental features is enabled in Settings. 144 unlocks only after tapping 120 four times and reading the warning. CFR drops frames or repeats duplicates; it does not interpolate.
- Encoder speed presets: fast, balanced, slow and custom. Custom accepts any FFmpeg `-preset` name, such as `veryslow`.
- Codec details: tapping a codec gives a short use case first, then a detail page with the implementation principle, standards body, origin, typical use and maximum support.
- More settings: HDR, metadata, chapters and faststart are individual switches instead of hard-coded command flags.

## HDR

When the source carries HDR, the matching switches appear under More settings.

- **HDR10 static metadata**: H.265 re-encoding writes colour tags, Mastering Display and MaxCLL / MaxFALL. AV1 writes the colour tags only, without Mastering Display / MaxCLL. H.264, VP9 and MPEG-4 do not write this set.
- **HDR10+ dynamic metadata**: this build can only keep it through remux. Injecting HDR10+ after re-encoding needs `hdr10plus_tool`, which is not bundled, so an HDR10+ source blocks re-encoding in preflight.
- **Dolby Vision**: remux only. Re-encoding drops the Dolby Vision layer, so preflight blocks it as well.

A switch being on does not mean every source can keep that metadata. When the source has no matching side data the switch is disabled and the reason is shown.

## Merge, split and audio

There is a separate entry below the home screen. It opens one editor with merge and split columns; narrow screens stack them vertically.

- **Split**: pull the first video stream and the first audio stream into two files. Both streams are copied; the extension follows the source codec. Video goes to MP4 or WebM, audio to M4A, MP3, Opus, FLAC or WAV.
- **Merge**: pick one video file and one audio file. The video stream is copied; audio can be copied as-is or re-encoded to AAC. The output container is MP4, MKV or WebM, chosen from the video and audio codecs.
- **Audio only**: export M4A / AAC, MP3, Opus, FLAC or WAV from a video or audio file, with an adjustable audio bitrate. The video stream is discarded.

Merge and split share one parameter model, so you can go back and adjust without locking the previous output.

## Frame interpolation

Frame interpolation is an optional package, not part of the core APK. The entry sits under More settings and shows its install state. The desktop build does not repeat it: desktop already has mature standalone interpolation tools, and bundling another one would only make the converter heavier.

## Android behaviour

- Conversion runs in an Android foreground service. The notification shows the current file and overall progress, and leaving the app does not silently kill the job.
- Tablets and foldables lay out by available width. Content is capped at 840 logical pixels, and the bottom action bar is not stretched across the whole screen.
- The completion banner stays on screen instead of disappearing after a few seconds. Page changes, button states and the bottom bar use transitions.
- Settings can grant a persistent output folder through Android's Storage Access Framework. The grant survives a restart, and results are written there directly with a “Done” card.

## Install

Download the Android arm64-v8a APK from [Releases](https://github.com/PrimaluxTeaers/Reencode/releases). Minimum Android 7.0 (API 24). Not on any app store.

Only arm64-v8a is shipped. armeabi-v7a, x86_64 and 32-bit packages are not included.

Package name is `com.teacers.reencode`. The APK uses this project's own signing key, not Timbre's. The two apps cannot overwrite each other.

## Build

Flutter 3.50.0, Dart 3.14, JDK 17 and Android SDK 36 are required.

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

The FFmpegKit Flutter package lives in `third_party/ffmpeg_kit_flutter_new`. It is a copy of upstream 4.6.8 with no changes to the Dart API or native code. Only `android/build.gradle` was changed: the AGP version and repository list, so it builds with the current Flutter / Gradle combination. Check that file before upgrading Flutter, AGP or Gradle.

## License

Reencode is distributed under **GPL-3.0**.

It uses the Full GPL build of FFmpegKit Flutter 4.6.8, which bundles x264, x265, xvidcore and vid.stab. Those are GPL codec libraries, so the combined application is distributed under GPL-3.0. This is deliberate: H.264 and H.265 software encoding remain available when a device has no hardware encoder, or when its hardware encoder is unreliable.

- Full application license: [LICENSE](LICENSE)
- Third-party components, versions, licenses and links: [THIRD_PARTY.md](THIRD_PARTY.md)
- Every release includes a source archive containing the code used to build that APK.

## Privacy

The release APK does not request the `INTERNET` permission. There is no ad SDK, no analytics SDK, and no upload of videos, filenames, device identifiers or conversion logs. Files are read from the path you pick and written to the folder you pick or to the app cache. The Android notification appears only after you start a conversion and contains only the current filename and progress.

## Known limits

- Only the first video stream and all audio streams are processed. Subtitles, attachments and multiple video tracks are not copied.
- Chapters and global metadata are copied when the target container supports them. Complex chapter layouts may be simplified by FFmpeg.
- 10-bit / 12-bit means pixel depth, not HDR. HDR10+ dynamic metadata is not injected, and Dolby Vision is not re-encoded; both survive only through stream copy.
- No MediaCodec hardware encoding, GPU encoding or GPU filters are exposed. The current path is FFmpeg software encoding.
- AV1 is a real `libaom-av1` encoder in the UI, with MP4, MKV and WebM output. Software encoding is very slow; 1080p is the practical target and 12-bit is blocked. H.266 / VVC has no `libvvenc`, cannot encode, and stays out of the stable release.
- Frame interpolation keeps only its entry and optional-package note; the core APK contains no interpolation algorithm.
- Large files need roughly twice their size in free space while the temporary output exists.
- Preflight catches clearly incompatible combinations. Whether the final mux succeeds is still decided by FFmpeg.

## Development

```bash
flutter analyze lib test
flutter test
```

`lib/models.dart` holds media summaries, codec / container enums, recipes and preflight checks; `lib/command_builder.dart` only builds FFmpeg arguments; `lib/engine.dart` handles FFprobe, FFmpeg execution, progress and cancellation; `lib/media_tools.dart` holds merge, split and lightweight audio; `lib/codec_details.dart` holds the codec detail copy. The argument rules can be tested without loading the native library.
