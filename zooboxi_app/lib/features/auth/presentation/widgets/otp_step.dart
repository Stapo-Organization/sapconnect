import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/otp_boxes.dart';
import '../../../../l10n/app_localizations.dart';

/// Step 2 — the four-digit code, with the resend countdown.
class OtpStep extends StatelessWidget {
  const OtpStep({
    super.key,
    required this.controller,
    required this.busy,
    required this.hasError,
    required this.secondsLeft,
    required this.onCompleted,
    required this.onResend,
    required this.onChangeNumber,
    this.error,
  });

  final TextEditingController controller;
  final bool busy;
  final bool hasError;
  final String? error;
  final int secondsLeft;
  final ValueChanged<String> onCompleted;
  final VoidCallback onResend;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final canResend = secondsLeft <= 0 && !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap.h12,
        OtpBoxes(
          controller: controller,
          enabled: !busy,
          hasError: hasError,
          onCompleted: onCompleted,
        ),
        if (error != null) ...[
          Gap.h12,
          Text(
            error!,
            textAlign: TextAlign.center,
            style: context.tt.bodySmall?.copyWith(color: cs.error),
          ),
        ],
        Gap.h16,
        if (busy)
          const Center(
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
          )
        else
          Center(
            child: canResend
                ? TextButton.icon(
                    onPressed: onResend,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l.authResend),
                  )
                : Text(
                    l.authResendIn(secondsLeft),
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
          ),
        Gap.h4,
        Center(
          child: TextButton(
            onPressed: busy ? null : onChangeNumber,
            child: Text(l.authChangeNumber),
          ),
        ),
        Gap.h8,
      ],
    );
  }
}
