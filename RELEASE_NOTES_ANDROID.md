# Reencode 1.5.0 — Android arm64-v8a（重做版）

## 中文

1.5 仍在重做，版本号保持 1.5.0。之前的 1.5 Release 和标签已从仓库撤下，这一轮改完后重新构建、重新发布；1.0.0 等旧发布记录不动。

- 更多设置改成逐项开关：HDR10 静态元数据、HDR10+ 动态元数据、杜比视界、全局元数据、章节、faststart。
- H.265 重编码会写 HDR10 色彩标记、Mastering Display、MaxCLL / MaxFALL；HDR10+ 需要 `hdr10plus_tool`，这一版只做流复制保留；杜比视界同样只允许 remux。
- 编码速度预设：快、均衡、慢、自定义；自定义可填 FFmpeg `-preset` 名。
- 每个编码有用途简称和详情页，讲实现原理、标准组织、发明背景、典型用途和最大支持。
- AV1 正式接入首页：使用包内 `libaom-av1`，可输出 MP4 / MKV / WebM；12-bit 拦截，1080p 以上给出慢速提示。
- 首页下方新增合并、分离、轻量音频入口：分离复制视频和音频，合并复制视频并可选 AAC 重编码音频，只要音频支持 M4A / MP3 / Opus / FLAC / WAV。
- 插帧只保留可选包入口，不进入核心 APK；桌面端不重复适配。
- Android 前台服务通知显示当前文件和整体进度；平板内容宽度限制为 840，底栏不再拉满全屏。
- 完成提示不自动消失，按钮、页面切换和底部栏有过渡动画。
- 应用名 `Reencode 64 位`，Windows 版 `Reencode x86-64`，只支持 Windows 10 / 11 x64。
- README 改为中英上下对照，去掉独立的 `README.en.md` 跳转。

安装包在重新构建后附上；当前 Release 不挂旧 APK。

## English

1.5 is still being reworked and the version stays 1.5.0. The previous 1.5 releases and tags were removed from the repository; this round will be rebuilt and republished when it is finished. Releases such as 1.0.0 remain untouched.

- More settings is now individual switches: HDR10 static metadata, HDR10+ dynamic metadata, Dolby Vision, global metadata, chapters and faststart.
- H.265 re-encoding writes HDR10 colour tags, Mastering Display and MaxCLL / MaxFALL. HDR10+ needs `hdr10plus_tool`, so this build keeps it through stream copy only. Dolby Vision is remux-only for the same reason.
- Encoder speed presets: fast, balanced, slow and custom. Custom accepts any FFmpeg `-preset` name.
- Each codec has a short use case and a detail page covering the implementation principle, standards body, origin, typical use and maximum support.
- AV1 is a real home-row encoder through the bundled `libaom-av1`, with MP4 / MKV / WebM output. 12-bit is blocked and anything above 1080p gets a slow-encode warning.
- A merge, split and lightweight-audio entry sits below the home screen: split copies video and audio, merge copies video and optionally re-encodes audio to AAC, and audio-only exports M4A / MP3 / Opus / FLAC / WAV.
- Frame interpolation keeps only an optional-package entry and stays out of the core APK. The desktop build does not repeat it.
- An Android foreground-service notification shows the current file and overall progress. Tablet content is capped at 840 logical pixels and the bottom bar no longer stretches across the screen.
- The completion banner stays on screen. Buttons, page changes and the bottom bar use transitions.
- App name `Reencode 64 位`; Windows build `Reencode x86-64`, supporting Windows 10 / 11 x64 only.
- README is a Chinese/English pair in one file, with no separate `README.en.md` jump.

The APK will be attached after the rebuild; this release carries no old APK.
