# Third-party components

Reencode 1.0.0 is distributed under **GPL-3.0** (see [LICENSE](LICENSE)). This file lists the direct components and the native libraries bundled by the conversion engine, with the license each one carries.

## Engine

| Component | Version | License | Role |
|---|---|---|---|
| FFmpegKit Flutter (`ffmpeg_kit_flutter_new`) | 4.6.8 | LGPL-3.0 | Flutter bindings for FFmpeg / FFprobe |
| `ffmpeg-kit-full-gpl` Android AAR (`com.antonkarpenko:ffmpeg-kit-full-gpl`) | 2.2.3 | GPL-3.0 bundle | Prebuilt FFmpeg, FFprobe and codec libraries |
| FFmpeg | 8.1.2 | LGPL-2.1-or-later; this build enables GPL parts | Demux, decode, filter, encode, mux |
| FFprobe | 8.1.2 | LGPL-2.1-or-later; this build enables GPL parts | Media inspection |

The FFmpegKit Flutter plugin itself is LGPL-3.0. Its `ffmpeg-kit-full-gpl` bundle contains GPL codecs, so an application that ships this combination is distributed under GPL-3.0. Reencode does that deliberately: keeping x264 and x265 means H.264 / H.265 software encoding works even when the device has no usable hardware encoder.

Upstream: <https://github.com/sk3llo/ffmpeg_kit_flutter> · <https://ffmpeg.org>

### Native libraries in the Full GPL bundle

The bundle is the `full-gpl` variant of FFmpegKit 2.2.3. It includes the following external libraries. Versions are fixed by that AAR.

| License family | Libraries |
|---|---|
| GPL | x264, x265, xvidcore, vid.stab |
| LGPL | FFmpegKit, FFmpeg, LAME, fribidi, gmp, gnutls, libiconv, kvazaar, soxr, twolame, shine |
| BSD | dav1d, libvpx, libwebp, libtheora, libvorbis, libogg, opus, snappy, speex, libilbc |
| ISC | libass |
| FreeType License / GPLv2 | FreeType |
| MIT | fontconfig, libxml2 |
| WTFPL | zimg |
| Apache-2.0 | opencore-amr, vo-amrwbenc |

Android system libraries used by the bundle: `zlib`, `MediaCodec`.

The upstream bundle ships the complete license texts and notices. They are also retained in the source archive published with each release. If a license text is missing from the archive, open an issue and it will be added.

## Vendored plugin copy

`third_party/ffmpeg_kit_flutter_new` is a copy of the upstream 4.6.8 package. Changes:

- `android/build.gradle`: Android Gradle Plugin classpath changed from 8.7.0 to 9.1.1, and Aliyun Maven mirrors added ahead of Google / Maven Central.
- Nothing else. The Dart API and the Android / iOS / macOS / Windows native source are unchanged.

The copy keeps the upstream `LICENSE` (LGPL-3.0) and `LICENSE.GPLv3`.

## Flutter and Dart packages

| Package | License | Role |
|---|---|---|
| `material_ui` 1.11.0 | BSD-3-Clause | Material 3 widgets |
| `file_picker` 13.3.3 | MIT | System file picker |
| `path` 1.9.1 | BSD-3-Clause | Path handling |
| `path_provider` 2.1.6 | BSD-3-Clause | App cache / temp directories |
| `share_plus` 13.3.1 | BSD-3-Clause | Android share sheet |
| `shared_preferences` 2.5.6 | BSD-3-Clause | Language, theme and output-folder state |
| `cupertino_icons` 1.0.8 | MIT | Icon font |

Transitive Flutter / Dart packages, AndroidX and the Flutter engine keep their own upstream licenses. Flutter and Dart are BSD-3-Clause; AndroidX libraries are Apache-2.0.

## Fonts and images

The launcher icon is a geometric drawing generated in this repository; it is not an AI-generated image. No third-party font is bundled. The interface uses the platform's default Material typography.

## What is not included

- No advertising SDK.
- No analytics or crash-reporting SDK.
- No network client in the release build. The release manifest does not request `INTERNET`.
- No proprietary codec that requires a separate patent license from this project. Patent rights for H.264, H.265, MP3 and AAC are separate from copyright licenses; users who redistribute or commercialise the APK are responsible for checking the patent position in their jurisdiction.
