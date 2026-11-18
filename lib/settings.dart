import "dart:io";

import "package:material_ui/material_ui.dart";

import "dialogs.dart";
import "frame_rate_field.dart";
import "hardware_profile.dart";
import "font_manager.dart";
import "font_manager_page.dart";
import "haptics.dart";
import "l10n.dart";
import "licenses_page.dart";
import "output_store.dart";
import "page_route.dart";
import "theme.dart";

const String kAppVersion = "1.6.0";

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  OutputTarget? _target;
  bool _busy = false;
  HardwareProfile? _hardware;

  @override
  void initState() {
    super.initState();
    S.revision.addListener(_onPreferenceChanged);
    AppPreferences.revision.addListener(_onPreferenceChanged);
    _loadTarget();
    _loadHardware();
  }

  @override
  void dispose() {
    S.revision.removeListener(_onPreferenceChanged);
    AppPreferences.revision.removeListener(_onPreferenceChanged);
    super.dispose();
  }

  void _onPreferenceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHardware() async {
    final HardwareProfile profile = await HardwareProfile.load(force: true);
    if (mounted) setState(() => _hardware = profile);
  }

  Future<void> _loadTarget() async {
    final OutputTarget? target = await OutputStore.current();
    if (mounted) setState(() => _target = target);
  }

  Future<void> _pickTarget() async {
    if (_busy) return;
    setState(() => _busy = true);
    final OutputTarget? target = await OutputStore.choose();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (target != null) _target = target;
    });
    if (target != null) {
      Haptics.selectionClick();
      _toast(S.t("Results will go here from now on.", "之后的转换结果会直接存到这里。"));
    }
  }

  Future<void> _clearTarget() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AppDialog(
        icon: Icons.folder_off_outlined,
        title: S.t("Use the default folder again?", "改回默认目录？"),
        message: S.t(
          "New conversions will stay in the app's own folder. Files already saved to the picked folder are untouched.",
          "之后的转换会回到应用自己的目录。已经存进所选文件夹的文件不会动。",
        ),
        secondaryLabel: S.t("Keep it", "保留"),
        secondaryResult: false,
        primaryLabel: S.t("Use default", "改回默认"),
        primaryResult: true,
      ),
    );
    if (confirmed != true) return;
    await OutputStore.clear();
    if (!mounted) return;
    setState(() => _target = null);
    _toast(S.t("Default folder restored.", "已改回默认目录。"));
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: Text(S.t("Settings", "设置")),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _languagePanel(scheme),
                const SizedBox(height: 16),
                _hardwarePanel(scheme),
                const SizedBox(height: 16),
                _performancePanel(scheme),
                const SizedBox(height: 16),
                if (Platform.isWindows) ...<Widget>[
                  _shortcutsPanel(scheme),
                  const SizedBox(height: 16),
                ],
                _folderPanel(scheme),
                const SizedBox(height: 16),
                _appearancePanel(scheme),
                const SizedBox(height: 16),
                _fontPanel(scheme),
                const SizedBox(height: 16),
                _frameRatePanel(scheme),
                const SizedBox(height: 16),
                _aboutPanel(scheme),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languagePanel(ColorScheme scheme) {
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle(scheme, Icons.translate_rounded, S.t("Language", "界面语言")),
          const SizedBox(height: 6),
          Text(
            S.t(
              "Changes apply immediately. “System” follows the phone language.",
              "切换后立即生效。“跟随系统”会跟着手机语言走。",
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: S.systemMode,
                  label: Text(S.t("System", "系统")),
                ),
                ButtonSegment<String>(value: S.zhMode, label: const Text("中文")),
                ButtonSegment<String>(
                  value: S.enMode,
                  label: const Text("English"),
                ),
              ],
              selected: <String>{S.mode},
              onSelectionChanged: (Set<String> value) {
                Haptics.selectionClick();
                S.setMode(value.first);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _hardwarePanel(ColorScheme scheme) {
    final HardwareProfile? profile = _hardware;
    final bool windows = profile?.isWindows ?? Platform.isWindows;
    final bool unknown =
        profile == null ||
        profile.error.isNotEmpty ||
        (!windows && !profile.socKnown && profile.isAndroid);
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _panelTitle(
                  scheme,
                  Icons.memory_rounded,
                  S.t("This device", "本机硬件"),
                ),
              ),
              IconButton(
                tooltip: S.t("Read again", "重新识别"),
                onPressed: _loadHardware,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (profile == null)
            Text(
              S.t("Reading the chip and codec list…", "正在读取芯片和编码器列表…"),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else ...[
            _factRow(
              scheme,
              S.t("Processor", "处理器"),
              windows ? profile.cpuLabel : profile.socLabel,
              warning: unknown,
            ),
            _factRow(
              scheme,
              S.t("Cores / RAM", "核心 / 内存"),
              windows
                  ? "${profile.physicalCores} cores · ${profile.logicalCores} threads · ${profile.totalRamMb} MB"
                  : "${profile.cores} cores · ${profile.totalRamMb} MB",
              warning: profile.cores <= 0 || profile.totalRamMb <= 0,
            ),
            _factRow(
              scheme,
              S.t("AV1", "AV1"),
              windows
                  ? S.t("Software only (libaom)", "仅软件（libaom）")
                  : profile.av1Text,
              warning: !profile.av1Decode,
            ),
            _factRow(
              scheme,
              windows
                  ? S.t("GPU encoders", "GPU 编码器")
                  : S.t("MediaCodec encoders", "MediaCodec 编码器"),
              windows
                  ? "NVENC ${profile.nvencAvailable ? "✓" : "—"} · AMF ${profile.amfAvailable ? "✓" : "—"}"
                  : profile.hasHardwareEncoder
                  ? "H.264 ${profile.avcEncode ? "✓" : "—"} · H.265 ${profile.hevcEncode ? "✓" : "—"}"
                  : S.t("None detected", "未检测到"),
              warning: !profile.hasHardwareEncoder,
            ),
            if (profile.lowRam)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  S.t(
                    "The system reports a low-RAM device. Keep exports short and leave the default memory budget alone.",
                    "系统报告这是低内存设备。导出短一点，内存上限保持默认。",
                  ),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.error),
                ),
              ),
            if (unknown)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  S.t(
                    "The processor name could not be read. Hardware acceleration stays available but is treated as unverified; check one short export before a long batch.",
                    "读不到具体处理器型号。硬件加速仍可用，但按未验证处理；长批次前先跑一条短视频确认。",
                  ),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.error),
                ),
              ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                S.t("GPU and acceleration", "GPU 与加速"),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(
                S.t(
                  windows
                      ? "NVENC / AMF use the GPU's fixed-function encoder. Intel Quick Sync is detected but kept off in this build."
                      : "Experimental on Android: MediaCodec is a dedicated video unit, not the GPU shader cores.",
                  windows
                      ? "NVENC / AMF 使用显卡的固定功能编码单元。Intel Quick Sync 会显示，但这一版不启用。"
                      : "安卓端为实验功能：MediaCodec 是专用视频单元，不是 GPU 着色器。",
                ),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              children: <Widget>[
                _factRow(
                  scheme,
                  "GPU",
                  profile.gpuLabel,
                  warning: !profile.gpuKnown,
                ),
                Text(
                  S.t(
                    windows
                        ? "Hardware encoding is limited to H.264 / H.265. AV1 export stays on libaom and is marked experimental."
                        : "Hardware encoding is used for H.264 / H.265 only. AV1 has hardware decode on current flagships but no hardware encoder, so AV1 export stays on libaom and is slow.",
                    windows ? "硬件编码只覆盖 H.264 / H.265。AV1 导出仍走 libaom，标为实验功能。" : "硬件编码只用于 H.264 / H.265。当前旗舰的 AV1 有硬件解码但没有硬件编码器，所以 AV1 导出仍走 libaom，速度慢。",
                  ),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (profile.error.isNotEmpty)
              Text(
                profile.error,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.error),
              ),
          ],
        ],
      ),
    );
  }

  Widget _factRow(
    ColorScheme scheme,
    String name,
    String value, {
    bool warning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              name,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: warning ? scheme.error : scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _performancePanel(ColorScheme scheme) {
    final int threads = AppPreferences.threadLimit;
    final int memory = AppPreferences.memoryBudgetMb;
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle(
            scheme,
            Icons.speed_rounded,
            S.t("Background and limits", "后台与上限"),
          ),
          const SizedBox(height: 6),
          Text(
            Platform.isWindows
                ? S.t(
                    "Windows keeps the window and the conversion process together. Closing the window stops the job; there is no background service.",
                    "Windows 版窗口和转换进程绑定。关掉窗口就会停止任务，没有后台服务。",
                  )
                : S.t(
                    "Android only. Lock the app in Recents, allow unrestricted battery use, then come back and confirm here. Turning this off returns the app to normal foreground limits.",
                    "仅安卓。把应用在最近任务里锁定、电池设为无限制，再回来这里确认启用。关掉后恢复普通前台限制。",
                  ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (!Platform.isWindows)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.t("Keep working in background", "允许后台驻留")),
              subtitle: Text(
                S.t(
                  "Needs the system background lock and unrestricted battery. The app still shows a foreground notification while a job runs.",
                  "需要系统后台锁定和无限制电池。任务运行时仍会显示前台通知。",
                ),
              ),
              value: AppPreferences.backgroundMode,
              onChanged: (bool value) {
                Haptics.selectionClick();
                AppPreferences.setBackgroundMode(value);
              },
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Platform.isWindows
                ? Text(S.t("Use GPU encoder when available", "有 GPU 编码器时使用"))
                : Text(S.t("Use MediaCodec when available", "有硬件编码器时使用")),
            subtitle: Text(
              S.t(
                Platform.isWindows
                    ? "NVENC / AMF, H.264 / H.265 only. A failed hardware run retries on the CPU."
                    : "Experimental on Android. H.264 / H.265 only; AV1 stays software.",
                Platform.isWindows
                    ? "NVENC / AMF，只对 H.264 / H.265 生效。硬件运行失败会自动回到 CPU 重试。"
                    : "安卓端实验功能。只对 H.264 / H.265 生效；AV1 仍走软件。",
              ),
            ),
            value: AppPreferences.hardwareEncoding,
            onChanged: (bool value) {
              Haptics.selectionClick();
              AppPreferences.setHardwareEncoding(value);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  S.t("Thread cap", "线程上限"),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                threads == 0 ? S.t("Auto", "自动") : "$threads",
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          Slider(
            value: threads.toDouble(),
            min: 0,
            max: 8,
            divisions: 8,
            label: threads == 0 ? S.t("Auto", "自动") : "$threads",
            onChanged: (double value) {
              AppPreferences.setThreadLimit(value.round());
            },
          ),
          Text(
            S.t(
              "Auto lets FFmpeg decide. 1 thread is very slow; 6–8 can starve the foreground. The useful range is 2–4.",
              "自动由 FFmpeg 决定。1 线程很慢；6–8 会抢前台资源。常用范围是 2–4。",
            ),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  S.t("Memory budget", "内存上限"),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                memory == 0 ? S.t("System default", "系统默认") : "$memory MB",
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          Slider(
            value: memory == 0 ? 0 : memory.toDouble(),
            min: 0,
            max: 4096,
            divisions: 32,
            label: memory == 0 ? S.t("System default", "系统默认") : "$memory MB",
            onChanged: (double value) {
              final int next = value <= 0 ? 0 : (value / 128).round() * 128;
              AppPreferences.setMemoryBudgetMb(next);
            },
          ),
          Text(
            S.t(
              "0 means no app-side cap. The provisional floor is 512 MB and the ceiling is 4096 MB; this range is waiting for your confirmation. Android may still kill the process under pressure, and virtual RAM is not requested on purpose.",
              "0 表示不设应用侧上限。暂定下限 512 MB、上限 4096 MB，这个范围等你确认。系统压力大时仍可能杀掉进程；不会主动占用厂商虚拟内存。",
            ),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (threads == 1 || threads >= 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                threads == 1
                    ? S.t(
                        "One thread keeps the phone usable but can be extremely slow.",
                        "单线程能让手机保持可用，但会非常慢。",
                      )
                    : S.t(
                        "Six to eight threads can make the foreground stutter; use 1–4 unless the phone can spare it.",
                        "6 到 8 线程会让前台卡顿；除非手机扛得住，建议 1–4。",
                      ),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shortcutsPanel(ColorScheme scheme) {
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _panelTitle(scheme, Icons.keyboard_rounded, S.t("Shortcuts", "快捷键")),
          const SizedBox(height: 6),
          Text(
            S.t(
              "Ctrl+O adds files, Ctrl+Enter starts or cancels, Esc cancels, Ctrl+, opens Settings. These are fixed in 1.6 and do not change the Android build.",
              "Ctrl+O 添加文件，Ctrl+Enter 开始或取消，Esc 取消，Ctrl+, 打开设置。1.6 固定这套组合，不影响安卓版。",
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _factRow(scheme, "Ctrl+O", S.t("Add video / audio", "添加视频 / 音频")),
          _factRow(scheme, "Ctrl+Enter", S.t("Start / cancel", "开始 / 取消")),
          _factRow(scheme, "Esc", S.t("Cancel the running job", "取消正在跑的任务")),
          _factRow(scheme, "Ctrl+,", S.t("Open Settings", "打开设置")),
        ],
      ),
    );
  }

  Widget _folderPanel(ColorScheme scheme) {
    final String folder =
        _target?.name ?? S.t("App's own folder (default)", "应用专属目录（默认）");
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _panelTitle(
                  scheme,
                  Icons.folder_outlined,
                  S.t("Save results to", "转换结果存到"),
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            folder,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            S.t(
              "Pick a folder through the system picker. The permission survives a restart, and finished files go there directly. Once it is set, completed rows show Done instead of Share.",
              "通过系统文件夹选择器授权，重启后仍有效。设置后结果直接写进去，完成栏显示“已完成”，不再给分享按钮。",
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : _pickTarget,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(
                    _target == null
                        ? S.t("Choose folder", "选择文件夹")
                        : S.t("Change folder", "换一个文件夹"),
                  ),
                ),
              ),
              if (_target != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _busy ? null : _clearTarget,
                  tooltip: S.t("Use default", "改回默认"),
                  icon: const Icon(Icons.folder_off_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearancePanel(ColorScheme scheme) {
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle(scheme, Icons.palette_outlined, S.t("Appearance", "外观")),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text(S.t("System", "系统")),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text(S.t("Light", "浅色")),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text(S.t("Dark", "深色")),
                ),
              ],
              selected: <ThemeMode>{AppPreferences.themeMode},
              onSelectionChanged: (Set<ThemeMode> value) {
                Haptics.selectionClick();
                AppPreferences.setThemeMode(value.first);
              },
            ),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.t("Haptic feedback", "震动反馈")),
            subtitle: Text(
              S.t(
                "On by default. Turn it off to stop every tap and impact vibration.",
                "默认开启。关闭后所有点按和操作震动都会停。",
              ),
            ),
            value: Haptics.enabled,
            onChanged: (bool value) {
              setState(() => Haptics.enabled = value);
              Haptics.setEnabled(value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            S.t("Accent colour", "主题色"),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: kAccentPalette.map((item) {
              final bool selected =
                  AppPreferences.seed.toARGB32() == item.$1.toARGB32();
              final String label = S.t(item.$2, item.$3);
              return Semantics(
                button: true,
                selected: selected,
                label: label,
                child: Tooltip(
                  message: label,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      Haptics.selectionClick();
                      AppPreferences.setSeed(item.$1);
                    },
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: item.$1,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? scheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _fontPanel(ColorScheme scheme) {
    final String current = FontManager.selectedPath?.split(Platform.pathSeparator).last ??
        S.t("System default", "系统默认");
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle(scheme, Icons.font_download_outlined, S.t("Fonts", "字体")),
          const SizedBox(height: 6),
          Text(
            S.t("Current: $current", "当前：$current"),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            S.t(
              "Import TTF/OTF/TTC files, or put them in the app's font folder and tick one in the manager. Untick to return to the system font. Android does not allow a normal app to replace system fonts; this affects this app only.",
              "可导入 TTF/OTF/TTC，或把文件放进应用字体文件夹，在管理页勾选。取消勾选回到系统字体。安卓不允许普通应用替换系统字体，这里只改本应用。",
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () {
              Haptics.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FontManagerPage(),
                ),
              );
            },
            icon: const Icon(Icons.manage_search_rounded),
            label: Text(S.t("Manage fonts", "管理字体")),
          ),
        ],
      ),
    );
  }

  Widget _frameRatePanel(ColorScheme scheme) {
    final bool cfr = AppPreferences.defaultForceCfr;
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle(
            scheme,
            Icons.speed_rounded,
            S.t("Default frame rate", "默认帧率"),
          ),
          const SizedBox(height: 6),
          Text(
            S.t(
              "New recipes start with this. Passthrough keeps the source timing; a fixed rate repeats or drops frames and does not interpolate.",
              "新建任务按这里的默认值起步。跟随源保留源时间基；固定帧率只补重复帧或丢帧，不插帧。",
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.t("Use a fixed frame rate", "默认固定帧率")),
            value: cfr,
            onChanged: (bool value) {
              Haptics.selectionClick();
              AppPreferences.setDefaultForceCfr(value);
            },
          ),
          if (cfr) ...[
            FrameRateField(
              value: AppPreferences.defaultTargetFps,
              onChanged: AppPreferences.setDefaultTargetFps,
            ),
          ],
        ],
      ),
    );
  }

  Widget _aboutPanel(ColorScheme scheme) {
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle(
            scheme,
            Icons.info_outline_rounded,
            "Reencode $kAppVersion",
          ),
          const SizedBox(height: 8),
          Text(
            S.t(
              "Video bitrate, codec and container conversion. Open source under GPL-3.0. No ads, no tracking, no network access.",
              "视频码率、编码和容器转换。GPL-3.0 开源，无广告、无追踪、不联网。",
            ),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).push<bool>(appPageRoute(builder: (_) => const LicensesPage())),
              icon: const Icon(Icons.gavel_outlined),
              label: Text(S.t("Licenses, source and privacy", "许可、源码与隐私")),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelTitle(ColorScheme scheme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(width: 10),
        Flexible(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }

  Widget _panel(ColorScheme scheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
      ),
      child: child,
    );
  }
}
