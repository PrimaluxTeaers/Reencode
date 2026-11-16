# Reencode 1.5.0 — Android arm64-v8a

## 中文

Reencode 从 1.0.0 跳到 1.5.0。Android 与 Windows 共用 1.5 版本线，这一版先发 Android arm64-v8a。

- 首页四种编码：H.264、H.265 / HEVC、VP9、MPEG-4。
- 视频码率 1–100000 kbps，最高等效 100 Mbps；数字精调、滑块粗调、kbps / Mbps 切换。
- 分辨率：原始、4K 2160p、2K 1440p、1.5K 1220p（实验）、1080p、720p、480p。
- 位深：保留、8/10/12-bit；H.265 / VP9 支持 10-bit，H.265 开放 12-bit 实验项，H.264 / MPEG-4 固定 8-bit。
- 帧率：Passthrough / CFR；24–60 连续；90 / 120 需开启实验功能；144 连续点 120 四次并读完警告后解锁。CFR 不插帧。
- 设置页实验功能开关、SAF 持久输出目录、双语界面、预检和队列保持。

安装包：`Reencode-1.5.0-arm64-v8a.apk`  
versionName `1.5.0`，versionCode `3500`  
SHA-256：`41aa0c158d8b778aa860a8ce79ae1887966ddcca337016a0ed4c908725ff1f7e`

已知边界：HDR10 静态元数据、HDR10+ 动态元数据和杜比视界不写入输出；没有开放 MediaCodec / GPU 编码；AV1 只有库、1.5 不接 UI；H.266 没有编码器。

## English

Reencode moves from 1.0.0 to 1.5.0. Android and Windows share the 1.5 line; this release ships Android arm64-v8a first.

- Four codecs on the home screen: H.264, H.265 / HEVC, VP9 and MPEG-4.
- Video bitrate 1–100000 kbps, up to 100 Mbps equivalent, with numeric input, slider and kbps / Mbps switch.
- Resolution: source, 4K 2160p, 2K 1440p, 1.5K 1220p (experimental), 1080p, 720p, 480p.
- Bit depth: preserve, 8/10/12-bit. H.265 / VP9 support 10-bit; H.265 adds a 12-bit experimental option; H.264 / MPEG-4 are 8-bit.
- Frame rate: passthrough or CFR. 24–60 continuous; 90 / 120 require Experimental features; 144 unlocks after four taps on 120 and the warning. CFR does not interpolate.
- Settings experimental switch, persistent SAF output, bilingual UI, preflight and queue are retained.

APK: `Reencode-1.5.0-arm64-v8a.apk`  
versionName `1.5.0`, versionCode `3500`  
SHA-256: `41aa0c158d8b778aa860a8ce79ae1887966ddcca337016a0ed4c908725ff1f7e`

Known limits: HDR10 static metadata, HDR10+ dynamic metadata and Dolby Vision are not written; MediaCodec / GPU encoding is not exposed; AV1 is present as a library but not in the 1.5 UI; H.266 has no encoder.
