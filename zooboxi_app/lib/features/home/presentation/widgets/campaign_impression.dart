import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/analytics/events_buffer.dart';
import '../../../catalog/data/catalog_models.dart';

/// The zone string the server's campaign rollups group by: it queries
/// `zone LIKE 'campaign:%'` and splits on `:`, so both the impression and the
/// click of one placement must spell it identically or the funnel breaks in
/// half. `payload.campaign_id` rides along for the joins that don't parse it.
String campaignZone(String campaignId, String zone) => 'campaign:$campaignId:$zone';

ZbEvent _event(String type, Campaign campaign, String zone) => ZbEvent(
      type: type,
      zone: campaignZone(campaign.campaignId, zone),
      campaignId: campaign.campaignId,
      abVariant: campaign.abVariant,
      itemCode: campaign.itemCode,
      payload: {'campaign_id': campaign.campaignId},
    );

/// One impression per campaign *per placement* per app session.
///
/// Session-scoped rather than per-widget: scrolling a banner off and back on
/// is the same impression, and counting it twice would halve every measured
/// click-through rate.
final Set<String> _seenThisSession = <String>{};

@visibleForTesting
void resetCampaignImpressions() => _seenThisSession.clear();

void trackCampaignImpression(WidgetRef ref, Campaign campaign, String zone) {
  final key = campaignZone(campaign.campaignId, zone);
  if (!_seenThisSession.add(key)) return;
  ref.track(_event(ZbEvents.impression, campaign, zone));
}

void trackCampaignClick(WidgetRef ref, Campaign campaign, String zone) =>
    ref.track(_event(ZbEvents.campaignClick, campaign, zone));

/// Fires [trackCampaignImpression] once the creative is at least half on
/// screen. Half, not a pixel: a banner clipped to a sliver at the fold was
/// never shown to anyone.
class CampaignImpression extends ConsumerWidget {
  const CampaignImpression({
    super.key,
    required this.campaign,
    required this.zone,
    required this.child,
  });

  final Campaign campaign;
  final String zone;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VisibilityDetector(
      key: ValueKey('zb-campaign-${campaign.campaignId}-$zone'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.5) return;
        trackCampaignImpression(ref, campaign, zone);
      },
      child: child,
    );
  }
}
