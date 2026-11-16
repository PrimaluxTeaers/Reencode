# Reencode

Android 视频转码工具。离线运行，无广告，无统计。三个入口：只换容器、换编码、压码率。

首页直接列出四种视频编码：H.264、H.265 / HEVC、VP9、MPEG-4。MPEG-4 不是隐藏项，选编码时就在这一行里。转码由 FFmpeg 8.1.2 执行，只换容器走流复制，换编码和压码率会重新编码。

[English](README.en.md)

## 能做什么

- 容器：MP4、MKV、MOV、WebM。
- 视频编码：H.264、H.265 / HEVC、VP9、MPEG-4。
- 音频编码：AAC、Opus、MP3、原样复制。
- 目标视频码率 1–100000 kbps，最高等效 100 Mbps。数字框可精调，滑块可粗调，点单位在 kbps / Mbps 之间切换；低于 64 kbps 会标为实验性低码率。
- 分辨率：原始、4K（2160p）、2K（1440p）、1.5K（1220p，实验）、1080p、720p、480p。只改输出尺寸，不会把原片没有的细节补回来。
- 位深：保留、8-bit、10-bit、12-bit。H.265 / VP9 可保留 10-bit；H.265 额外开放 12-bit 实验项；H.264 和 MPEG-4 固定 8-bit。源文件没有的位深选项会灰掉。
- 帧率：跟随源（Passthrough）或固定帧率（CFR）。24–60 连续可调；90 / 120 要在设置页打开“实验功能”后出现；144 还要连续点 120 帧四次并读完警告才会解锁。
- 固定帧率只做丢帧或补重复帧，不做插帧。90 / 120 / 144 是实验档，发热、卡顿和编码失败都可能发生。普通手机用户保持 60 帧就够。
- 多文件导入、逐个探测、队列顺序转码、实时进度、取消。
- 转码前预检：容器和编码不兼容、码率越界、源音频不能复制进目标容器，先拦下来。
- 设置页可授权持久输出目录（Android SAF），重启后仍有效；结果卡只显示“已完成”，不再出现分享按钮。
- 中文 / English 运行时切换。主题、主题色、输出目录和实验功能都在设置页。

## 安装

到 [Releases](https://github.com/PrimaluxTeaers/Reencode/releases) 下载 arm64-v8a APK。最低 Android 7.0（API 24）。没有上架应用商店。

只提供 arm64-v8a。armeabi-v7a 和 x86_64 没有随包提供。

包名 `com.teacers.reencode`，签名用本项目自己的证书，和 Timbre 不共用。两个应用不能互相覆盖安装。

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

Release APK 不申请 `INTERNET` 权限。没有广告 SDK，没有统计 SDK，不上传视频、文件名、设备标识或转换日志。文件只从你选择的路径读，只写到你选择的文件夹或应用缓存。

## 已知边界

- 只处理第一条视频流和全部音频流。字幕、附件不复制。
- 目标容器支持时，章节和全局元数据会复制；复杂章节结构可能被简化。
- 10-bit / 12-bit 只表示像素位深，不等于 HDR。HDR10 静态元数据（Mastering Display、CLL）、HDR10+ 动态元数据和杜比视界目前都不写入输出。杜比视界需要原样保留时，用“只换容器 + 原样复制”。
- 没有开放 MediaCodec 硬件编码，也没有 GPU 编码或 GPU 滤镜。当前走 FFmpeg 软件路径。
- AV1 的 `libaom-av1` 在包内，但 1.5 没有接 UI，不作为可选编码。H.266 / VVC 只有设备或 FFmpeg 提供的解码路径，没有 `libvvenc`，不能编码；H.266 不进入稳定版。
- 多视频轨不处理。
- 大文件在临时输出存在期间，大约需要相当于原文件两倍的剩余空间。
- 预检只拦明确不兼容的组合，最终能不能封装仍以 FFmpeg 的结果为准。

## 开发

```bash
flutter analyze lib test
flutter test
```

`lib/models.dart` 放媒体摘要、编码 / 容器枚举、配方和预检；`lib/command_builder.dart` 只生成 FFmpeg 参数；`lib/engine.dart` 负责 FFprobe、FFmpeg 执行、进度和取消。参数规则可以单独测试，不需要加载 native 库。
