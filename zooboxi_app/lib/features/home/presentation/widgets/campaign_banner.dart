import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/zb_image.dart';
import '../../../catalog/data/catalog_models.dart';
import 'campaign_chips.dart';
import 'campaign_composition.dart';
import 'campaign_impression.dart';
import 'link_navigation.dart';

/// A campaign placed between the rails.
///
/// Two shapes, picked by what artwork actually exists. A purpose-made wide
/// creative is trusted to carry the message and only gets the chips it can't
/// draw itself — a coupon code, a ticking deadline. Anything else is composed:
/// a painted panel, live copy, and the product photo bleeding off the end.
class CampaignBanner extends ConsumerWidget {
  const CampaignBanner({super.key, required this.campaign, this.zone = 'app_banner'});

  final Campaign campaign;

  /// Travels with the impression and the click, so the server can tell a
  /// mid-feed banner apart from the same creative in the hero.
  final String zone;

  static const double _wideAspect = 4;
  static const double _panelAspect = 2.2;
  static const double _maxTextScale = 1.3;

  /// Composed banners carry live copy, so — like the hero and the product card
  /// — the box grows with the text scale instead of clipping at 1.3×.
  static double _height(BuildContext context, double width, double aspect) {
    final factor =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _maxTextScale).scale(16) / 16;
    return width / aspect + (factor - 1) * 96;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wideArt = campaign.artFor(const ['wide', 'strip']);
    final art = wideArt ?? campaign.artFor(const ['app_hero', 'hero', 'card']);
    final panel = CampaignPanel.of(context, campaignType: campaign.campaignType);

    return CampaignImpression(
      campaign: campaign,
      zone: zone,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: _maxTextScale,
          child: LayoutBuilder(
            builder: (context, constraints) => PressScale(
              borderRadius: BorderRadius.circular(ZbTokens.rLg),
              onTap: () {
                trackCampaignClick(ref, campaign, zone);
                unawaited(followLink(
                  context,
                  ZbLink.fromUrl(campaign.linkUrl, productId: campaign.productId),
                  title: campaign.headline,
                ));
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ZbTokens.rLg),
                child: SizedBox(
                  height: _height(
                    context,
                    constraints.maxWidth,
                    wideArt != null ? _wideAspect : _panelAspect,
                  ),
                  child: wideArt != null
                      ? _WideBanner(campaign: campaign, panel: panel, art: wideArt)
                      : _PanelBanner(campaign: campaign, panel: panel, art: art),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Finished artwork. Nothing is drawn over it but the chips that must stay
/// live — a coupon code and a countdown are wrong the moment they are baked
/// into a JPEG.
class _WideBanner extends StatelessWidget {
  const _WideBanner({required this.campaign, required this.panel, required this.art});

  final Campaign campaign;
  final CampaignPanel panel;
  final String art;

  bool get _hasChips =>
      (campaign.badge ?? '').isNotEmpty ||
      campaign.couponCode != null ||
      (campaign.discountPct ?? 0) > 0 ||
      campaign.endsAt != null;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ZbImage(url: art, fit: BoxFit.cover),
        if (_hasChips) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          PositionedDirectional(
            start: 12,
            end: 12,
            bottom: 10,
            child: CampaignChipRow(campaign: campaign, panel: panel, maxChips: 3),
          ),
        ],
      ],
    );
  }
}

/// No wide crop to work with: compose the banner the same way the hero
/// composes a campaign slide, one step tighter.
class _PanelBanner extends StatelessWidget {
  const _PanelBanner({required this.campaign, required this.panel, required this.art});

  final Campaign campaign;
  final CampaignPanel panel;
  final String? art;

  @override
  Widget build(BuildContext context) {
    final headline = campaign.headline;
    final subheadline = campaign.subheadline;
    final cta = campaign.cta;

    return CampaignComposition(
      panel: panel,
      art: art,
      artFactor: 0.40,
      copyFactor: 0.64,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 10, top: 12, bottom: 12),
      copy: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((headline ?? '').isNotEmpty)
            Flexible(
              child: Text(
                headline!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.titleMedium?.copyWith(
                  color: panel.fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          if ((subheadline ?? '').isNotEmpty) ...[
            Gap.h4,
            Flexible(
              child: Text(
                subheadline!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.tt.bodySmall?.copyWith(color: panel.muted),
              ),
            ),
          ],
          if ((cta ?? '').isNotEmpty) ...[
            Gap.h8,
            CampaignCta(label: cta!, compact: true),
          ],
          Gap.h8,
          CampaignChipRow(campaign: campaign, panel: panel, maxChips: 2),
        ],
      ),
    );
  }
}
