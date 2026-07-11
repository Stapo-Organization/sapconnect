import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/design_system/widgets/widgets.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';
import 'package:exhibition_manager_app/shared/widgets/skeleton_card.dart';
import 'package:exhibition_manager_app/shared/widgets/error_state_widget.dart';
import 'package:exhibition_manager_app/shared/widgets/full_screen_image_viewer.dart';
import 'package:exhibition_manager_app/features/promotions/data/promotions_repository.dart';
import 'package:exhibition_manager_app/features/promotions/data/models/campaign.dart';
import 'package:exhibition_manager_app/features/promotions/presentation/widgets/reject_feedback_sheet.dart';

/// Owner review & approval screen: creative gallery + editable Arabic copy +
/// offer/floor-safety + rationale + approve/reject/regenerate.
class PromotionDetailPage extends StatefulWidget {
  const PromotionDetailPage({super.key, required this.campaignId});

  final int campaignId;

  @override
  State<PromotionDetailPage> createState() => _PromotionDetailPageState();
}

class _PromotionDetailPageState extends State<PromotionDetailPage> {
  final PromotionsRepository _repo = PromotionsRepository();
  Campaign? _campaign;
  bool _loading = true;
  bool _hasError = false;
  bool _busy = false;

  String _variant = 'A';
  List<AdPlacement> _placements = const [];
  final _headline = TextEditingController();
  final _subheadline = TextEditingController();
  final _cta = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadPlacements();
  }

  Future<void> _loadPlacements() async {
    final res = await _repo.getPlacements();
    if (mounted && res.success) setState(() => _placements = res.placements);
  }

  @override
  void dispose() {
    _headline.dispose();
    _subheadline.dispose();
    _cta.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _hasError = false;
    });
    final res = await _repo.getCampaign(widget.campaignId);
    if (!mounted) return;
    setState(() {
      _campaign = res.campaign;
      _loading = false;
      _hasError = !res.success;
      if (res.campaign != null) {
        _variant = res.campaign!.variants.first;
        _headline.text = res.campaign!.headlineAr ?? '';
        _subheadline.text = res.campaign!.subheadlineAr ?? '';
        _cta.text = res.campaign!.ctaAr ?? '';
      }
    });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  /// Step 1: owner approves the concept → picks a placement → the single
  /// placement-sized creative is generated (preview). Not live yet.
  Future<void> _approveWithPlacement() async {
    final brand = _campaign?.brandName;
    final hasBrand = brand != null && brand.trim().isNotEmpty;
    final result = await showModalBottomSheet<({String placement, String identity})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlacementSheet(
        placements: _placements,
        brandName: brand,
        initialIdentity: _campaign?.designIdentity ?? (hasBrand ? 'brand' : 'zooboxi'),
      ),
    );
    if (result == null) return;
    setState(() => _busy = true);
    final res = await _repo.approve(
      _campaign!.id,
      placement: result.placement,
      designIdentity: result.identity,
      headline: _headline.text.trim(),
      subheadline: _subheadline.text.trim(),
      cta: _cta.text.trim(),
    );
    if (!mounted) return;
    if (res.success) {
      setState(() => _campaign = res.campaign ?? _campaign);
      _snack(context.tr('promo_generating_design'), AppDomain.promotions.accent);
      _pollUntilReady(); // wait for the preview image
    } else {
      setState(() => _busy = false);
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  /// Step 2: publish the previewed creative live into its placement.
  Future<void> _publish() async {
    setState(() => _busy = true);
    final res = await _repo.publish(_campaign!.id, variant: _variant);
    if (!mounted) return;
    if (res.success) {
      _snack(context.tr('promo_published_done'), AppColors.success);
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  Future<void> _reject() async {
    final result = await showRejectFeedback(context);
    if (result == null) return; // cancelled
    setState(() => _busy = true);
    final res = await _repo.reject(
      _campaign!.id,
      reason: result.reason.isEmpty ? null : result.reason,
      category: result.category,
    );
    if (!mounted) return;
    if (res.success) {
      _snack(context.tr('promo_rejected'), AppColors.warning);
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  Future<void> _regenerate() async {
    setState(() => _busy = true);
    final res = await _repo.regenerate(_campaign!.id);
    if (!mounted) return;
    if (res.success) {
      _snack(context.tr('promo_regenerating'), AppDomain.promotions.accent);
      _pollUntilReady();
    } else {
      setState(() => _busy = false);
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  /// AI edit: owner writes a note → backend re-renders the banner to it.
  Future<void> _refine() async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RefineSheet(initial: _campaign?.refinementNote),
    );
    if (note == null || note.trim().isEmpty) return;
    setState(() => _busy = true);
    final res = await _repo.refine(_campaign!.id, note.trim());
    if (!mounted) return;
    if (res.success) {
      _snack(context.tr('promo_refining'), AppDomain.promotions.accent);
      _pollUntilReady();
    } else {
      setState(() => _busy = false);
      _snack(res.error ?? context.tr('unexpected_error'), AppColors.error);
    }
  }

  /// Poll the campaign until its creatives finish (re)generating (~3 min cap).
  Future<void> _pollUntilReady() async {
    for (int i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      final res = await _repo.getCampaign(widget.campaignId);
      if (!mounted) return;
      if (res.campaign != null) {
        setState(() => _campaign = res.campaign);
        final stillGenerating = res.campaign!.creatives.any((c) => c.isGenerating);
        if (!stillGenerating && res.campaign!.creatives.isNotEmpty) break;
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    final c = _campaign;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('promotions')),
        bottomNavigationBar: (c != null && c.isReviewable && !_loading) ? _actionBar(c) : null,
        body: _loading
            ? const SkeletonList(itemCount: 4, cardHeight: 120)
            : _hasError || c == null
                ? ErrorStateWidget(onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, AppSpacing.xl),
                    children: [
                      _stageHeader(c),
                      const SizedBox(height: AppSpacing.base),
                      _gallery(c),
                      const SizedBox(height: AppSpacing.base),
                      _productsCard(c),
                      if (c.products.isNotEmpty) const SizedBox(height: AppSpacing.base),
                      _copyEditor(c),
                      const SizedBox(height: AppSpacing.base),
                      _offerCard(c),
                      const SizedBox(height: AppSpacing.base),
                      _rationaleCard(c),
                      const SizedBox(height: AppSpacing.base),
                      _scheduleNote(c),
                    ],
                  ),
      ),
    );
  }

  // ── stage stepper (concept → preview → published) ─────────
  Widget _stageHeader(Campaign c) {
    final accent = AppDomain.promotions.accent;
    final step = c.isSuggested ? 0 : (c.isPublished ? 2 : 1);
    final steps = <(IconData, String)>[
      (Icons.lightbulb_outline_rounded, context.tr('promo_stage_concept')),
      (Icons.visibility_outlined, context.tr('promo_stage_preview')),
      (Icons.public_rounded, context.tr('promo_stage_published')),
    ];
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i <= step ? accent : AppColors.surfaceVariant,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i <= step ? accent : AppColors.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(steps[i].$1, size: 18, color: i <= step ? Colors.white : AppColors.textTertiary),
                ),
                const SizedBox(height: 5),
                Text(
                  steps[i].$2,
                  style: AppTypography.labelSmall.copyWith(
                    color: i <= step ? accent : AppColors.textTertiary,
                    fontWeight: i == step ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── creative gallery ──────────────────────────────────────
  Widget _gallery(Campaign c) {
    final accent = AppDomain.promotions.accent;
    final creatives = c.creativesOf(_variant);
    final hero = creatives.isNotEmpty ? creatives.first : c.primaryCreative;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_rounded, color: accent, size: 20),
              const SizedBox(width: 6),
              Text(context.tr('promo_creative'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (c.isApproved && _hasReadyCreative(c))
                TextButton.icon(
                  onPressed: _busy ? null : _refine,
                  icon: Icon(Icons.auto_fix_high_rounded, size: 18, color: accent),
                  label: Text(context.tr('promo_edit_ad'),
                      style: AppTypography.labelSmall.copyWith(color: accent, fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              if (c.variants.length > 1)
                Row(
                  children: c.variants
                      .map((v) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(v),
                              selected: _variant == v,
                              selectedColor: accent.withValues(alpha: 0.18),
                              onSelected: (_) => setState(() => _variant = v),
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: AspectRatio(
              aspectRatio: 16 / 6,
              child: _heroPreview(c, hero),
            ),
          ),
          if (creatives.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: creatives
                  .map((cr) => ClipRRect(
                        borderRadius: AppRadius.borderSm,
                        child: SizedBox(
                          width: 80,
                          height: 64,
                          child: _zoomable(
                            cr.image,
                            _img(cr.image, fallbackIcon: Icons.image_outlined, generating: cr.isGenerating),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Hero slot: generating spinner → concept hint (no image yet) → ready image.
  Widget _heroPreview(Campaign c, AdCreative? hero) {
    final generating = (_busy && !_hasReadyCreative(c)) || (hero?.isGenerating ?? false);
    if (generating) {
      return _img(null, fallbackIcon: Icons.campaign_rounded, generating: true);
    }
    if (hero?.image == null) {
      return Container(
        color: AppColors.surfaceVariant,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppDomain.promotions.accent, size: 30),
                const SizedBox(height: 8),
                Text(context.tr('promo_no_image_yet'),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }
    return _zoomable(hero!.image, _img(hero.image, fallbackIcon: Icons.campaign_rounded));
  }

  Widget _img(String? url, {required IconData fallbackIcon, bool generating = false}) {
    if (generating) {
      return Container(
        color: AppColors.surfaceVariant,
        child: Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppDomain.promotions.accent),
          ),
        ),
      );
    }
    if (url == null) {
      return Container(color: AppColors.surfaceVariant, child: Icon(fallbackIcon, color: AppColors.textTertiary));
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (c, u) => Shimmer.fromColors(
        baseColor: AppColors.surfaceVariant,
        highlightColor: AppColors.surface,
        child: Container(color: Colors.white),
      ),
      errorWidget: (_, _, _) =>
          Container(color: AppColors.surfaceVariant, child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary)),
    );
  }

  bool _hasReadyCreative(Campaign c) => c.creativesOf(_variant).any((x) => x.isReady);

  /// Wrap an image so a tap opens it full-screen (with pinch-zoom).
  Widget _zoomable(String? url, Widget child) {
    if (url == null) return child;
    return GestureDetector(onTap: () => showFullScreenImage(context, url), child: child);
  }

  // ── original products (name / image / code) ───────────────
  Widget _productsCard(Campaign c) {
    if (c.products.isEmpty) return const SizedBox.shrink();
    final accent = AppDomain.promotions.accent;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: accent, size: 20),
              const SizedBox(width: 6),
              Text(context.tr('promo_products'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${c.products.length}', style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...c.products.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.borderSm,
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: _zoomable(
                          p.imageUrl,
                          _img(p.imageUrl, fallbackIcon: Icons.inventory_2_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          Text(p.itemCode, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── copy editor ───────────────────────────────────────────
  Widget _copyEditor(Campaign c) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('promo_copy'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          _field(_headline, context.tr('promo_headline')),
          const SizedBox(height: AppSpacing.sm),
          _field(_subheadline, context.tr('promo_subheadline')),
          const SizedBox(height: AppSpacing.sm),
          _field(_cta, context.tr('promo_cta')),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) => TextField(
        controller: ctrl,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(labelText: label),
      );

  // ── offer + floor safety ──────────────────────────────────
  Widget _offerCard(Campaign c) {
    final safe = c.floorSafe;
    final offerLabel = c.scope == 'coupon'
        ? context.tr('offer_coupon')
        : c.scope == 'bundle'
            ? context.tr('offer_bundle')
            : context.tr('offer_visibility');
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(context.tr('promo_offer'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              StatusBadge(label: offerLabel, color: AppDomain.promotions.accent, showDot: false, icon: Icons.local_offer_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: (safe ? AppColors.success : AppColors.error).withValues(alpha: 0.10),
              borderRadius: AppRadius.borderSm,
            ),
            child: Row(
              children: [
                Icon(safe ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                    color: safe ? AppColors.success : AppColors.error, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    safe ? context.tr('floor_safe') : context.tr('floor_breach'),
                    style: AppTypography.bodySmall.copyWith(
                        color: safe ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── rationale ─────────────────────────────────────────────
  Widget _rationaleCard(Campaign c) {
    final accent = AppDomain.promotions.accent;
    final chips = <Widget>[];
    void add(String key, String label, {bool pct = false}) {
      final v = c.rationale[key];
      if (v == null) return;
      final num? n = v is num ? v : num.tryParse(v.toString());
      final text = n != null ? (pct ? '${(n).toStringAsFixed(0)}%' : _fmt(n)) : v.toString();
      chips.add(_infoChip('$label: $text', accent));
    }

    add('lps', 'LPS');
    add('capital_at_risk', context.tr('rationale_capital'));
    add('days_of_cover', context.tr('rationale_cover'));
    add('composite_rank_score', context.tr('rationale_rank'));
    add('velocity_blended', context.tr('rationale_velocity'));
    add('fbt_lift', context.tr('rationale_fbt'));
    if (c.rationale['abc_class'] != null) chips.add(_infoChip('ABC: ${c.rationale['abc_class']}', accent));

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: accent.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlowIconChip(
                icon: Icons.insights_rounded,
                color: accent,
                size: 34,
                iconSize: 18,
                borderRadius: AppRadius.borderSm,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(context.tr('promo_why'), style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold))),
              // Tap to learn what this reason means and how we computed it.
              InkWell(
                onTap: () => _showReasonHelp(c),
                borderRadius: AppRadius.borderFull,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.help_outline_rounded, color: accent, size: 22),
                ),
              ),
            ],
          ),
          if ((c.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () => _showReasonHelp(c),
              borderRadius: AppRadius.borderSm,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(c.reason!, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  ),
                  Icon(Icons.info_outline_rounded, color: accent, size: 16),
                ],
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: chips),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(String text, Color accent) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: AppRadius.borderFull),
        child: Text(text, style: AppTypography.labelSmall.copyWith(color: accent, fontWeight: FontWeight.w700)),
      );

  // ── reason explanation popup ──────────────────────────────
  // Explains what the suggestion's reason means and exactly which signals (with
  // their live values + a plain-language gloss) drove it. Owner asked: "how did
  // you know capital is tied up?" — this answers it transparently.
  void _showReasonHelp(Campaign c) {
    final accent = AppDomain.promotions.accent;
    final help = _reasonHelp(c);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomSheetScaffold(
        title: context.tr('reason_help_title'),
        icon: Icons.lightbulb_rounded,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((c.reason ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: AppRadius.borderSm),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: accent, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(c.reason!, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(help.meaning, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.55)),
              if (help.metrics.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(context.tr('reason_help_how'),
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                for (final m in help.metrics) _metricRow(m, accent),
              ],
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: AppRadius.borderSm),
                child: Row(
                  children: [
                    Icon(Icons.verified_user_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(context.tr('reason_help_safe'),
                        style: AppTypography.labelSmall.copyWith(color: AppColors.textSecondary, height: 1.4))),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricRow((String, String, String) m, Color accent) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(m.$1,
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: AppRadius.borderFull),
                  child: Text(m.$2, style: AppTypography.labelSmall.copyWith(color: accent, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(m.$3, style: AppTypography.labelSmall.copyWith(color: AppColors.textTertiary, height: 1.4)),
          ],
        ),
      );

  /// Plain-language meaning + the live signals (label, value, gloss) that drove
  /// this suggestion, derived from the campaign's rationale.
  ({String meaning, List<(String, String, String)> metrics}) _reasonHelp(Campaign c) {
    final r = c.rationale;
    final metrics = <(String, String, String)>[];
    num? asNum(String k) {
      final v = r[k];
      return v is num ? v : num.tryParse('${v ?? ''}');
    }

    void add(String key, String label, String gloss, String Function(num) fmt) {
      final n = asNum(key);
      if (n != null) metrics.add((label, fmt(n), gloss));
    }

    switch (c.campaignType) {
      case 'clearance':
        add('lps', 'LPS', context.tr('gloss_lps'), (n) => _fmt(n));
        add('capital_at_risk', context.tr('rationale_capital'), context.tr('gloss_capital'),
            (n) => '${_fmt(n)} ${context.tr('currency_sar')}');
        add('days_of_cover', context.tr('rationale_cover'), context.tr('gloss_cover'),
            (n) => '${_fmt(n)} ${context.tr('unit_day')}');
        return (meaning: context.tr('reason_help_clearance'), metrics: metrics);
      case 'spotlight':
        add('composite_rank_score', context.tr('rationale_rank'), context.tr('gloss_rank'), (n) => '${_fmt(n)}/100');
        add('velocity_blended', context.tr('rationale_velocity'), context.tr('gloss_velocity'),
            (n) => '${_fmt(n)} ${context.tr('unit_per_day')}');
        if (r['abc_class'] != null) metrics.add(('ABC', '${r['abc_class']}', context.tr('gloss_abc')));
        return (meaning: context.tr('reason_help_spotlight'), metrics: metrics);
      case 'bundle':
        add('fbt_lift', context.tr('rationale_fbt'), context.tr('gloss_fbt'), (n) => '×${_fmt(n)}');
        return (meaning: context.tr('reason_help_bundle'), metrics: metrics);
      case 'express':
        add('in_stock_rate', context.tr('rationale_in_stock'), context.tr('gloss_in_stock'),
            (n) => '${(n * 100).round()}%');
        add('velocity_blended', context.tr('rationale_velocity'), context.tr('gloss_velocity'),
            (n) => '${_fmt(n)} ${context.tr('unit_per_day')}');
        return (meaning: context.tr('reason_help_express'), metrics: metrics);
      case 'new_arrival':
        add('current_stock', context.tr('rationale_stock'), context.tr('gloss_stock'), (n) => _fmt(n));
        return (meaning: context.tr('reason_help_new_arrival'), metrics: metrics);
      default:
        return (meaning: c.reason ?? '', metrics: metrics);
    }
  }

  Widget _scheduleNote(Campaign c) => Row(
        children: [
          Icon(Icons.schedule_rounded, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          Text(context.tr('publish_now'), style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        ],
      );

  // ── action bar (depends on stage: concept → preview) ──────
  Widget _actionBar(Campaign c) {
    final children = <Widget>[
      Expanded(
        child: AppButton(
          label: context.tr('promo_reject'),
          onPressed: _busy ? null : _reject,
          variant: AppButtonVariant.outline,
          color: AppColors.error,
        ),
      ),
    ];

    if (c.isSuggested) {
      // Concept stage: approve + pick placement (generates the preview image).
      children.add(const SizedBox(width: AppSpacing.sm));
      children.add(Expanded(
        flex: 2,
        child: AppButton(
          label: context.tr('promo_approve_place'),
          icon: Icons.place_rounded,
          onPressed: (_busy || _placements.isEmpty) ? null : _approveWithPlacement,
          color: AppColors.success,
          loading: _busy,
        ),
      ));
    } else {
      // Preview stage: regenerate + publish live.
      children.add(const SizedBox(width: AppSpacing.sm));
      children.add(Expanded(
        child: AppButton(
          label: context.tr('promo_regenerate'),
          onPressed: _busy ? null : _regenerate,
          variant: AppButtonVariant.tonal,
          color: AppDomain.promotions.accent,
        ),
      ));
      children.add(const SizedBox(width: AppSpacing.sm));
      children.add(Expanded(
        flex: 2,
        child: AppButton(
          label: context.tr('promo_publish'),
          icon: Icons.publish_rounded,
          onPressed: (_busy || !_hasReadyCreative(c)) ? null : _publish,
          color: AppColors.success,
          loading: _busy,
        ),
      ));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Row(children: children),
      ),
    );
  }

  String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1);
}


/// AI-edit note bottom sheet → returns the note (null = cancel).
class _RefineSheet extends StatefulWidget {
  const _RefineSheet({this.initial});
  final String? initial;

  @override
  State<_RefineSheet> createState() => _RefineSheetState();
}

class _RefineSheetState extends State<_RefineSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppDomain.promotions.accent;
    return BottomSheetScaffold(
      title: context.tr('promo_edit_ad'),
      icon: Icons.auto_fix_high_rounded,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('promo_edit_desc'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _ctrl,
              maxLines: 4,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(hintText: context.tr('promo_edit_hint')),
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: context.tr('promo_edit_submit'),
              icon: Icons.auto_fix_high_rounded,
              onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
              color: accent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Approve sheet → owner picks the design identity (brand vs Zooboxi) + the
/// placement. Returns (placement, identity) or null on cancel.
class _PlacementSheet extends StatefulWidget {
  const _PlacementSheet({
    required this.placements,
    required this.initialIdentity,
    this.brandName,
  });
  final List<AdPlacement> placements;
  final String initialIdentity; // 'brand' | 'zooboxi'
  final String? brandName;

  @override
  State<_PlacementSheet> createState() => _PlacementSheetState();
}

class _PlacementSheetState extends State<_PlacementSheet> {
  String? _selected;
  late String _identity;

  bool get _hasBrand => widget.brandName != null && widget.brandName!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.placements.length == 1) _selected = widget.placements.first.key;
    _identity = _hasBrand ? widget.initialIdentity : 'zooboxi';
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppDomain.promotions.accent;
    return BottomSheetScaffold(
      title: context.tr('promo_approve_title'),
      icon: Icons.check_circle_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Design identity (only when the campaign has a brand) ──
          if (_hasBrand) ...[
            Text(context.tr('design_identity_title'),
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(context.tr('design_identity_desc'),
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            AppSegmentedControl(
              items: [
                SegmentItem(widget.brandName!, icon: Icons.sell_rounded),
                const SegmentItem('Zooboxi', icon: Icons.pets_rounded),
              ],
              selectedIndex: _identity == 'brand' ? 0 : 1,
              onChanged: (i) => setState(() => _identity = i == 0 ? 'brand' : 'zooboxi'),
              activeColor: accent,
            ),
            const SizedBox(height: AppSpacing.base),
          ],
          // ── Placement ──
          Text(context.tr('promo_place_section'),
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(context.tr('promo_place_desc'),
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: widget.placements.map((p) {
              final sel = _selected == p.key;
              return ChoiceChip(
                label: Text(p.labelAr),
                selected: sel,
                selectedColor: accent.withValues(alpha: 0.18),
                onSelected: (_) => setState(() => _selected = p.key),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            label: context.tr('promo_approve_place'),
            icon: Icons.check_rounded,
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(context, (placement: _selected!, identity: _identity)),
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}
