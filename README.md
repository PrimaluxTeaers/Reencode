# Reencode

Android 与 Windows 视频转码工具。三种操作：只换容器、换编码、压码率。同一个文件可以只改一项，也可以同时换编码和容器。离线运行，无广告，无统计。

Reencode 用 FFmpeg 8.1.2 转码。只换容器走流复制，不重新编码；换编码和压码率会重新编码，界面会在开始前标出。

## 平台

Android：arm64-v8a，最低 Android 7.0（API 24）。

Windows：x64，Windows 10 / 11。发行包是 zip，解压后运行 `reencode.exe`；`ffmpeg.exe` 和 `ffprobe.exe` 在旁边的 `ffmpeg` 文件夹里，不依赖系统 PATH。Windows 源码在 `windows-port` 分支，发行包在 `windows-v1.0.0` Release。

Windows 7 / 8 / 8.1 没有构建。Flutter 的 Windows 运行时最低是 Windows 10，这三个系统要另做界面外壳，目前没有做。

只发 64 位。macOS、iPhone、iPad 没有适配计划。

## 功能

- 容器：MP4、MKV、MOV、WebM。
- 视频编码：H.264、H.265 / HEVC、VP9、MPEG-4。
- 音频编码：AAC、Opus、MP3、原样复制。
- 目标视频码率、分辨率（原始 / 2160 / 1440 / 1080 / 720 / 480）、帧率（原始 / 60 / 30 / 24）、音频码率。视频码率最低 1 kbps，低于 64 kbps 会提示实验性低码率档；音频最低 8 kbps。
- 多文件导入、逐个探测、队列顺序转码、实时进度、取消。
- 10-bit 源在 H.265 / VP9 输出时保留 10-bit 像素格式；HDR 元数据不保留。
- 转换前做参数预检：容器和编码不兼容、码率越界、源音频不能复制进目标容器，都会先拦下。
- 设置里可以授权一个持久文件夹（Android SAF）。授权后结果直接写进去，重启仍然有效；结果卡只显示“已完成”，不再给分享按钮。
- 中文 / English 运行时切换。主题、主题色、输出目录都在设置页。

Windows 版的 H.264 / H.265 可以使用 NVIDIA NVENC 和 AMD AMF；启动时先按 PCI 厂商 ID 识别，再实际跑一帧确认编码器能启动。Intel、Arc 和其他厂商退回 CPU 编码，设置页会标明原因。CPU 按物理核数和 L3 缓存分档，6 核是下限。Android 版没有开放 MediaCodec 硬件编码。

## 安装

Android：到 [Releases](https://github.com/PrimaluxTeaers/Reencode/releases) 下载 `Reencode-1.0.0-arm64-v8a-newicon.apk`。最低 Android 7.0（API 24），没有上架应用商店。

Windows：到 [windows-v1.0.0](https://github.com/PrimaluxTeaers/Reencode/releases/tag/windows-v1.0.0) 下载 `Reencode-windows-x64.zip`，解压后运行。只支持 Win10/11 x64。

首版只打 arm64-v8a。armeabi-v7a 和 x86_64 没有随包提供。

签名用的是这个项目自己的证书，和 Timbre 不共用。两个应用不能互相覆盖安装。

## 构建

Android 需要 Flutter 3.50.0、Dart 3.14、JDK 17、Android SDK 35。

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

Windows 需要 Flutter 3.50.0 与 Visual Studio 2022 的 C++ 桌面工作负载，只能出 x64。Windows 目录由 CI 用 `flutter create --platforms=windows` 生成，构建后把 `ffmpeg.exe` 和 `ffprobe.exe` 放进输出目录的 `ffmpeg` 子文件夹。

FFmpegKit Flutter 包放在 `third_party/ffmpeg_kit_flutter_new`。这是上游 4.6.8 的副本，Dart 接口和原生代码没有改，只改了 `android/build.gradle` 的 AGP 版本和仓库地址，让它能在当前 Flutter / Gradle 组合里构建。Windows 不走 FFmpegKit，直接启动 `ffmpeg.exe` 子进程；这份副本的 `pubspec.yaml` 去掉了 windows 与 linux 平台声明。

## 许可

Reencode 按 GPL-3.0 分发，不是 LGPL。

它使用 FFmpegKit Flutter 4.6.8 Full GPL 包，里面带 x264、x265、xvidcore、vid.stab 这些 GPL 编码库。应用包含这些库，所以整体按 GPL-3.0 分发。Windows 包内的 FFmpeg 是 BtbN 的 GPL 构建，许可证不变。

- 应用许可证全文：[LICENSE](LICENSE)
- 第三方组件、版本、许可证和链接：[THIRD_PARTY.md](THIRD_PARTY.md)
- 每个 Android 发行版附带源码包，内容就是构建该 APK 的代码。

## 隐私

Release APK 不申请 `INTERNET` 权限。没有广告 SDK，没有统计 SDK，不上传视频、文件名、设备标识或转换日志。文件只从你选择的路径读，只写到你选择的文件夹或应用缓存。

Windows 版在探测硬件时调用一次本地 WMI 读 CPU 和显卡名称，不联网，结果不保存也不上传。

## 已知边界

- 只处理第一条视频流和全部音频流。字幕流、附件流不复制。
- 目标容器支持时，章节和全局元数据会复制；复杂章节结构可能被简化。
- 多视频轨、HDR 元数据、杜比视界不保留。
- Android 版只走软件编码，没有开放 MediaCodec 硬件编码。Windows 版按 NVENC / AMF 白名单走硬件编码，白名单外的显卡一律软件编码。
- 大文件在临时输出存在期间，大约需要相当于原文件两倍的剩余空间。
- 预检只拦明确不兼容的组合，最终能不能封装仍以 FFmpeg 的结果为准。

## 开发

```bash
flutter analyze
flutter test
```

`lib/models.dart` 放媒体摘要、编码 / 容器枚举、配方和预检；`lib/command_builder.dart` 只生成 FFmpeg 参数，不碰原生层；`lib/engine.dart` 负责 FFprobe、FFmpeg 执行、进度和取消。参数规则可以单独测试，不需要加载 native 库。

Windows 分支的引擎在 `lib/engine_windows.dart`，硬件判断在 `lib/hardware_profile.dart`。`main` 与 `windows-port` 不自动合并。
