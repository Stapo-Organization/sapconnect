import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/zb_colors.dart';
import '../../app/theme/zooboxi_tokens.dart';
import '../motion/motion.dart';
import '../utils/haptics.dart';

/// Four-digit OTP entry rendered as boxes.
///
/// One hidden field backs all four boxes rather than four focus-juggling
/// fields: that keeps SMS autofill working (iOS fills the whole code at once),
/// makes backspace behave, and means paste works.
class OtpBoxes extends StatefulWidget {
  const OtpBoxes({
    super.key,
    required this.controller,
    this.length = 4,
    this.onCompleted,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  final FocusNode _focus = FocusNode();
  String _lastValue = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    // The active-box ring tracks focus, so it has to repaint when focus moves.
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onChanged() {
    final value = widget.controller.text;
    if (value == _lastValue) return;
    final wasShorter = value.length > _lastValue.length;
    _lastValue = value;
    setState(() {});
    if (wasShorter) Haptics.selection();
    if (value.length == widget.length) {
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.controller.text;

    return Stack(
      children: [
        // The real field, invisible but focusable — autofill and the keyboard
        // attach to it.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ),
        GestureDetector(
          onTap: widget.enabled ? () => _focus.requestFocus() : null,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              final filled = index < digits.length;
              final active = index == digits.length && _focus.hasFocus;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _Box(
                  digit: filled ? digits[index] : '',
                  active: active,
                  hasError: widget.hasError,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.hasError});

  final String digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final borderColor = hasError
        ? cs.error
        : active
            ? cs.primary
            : (digit.isEmpty ? cs.outlineVariant : cs.outline);

    return AnimatedContainer(
      duration: Motion.select,
      curve: Motion.decelerate,
      width: 58,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ZbTokens.rMd),
        border: Border.all(color: borderColor, width: active || hasError ? 1.8 : 1.2),
      ),
      // The code itself is always LTR — a 4-digit number does not mirror.
      child: Text(
        digit,
        textDirection: TextDirection.ltr,
        style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
