import "dart:async";
import "dart:io";

import "package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart";
import "package:ffmpeg_kit_flutter_new/ffmpeg_session.dart";
import "package:ffmpeg_kit_flutter_new/return_code.dart";
import "package:ffmpeg_kit_flutter_new/statistics.dart";
import "package:file_picker/file_picker.dart";
import "package:material_ui/material_ui.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

import "engine.dart";
import "gallery_picker.dart";
import "l10n.dart";
import "models.dart";
import "output_store.dart";

enum ToolMode { split, merge, audio }

enum AudioTarget { aac, mp3, opus, flac, wav }

enum SplitVideoTarget { copy, h264Mp4, hevcMp4, h264Mkv, hevcMkv }

extension SplitVideoTargetInfo on SplitVideoTarget {
  String get label => switch (this) {
    SplitVideoTarget.copy => "Original",
    SplitVideoTarget.h264Mp4 => "MP4 / H.264",
    SplitVideoTarget.hevcMp4 => "MP4 / H.265",
    SplitVideoTarget.h264Mkv => "MKV / H.264",
    SplitVideoTarget.hevcMkv => "MKV / H.265",
  };

  String get container => switch (this) {
    SplitVideoTarget.copy => "",
    SplitVideoTarget.h264Mp4 || SplitVideoTarget.hevcMp4 => "mp4",
    SplitVideoTarget.h264Mkv || SplitVideoTarget.hevcMkv => "mkv",
  };

  String get codec => switch (this) {
    SplitVideoTarget.copy => "copy",
    SplitVideoTarget.h264Mp4 || SplitVideoTarget.h264Mkv => "libx264",
    SplitVideoTarget.hevcMp4 || SplitVideoTarget.hevcMkv => "libx265",
  };
}

extension AudioTargetInfo on AudioTarget {
  String get label => switch (this) {
    AudioTarget.aac => "M4A / AAC",
    AudioTarget.mp3 => "MP3",
    AudioTarget.opus => "Opus",
    AudioTarget.flac => "FLAC",
    AudioTarget.wav => "WAV",
  };

  String get fileExtension => switch (this) {
    AudioTarget.aac => "m4a",
    AudioTarget.mp3 => "mp3",
    AudioTarget.opus => "opus",
    AudioTarget.flac => "flac",
    AudioTarget.wav => "wav",
  };

  String get ffmpegCodec => switch (this) {
    AudioTarget.aac => "aac",
    AudioTarget.mp3 => "libmp3lame",
    AudioTarget.opus => "libopus",
    AudioTarget.flac => "flac",
    AudioTarget.wav => "pcm_s16le",
  };
}

class ToolFile {
  final String path;
  final String name;
  final MediaSummary media;

  const ToolFile({required this.path, required this.name, required this.media});
}

class ToolOutput {
  final String path;
  final String name;
  final String? uri;

  const ToolOutput({required this.path, required this.name, this.uri});
}

class MediaToolsPage extends StatefulWidget {
  const MediaToolsPage({super.key});

  @override
  State<MediaToolsPage> createState() => _MediaToolsPageState();
}

class _MediaToolsPageState extends State<MediaToolsPage> {
  ToolMode _mode = ToolMode.split;
  ToolFile? _splitSource;
  ToolFile? _mergeVideo;
  ToolFile? _mergeAudio;
  ToolFile? _audioSource;
  AudioTarget _audioTarget = AudioTarget.aac;
  int _audioBitrate = 192;
  SplitVideoTarget _splitVideoTarget = SplitVideoTarget.copy;
  bool _splitAudioCopy = true;
  AudioTarget _splitAudioTarget = AudioTarget.aac;
  bool _mergeAudioCopy = false;
  AudioTarget _mergeAudioTarget = AudioTarget.aac;
  double _mergeVolume = 1.0;
  bool _busy = false;
  double _progress = 0;
  String? _error;
  List<ToolOutput> _results = <ToolOutput>[];

  Future<ToolFile?> _pick({
    required bool video,
    bool any = false,
    bool requireVideo = true,
  }) async {
    String? path;
    if (video && !any && Platform.isAndroid) {
      path = await GalleryPicker.pickVideo();
    }
    if (path == null) {
      final PlatformFile? picked = await FilePicker.pickFile(
        type: any ? FileType.any : (video ? FileType.video : FileType.audio),
      );
      path = picked?.path;
    }
    if (path == null) return null;
    try {
      final MediaSummary media = await MediaProbe.read(
        path,
        requireVideo: requireVideo,
      );
      return ToolFile(path: path, name: p.basename(path), media: media);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return null;
    }
  }

  Future<void> _runSplit() async {
    final ToolFile? source = _splitSource;
    if (source == null || _busy) return;
    if (!source.media.hasAudio) {
      setState(() => _error = S.t("No audio stream to split.", "没有可分离的音频流。"));
      return;
    }
    final Directory dir = await getTemporaryDirectory();
    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String base = p.basenameWithoutExtension(source.path);
    final String videoContainer = _splitVideoTarget.container.isEmpty
        ? ((source.media.video?.codec ?? "") == "vp9" ? "webm" : "mp4")
        : _splitVideoTarget.container;
    final String videoPath = p.join(
      dir.path,
      "$base-video-$stamp.$videoContainer",
    );
    final String audioPath = p.join(
      dir.path,
      "$base-audio-$stamp.${_splitAudioCopy ? audioExtension(source.media.audio?.codec ?? "") : _splitAudioTarget.fileExtension}",
    );
    await _runCommands(<List<String>>[
      splitVideoArgs(source.path, videoPath, target: _splitVideoTarget),
      splitAudioArgs(
        source.path,
        audioPath,
        copy: _splitAudioCopy,
        target: _splitAudioTarget,
        bitrateKbps: _audioBitrate,
      ),
    ]);
    if (!mounted || _error != null) return;
    await _publish(<String>[videoPath, audioPath]);
  }

  Future<void> _runMerge() async {
    final ToolFile? video = _mergeVideo;
    final ToolFile? audio = _mergeAudio;
    if (video == null || audio == null || _busy) return;
    final String container = mergeContainer(
      video.media,
      audio.media,
      !_mergeAudioCopy,
    );
    final Directory dir = await getTemporaryDirectory();
    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String outputPath = p.join(
      dir.path,
      "${p.basenameWithoutExtension(video.path)}-merged-$stamp.$container",
    );
    await _runCommands(<List<String>>[
      mergeArgs(
        video.path,
        audio.path,
        outputPath,
        copyAudio: _mergeAudioCopy,
        target: _mergeAudioTarget,
        audioBitrate: _audioBitrate,
        volume: _mergeVolume,
      ),
    ]);
    if (!mounted || _error != null) return;
    await _publish(<String>[outputPath]);
  }

  Future<void> _runAudio() async {
    final ToolFile? source = _audioSource;
    if (source == null || _busy) return;
    final Directory dir = await getTemporaryDirectory();
    final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String outputPath = p.join(
      dir.path,
      "${p.basenameWithoutExtension(source.path)}-audio-$stamp.${_audioTarget.fileExtension}",
    );
    await _runCommands(<List<String>>[
      audioOnlyArgs(
        source.path,
        outputPath,
        target: _audioTarget,
        bitrateKbps: _audioBitrate,
      ),
    ]);
    if (!mounted || _error != null) return;
    await _publish(<String>[outputPath]);
  }

  Future<void> _runCommands(List<List<String>> commands) async {
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
      _results = <ToolOutput>[];
    });
    for (int i = 0; i < commands.length; i++) {
      final Completer<int?> completer = Completer<int?>();
      final FFmpegSession session = await FFmpegKit.executeWithArgumentsAsync(
        commands[i],
        (FFmpegSession finished) async {
          if (!completer.isCompleted) {
            completer.complete((await finished.getReturnCode())?.getValue());
          }
        },
        null,
        (Statistics stats) {
          final int timeMs = stats.getTime();
          if (timeMs <= 0) return;
          final double local = ((timeMs / 1000.0) / 120.0).clamp(0.0, 0.99);
          final double total = (i + local) / commands.length;
          if (mounted) setState(() => _progress = total);
        },
      );
      final int? code = await completer.future;
      if (code != ReturnCode.success) {
        final String? logs = await session.getAllLogsAsString();
        if (mounted) {
          setState(() {
            _busy = false;
            _error =
                lastError(logs) ??
                S.t("FFmpeg exited with code $code.", "FFmpeg 返回码 $code。");
          });
        }
        return;
      }
    }
    if (mounted) setState(() => _progress = 1);
  }

  Future<void> _publish(List<String> paths) async {
    final List<ToolOutput> outputs = <ToolOutput>[];
    for (final String path in paths) {
      final File file = File(path);
      if (!await file.exists()) continue;
      final PublishedFile? published = await OutputStore.publish(path);
      outputs.add(
        ToolOutput(path: path, name: p.basename(path), uri: published?.uri),
      );
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _results = outputs;
      if (outputs.isEmpty) {
        _error = S.t(
          "FFmpeg finished but no output file was found.",
          "FFmpeg 结束了，但没找到输出文件。",
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(S.t("Merge, split, audio", "合并、分离、音频")),
        backgroundColor: Colors.transparent,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 720;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
            children: [
              _modePicker(scheme),
              const SizedBox(height: 14),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _splitCard(scheme)),
                    const SizedBox(width: 12),
                    Expanded(child: _mergeCard(scheme)),
                  ],
                )
              else
                _mode == ToolMode.split
                    ? _splitCard(scheme)
                    : _mode == ToolMode.merge
                    ? _mergeCard(scheme)
                    : _audioCard(scheme),
              if (wide) ...[const SizedBox(height: 12), _audioCard(scheme)],
              if (_busy || _progress > 0) ...[
                const SizedBox(height: 14),
                _progressPanel(scheme),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                _errorPanel(scheme),
              ],
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 12),
                _resultsPanel(scheme),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _modePicker(ColorScheme scheme) {
    return SegmentedButton<ToolMode>(
      showSelectedIcon: false,
      segments: <ButtonSegment<ToolMode>>[
        ButtonSegment<ToolMode>(
          value: ToolMode.split,
          icon: const Icon(Icons.call_split_rounded, size: 18),
          label: Text(S.t("Split", "分离")),
        ),
        ButtonSegment<ToolMode>(
          value: ToolMode.merge,
          icon: const Icon(Icons.merge_rounded, size: 18),
          label: Text(S.t("Merge", "合并")),
        ),
        ButtonSegment<ToolMode>(
          value: ToolMode.audio,
          icon: const Icon(Icons.audiotrack_rounded, size: 18),
          label: Text(S.t("Audio", "音频")),
        ),
      ],
      selected: <ToolMode>{_mode},
      onSelectionChanged: (Set<ToolMode> value) {
        setState(() {
          _mode = value.first;
          _error = null;
          _results = <ToolOutput>[];
        });
      },
    );
  }

  Widget _splitCard(ColorScheme scheme) {
    return _card(
      scheme,
      icon: Icons.call_split_rounded,
      title: S.t("Split a video", "分离视频"),
      hint: S.t(
        "One video in, one video stream and one audio stream out. Copy both by default, or set a new format and bitrate before splitting.",
        "一个视频进去，出来一条视频流和一条音频流。默认两边原样复制；分离前也可以改格式和码率。",
      ),
      children: [
        _fileRow(
          scheme,
          label: S.t("Source video", "源视频"),
          file: _splitSource,
          onPick: () async {
            final ToolFile? file = await _pick(video: true);
            if (file != null) setState(() => _splitSource = file);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<SplitVideoTarget>(
          initialValue: _splitVideoTarget,
          decoration: InputDecoration(labelText: S.t("Video output", "视频输出")),
          items: SplitVideoTarget.values.map((SplitVideoTarget value) {
            return DropdownMenuItem<SplitVideoTarget>(
              value: value,
              child: Text(value.label),
            );
          }).toList(),
          onChanged: (SplitVideoTarget? value) {
            if (value != null) setState(() => _splitVideoTarget = value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(S.t("Copy audio stream", "音频流原样复制")),
          subtitle: Text(
            S.t(
              "On: keep the source audio codec. Off: re-encode to the format below.",
              "开：保留源音频编码。关：按下面的格式重新编码。",
            ),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          value: _splitAudioCopy,
          onChanged: (bool value) => setState(() => _splitAudioCopy = value),
        ),
        if (!_splitAudioCopy) ...[
          DropdownButtonFormField<AudioTarget>(
            initialValue: _splitAudioTarget,
            decoration: InputDecoration(labelText: S.t("Audio output", "音频输出")),
            items: AudioTarget.values.map((AudioTarget value) {
              return DropdownMenuItem<AudioTarget>(
                value: value,
                child: Text(value.label),
              );
            }).toList(),
            onChanged: (AudioTarget? value) {
              if (value != null) setState(() => _splitAudioTarget = value);
            },
          ),
          if (_splitAudioTarget != AudioTarget.flac &&
              _splitAudioTarget != AudioTarget.wav)
            _bitrateRow(scheme),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _runSplit,
            icon: const Icon(Icons.call_split_rounded),
            label: Text(S.t("Split video and audio", "分离画面和音频")),
          ),
        ),
      ],
    );
  }

  Widget _mergeCard(ColorScheme scheme) {
    return _card(
      scheme,
      icon: Icons.merge_rounded,
      title: S.t("Merge video and audio", "合并视频和音频"),
      hint: S.t(
        "Video stream stays untouched. Audio can be copied or re-encoded.",
        "视频流不动；音频可以原样复制，也可以重新编码。",
      ),
      children: [
        _fileRow(
          scheme,
          label: S.t("Video", "视频"),
          file: _mergeVideo,
          onPick: () async {
            final ToolFile? file = await _pick(video: true);
            if (file != null) setState(() => _mergeVideo = file);
          },
        ),
        const SizedBox(height: 8),
        _fileRow(
          scheme,
          label: S.t("Audio", "音频"),
          file: _mergeAudio,
          onPick: () async {
            final ToolFile? file = await _pick(video: false);
            if (file != null) setState(() => _mergeAudio = file);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(S.t("Copy audio stream", "音频流原样复制")),
          subtitle: Text(
            S.t(
              "On: lossless copy. Off: re-encode to the chosen format and bitrate.",
              "开：无损复制。关：按选定格式和码率重新编码。",
            ),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          value: _mergeAudioCopy,
          onChanged: (bool value) => setState(() => _mergeAudioCopy = value),
        ),
        if (!_mergeAudioCopy) ...[
          DropdownButtonFormField<AudioTarget>(
            initialValue: _mergeAudioTarget,
            decoration: InputDecoration(labelText: S.t("Audio output", "音频输出")),
            items: AudioTarget.values.map((AudioTarget value) {
              return DropdownMenuItem<AudioTarget>(
                value: value,
                child: Text(value.label),
              );
            }).toList(),
            onChanged: (AudioTarget? value) {
              if (value != null) setState(() => _mergeAudioTarget = value);
            },
          ),
          if (_mergeAudioTarget != AudioTarget.flac &&
              _mergeAudioTarget != AudioTarget.wav)
            _bitrateRow(scheme),
          Text(
            S.t("Audio volume · ${(_mergeVolume * 100).round()}%",
                "音频音量 · ${(_mergeVolume * 100).round()}%"),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Slider(
            value: _mergeVolume,
            min: 0.5,
            max: 2.0,
            divisions: 30,
            label: "${(_mergeVolume * 100).round()}%",
            onChanged: (double value) => setState(() => _mergeVolume = value),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _runMerge,
            icon: const Icon(Icons.merge_rounded),
            label: Text(S.t("Merge", "合并")),
          ),
        ),
      ],
    );
  }

  Widget _audioCard(ColorScheme scheme) {
    return _card(
      scheme,
      icon: Icons.audiotrack_rounded,
      title: S.t("Audio only", "只要音频"),
      hint: S.t(
        "Video or audio in, audio file out. This is the light version; Timbre keeps the full format list.",
        "视频或音频进去，音频文件出来。这里是轻量版；完整格式归 Timbre。",
      ),
      children: [
        _fileRow(
          scheme,
          label: S.t("Source", "源文件"),
          file: _audioSource,
          onPick: () async {
            final ToolFile? file = await _pick(
              video: true,
              any: true,
              requireVideo: false,
            );
            if (file != null) setState(() => _audioSource = file);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AudioTarget>(
          initialValue: _audioTarget,
          decoration: InputDecoration(labelText: S.t("Output format", "输出格式")),
          items: AudioTarget.values.map((AudioTarget value) {
            return DropdownMenuItem<AudioTarget>(
              value: value,
              child: Text(value.label),
            );
          }).toList(),
          onChanged: (AudioTarget? value) {
            if (value != null) setState(() => _audioTarget = value);
          },
        ),
        if (_audioTarget != AudioTarget.flac && _audioTarget != AudioTarget.wav)
          _bitrateRow(scheme, max: 512),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : _runAudio,
            icon: const Icon(Icons.audiotrack_rounded),
            label: Text(S.t("Extract audio", "提取音频")),
          ),
        ),
      ],
    );
  }

  Widget _bitrateRow(ColorScheme scheme, {int max = 320}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          S.t(
            "Audio bitrate · $_audioBitrate kbps",
            "音频码率 · $_audioBitrate kbps",
          ),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        Slider(
          value: _audioBitrate.toDouble().clamp(32, max.toDouble()),
          min: 32,
          max: max.toDouble(),
          divisions: (max - 32) ~/ 16,
          label: "$_audioBitrate",
          onChanged: (double value) {
            setState(() => _audioBitrate = (value / 16).round() * 16);
          },
        ),
      ],
    );
  }

  Widget _fileRow(
    ColorScheme scheme, {
    required String label,
    required ToolFile? file,
    required VoidCallback onPick,
  }) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _busy ? null : onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                file == null ? Icons.add_rounded : Icons.insert_drive_file,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      file?.name ?? S.t("Choose a file", "选择一个文件"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (file != null)
                      Text(
                        <String>[
                          file.media.formatLabel,
                          file.media.durationLabel,
                          file.media.sizeLabel,
                        ].join(" · "),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressPanel(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _busy ? S.t("Working on it…", "正在处理…") : S.t("Finished", "已完成"),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(value: _progress),
          ),
          const SizedBox(height: 8),
          Text(
            "${(_progress * 100).round()}%",
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _errorPanel(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultsPanel(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.t("Output files", "输出文件"),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final ToolOutput output in _results)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.check_circle_rounded, color: scheme.primary),
              title: Text(output.name),
              subtitle: Text(
                output.uri ?? output.path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: S.t("Share", "分享"),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(files: <XFile>[XFile(output.path)]),
                ),
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required String hint,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

String audioExtension(String codec) {
  final String normalized = codec.toLowerCase();
  if (normalized.contains("opus")) return "opus";
  if (normalized.contains("mp3")) return "mp3";
  if (normalized.contains("flac")) return "flac";
  if (normalized.contains("pcm")) return "wav";
  return "m4a";
}

List<String> splitVideoArgs(
  String input,
  String output, {
  SplitVideoTarget target = SplitVideoTarget.copy,
}) {
  return <String>[
    "-y",
    "-i",
    input,
    "-map",
    "0:v:0",
    "-c:v",
    target.codec,
    if (target != SplitVideoTarget.copy) ...<String>[
      "-preset",
      "medium",
      "-crf",
      "20",
    ],
    "-an",
    output,
  ];
}

List<String> splitAudioArgs(
  String input,
  String output, {
  bool copy = true,
  AudioTarget target = AudioTarget.aac,
  int bitrateKbps = 192,
}) {
  return <String>[
    "-y",
    "-i",
    input,
    "-map",
    "0:a:0",
    "-c:a",
    copy ? "copy" : target.ffmpegCodec,
    if (!copy && target != AudioTarget.flac && target != AudioTarget.wav) ...<String>[
      "-b:a",
      "${bitrateKbps}k",
    ],
    "-vn",
    output,
  ];
}

List<String> mergeArgs(
  String video,
  String audio,
  String output, {
  bool copyAudio = true,
  AudioTarget target = AudioTarget.aac,
  int audioBitrate = 192,
  double volume = 1.0,
}) {
  return <String>[
    "-y",
    "-i",
    video,
    "-i",
    audio,
    "-map",
    "0:v:0",
    "-map",
    "1:a:0",
    "-c:v",
    "copy",
    "-c:a",
    copyAudio ? "copy" : target.ffmpegCodec,
    if (!copyAudio && target != AudioTarget.flac && target != AudioTarget.wav) ...<String>[
      "-b:a",
      "${audioBitrate}k",
    ],
    if (!copyAudio && volume != 1.0) ...<String>[
      "-af",
      "volume=${volume.toStringAsFixed(2)}",
    ],
    "-shortest",
    output,
  ];
}

List<String> audioOnlyArgs(
  String input,
  String output, {
  required AudioTarget target,
  required int bitrateKbps,
}) {
  return <String>[
    "-y",
    "-i",
    input,
    "-map",
    "0:a:0",
    "-vn",
    "-c:a",
    target.ffmpegCodec,
    if (target != AudioTarget.flac && target != AudioTarget.wav) ...<String>[
      "-b:a",
      "${bitrateKbps}k",
    ],
    output,
  ];
}

String mergeContainer(
  MediaSummary video,
  MediaSummary audio,
  bool reencodeAudio,
) {
  final String videoCodec = video.video?.codec ?? "";
  final String audioCodec = audio.audio?.codec ?? "";
  if (videoCodec == "vp9" || videoCodec == "av1") {
    return !reencodeAudio && (audioCodec == "opus" || audioCodec == "vorbis")
        ? "webm"
        : "mkv";
  }
  if (reencodeAudio) return "mp4";
  if (videoCodec == "h264" || videoCodec == "hevc" || videoCodec == "mpeg4") {
    if (audioCodec == "aac" || audioCodec == "mp3" || audioCodec == "alac") {
      return "mp4";
    }
  }
  return "mkv";
}

String? lastError(String? log) {
  if (log == null) return null;
  final List<String> lines = log.split("\n");
  for (final String line in lines.reversed) {
    final String lower = line.toLowerCase();
    if (lower.contains("error") ||
        lower.contains("invalid") ||
        lower.contains("failed")) {
      return line.trim();
    }
  }
  return null;
}
