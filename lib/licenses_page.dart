import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";

import "l10n.dart";

class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  static const String sourceUrl = "https://github.com/PrimaluxTeaers/Reencode";

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(S.t("Licenses and privacy", "许可与隐私"))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _section(
            context,
            title: S.t("Reencode is GPL-3.0", "Reencode 按 GPL-3.0 分发"),
            body: S.t(
              "The application source is available at $sourceUrl. You may run, study, share and modify it under the GNU General Public License, version 3. The source archive shipped with each release contains the exact code used to build that APK.",
              "应用源码在 $sourceUrl。你可以按 GNU 通用公共许可证第 3 版运行、研究、分享和修改。每个发行版附带的源码包就是构建该 APK 所用的完整代码。",
            ),
          ),
          const SizedBox(height: 14),
          _section(
            context,
            title: S.t("Why the whole app is GPL", "为什么整个应用是 GPL"),
            body: S.t(
              "Reencode uses the Full GPL build of FFmpegKit Flutter 4.6.8. It bundles FFmpeg 8.1.2 with x264, x265, xvidcore and vid.stab. Those codec libraries are GPL-licensed, so the combined application is distributed under GPL-3.0, not LGPL alone. This is a deliberate choice: it keeps H.264 and H.265 software encoding available on devices whose hardware encoder is missing or unreliable.",
              "Reencode 用的是 FFmpegKit Flutter 4.6.8 的 Full GPL 包，内含 FFmpeg 8.1.2 以及 x264、x265、xvidcore、vid.stab。这些编码库是 GPL 许可，所以整个应用按 GPL-3.0 分发，而不是只按 LGPL。这是有意选择：即使设备没有硬件编码器，或者硬件编码器不可靠，H.264 和 H.265 的软件编码仍然可用。",
            ),
          ),
          const SizedBox(height: 14),
          _section(
            context,
            title: S.t("Engine and third-party components", "引擎与第三方组件"),
            body: S.t(
              "FFmpegKit Flutter 4.6.8 (LGPL-3.0) · FFmpeg 8.1.2 (LGPL-2.1-or-later; this build enables GPL parts) · x264, x265, xvidcore, vid.stab (GPL) · libvpx, dav1d, libwebp, libtheora, libvorbis, libogg (BSD) · libopus (BSD) · LAME (LGPL-2.0) · libass (ISC) · FreeType (FTL/GPLv2) · fontconfig, fribidi, zimg and the remaining bundled libraries keep their upstream licenses.",
              "FFmpegKit Flutter 4.6.8（LGPL-3.0）· FFmpeg 8.1.2（LGPL-2.1 或更高；本次构建启用了 GPL 部分）· x264、x265、xvidcore、vid.stab（GPL）· libvpx、dav1d、libwebp、libtheora、libvorbis、libogg（BSD）· libopus（BSD）· LAME（LGPL-2.0）· libass（ISC）· FreeType（FTL/GPLv2）· fontconfig、fribidi、zimg 及其余随包库各自保留上游许可。",
            ),
          ),
          const SizedBox(height: 14),
          _section(
            context,
            title: S.t("Privacy", "隐私"),
            body: S.t(
              "Reencode does not request network access, does not contain ads or analytics, and does not upload video, filenames, device identifiers or conversion logs. Files are read from the path you choose and written to the folder you choose. Temporary output stays inside the app's cache until you share it or it is written into the selected folder.",
              "Reencode 不申请网络权限，不含广告和统计，不上传视频、文件名、设备标识或转换日志。文件只从你选择的路径读取，只写到你选择的文件夹。临时输出留在应用缓存里，直到你分享它，或者它被写进所选文件夹。",
            ),
          ),
          const SizedBox(height: 14),
          _section(
            context,
            title: S.t("Known limits", "已知边界"),
            body: S.t(
              "Version 1.5 processes the first video stream and all audio streams. Chapters and global metadata are copied when the target container supports them; subtitle and attachment streams are not copied. Multiple video tracks are not copied. HDR10 static metadata is written for H.265; AV1 writes the colour tags only. HDR10+ dynamic metadata and Dolby Vision are preserved only by Remux. AV1 is a real libaom encoder here, 12-bit is blocked and software encoding is very slow. H.266 has no encoder in this build. The Full GPL build uses software encoding; MediaCodec hardware acceleration is not exposed in this release. Very large files need roughly twice their size in free space while the temporary output exists.",
              "1.5 处理第一条视频流和全部音频流。目标容器支持时，章节和全局元数据会复制；字幕和附件流不会复制，多视频轨也不会复制。H.265 会写 HDR10 静态元数据；AV1 只写色彩标记。HDR10+ 动态元数据和杜比视界只有“只换容器”能保留。AV1 这版用 libaom 真正接入，12-bit 会拦截，软件编码非常慢。H.266 没有编码器。Full GPL 包走软件编码；这一版没有开放 MediaCodec 硬件加速。大文件在临时输出存在期间，大约需要相当于原文件两倍的剩余空间。",
            ),
          ),
          const SizedBox(height: 14),
          _section(
            context,
            title: S.t("Source and license text", "源码与许可证全文"),
            body: S.t(
              "The repository ships LICENSE (GPL-3.0), THIRD_PARTY.md, README.md and CHANGES.md. The complete GPL text is also bundled in the app.",
              "仓库里有 LICENSE（GPL-3.0）、THIRD_PARTY.md、README.md 和 CHANGES.md。GPL 全文也随应用打包。",
            ),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(S.t("GNU GPL version 3 text", "GNU GPL 第 3 版全文")),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FutureBuilder<String>(
                  future: rootBundle.loadString("assets/licenses/GPL-3.0.txt"),
                  builder:
                      (BuildContext context, AsyncSnapshot<String> snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return SelectableText(
                          snapshot.data!,
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: "Reencode",
              applicationVersion: "1.5.0",
              applicationLegalese: S.t(
                "GPL-3.0. FFmpegKit and bundled libraries keep their own licenses.",
                "GPL-3.0。FFmpegKit 与随包库各自保留许可。",
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(
              S.t("Flutter and Dart package licenses", "Flutter 与 Dart 包许可"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(
            body,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
          ),
        ],
      ),
    );
  }
}
