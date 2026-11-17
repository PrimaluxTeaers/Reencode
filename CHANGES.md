# Changes

## 1.5.0 — 2026-11-16

### 中文

版本号从 1.0.0 跳到 1.5.0，versionCode 1500（base）；arm64-v8a 最终为 3500。Android 与 Windows 共用 1.5 版本线；本轮只发 Android arm64-v8a，Windows 由另一侧构建。

- 首页编码区直接显示四种编码：H.264、H.265 / HEVC、VP9、MPEG-4。MPEG-4 补进首屏，不再是隐藏项。
- 视频码率上限从原来的档位改为 1–100000 kbps，最高等效 100 Mbps；数字框精调、滑块粗调、kbps / Mbps 单位切换。
- 分辨率增加 4K（2160p）、2K（1440p）、1.5K（1220p，实验）；保留原始尺寸档。1.5K 只改输出尺寸，不补细节。
- 位深选择：保留、8-bit、10-bit、12-bit。H.265 / VP9 支持 10-bit，H.265 额外开放 12-bit 实验项；H.264 / MPEG-4 固定 8-bit；源文件没有的位深灰显。
- 帧率增加 Passthrough / CFR 两种模式。24–60 连续可调；设置页打开“实验功能”后出现 90 / 120；144 连续点 120 四次并读完警告后解锁。CFR 只丢帧或补重复帧，不插帧。
- 设置页新增“实验功能”面板，集中管理 90 / 120 / 144 和实验性帧率警告。
- 参数预检、SAF 持久输出目录、双语界面、四编码首页测试同步补齐。
- `flutter analyze lib test` 无问题，`flutter test` 15 项通过。

已知边界不变：HDR10 静态元数据、HDR10+ 动态元数据、杜比视界不写入输出；没有开放 MediaCodec / GPU 编码；AV1 只有包内库，1.5 不接 UI；H.266 无编码器，不进入稳定版。

### English

Version jumps from 1.0.0 to 1.5.0, versionCode 1500 (base); the arm64-v8a output is 3500. Android and Windows share the 1.5 line; this release ships Android arm64-v8a only, with Windows built separately.

- The home codec row now shows all four codecs: H.264, H.265 / HEVC, VP9 and MPEG-4. MPEG-4 is visible instead of hidden.
- Video bitrate is now 1–100000 kbps, up to the equivalent of 100 Mbps, with a numeric field, a slider and a kbps / Mbps unit switch.
- Resolution adds 4K (2160p), 2K (1440p) and 1.5K (1220p, experimental), while keeping the source-size option. 1.5K only changes output dimensions.
- Bit depth: preserve, 8-bit, 10-bit, 12-bit. H.265 / VP9 support 10-bit; H.265 adds a 12-bit experimental option; H.264 / MPEG-4 stay at 8-bit. Depths absent from the source are disabled.
- Frame rate adds passthrough and CFR. 24–60 is continuous. 90 / 120 appear after enabling Experimental features in Settings. 144 unlocks after four taps on 120 and the warning. CFR only drops or repeats frames; it does not interpolate.
- Settings gains an Experimental features panel for 90 / 120 / 144 and the high-frame-rate warning.
- Preflight, persistent SAF output, bilingual UI and four-codec home tests are updated.
- `flutter analyze lib test` is clean; `flutter test` passes 15 tests.

Known limits are unchanged: HDR10 static metadata, HDR10+ dynamic metadata and Dolby Vision are not written to the output; MediaCodec / GPU encoding is not exposed; AV1 is present as a library but not in the 1.5 UI; H.266 has no encoder and stays out of the stable release.

---

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
