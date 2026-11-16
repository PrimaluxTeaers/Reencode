# Changes

## 1.0.0 — 2026-11-15

### 中文

第一个版本。

- 三种模式：只换容器、换编码、压码率。可以单独改一项，也可以同时改编码和容器。
- 容器 MP4 / MKV / MOV / WebM，视频编码 H.264 / H.265 / VP9 / MPEG-4，音频 AAC / Opus / MP3 / 原样复制。
- 目标码率、分辨率、帧率、音频码率可调。视频码率最低 1 kbps，64 kbps 以下会提示实验性低码率档；音频最低 8 kbps。只换容器走流复制，不重新编码。
- 多文件队列、探测、预检、进度、取消、失败重试。
- Android SAF 持久输出目录。授权后结果直接写入，结果卡只保留“已完成”；未授权时保留分享。
- 中文 / English 运行时切换，主题和主题色可调。
- 应用内许可页、完整 GPL-3.0 文本、第三方组件清单和隐私说明。
- 首个发行版只提供 arm64-v8a APK，最低 Android 7.0。

已知边界：字幕、附件、多视频轨、HDR 元数据、杜比视界不保留；没有开放 MediaCodec 硬件编码。

### English

First release.

- Three modes: remux, re-encode, compress. Use one at a time, or combine a codec change with a container change.
- Containers: MP4 / MKV / MOV / WebM. Video: H.264 / H.265 / VP9 / MPEG-4. Audio: AAC / Opus / MP3 / stream copy.
- Adjustable target bitrate, resolution, frame rate and audio bitrate. Video bitrate goes down to 1 kbps, with a warning below 64 kbps; audio down to 8 kbps. Remux copies streams without re-encoding.
- Multi-file queue, probing, preflight checks, progress, cancellation and retry after failure.
- Persistent Android SAF output folder. Once granted, results are written there and the card shows only “Done”; without a folder, sharing stays available.
- Chinese / English runtime switch, theme and accent colour.
- In-app licenses page, full GPL-3.0 text, third-party inventory and privacy note.
- First release is arm64-v8a only, minimum Android 7.0.

Known limits: subtitle, attachment and multiple video tracks are not preserved; HDR metadata and Dolby Vision are not preserved; MediaCodec hardware encoding is not exposed.

---

Build: Flutter 3.50.0 · Dart 3.14 · FFmpegKit Flutter 4.6.8 (Full GPL) · FFmpeg 8.1.2.
