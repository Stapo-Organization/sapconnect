import 'package:flutter/material.dart';

import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Step 3 — first sign-in only: a name to greet them by, and an optional
/// email for receipts. Both are skippable in practice, since the submit
/// button never blocks on them.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap.h8,
        TextField(
          controller: nameController,
          enabled: !busy,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: l.authNameLabel,
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
        ),
        Gap.h12,
        TextField(
          controller: emailController,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => onSubmit(),
          decoration: InputDecoration(
            labelText: l.authEmailLabel,
            prefixIcon: const Icon(Icons.alternate_email_rounded),
          ),
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
              : Text(l.authFinish),
        ),
        Gap.h8,
      ],
    );
  }
}
