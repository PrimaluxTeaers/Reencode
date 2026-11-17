import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences/shared_preferences.dart";

/// Runtime localization. English and Chinese strings live together at each
/// call site; the settings page can override the system language.
class S {
  static const String systemMode = "system";
  static const String zhMode = "zh";
  static const String enMode = "en";

  static String _mode = systemMode;

  /// Bumped whenever the language changes so open pages rebuild in place.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool get _systemChinese {
    try {
      return PlatformDispatcher.instance.locale.languageCode == "zh";
    } catch (_) {
      return false;
    }
  }

  static String get mode => _mode;

  static bool get isChinese =>
      _mode == zhMode || (_mode == systemMode && _systemChinese);

  static Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString("languageMode");
      if (stored == zhMode || stored == enMode || stored == systemMode) {
        _mode = stored!;
      }
    } catch (_) {
      // Preferences are optional; the system language still works.
    }
  }

  static Future<void> setMode(String mode) async {
    if (mode != systemMode && mode != zhMode && mode != enMode) return;
    if (_mode == mode) return;
    _mode = mode;
    revision.value++;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString("languageMode", mode);
    } catch (_) {}
  }

  static String t(String en, String zh) => isChinese ? zh : en;
}

/// Persisted appearance choice, kept separate from the language because a
/// user may want a dark app while reading English.
class AppPreferences {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static ThemeMode themeMode = ThemeMode.system;
  static Color seed = const Color(0xFF0F5F66);
  static bool experimentalFrameRates = false;
  static bool hardwareEncoding = false;
  static bool backgroundMode = false;
  static int threadLimit = 0;
  static int memoryBudgetMb = 0;

  static Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? mode = prefs.getString("themeMode");
      if (mode == "light") {
        themeMode = ThemeMode.light;
      } else if (mode == "dark") {
        themeMode = ThemeMode.dark;
      } else {
        themeMode = ThemeMode.system;
      }
      final int? storedSeed = prefs.getInt("accentSeed");
      if (storedSeed != null) seed = Color(storedSeed);
      experimentalFrameRates = prefs.getBool("experimentalFrameRates") ?? false;
      hardwareEncoding = prefs.getBool("hardwareEncoding") ?? false;
      backgroundMode = prefs.getBool("backgroundMode") ?? false;
      threadLimit = prefs.getInt("threadLimit") ?? 0;
      memoryBudgetMb = prefs.getInt("memoryBudgetMb") ?? 0;
    } catch (_) {}
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) return;
    themeMode = mode;
    revision.value++;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        "themeMode",
        mode == ThemeMode.light
            ? "light"
            : mode == ThemeMode.dark
            ? "dark"
            : "system",
      );
    } catch (_) {}
  }

  static Future<void> setSeed(Color value) async {
    if (seed.toARGB32() == value.toARGB32()) return;
    seed = value;
    revision.value++;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt("accentSeed", value.toARGB32());
    } catch (_) {}
  }

  static Future<void> setExperimentalFrameRates(bool value) async {
    if (experimentalFrameRates == value) return;
    experimentalFrameRates = value;
    revision.value++;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("experimentalFrameRates", value);
    } catch (_) {}
  }

  static Future<void> setHardwareEncoding(bool value) async {
    if (hardwareEncoding == value) return;
    hardwareEncoding = value;
    revision.value++;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("hardwareEncoding", value);
    } catch (_) {}
  }

  static Future<void> setBackgroundMode(bool value) async {
    if (backgroundMode == value) return;
    backgroundMode = value;
    revision.value++;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("backgroundMode", value);
    } catch (_) {}
  }

  static Future<void> setThreadLimit(int value) async {
    final int next = value.clamp(0, 8);
    if (threadLimit == next) return;
    threadLimit = next;
    revision.value++;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt("threadLimit", next);
    } catch (_) {}
  }

  static Future<void> setMemoryBudgetMb(int value) async {
    final int next = value <= 0 ? 0 : value.clamp(512, 4096);
    if (memoryBudgetMb == next) return;
    memoryBudgetMb = next;
    revision.value++;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt("memoryBudgetMb", next);
    } catch (_) {}
  }
}
