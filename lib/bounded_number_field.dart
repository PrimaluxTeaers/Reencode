import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";

/// A text field for one integer setting.
///
/// Typing is not clamped on every keystroke: an intermediate "1" on the way to
/// "1080" must not jump to the minimum. The value is committed on submit or
/// when focus leaves, then clamped to [min]..[max].
class BoundedNumberField extends StatefulWidget {
  const BoundedNumberField({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
    this.suffix,
    this.hint,
    this.width,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final String? suffix;
  final String? hint;
  final double? width;

  @override
  State<BoundedNumberField> createState() => _BoundedNumberFieldState();
}

class _BoundedNumberFieldState extends State<BoundedNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: "${widget.value}",
  );
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant BoundedNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _syncText();
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _commit();
  }

  void _syncText() {
    final String text = "${widget.value}";
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _commit() {
    final int? parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      _syncText();
      return;
    }
    final int next = parsed.clamp(widget.min, widget.max);
    if (next != widget.value) {
      widget.onChanged(next);
    } else {
      _syncText();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter("${widget.max}".length),
      ],
      decoration: InputDecoration(
        isDense: true,
        suffixText: widget.suffix,
        hintText: widget.hint,
      ),
      onSubmitted: (_) {
        _commit();
        _focus.unfocus();
      },
    );
    return widget.width == null
        ? field
        : SizedBox(width: widget.width, child: field);
  }
}
