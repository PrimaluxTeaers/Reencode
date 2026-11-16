import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";

import "dialogs.dart";
import "hardware_profile.dart";
import "l10n.dart";
import "licenses_page.dart";
import "output_store.dart";
import "page_route.dart";
import "theme.dart";

const String kAppVersion = "1.0.0";

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
    if (Platform.isWindows) {
      HardwareProbe.read().then((HardwareProfile profile) {
        if (mounted) setState(() => _hardware = profile);
      });
    }
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
      HapticFeedback.selectionClick();
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
                _folderPanel(scheme),
                const SizedBox(height: 16),
                if (Platform.isWindows) ...[
                  _hardwarePanel(scheme),
                  const SizedBox(height: 16),
                ],
                _appearancePanel(scheme),
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
                HapticFeedback.selectionClick();
                S.setMode(value.first);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Windows only. The CPU line is informational; the GPU line is the one that
  /// matters, because Intel and other vendors deliberately get no hardware path.
  Widget _hardwarePanel(ColorScheme scheme) {
    final HardwareProfile? hw = _hardware;
    final TextStyle? noteStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return _panel(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelTitle(scheme, Icons.memory_rounded, S.t("Hardware", "硬件")),
          const SizedBox(height: 10),
          Text(
            hw == null
                ? S.t("Reading hardware information…", "正在读取硬件信息…")
                : "${hw.cpuName} · ${hw.physicalCores}C/${hw.logicalCores}T · L3 ${hw.l3Mb} MB",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (hw != null) ...[
            const SizedBox(height: 6),
            Text(_gpuNote(hw), style: noteStyle),
          ],
        ],
      ),
    );
  }

  String _gpuNote(HardwareProfile hw) {
    switch (hw.gpuVendor) {
      case "nvidia":
        return hw.nvencAvailable
            ? S.t("NVIDIA NVENC is available.", "NVIDIA NVENC 可用。")
            : S.t(
                "NVIDIA GPU found, but NVENC did not start. Falling back to CPU.",
                "检测到 NVIDIA 显卡，但 NVENC 没能启动，改用 CPU。",
              );
      case "amd":
        return hw.amfAvailable
            ? S.t("AMD AMF is available.", "AMD AMF 可用。")
            : S.t(
                "AMD GPU found, but AMF did not start. Falling back to CPU.",
                "检测到 AMD 显卡，但 AMF 没能启动，改用 CPU。",
              );
      case "intel":
        return S.t(
          "Intel and Arc graphics are not supported for hardware encoding. Encoding runs on the CPU.",
          "Intel 核显与 Arc 不提供硬件加速，编码全部走 CPU。",
        );
      default:
        return S.t(
          "No supported GPU found. Hardware acceleration is off; encoding runs on the CPU.",
          "没有受支持的显卡，硬件加速关闭，编码走 CPU。",
        );
    }
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
                HapticFeedback.selectionClick();
                AppPreferences.setThemeMode(value.first);
              },
            ),
          ),
          const SizedBox(height: 18),
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
                      HapticFeedback.selectionClick();
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
