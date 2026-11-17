import "package:material_ui/material_ui.dart";

import "l10n.dart";
import "models.dart";

class CodecDetail {
  final String taglineEn;
  final String taglineZh;
  final String whatEn;
  final String whatZh;
  final String howEn;
  final String howZh;
  final String whoEn;
  final String whoZh;
  final String maxEn;
  final String maxZh;
  final String notesEn;
  final String notesZh;

  const CodecDetail({
    required this.taglineEn,
    required this.taglineZh,
    required this.whatEn,
    required this.whatZh,
    required this.howEn,
    required this.howZh,
    required this.whoEn,
    required this.whoZh,
    required this.maxEn,
    required this.maxZh,
    required this.notesEn,
    required this.notesZh,
  });
}

const Map<VideoCodec, CodecDetail> _details = <VideoCodec, CodecDetail>{
  VideoCodec.h264: CodecDetail(
    taglineEn: "The format almost everything can play",
    taglineZh: "几乎所有设备都能播的通用格式",
    whatEn: "H.264, also called AVC, is the workhorse video codec of the last two decades. It is the safe choice for phones, TVs, browsers, social platforms and old hardware.",
    whatZh: "H.264 也叫 AVC，是过去二十年最通用的视频编码。手机、电视、浏览器、社交平台和老设备基本都认，拿不准时选它最稳。",
    howEn: "It splits a frame into macroblocks, predicts motion between frames, transforms the residual with an integer DCT, and entropy-codes the result with CABAC or CAVLC. The encoder trades motion search and compression tools for speed.",
    howZh: "把画面切成宏块，先做帧间运动预测，再把残差做整数 DCT 变换，最后用 CABAC 或 CAVLC 熵编码。编码器在运动搜索和压缩工具之间换速度。",
    whoEn: "Developed by the Joint Video Team of ITU-T VCEG and ISO/IEC MPEG. It is a standard, not one person's invention; the reference software and patent pool involve many companies.",
    whoZh: "由 ITU-T VCEG 和 ISO/IEC MPEG 的联合视频组（JVT）制定。它是标准，不是某一个人的发明；参考软件和专利池涉及多家公司。",
    maxEn: "The standard reaches 8K and 4:2:0 10-bit in High 10. Phone software encoders usually top out at 4K; 8K is not a practical target here.",
    maxZh: "标准本身能到 8K，High 10 Profile 支持 4:2:0 10-bit。手机软件编码通常以 4K 为实用上限，8K 不是这里的现实目标。",
    notesEn: "Widest compatibility, fast software encode, larger files than H.265 at the same quality. Patent licensing is the main commercial cost.",
    notesZh: "兼容最广，软件编码快，同画质下体积比 H.265 大。商业使用的主要成本是专利授权。",
  ),
  VideoCodec.h265: CodecDetail(
    taglineEn: "Smaller files, newer hardware",
    taglineZh: "同画质更小，新设备支持更好",
    whatEn: "H.265, also called HEVC, is the successor to H.264. It is the right choice when the target device supports it and you care about size.",
    whatZh: "H.265 也叫 HEVC，是 H.264 的继任者。目标设备支持、又在意体积时选它。",
    howEn: "It uses larger coding tree units, a quadtree split, better intra prediction, sample adaptive offset and parallel tools. The same quality usually needs 25–50% fewer bits than H.264.",
    howZh: "用更大的编码树单元和四叉树划分，帧内预测更细，加了 SAO 和并行工具。同画质通常比 H.264 少 25–50% 的码率。",
    whoEn: "Developed by the Joint Collaborative Team on Video Coding (JCT-VC), formed by ITU-T VCEG and ISO/IEC MPEG. Again a standard with many contributors and patent holders.",
    whoZh:
        "由 ITU-T VCEG 和 ISO/IEC MPEG 组成的视频编码联合协作组（JCT-VC）制定。同样是标准，贡献者和专利持有者很多。",
    maxEn: "Main 10 reaches 10-bit; Range Extensions reach 12-bit and 4:2:2 / 4:4:4; the standard covers 8K. Phone software encoding at 4K is realistic, 8K is not.",
    maxZh: "Main 10 到 10-bit，Range Extensions 到 12-bit 和 4:2:2 / 4:4:4，标准覆盖 8K。手机上 4K 软件编码比较现实，8K 不现实。",
    notesEn: "Better compression and HDR10 static metadata support. Slower to encode, more patent complexity, and old devices may not decode it.",
    notesZh: "压缩更好，能写 HDR10 静态元数据。编码更慢，专利更复杂，老设备可能解不动。",
  ),
  VideoCodec.vp9: CodecDetail(
    taglineEn: "Royalty-free, made for the web",
    taglineZh: "免版税，为网页而生",
    whatEn: "VP9 is Google's open, royalty-free codec. It is the natural pair for WebM and works well for web video and mid-range Android devices.",
    whatZh: "VP9 是 Google 的开放、免版税编码，和 WebM 是天然搭配，网页视频和中端安卓设备都合适。",
    howEn: "It uses superblocks, recursive partitioning, several intra predictors and motion-vector prediction. Encoding is slower than H.264 at the same settings, but the format avoids patent royalties.",
    howZh: "用超级块和递归划分，多种帧内预测和运动矢量预测。同设置下编码比 H.264 慢，但格式本身不收专利费。",
    whoEn: "Developed by Google's WebM team, with contributions from the open-source community. It is not an ISO/IEC standard.",
    whoZh: "由 Google 的 WebM 团队主导，开源社区参与。它不是 ISO/IEC 标准。",
    maxEn: "Profile 0 is 8-bit 4:2:0; Profile 2 reaches 10-bit and 4:4:4; the format covers 8K. This build exposes 8-bit and 10-bit.",
    maxZh: "Profile 0 是 8-bit 4:2:0，Profile 2 到 10-bit 和 4:4:4，格式覆盖 8K。这版只开放 8-bit 和 10-bit。",
    notesEn: "No royalty, good web support, slower software encode. Some old TVs and car players do not decode it.",
    notesZh: "免版税，网页支持好，软件编码偏慢。部分老电视和车机解不了。",
  ),
  VideoCodec.av1: CodecDetail(
    taglineEn: "Best compression, royalty-free, slow to encode",
    taglineZh: "压缩最好、免版税，但编码很慢",
    whatEn: "AV1 is the newest open video codec from the Alliance for Open Media. It is designed for streaming and storage where every bit counts, and it carries no patent royalty.",
    whatZh: "AV1 是开放媒体联盟（AOMedia）推出的新一代开放视频编码，面向码率敏感的流媒体和存储场景，而且不收专利费。",
    howEn: "It uses a flexible partition tree, directional intra prediction, compound inter prediction, CDEF and loop restoration, plus film-grain synthesis. The encoder searches far more combinations than H.264, which is why software encoding is slow.",
    howZh: "用灵活的块划分树、方向性帧内预测、复合帧间预测、CDEF 与环路恢复，还有胶片颗粒合成。编码器要搜索的组合远多于 H.264，所以软件编码很慢。",
    whoEn: "Developed by the Alliance for Open Media, founded in 2015 by Amazon, Cisco, Google, Intel, Microsoft, Mozilla and Netflix. The reference encoder is libaom; SVT-AV1 is a faster alternative.",
    whoZh: "由开放媒体联盟（AOMedia）制定，2015 年由 Amazon、Cisco、Google、Intel、Microsoft、Mozilla、Netflix 等发起。参考编码器是 libaom，SVT-AV1 是更快的实现。",
    maxEn: "The format covers 8K, 8/10/12-bit and 4:2:0 / 4:2:2 / 4:4:4. Phone software encoding in this build is practical around 1080p; 4K is very slow.",
    maxZh: "格式覆盖 8K、8/10/12-bit 和 4:2:0 / 4:2:2 / 4:4:4。这版的手机软件编码以 1080p 左右比较现实，4K 会非常慢。",
    notesEn: "Exposed as a real encoder through libaom. MP4, MKV and WebM are allowed; 12-bit is blocked. HDR10 colour tags are written when the source is HDR, but Mastering Display / MaxCLL metadata is not written in this build.",
    notesZh: "这版用 libaom 真正接入了 AV1 编码，允许 MP4、MKV、WebM，12-bit 会拦截。源是 HDR 时会写 HDR10 色彩标记，但这一版不写 Mastering Display / MaxCLL 元数据。",
  ),
  VideoCodec.mpeg4: CodecDetail(
    taglineEn: "For old players that refuse everything else",
    taglineZh: "给只认老格式的设备兜底",
    whatEn: "MPEG-4 Part 2 is the older MPEG-4 video codec, not the same thing as MP4 the container. It is kept for legacy hardware and odd playback chains.",
    whatZh: "MPEG-4 Part 2 是老一代 MPEG-4 视频编码，和 MP4 这个容器不是一回事。留着是给老设备和奇怪播放链路兜底。",
    howEn: "It uses rectangular video object planes, macroblocks, motion estimation and texture coding. Simple Profile and Advanced Simple Profile are the common phone-era profiles.",
    howZh: "用矩形视频对象平面、宏块、运动估计和纹理编码。Simple Profile 和 Advanced Simple Profile 是手机时代最常见的档位。",
    whoEn: "Standardized by the ISO/IEC MPEG group. It is a committee standard, not a single inventor's format.",
    whoZh: "由 ISO/IEC MPEG 组制定。它是委员会标准，不是某个人的格式。",
    maxEn: "Advanced Simple Profile is 8-bit, typically up to 720p or 1080p in old devices. It does not support 10-bit or HDR.",
    maxZh:
        "Advanced Simple Profile 是 8-bit，老设备通常到 720p 或 1080p。不支持 10-bit 和 HDR。",
    notesEn: "Only pick it when the target explicitly needs it. Compression and quality are worse than H.264; it is not a modern archive format.",
    notesZh: "只有目标设备明确需要时才选。压缩和画质都不如 H.264，不适合当现代归档格式。",
  ),
};

String codecTagline(VideoCodec codec) {
  final CodecDetail detail = _details[codec]!;
  return S.t(detail.taglineEn, detail.taglineZh);
}

Future<void> showCodecDetail(BuildContext context, VideoCodec codec) {
  final CodecDetail detail = _details[codec]!;
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (BuildContext context, ScrollController controller) {
          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  codec.label,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  S.t(detail.taglineEn, detail.taglineZh),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 22),
                _section(
                  context,
                  scheme,
                  S.t("What it is", "是什么"),
                  S.t(detail.whatEn, detail.whatZh),
                ),
                _section(
                  context,
                  scheme,
                  S.t("How it works", "实现原理"),
                  S.t(detail.howEn, detail.howZh),
                ),
                _section(
                  context,
                  scheme,
                  S.t("Who made it", "谁定的标准"),
                  S.t(detail.whoEn, detail.whoZh),
                ),
                _section(
                  context,
                  scheme,
                  S.t("Maximum support", "最大支持"),
                  S.t(detail.maxEn, detail.maxZh),
                ),
                _section(
                  context,
                  scheme,
                  S.t("In this app", "在这个应用里"),
                  S.t(detail.notesEn, detail.notesZh),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _section(
  BuildContext context,
  ColorScheme scheme,
  String title,
  String body,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
        ),
      ],
    ),
  );
}
