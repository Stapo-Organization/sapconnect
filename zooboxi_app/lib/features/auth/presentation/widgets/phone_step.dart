import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Step 1 — the phone number.
class PhoneStep extends StatelessWidget {
  const PhoneStep({
    super.key,
    required this.controller,
    required this.busy,
    required this.onSubmit,
    this.error,
  });

  final TextEditingController controller;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap.h8,
        TextField(
          controller: controller,
          enabled: !busy,
          autofocus: true,
          keyboardType: TextInputType.phone,
          // A phone number is a number: it reads left-to-right even in Arabic.
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: context.tt.titleMedium?.copyWith(letterSpacing: 1.2),
          decoration: InputDecoration(
            labelText: l.authPhoneLabel,
            hintText: l.authPhoneHint,
            hintTextDirection: TextDirection.ltr,
            errorText: error,
            prefixIcon: const Icon(Icons.phone_iphone_rounded),
          ),
        ),
        Gap.h12,
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: cs.onSurfaceVariant),
            Gap.w6,
            Expanded(
              child: Text(
                l.authSubtitle,
                style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
        Gap.h20,
        FilledButton(
          onPressed: busy ? null : onSubmit,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : Text(l.authSendCode),
        ),
        Gap.h8,
      ],
    );
  }
}
