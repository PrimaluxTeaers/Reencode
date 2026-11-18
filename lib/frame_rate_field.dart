import "package:material_ui/material_ui.dart";

import "bounded_number_field.dart";
import "dialogs.dart";
import "l10n.dart";

/// Frame-rate control shared by the output recipe and the settings page.
///
/// Normal range: fixed stops from 24 to 60, plus an exact integer field capped
/// at 60. 90 and 120 are independent experimental chips below the normal
/// control. 144 appears only after four taps on 120 and a confirmation.
class FrameRateField extends StatefulWidget {
  const FrameRateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  State<FrameRateField> createState() => _FrameRateFieldState();
}

class _FrameRateFieldState extends State<FrameRateField> {
  static const List<int> _normalStops = <int>[24, 25, 30, 48, 50, 60];
  int _tap120 = 0;
  bool _unlocked144 = false;

  @override
  void initState() {
    super.initState();
    _unlocked144 = widget.value >= 144;
  }

  int get _normalIndex {
    int best = 0;
    for (int i = 1; i < _normalStops.length; i++) {
      if ((_normalStops[i] - widget.value).abs() <
          (_normalStops[best] - widget.value).abs()) {
        best = i;
      }
    }
    return best;
  }

  void _select(int fps) {
    if (!widget.enabled) return;
    if (fps == 144 && !_unlocked144) return;
    if (fps == 120) {
      _tap120++;
      if (_tap120 >= 4) {
        _tap120 = 0;
        widget.onChanged(120);
        _unlock144();
        return;
      }
    } else {
      _tap120 = 0;
    }
    widget.onChanged(fps);
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
      setState(() => _unlocked144 = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int index = _normalIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Slider(
                value: index.toDouble(),
                min: 0,
                max: (_normalStops.length - 1).toDouble(),
                divisions: _normalStops.length - 1,
                label: "${_normalStops[index]} fps",
                onChanged: widget.enabled
                    ? (double raw) => _select(
                        _normalStops[raw.round().clamp(
                          0,
                          _normalStops.length - 1,
                        )],
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            BoundedNumberField(
              value: widget.value,
              min: 24,
              max: 60,
              enabled: widget.enabled,
              suffix: "fps",
              width: 92,
              onChanged: (int next) {
                _tap120 = 0;
                widget.onChanged(next);
              },
            ),
          ],
        ),
        Text(
          S.t(
            "Normal range: fixed stops 24 / 25 / 30 / 48 / 50 / 60. The number field accepts 24–60 only; values above 60 need an experimental chip.",
            "正常范围：固定档 24 / 25 / 30 / 48 / 50 / 60。数字框只收 24–60；超过 60 只能用下面的实验档。",
          ),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _normalStops.map((int fps) {
            return ChoiceChip(
              selected: widget.value == fps,
              onSelected: widget.enabled ? (_) => _select(fps) : null,
              label: Text("$fps fps"),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Text(
          S.t("Experimental frame rates", "实验帧率档"),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final int fps in <int>[90, 120])
              ChoiceChip(
                selected: widget.value == fps,
                onSelected: widget.enabled ? (_) => _select(fps) : null,
                label: Text("$fps fps"),
              ),
            if (_unlocked144)
              ChoiceChip(
                selected: widget.value == 144,
                onSelected: widget.enabled ? (_) => _select(144) : null,
                label: Text(S.t("144 fps (high risk)", "144 帧（高危）")),
              ),
          ],
        ),
        if (widget.value >= 90) ...[
          const SizedBox(height: 8),
          Text(
            widget.value >= 144
                ? S.t(
                    "144 fps is experimental and high-risk. Fixed-rate conversion repeats or drops frames; it does not add real motion.",
                    "144 帧是实验高危档。固定帧率只补重复帧或丢帧，不会增加真实运动。",
                  )
                : S.t(
                    "90/120 fps are experimental. Fixed-rate conversion repeats or drops frames; it does not make 30 fps source look smoother.",
                    "90/120 帧是实验档。固定帧率只补重复帧或丢帧；30 帧源不会因此变流畅。",
                  ),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.error),
          ),
        ],
        if (!_unlocked144) ...[
          const SizedBox(height: 4),
          Text(
            S.t(
              "Tap 120 fps four times to reveal the 144 fps option.",
              "连点 120 帧四次，才会出现 144 帧选项。",
            ),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
