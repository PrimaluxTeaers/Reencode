# Reencode

Android 视频转码工具。三种操作：只换容器、换编码、压码率。同一个文件可以只改一项，也可以同时换编码和容器。离线运行，无广告，无统计。

Reencode 用 FFmpeg 8.1.2 做真正的转码，不是演示壳。只换容器走流复制，不重新编码；换编码和压码率会重新编码，界面会明确标出。

## 能做什么

- 容器：MP4、MKV、MOV、WebM。
- 视频编码：H.264、H.265 / HEVC、VP9、MPEG-4。
- 音频编码：AAC、Opus、MP3、原样复制。
- 目标视频码率、分辨率（原始 / 2160 / 1440 / 1080 / 720 / 480）、帧率（原始 / 60 / 30 / 24）、音频码率。视频码率最低可设 1 kbps，低于 64 kbps 会提示实验性低码率档；音频最低 8 kbps。
- 多文件导入、逐个探测、队列顺序转码、实时进度、取消。
- 10-bit 源在 H.265 / VP9 输出时保留 10-bit 像素格式；HDR 元数据不保留。
- 转换前做参数预检：容器和编码不兼容、码率越界、源音频不能复制进目标容器，都会先拦下来。
- 设置里可以授权一个持久文件夹（Android SAF）。授权后结果直接写进去，重启仍然有效；结果卡只显示“已完成”，不再给分享按钮。
- 中文 / English 运行时切换。主题、主题色、输出目录都在设置页。

## 安装

到 [Releases](https://github.com/PrimaluxTeaers/Reencode/releases) 下载 arm64-v8a APK。最低 Android 7.0（API 24）。没有上架应用商店。

首版只打 arm64-v8a。armeabi-v7a 和 x86_64 没有随包提供。

签名用的是这个项目自己的证书，和旧的 Timbre 不共用。两个应用不能互相覆盖安装。

## 构建

需要 Flutter 3.50.0、Dart 3.14、JDK 17、Android SDK 35。

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

FFmpegKit Flutter 包放在 `third_party/ffmpeg_kit_flutter_new`。这是上游 4.6.8 的副本，Dart 接口和原生代码没改，只改了 `android/build.gradle` 的 AGP 版本和仓库地址，让它能在当前 Flutter / Gradle 组合里构建。升级 Flutter、AGP 或 Gradle 时，先检查这个文件。

## 许可

Reencode 按 **GPL-3.0** 分发，不是 LGPL。

原因是它用 FFmpegKit Flutter 4.6.8 的 Full GPL 包，里面带 x264、x265、xvidcore、vid.stab 这些 GPL 编码库。只要应用里包含它们，整个应用就得按 GPL-3.0 分发。这个选择是有意的：设备没有硬件编码器，或者硬件编码器不可靠时，H.264 / H.265 软件编码仍然能用。

- 应用许可证全文：[LICENSE](LICENSE)
- 第三方组件、版本、许可证和链接：[THIRD_PARTY.md](THIRD_PARTY.md)
- 每个发行版附带源码包，内容就是构建该 APK 的代码。

## 隐私

Release APK 不申请 `INTERNET` 权限。没有广告 SDK，没有统计 SDK，不上传视频、文件名、设备标识或转换日志。文件只从你选择的路径读，只写到你选择的文件夹或应用缓存。

## 已知边界

- 只处理第一条视频流和全部音频流。字幕流、附件流不复制。
- 目标容器支持时，章节和全局元数据会复制；复杂章节结构可能被简化。
- 多视频轨、HDR 元数据、杜比视界不保留。
- Full GPL 包走软件编码。这一版没有开放 MediaCodec 硬件编码。
- 大文件在临时输出存在期间，大约需要相当于原文件两倍的剩余空间。
- 预检只拦明确不兼容的组合，最终能不能封装仍以 FFmpeg 的结果为准。

## 开发

```bash
flutter analyze
flutter test
```

`lib/models.dart` 放媒体摘要、编码 / 容器枚举、配方和预检；`lib/command_builder.dart` 只生成 FFmpeg 参数，不碰原生层；`lib/engine.dart` 负责 FFprobe、FFmpeg 执行、进度和取消。参数规则可以单独测试，不需要加载 native 库。
