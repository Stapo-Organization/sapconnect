import 'package:flutter/material.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Where a hosted payment attempt currently stands.
enum PaymentPhase { opening, waiting, failed }

/// The waiting room.
///
/// It says exactly one true thing at a time. "Finish paying in the window" is
/// honest while the tab is open; a fake progress bar pretending to know how
/// far along a 3-D Secure challenge is, is not.
class PaymentStatusView extends StatelessWidget {
  const PaymentStatusView({
    super.key,
    required this.phase,
    required this.orderNumber,
    required this.onRetry,
    required this.onOpenOrder,
    this.message,
    this.notice,
  });

  final PaymentPhase phase;
  final String orderNumber;
  final String? message;

  /// Why the customer ended up here rather than on the in-app card form. Shown
  /// once, above the status, because arriving somewhere unexpected without
  /// being told why is how a checkout loses people.
  final String? notice;

  final VoidCallback onRetry;
  final VoidCallback onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    final (title, body) = switch (phase) {
      PaymentPhase.opening => (l.paymentOpening, null),
      PaymentPhase.waiting => (l.paymentWaiting, l.paymentWaitingHint),
      PaymentPhase.failed => (l.paymentFailedTitle, message ?? l.paymentFailedHint),
    };

    final notice = this.notice;

    return Column(
      children: [
        if (notice != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(ZbTokens.rMd),
            ),
            child: Text(
              notice,
              textAlign: TextAlign.center,
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        const Spacer(),
        _Mark(phase: phase),
        Gap.h24,
        Text(title, style: context.tt.titleLarge, textAlign: TextAlign.center),
        if (body != null) ...[
          Gap.h8,
          Text(
            body,
            style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
        Gap.h16,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(ZbTokens.rPill),
          ),
          child: Text(
            l.successOrderNumber(orderNumber),
            textDirection: TextDirection.ltr,
            style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const Spacer(),
        if (phase == PaymentPhase.failed) ...[
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(l.actionRetry),
            style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          ),
          Gap.h8,
          OutlinedButton(
            onPressed: onOpenOrder,
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: Text(l.paymentViewOrder),
          ),
          Gap.h12,
          Text(
            l.paymentSupportHint,
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton(
              onPressed: onOpenOrder,
              child: Text(l.paymentViewOrder),
            ),
          ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.phase});

  final PaymentPhase phase;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final failed = phase == PaymentPhase.failed;

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!failed)
            SizedBox(
              width: 96,
              height: 96,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: cs.primary,
                backgroundColor: cs.primary.withValues(alpha: 0.14),
              ),
            ),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: failed
                  ? cs.errorContainer.withValues(alpha: 0.6)
                  : cs.primaryContainer.withValues(alpha: 0.5),
            ),
            child: Icon(
              failed ? Icons.error_outline_rounded : Icons.lock_rounded,
              size: 30,
              color: failed ? cs.error : cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}
