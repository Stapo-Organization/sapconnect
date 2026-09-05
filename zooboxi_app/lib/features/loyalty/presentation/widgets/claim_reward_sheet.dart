import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/analytics/events_buffer.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/error_text.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/bottom_sheet_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../cart/data/cart_controller.dart';
import '../../data/loyalty_models.dart';
import '../../data/loyalty_repository.dart';
import 'grant_card.dart';

/// Opens the "use a reward" sheet. Resolves `true` once one has actually been
/// carried into the cart, so the caller can celebrate only a real claim.
Future<bool> showClaimRewardSheet(BuildContext context) async {
  final claimed = await showZbSheet<bool>(
    context,
    builder: (_) => const ClaimRewardSheet(),
  );
  return claimed ?? false;
}

/// The rewards this customer can spend on the basket in front of them.
///
/// Deliberately not a picker of everything they own: a pending grant is not
/// usable yet and showing it here would only teach that the button lies.
class ClaimRewardSheet extends ConsumerStatefulWidget {
  const ClaimRewardSheet({super.key});

  @override
  ConsumerState<ClaimRewardSheet> createState() => _ClaimRewardSheetState();
}

class _ClaimRewardSheetState extends ConsumerState<ClaimRewardSheet> {
  int? _busyGrant;

  Future<void> _claim(Grant grant) async {
    if (_busyGrant != null) return;
    setState(() => _busyGrant = grant.id);
    Haptics.light();

    try {
      await ref.read(cartControllerProvider.notifier).claimGrant(grant.id);
      ref.read(eventsBufferProvider).track(
            ZbEvent(
              type: ZbEvents.loyaltyClaim,
              zone: 'cart',
              payload: {'grant_id': grant.id},
            ),
          );
      invalidateLoyalty(ref);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyGrant = null);
      AppToast.error(context, _message(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyGrant = null);
      AppToast.error(context, L.of(context).rewardClaimFailed);
    }
  }

  /// The server's own sentence wins; the app only supplies wording for the two
  /// refusals it can explain better than a generic error.
  String _message(ApiException e) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return switch (e.code) {
      LoyaltyErrors.giftUnavailable => l.rewardGiftUnavailable,
      LoyaltyErrors.grantNotActive || LoyaltyErrors.alreadyClaimed =>
        e.messageFor(locale) ?? l.rewardClaimFailed,
      _ => errorMessage(context, e),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final grants = ref.watch(claimableGrantsProvider);

    return BottomSheetScaffold(
      title: l.rewardSheetTitle,
      subtitle: l.rewardSheetHint,
      child: grants.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: EmptyState(
                icon: Icons.card_giftcard_rounded,
                title: l.rewardSheetEmpty,
                message: l.rewardsEmptyHint,
                compact: true,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final grant in grants) ...[
                  GrantCard(
                    grant: grant,
                    busy: _busyGrant == grant.id,
                    onUse: () => _claim(grant),
                  ),
                  Gap.h12,
                ],
                Gap.h4,
              ],
            ),
    );
  }
}
