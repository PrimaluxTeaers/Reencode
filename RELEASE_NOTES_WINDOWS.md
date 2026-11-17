# Reencode 1.5.0 — Windows x86-64

## 中文

Reencode 的 Windows 版由同一项目的 Windows 实现接手，版本线与 Android 共用 1.5.0。只支持 Windows 10 / 11 x64，应用名为 `Reencode x86-64`。

这一版需要对齐 Android 1.5 重做后的能力：

- 容器：MP4、MKV、MOV、WebM。
- 视频编码：H.264、H.265 / HEVC、VP9、AV1、MPEG-4。
- 音频：AAC、Opus、MP3、原样复制。
- 编码速度预设：快、均衡、慢、自定义。
- 更多设置逐项开关：HDR10 静态元数据、HDR10+ 动态元数据、杜比视界、全局元数据、章节、faststart。
- 合并、分离、轻量音频：分离复制视频和音频，合并复制视频并可选 AAC 重编码，只要音频支持 M4A / MP3 / Opus / FLAC / WAV。
- 插帧不进入核心包。桌面端已有成熟独立工具，不重复适配。
- 完成提示、按钮和页面切换保留过渡动画；Windows 不做 Android 通知，也不把通知写成平台限制。
- 构建说明、编码命令和字段定义见仓库中的 `WINDOWS-IMPLEMENTATION-NOTES.md`。

Windows 安装包由 Windows 侧构建后附上，仓库不会把 Android APK 当作 Windows 包。

## English

The Windows build is handled by the project's Windows implementation and shares the 1.5.0 line with Android. It supports Windows 10 / 11 x64 only and ships as `Reencode x86-64`.

This build needs to match the reworked Android 1.5:

- Containers: MP4, MKV, MOV, WebM.
- Video codecs: H.264, H.265 / HEVC, VP9, AV1, MPEG-4.
- Audio: AAC, Opus, MP3, stream copy.
- Encoder speed presets: fast, balanced, slow and custom.
- Individual switches under More settings: HDR10 static metadata, HDR10+ dynamic metadata, Dolby Vision, global metadata, chapters and faststart.
- Merge, split and lightweight audio: split copies video and audio; merge copies video with optional AAC audio re-encoding; audio-only exports M4A / MP3 / Opus / FLAC / WAV.
- Frame interpolation stays out of the core package. Desktop already has mature standalone tools, so it is not repeated here.
- Completion banners, buttons and page changes keep their transitions. Windows has no Android notification, and the docs do not present that as a platform limitation.
- Build notes, command lines and field definitions live in `WINDOWS-IMPLEMENTATION-NOTES.md`.

The Windows installer is attached by the Windows side after it is built; the repository never treats the Android APK as a Windows package.
