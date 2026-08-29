import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Renders a numeric string where each character fades + slides up whenever it
/// changes or a new digit appears (odometer-style). Purely presentational — it
/// does not handle input. Pair it with [AnimatedAmountField] for editable
/// amounts.
class AnimatedDigits extends StatelessWidget {
  final String text;
  final TextStyle style;

  const AnimatedDigits({super.key, required this.text, required this.style});

  static bool _isDigit(String ch) {
    final c = ch.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  @override
  Widget build(BuildContext context) {
    // Key each digit by its position counted from the LEFT among digits only,
    // so appending a new digit gives it a fresh key (it animates) while the
    // existing digits keep their key even when a grouping separator shifts the
    // raw string index. Separators (',' '.') are structural and don't animate.
    final children = <Widget>[];
    var digitRank = 0;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (_isDigit(ch)) {
        children.add(
          Text(ch, style: style)
              .animate(key: ValueKey('d$digitRank:$ch'))
              .fadeIn(duration: 180.ms)
              .slideY(
                begin: 0.45,
                end: 0,
                duration: 220.ms,
                curve: Curves.easeOutCubic,
              ),
        );
        digitRank++;
      } else {
        children.add(Text(ch, key: ValueKey('sep$digitRank'), style: style));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

/// An editable amount field that shows [AnimatedDigits] over a transparent
/// [TextField]. The text field keeps handling the system keyboard, caret and
/// formatting; the visible digits animate as the value changes.
class AnimatedAmountField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final TextStyle style;
  final Color cursorColor;
  final String hintText;
  final TextStyle hintStyle;
  final bool autofocus;
  final FocusNode? focusNode;
  final List<TextInputFormatter> inputFormatters;
  final TextAlign textAlign;

  const AnimatedAmountField({
    super.key,
    required this.controller,
    required this.style,
    required this.cursorColor,
    required this.hintStyle,
    this.onChanged,
    this.hintText = '0',
    this.autofocus = false,
    this.focusNode,
    this.inputFormatters = const [],
    this.textAlign = TextAlign.center,
  });

  @override
  State<AnimatedAmountField> createState() => _AnimatedAmountFieldState();
}

class _AnimatedAmountFieldState extends State<AnimatedAmountField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant AnimatedAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final showHint = text.isEmpty;
    final overlayAlign = switch (widget.textAlign) {
      TextAlign.left || TextAlign.start => Alignment.centerLeft,
      TextAlign.right || TextAlign.end => Alignment.centerRight,
      _ => Alignment.center,
    };

    return Stack(
      alignment: Alignment.center,
      children: [
        // Sizing + input layer: the transparent text field owns the caret,
        // keyboard and formatting. All theme borders/fill are stripped so it
        // renders nothing but the caret and sizes tightly to its content.
        IntrinsicWidth(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: widget.inputFormatters,
            textAlign: widget.textAlign,
            cursorColor: widget.cursorColor,
            style: widget.style.copyWith(color: Colors.transparent),
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: widget.hintText,
              hintStyle: widget.hintStyle.copyWith(color: Colors.transparent),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        // Visible, animated digits overlaid on top without affecting layout.
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: overlayAlign,
              child: showHint
                  ? Text(widget.hintText, style: widget.hintStyle)
                  : AnimatedDigits(text: text, style: widget.style),
            ),
          ),
        ),
      ],
    );
  }
}
