import "dart:async";
import "dart:io";

import "package:file_picker/file_picker.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

import "dialogs.dart";
import "engine.dart";
import "l10n.dart";
import "models.dart";
import "output_store.dart";
import "page_route.dart";
import "settings.dart";
import "theme.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await S.load();
  await AppPreferences.load();
  runApp(const ReencodeApp());
}

class ReencodeApp extends StatefulWidget {
  const ReencodeApp({super.key});

  @override
  State<ReencodeApp> createState() => _ReencodeAppState();
}

class _ReencodeAppState extends State<ReencodeApp> {
  @override
  void initState() {
    super.initState();
    S.revision.addListener(_rebuild);
    AppPreferences.revision.addListener(_rebuild);
  }

  @override
  void dispose() {
    S.revision.removeListener(_rebuild);
    AppPreferences.revision.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Reencode",
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light, AppPreferences.seed),
      darkTheme: buildAppTheme(Brightness.dark, AppPreferences.seed),
      themeMode: AppPreferences.themeMode,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<VideoJob> _jobs = <VideoJob>[];
  final ConversionRunner _runner = ConversionRunner();
  ConversionRecipe _recipe = const ConversionRecipe();
  bool _recipeTouched = false;
  bool _adding = false;
  bool _running = false;
  OutputTarget? _target;

  @override
  void initState() {
    super.initState();
    S.revision.addListener(_onLanguageChanged);
    _loadTarget();
  }

  @override
  void dispose() {
    S.revision.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTarget() async {
    final OutputTarget? target = await OutputStore.current();
    if (!mounted) return;
    setState(() => _target = target);
  }

  Future<void> _pickVideos() async {
    if (_adding || _running) return;
    setState(() => _adding = true);
    try {
      final List<PlatformFile> picked = await FilePicker.pickFiles(
        type: FileType.video,
      );
      if (picked.isEmpty) return;
      final List<String> paths = picked
          .map((PlatformFile file) => file.path)
          .whereType<String>()
          .where((String path) => path.isNotEmpty)
          .toList();
      final List<String> fresh = <String>[];
      for (final String path in paths) {
        if (_jobs.any((VideoJob job) => job.path == path)) continue;
        fresh.add(path);
      }
      if (fresh.isEmpty) return;
      final List<VideoJob> added = fresh
          .map((String path) => VideoJob(path: path, name: p.basename(path)))
          .toList();
      setState(() {
        _jobs.addAll(added);
      });
      await _probeJobs(added);
    } catch (error) {
      _toast(S.t("Could not open the picker: $error", "打不开文件选择器：$error"));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _probeJobs(List<VideoJob> jobs) async {
    for (final VideoJob job in jobs) {
      try {
        final MediaSummary media = await MediaProbe.read(job.path);
        if (!mounted) return;
        setState(() {
          job.media = media;
          job.status = JobStatus.ready;
          if (!_recipeTouched) {
            _recipe = ConversionRecipe.defaultsFor(media);
            _recipeTouched = true;
          }
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          job.status = JobStatus.failed;
          job.error = error.toString();
        });
      }
    }
    if (mounted) setState(() {});
  }

  void _retryProbe(VideoJob job) {
    if (_running) return;
    setState(() {
      job.status = JobStatus.probing;
      job.error = null;
    });
    _probeJobs(<VideoJob>[job]);
  }

  void _removeJob(VideoJob job) {
    if (job.isBusy && _running) return;
    setState(() => _jobs.remove(job));
  }

  void _onRecipeChanged(ConversionRecipe recipe) {
    setState(() {
      _recipe = recipe;
      _recipeTouched = true;
    });
  }

  List<RecipeIssue> get _issues {
    final List<RecipeIssue> issues = <RecipeIssue>[];
    for (final VideoJob job in _jobs) {
      if (job.status == JobStatus.ready && job.media != null) {
        for (final RecipeIssue issue in _recipe.validate(job.media!)) {
          if (!issues.any(
            (RecipeIssue existing) => existing.message == issue.message,
          )) {
            issues.add(issue);
          }
        }
      }
    }
    return issues;
  }

  bool get _hasBlockingIssue =>
      _issues.any((RecipeIssue issue) => issue.blocking);

  bool get _canStart =>
      !_running &&
      _jobs.any((VideoJob job) => job.status == JobStatus.ready) &&
      !_hasBlockingIssue;

  Future<void> _startAll() async {
    if (!_canStart) {
      if (_issues.isNotEmpty) {
        await _showIssues(_issues);
      }
      return;
    }
    final List<VideoJob> ready = _jobs
        .where((VideoJob job) => job.status == JobStatus.ready)
        .toList();
    if (ready.isEmpty) return;
    setState(() {
      _running = true;
      for (final VideoJob job in ready) {
        job.status = JobStatus.running;
        job.progress = 0;
        job.error = null;
        job.outputPath = null;
        job.publishedName = null;
        job.publishedUri = null;
      }
    });

    try {
      final Directory temp = await getTemporaryDirectory();
      final Directory outDir = Directory(p.join(temp.path, "reencode"));
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      for (final VideoJob job in ready) {
        if (!mounted) return;
        setState(() {
          job.status = JobStatus.running;
          job.progress = 0;
        });
        final MediaSummary? media = job.media;
        if (media == null) {
          setState(() {
            job.status = JobStatus.failed;
            job.error = S.t("Media information is missing.", "缺少媒体信息。");
          });
          continue;
        }
        final String outputName = _uniqueName(
          outDir,
          outputNameFor(job, _recipe),
        );
        final String outputPath = p.join(outDir.path, outputName);
        final ConversionResult result = await _runner.run(
          media: media,
          recipe: _recipe,
          outputPath: outputPath,
          onProgress: (double progress) {
            if (mounted) setState(() => job.progress = progress);
          },
        );

        if (!mounted) return;
        if (result.canceled) {
          await _deleteIfExists(outputPath);
          setState(() {
            job.status = JobStatus.canceled;
            job.progress = 0;
            job.error = S.t("Cancelled.", "已取消。");
          });
          continue;
        }
        if (!result.success) {
          await _deleteIfExists(outputPath);
          setState(() {
            job.status = JobStatus.failed;
            job.progress = 0;
            job.error = result.summary;
          });
          continue;
        }

        final File output = File(outputPath);
        if (!await output.exists()) {
          setState(() {
            job.status = JobStatus.failed;
            job.error = S.t(
              "FFmpeg finished but the output file is missing.",
              "FFmpeg 结束了，但没有生成输出文件。",
            );
          });
          continue;
        }

        if (_target != null) {
          final PublishedFile? published = await OutputStore.publish(
            outputPath,
          );
          if (published != null) {
            await _deleteIfExists(outputPath);
            setState(() {
              job.status = JobStatus.completed;
              job.progress = 1;
              job.publishedName = published.name;
              job.publishedUri = published.uri;
              job.finishedAt = DateTime.now();
            });
            continue;
          }
          // The folder exists but the copy failed: keep the local file so the
          // result is not lost, and leave the share button available.
          setState(() {
            job.status = JobStatus.completed;
            job.progress = 1;
            job.outputPath = outputPath;
            job.error = S.t(
              "Could not copy into the chosen folder. The file is still in the app cache; share it instead.",
              "没能复制进所选文件夹。文件还在应用缓存里，可以直接分享。",
            );
            job.finishedAt = DateTime.now();
          });
          continue;
        }

        setState(() {
          job.status = JobStatus.completed;
          job.progress = 1;
          job.outputPath = outputPath;
          job.finishedAt = DateTime.now();
        });
      }
    } catch (error) {
      _toast(S.t("Conversion setup failed: $error", "转换准备失败：$error"));
    } finally {
      if (mounted) {
        setState(() => _running = false);
        final int completed = _jobs
            .where((VideoJob job) => job.status == JobStatus.completed)
            .length;
        if (completed > 0) {
          _toast(
            S.t("$completed file(s) finished.", "已完成 $completed 个文件。"),
            duration: const Duration(seconds: 2),
          );
          HapticFeedback.mediumImpact();
        }
      }
    }
  }

  String _uniqueName(Directory dir, String name) {
    String candidate = name;
    int index = 2;
    while (File(p.join(dir.path, candidate)).existsSync()) {
      final String base = p.basenameWithoutExtension(name);
      final String ext = p.extension(name);
      candidate = "$base-$index$ext";
      index++;
    }
    return candidate;
  }

  Future<void> _deleteIfExists(String path) async {
    try {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _share(VideoJob job) async {
    final String? path = job.outputPath;
    if (path == null || !File(path).existsSync()) {
      _toast(S.t("The output file is not available anymore.", "输出文件已经不在了。"));
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path)],
          subject: job.name,
          text: S.t("Converted with Reencode", "由 Reencode 转换"),
        ),
      );
    } catch (error) {
      _toast(S.t("Could not share: $error", "分享失败：$error"));
    }
  }

  Future<void> _showIssues(List<RecipeIssue> issues) async {
    final String message = issues
        .map((RecipeIssue issue) => issue.message)
        .join("\n");
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AppDialog(
        icon: Icons.rule_rounded,
        title: S.t("Check the recipe", "检查一下参数"),
        message: message,
        primaryLabel: S.t("Got it", "知道了"),
      ),
    );
  }

  void _toast(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
  }

  Future<void> _cancelAll() async {
    if (!_running) return;
    _runner.cancel();
    setState(() {
      for (final VideoJob job in _jobs) {
        if (job.status == JobStatus.running) {
          job.error = S.t("Cancelling…", "正在取消…");
        }
      }
    });
  }

  void _openSettings() {
    Navigator.of(context)
        .push<bool>(appPageRoute(builder: (_) => const SettingsPage()))
        .then((_) => _loadTarget());
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasJobs = _jobs.isNotEmpty;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(scheme),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: hasJobs ? _jobBody(scheme) : _emptyBody(scheme),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: hasJobs ? _bottomBar(scheme) : null,
    );
  }

  Widget _header(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.movie_filter_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Reencode", style: Theme.of(context).textTheme.titleLarge),
                Text(
                  S.t("Video bitrate · codec · container", "视频码率 · 编码 · 容器"),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (_target != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: _target!.name,
                child: Icon(
                  Icons.folder_rounded,
                  color: scheme.primary,
                  size: 18,
                ),
              ),
            ),
          IconButton(
            onPressed: _openSettings,
            tooltip: S.t("Settings", "设置"),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }

  Widget _emptyBody(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        _capabilityStrip(scheme),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              colors: <Color>[
                scheme.primaryContainer,
                scheme.tertiaryContainer.withValues(alpha: 0.72),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  Icons.video_file_outlined,
                  size: 34,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 42),
              Text(
                S.t(
                  "Bring in a video.\nLeave with the right file.",
                  "把视频拿进来，\n带着对的格式走。",
                ),
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: scheme.onPrimaryContainer, height: 1.12),
              ),
              const SizedBox(height: 10),
              Text(
                S.t(
                  "One workbench for bitrate, codec and container. Batch friendly. Nothing leaves the phone.",
                  "码率、编码、容器，一个工作台。支持批量。文件不出手机。",
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _adding || _running ? null : _pickVideos,
                icon: _adding
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(
                  _adding
                      ? S.t("Reading…", "读取中…")
                      : S.t("Choose videos", "选择视频"),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimaryContainer,
                  foregroundColor: scheme.primaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _feature(
                scheme,
                Icons.swap_horiz_rounded,
                S.t("Container", "容器"),
                S.t("MP4 · MKV · MOV · WebM", "MP4 · MKV · MOV · WebM"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _feature(
                scheme,
                Icons.memory_rounded,
                S.t("Codec", "编码"),
                "H.264 · H.265 · VP9 · MPEG-4",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _feature(
                scheme,
                Icons.speed_rounded,
                S.t("Bitrate", "码率"),
                S.t("Target size, not guesswork", "目标体积，不靠猜"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _quickSettings(scheme),
      ],
    );
  }

  Widget _capabilityStrip(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.view_carousel_outlined,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                S.t("Video codecs", "视频编码"),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                S.t("4 available", "4 种可选"),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _codecBadge(scheme, "H.264"),
              _codecBadge(scheme, "H.265"),
              _codecBadge(scheme, "VP9"),
              _codecBadge(scheme, "MPEG-4"),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            S.t(
              "H.265 and VP9 can keep a 10-bit source. H.264 writes 8-bit. MPEG-4 is the legacy fallback.",
              "H.265 和 VP9 可保留 10-bit 源；H.264 输出 8-bit；MPEG-4 是老设备兜底。",
            ),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _codecBadge(ColorScheme scheme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _quickSettings(ColorScheme scheme) {
    final String folder = _target?.name ?? S.t("App's own folder", "应用专属目录");
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _openSettings,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.tune_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      S.t("Workspace settings", "工作台设置"),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "$folder · ${S.t('Language', '语言')} · ${S.t('Appearance', '外观')}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feature(
    ColorScheme scheme,
    IconData icon,
    String title,
    String body,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(
            body,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _jobBody(ColorScheme scheme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Text(
              S.t("${_jobs.length} file(s)", "${_jobs.length} 个文件"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _adding || _running ? null : _pickVideos,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(S.t("Add", "添加")),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RecipeCard(
          recipe: _recipe,
          sample: _firstMedia,
          issues: _issues,
          enabled: !_running,
          onChanged: _onRecipeChanged,
        ),
        const SizedBox(height: 12),
        for (final VideoJob job in _jobs) ...[
          _jobCard(scheme, job),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  MediaSummary? get _firstMedia {
    for (final VideoJob job in _jobs) {
      if (job.media != null) return job.media;
    }
    return null;
  }

  Widget _jobCard(ColorScheme scheme, VideoJob job) {
    final StreamSummary? video = job.media?.video;
    final String meta = <String?>[
      job.media?.formatLabel,
      job.media?.durationLabel,
      video?.resolution,
      video?.codec.toUpperCase(),
      video?.fpsLabel,
      job.media?.sizeLabel,
    ].where((String? value) => value != null && value != "—").join(" · ");

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: job.status == JobStatus.running
            ? Border.all(
                color: scheme.primary.withValues(alpha: 0.55),
                width: 1.4,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  job.status == JobStatus.failed
                      ? Icons.error_outline_rounded
                      : job.status == JobStatus.completed
                      ? Icons.check_rounded
                      : Icons.movie_outlined,
                  color: job.status == JobStatus.failed
                      ? scheme.error
                      : scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta.isEmpty ? S.t("Reading media…", "正在读取媒体…") : meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _statusBadge(scheme, job),
            ],
          ),
          if (job.status == JobStatus.probing) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(
              borderRadius: BorderRadius.circular(10),
              minHeight: 6,
            ),
          ],
          if (job.status == JobStatus.running) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: job.progress),
                    duration: const Duration(milliseconds: 260),
                    builder:
                        (BuildContext context, double value, Widget? child) =>
                            LinearProgressIndicator(
                              value: value,
                              borderRadius: BorderRadius.circular(10),
                              minHeight: 8,
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "${(job.progress * 100).round()}%",
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _recipe.mode == WorkMode.remux
                        ? S.t("Copying streams…", "正在复制流…")
                        : S.t("Encoding on this phone…", "正在这台手机上编码…"),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                TextButton.icon(
                  onPressed: _cancelAll,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: Text(S.t("Cancel", "取消")),
                ),
              ],
            ),
          ],
          if (job.status == JobStatus.completed) ...[
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: job.hasOutputFolder
                    ? () {
                        HapticFeedback.selectionClick();
                        _removeJob(job);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        job.hasOutputFolder
                            ? Icons.folder_rounded
                            : Icons.insert_drive_file_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job.hasOutputFolder
                                  ? job.publishedName!
                                  : p.basename(job.outputPath ?? ""),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            if (job.error != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                job.error!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.error),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (job.hasOutputFolder)
                        FilledButton.tonalIcon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _removeJob(job);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(S.t("Done", "已完成")),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        )
                      else if (job.outputPath != null)
                        FilledButton.tonalIcon(
                          onPressed: () => _share(job),
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: Text(S.t("Share", "分享")),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (job.status == JobStatus.failed ||
              job.status == JobStatus.canceled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.error ??
                        S.t("This file could not be read.", "这个文件读不了。"),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: job.status == JobStatus.failed
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (job.status == JobStatus.failed && job.media == null)
                  TextButton(
                    onPressed: () => _retryProbe(job),
                    child: Text(S.t("Retry", "重试")),
                  ),
              ],
            ),
          ],
          if (job.status == JobStatus.ready) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _recipe.targetLine,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  onPressed: _running ? null : () => _removeJob(job),
                  tooltip: S.t("Remove", "移除"),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(ColorScheme scheme, VideoJob job) {
    final (String text, Color color) = switch (job.status) {
      JobStatus.probing => (S.t("Reading", "读取中"), scheme.onSurfaceVariant),
      JobStatus.ready => (S.t("Ready", "就绪"), scheme.primary),
      JobStatus.running => (S.t("Running", "进行中"), scheme.primary),
      JobStatus.completed => (S.t("Done", "已完成"), scheme.primary),
      JobStatus.failed => (S.t("Failed", "失败"), scheme.error),
      JobStatus.canceled => (S.t("Stopped", "已停止"), scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }

  Widget _bottomBar(ColorScheme scheme) {
    final int ready = _jobs
        .where((VideoJob job) => job.status == JobStatus.ready)
        .length;
    final int estimate = _firstMedia == null
        ? 0
        : _recipe.estimatedBytesFor(_firstMedia!);
    final String label = _running
        ? S.t("Working…", "处理中…")
        : ready == 0
        ? S.t("Add a video to convert", "添加视频后开始")
        : S.t("Start $ready conversion(s)", "开始转换 $ready 个");
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _recipe.mode == WorkMode.remux
                      ? S.t("Lossless container change", "无损换容器")
                      : S.t(
                          "Target size ${formatBytes(estimate)}",
                          "目标体积 ${formatBytes(estimate)}",
                        ),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  _running
                      ? S.t("Keep the app open while encoding.", "编码时别把应用关掉。")
                      : S.t("Software encode. No network.", "软件编码，不联网。"),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _canStart ? _startAll : (_running ? _cancelAll : null),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text(_running ? S.t("Cancel", "取消") : label),
          ),
        ],
      ),
    );
  }
}

class RecipeCard extends StatefulWidget {
  final ConversionRecipe recipe;
  final MediaSummary? sample;
  final List<RecipeIssue> issues;
  final bool enabled;
  final ValueChanged<ConversionRecipe> onChanged;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.sample,
    required this.issues,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  late final TextEditingController _videoBitrate;
  late final TextEditingController _audioBitrate;
  bool _useMbps = false;
  bool _showSlider = false;
  bool _fps144Unlocked = false;
  int _tap120 = 0;

  @override
  void initState() {
    super.initState();
    AppPreferences.revision.addListener(_onPreferencesChanged);
    _videoBitrate = TextEditingController(
      text: _formatVideoBitrate(widget.recipe.videoBitrateKbps),
    );
    _audioBitrate = TextEditingController(
      text: "${widget.recipe.audioBitrateKbps}",
    );
  }

  @override
  void dispose() {
    AppPreferences.revision.removeListener(_onPreferencesChanged);
    _videoBitrate.dispose();
    _audioBitrate.dispose();
    super.dispose();
  }

  void _onPreferencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant RecipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipe.videoBitrateKbps != widget.recipe.videoBitrateKbps) {
      final String value = _formatVideoBitrate(widget.recipe.videoBitrateKbps);
      if (_videoBitrate.text != value) _videoBitrate.text = value;
    }
    if (oldWidget.recipe.audioBitrateKbps != widget.recipe.audioBitrateKbps) {
      final String value = "${widget.recipe.audioBitrateKbps}";
      if (_audioBitrate.text != value) _audioBitrate.text = value;
    }
  }

  String _formatVideoBitrate(int kbps) {
    if (!_useMbps) return "$kbps";
    final double mbps = kbps / 1000;
    return mbps == mbps.roundToDouble()
        ? mbps.toStringAsFixed(0)
        : mbps
              .toStringAsFixed(3)
              .replaceFirst(RegExp(r"0+$"), "")
              .replaceFirst(RegExp(r"\.$"), "");
  }

  int? _parseVideoBitrate(String text) {
    final double? value = double.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    final int kbps = (_useMbps ? value * 1000 : value).round();
    if (kbps < 1 || kbps > 100000) return null;
    return kbps;
  }

  void _toggleBitrateUnit() {
    setState(() => _useMbps = !_useMbps);
    _videoBitrate.text = _formatVideoBitrate(widget.recipe.videoBitrateKbps);
  }

  void _setVideoBitrateFromText(String text) {
    final int? parsed = _parseVideoBitrate(text);
    if (parsed != null) _setVideoBitrate(parsed);
  }

  void _setMode(WorkMode mode) {
    if (!widget.enabled) return;
    final MediaSummary? sample = widget.sample;
    widget.onChanged(
      sample == null
          ? widget.recipe.copyWith(mode: mode)
          : widget.recipe.forMode(mode, sample),
    );
  }

  void _setContainer(TargetContainer container) {
    if (!widget.enabled) return;
    ConversionRecipe recipe = widget.recipe.copyWith(container: container);
    if (recipe.mode != WorkMode.remux) {
      if (container == TargetContainer.webm) {
        if (recipe.videoCodec != VideoCodec.vp9) {
          recipe = recipe.copyWith(videoCodec: VideoCodec.vp9);
        }
        if (recipe.audioCodec != AudioCodec.opus &&
            recipe.audioCodec != AudioCodec.copy) {
          recipe = recipe.copyWith(audioCodec: AudioCodec.opus);
        }
      } else if (container == TargetContainer.mp4 ||
          container == TargetContainer.mov) {
        if (recipe.videoCodec == VideoCodec.vp9) {
          recipe = recipe.copyWith(videoCodec: VideoCodec.h264);
        }
        if (recipe.audioCodec == AudioCodec.opus) {
          recipe = recipe.copyWith(audioCodec: AudioCodec.aac);
        }
      }
    }
    widget.onChanged(recipe);
  }

  void _setVideoBitrate(int value) {
    if (!widget.enabled) return;
    widget.onChanged(widget.recipe.copyWith(videoBitrateKbps: value));
  }

  void _setAudioBitrate(int value) {
    if (!widget.enabled) return;
    widget.onChanged(widget.recipe.copyWith(audioBitrateKbps: value));
  }

  bool get _experimentalFps => AppPreferences.experimentalFrameRates;

  void _setFrameRateMode(FrameRateMode mode) {
    if (!widget.enabled) return;
    _tap120 = 0;
    widget.onChanged(
      widget.recipe.copyWith(
        frameRateMode: mode,
        targetFps: mode == FrameRateMode.cfr
            ? (widget.recipe.targetFps > 0 ? widget.recipe.targetFps : 30)
            : 0,
      ),
    );
  }

  void _selectFps(int fps) {
    if (!widget.enabled) return;
    if (fps == 144 && !_fps144Unlocked) return;
    if (fps == 120) {
      _tap120++;
      if (_tap120 >= 4) {
        _tap120 = 0;
        widget.onChanged(widget.recipe.copyWith(targetFps: 120));
        unawaited(_unlock144());
        return;
      }
    } else {
      _tap120 = 0;
    }
    widget.onChanged(widget.recipe.copyWith(targetFps: fps));
  }

  Future<void> _unlock144() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AppDialog(
        icon: Icons.warning_amber_rounded,
        title: S.t("Unlock 144 fps?", "解锁 144 帧？"),
        message: S.t(
          "144 fps is a low-level experimental target. It only repeats or drops frames; it does not interpolate. Many phones will overheat, stutter, or fail. Use it for short tests only.",
          "144 帧属于底层实验档。它只补重复帧或丢帧，不做插帧。很多手机会发热、卡顿甚至失败。只建议短片段测试。",
        ),
        secondaryLabel: S.t("Not now", "暂不"),
        secondaryResult: false,
        primaryLabel: S.t("Unlock", "解锁"),
        primaryResult: true,
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _fps144Unlocked = true);
    }
  }

  List<int> get _heights {
    final int source = widget.sample?.video?.height ?? 0;
    final List<int> values = <int>[0, 2160, 1440, 1220, 1080, 720, 480];
    if (source > 0 && !values.contains(source)) values.add(source);
    values.sort((int a, int b) {
      if (a == 0) return 1;
      if (b == 0) return -1;
      return b.compareTo(a);
    });
    return values;
  }

  String _heightLabel(int height) {
    return switch (height) {
      0 => S.t("Original", "原始"),
      2160 => S.t("4K (2160p)", "4K（2160p）"),
      1440 => S.t("2K (1440p)", "2K（1440p）"),
      1220 => S.t("1.5K (1220p, exp.)", "1.5K（1220p，实验）"),
      1080 => "1080p",
      720 => "720p",
      480 => "480p",
      _ => "${height}p",
    };
  }

  bool _depthEnabled(PixelDepth depth) {
    final int sourceBits = widget.sample?.video?.bitDepth ?? 0;
    final bool known = widget.sample?.video?.hasKnownDepth ?? false;
    if (depth == PixelDepth.auto) return true;
    if (widget.recipe.videoCodec == VideoCodec.h264 ||
        widget.recipe.videoCodec == VideoCodec.mpeg4) {
      return depth == PixelDepth.eight;
    }
    if (depth == PixelDepth.eight) return true;
    if (!known || sourceBits < depth.bits!) return false;
    if (widget.recipe.videoCodec == VideoCodec.vp9 &&
        depth == PixelDepth.twelve) {
      return false;
    }
    if (widget.recipe.videoCodec != VideoCodec.h265 &&
        depth == PixelDepth.twelve) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final MediaSummary? sample = widget.sample;
    final bool remux = widget.recipe.mode == WorkMode.remux;
    final bool hasAudio = sample?.hasAudio ?? true;
    final int estimate = sample == null
        ? 0
        : widget.recipe.estimatedBytesFor(sample);
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
              Text(
                S.t("Output recipe", "输出配方"),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (sample != null)
                Text(
                  S.t(
                    "Target ${formatBytes(estimate)}",
                    "目标 ${formatBytes(estimate)}",
                  ),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<WorkMode>(
              showSelectedIcon: false,
              segments: WorkMode.values.map((WorkMode mode) {
                return ButtonSegment<WorkMode>(
                  value: mode,
                  icon: Icon(mode.icon, size: 18),
                  label: Text(mode.label),
                );
              }).toList(),
              selected: <WorkMode>{widget.recipe.mode},
              onSelectionChanged: (Set<WorkMode> value) =>
                  _setMode(value.first),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.recipe.mode.hint,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _label(scheme, S.t("Container", "容器")),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TargetContainer.values.map((TargetContainer container) {
              return ChoiceChip(
                selected: widget.recipe.container == container,
                onSelected: widget.enabled
                    ? (_) => _setContainer(container)
                    : null,
                label: Text(container.label),
                avatar: widget.recipe.container == container
                    ? const Icon(Icons.check_rounded, size: 16)
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            widget.recipe.container.note,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: remux ? _remuxBody(scheme) : _encodeBody(scheme, hasAudio),
          ),
          const SizedBox(height: 14),
          if (widget.issues.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.issues.any((RecipeIssue issue) => issue.blocking)
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    color:
                        widget.issues.any((RecipeIssue issue) => issue.blocking)
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.issues.first.message,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            widget.issues.any(
                              (RecipeIssue issue) => issue.blocking,
                            )
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _remuxBody(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: scheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.t(
                "Video and audio streams are copied. The picture and sound are untouched; only the wrapper changes.",
                "视频和音频流直接复制。画面和声音都不动，只换外壳。",
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _encodeBody(ColorScheme scheme, bool hasAudio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(scheme, S.t("Video codec", "视频编码")),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: VideoCodec.values.map((VideoCodec codec) {
            return ChoiceChip(
              selected: widget.recipe.videoCodec == codec,
              onSelected: widget.enabled
                  ? (_) => widget.onChanged(
                      widget.recipe.copyWith(videoCodec: codec),
                    )
                  : null,
              label: Text(codec.shortLabel),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          widget.recipe.videoCodec.note,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _label(scheme, S.t("Video bitrate", "视频码率")),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _videoBitrate,
                enabled: widget.enabled,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: _useMbps,
                ),
                inputFormatters: <TextInputFormatter>[
                  if (_useMbps)
                    FilteringTextInputFormatter.allow(RegExp(r"[0-9.]"))
                  else
                    FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  suffixText: _useMbps ? "Mbps" : "kbps",
                  hintText: _useMbps ? "2" : "2000",
                ),
                onChanged: _setVideoBitrateFromText,
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: widget.enabled ? _toggleBitrateUnit : null,
              child: Text(_useMbps ? "Mbps" : "kbps"),
            ),
            if (widget.sample?.video?.bitrateKbps != null)
              TextButton(
                onPressed: widget.enabled
                    ? () => _setVideoBitrate(widget.sample!.video!.bitrateKbps)
                    : null,
                child: Text(S.t("Source", "源码率")),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          S.t(
            "1–100000 kbps (up to 100 Mbps). Type an exact number, or drag the slider for a rough value. Tap the unit to switch kbps / Mbps.",
            "1–100000 kbps（最高 100 Mbps）。数字精调，滑块粗调；点单位可在 kbps / Mbps 之间切换。",
          ),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              S.t("Precision", "精确输入"),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.enabled
                  ? () => setState(() => _showSlider = !_showSlider)
                  : null,
              child: Text(
                _showSlider ? S.t("Hide slider", "收起滑块") : S.t("Slider", "滑块"),
              ),
            ),
          ],
        ),
        if (_showSlider)
          Slider(
            value: widget.recipe.videoBitrateKbps.clamp(1, 100000).toDouble(),
            min: 1,
            max: 100000,
            divisions: 999,
            label: _formatVideoBitrate(widget.recipe.videoBitrateKbps),
            onChanged: widget.enabled
                ? (double value) => _setVideoBitrate(value.round())
                : null,
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              <int>[
                10,
                50,
                100,
                250,
                500,
                1000,
                2000,
                4000,
                10000,
                20000,
                40000,
                80000,
                100000,
              ].map((int value) {
                return ActionChip(
                  onPressed: widget.enabled
                      ? () => _setVideoBitrate(value)
                      : null,
                  label: Text(_formatVideoBitrate(value)),
                );
              }).toList(),
        ),
        const SizedBox(height: 16),
        _label(scheme, S.t("Resolution", "分辨率")),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _heights.map((int height) {
            return ChoiceChip(
              selected: widget.recipe.targetHeight == height,
              onSelected: widget.enabled
                  ? (_) => widget.onChanged(
                      widget.recipe.copyWith(targetHeight: height),
                    )
                  : null,
              label: Text(_heightLabel(height)),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          S.t(
            "Tiers keep the source aspect. “Original” keeps its exact size. 1.5K is experimental and will not restore detail the source never had.",
            "档位按源比例缩放；“原始”保持原尺寸。1.5K 是实验档，不会把源里没有的细节变出来。",
          ),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _label(scheme, S.t("Bit depth", "位深")),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PixelDepth.values.map((PixelDepth depth) {
            final bool enabled = _depthEnabled(depth);
            return ChoiceChip(
              selected: widget.recipe.pixelDepth == depth,
              onSelected: widget.enabled && enabled
                  ? (_) => widget.onChanged(
                      widget.recipe.copyWith(pixelDepth: depth),
                    )
                  : null,
              label: Text(depth.label),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          widget.sample?.video?.hasKnownDepth == true
              ? S.t(
                  "Source: ${widget.sample!.video!.bitDepth}-bit. Options the source does not contain are disabled. 12-bit is H.265-only and experimental.",
                  "源：${widget.sample!.video!.bitDepth}-bit。源里没有的位深会灰显。12-bit 只给 H.265，且标实验。",
                )
              : S.t(
                  "Source depth is unknown. Only 8-bit and automatic are safe defaults.",
                  "源位深未知。稳妥起见只开 8-bit 和自动保留。",
                ),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _label(scheme, S.t("Frame rate", "帧率")),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FrameRateMode.values.map((FrameRateMode mode) {
            return ChoiceChip(
              selected: widget.recipe.frameRateMode == mode,
              onSelected: widget.enabled
                  ? (_) => _setFrameRateMode(mode)
                  : null,
              label: Text(mode.label),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        if (widget.recipe.frameRateMode == FrameRateMode.passthrough)
          Text(
            S.t(
              "Keep the source timing. No -r, no forced CFR. This is the safest option for odd rates like 23.976 or 29.97.",
              "保持源时间基，不加 -r，也不强制 CFR。23.976、29.97 这类非整数帧率最稳。",
            ),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          )
        else ...[
          Row(
            children: [
              Text(
                S.t("24–60 fps", "24–60 帧"),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                "${widget.recipe.targetFps.clamp(24, 60)} fps",
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          Slider(
            value: widget.recipe.targetFps.clamp(24, 60).toDouble(),
            min: 24,
            max: 60,
            divisions: 36,
            label: "${widget.recipe.targetFps.clamp(24, 60)} fps",
            onChanged: widget.enabled
                ? (double value) => _selectFps(value.round())
                : null,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <int>[24, 30, 60].map((int fps) {
              return ChoiceChip(
                selected: widget.recipe.targetFps == fps,
                onSelected: widget.enabled ? (_) => _selectFps(fps) : null,
                label: Text("$fps fps"),
              );
            }).toList(),
          ),
          if (_experimentalFps) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <int>[90, 120].map((int fps) {
                return ChoiceChip(
                  selected: widget.recipe.targetFps == fps,
                  onSelected: widget.enabled ? (_) => _selectFps(fps) : null,
                  label: Text("$fps fps"),
                );
              }).toList(),
            ),
          ],
          if (_fps144Unlocked) ...[
            const SizedBox(height: 8),
            ChoiceChip(
              selected: widget.recipe.targetFps == 144,
              onSelected: widget.enabled ? (_) => _selectFps(144) : null,
              label: Text(S.t("144 fps (high risk)", "144 帧（高危）")),
            ),
          ],
          if (widget.recipe.targetFps >= 90) ...[
            const SizedBox(height: 8),
            Text(
              widget.recipe.targetFps >= 144
                  ? S.t(
                      "144 fps is experimental and high-risk. Fixed-rate conversion repeats or drops frames; it does not add real motion.",
                      "144 帧是实验高危档。固定帧率只补重复帧或丢帧，不会增加真实运动。",
                    )
                  : S.t(
                      "90/120 fps are experimental. Fixed-rate conversion repeats or drops frames; it does not make 30 fps source look smoother.",
                      "90/120 帧是实验档。固定帧率只补重复帧或丢帧；30 帧源不会因此变流畅。",
                    ),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.error),
            ),
          ],
        ],
        if (hasAudio) ...[
          const SizedBox(height: 16),
          _label(scheme, S.t("Audio codec", "音频编码")),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AudioCodec.values.map((AudioCodec codec) {
              return ChoiceChip(
                selected: widget.recipe.audioCodec == codec,
                onSelected: widget.enabled
                    ? (_) => widget.onChanged(
                        widget.recipe.copyWith(audioCodec: codec),
                      )
                    : null,
                label: Text(codec.label),
              );
            }).toList(),
          ),
          if (widget.recipe.audioCodec != AudioCodec.copy) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 156,
              child: TextField(
                controller: _audioBitrate,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(suffixText: "kbps"),
                onChanged: (String value) {
                  final int? parsed = int.tryParse(value);
                  if (parsed != null) _setAudioBitrate(parsed);
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              S.t("8–512 kbps", "8–512 kbps"),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ],
    );
  }

  Widget _label(ColorScheme scheme, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: scheme.onSurfaceVariant),
    );
  }
}
