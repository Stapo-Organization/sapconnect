import 'package:flutter/material.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/colors.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/domain.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/typography.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/spacing.dart';
import 'package:exhibition_manager_app/core/design_system/tokens/radius.dart';
import 'package:exhibition_manager_app/core/localization/app_localizations.dart';
import 'package:exhibition_manager_app/core/notifications/notifications_repository.dart';
import 'package:exhibition_manager_app/shared/widgets/muntajat_app_bar.dart';

/// شاشة تفضيلات الإشعارات — لكل تنبيه يختار المستخدم القناة:
/// بريد / تطبيق / الاثنين. مجمّعة حسب القسم، تُحفظ فور التغيير.
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  final NotificationsRepository _repo = NotificationsRepository();
  late Future<List<NotificationPref>> _future;
  List<NotificationPref> _prefs = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<NotificationPref>> _load() async {
    _prefs = await _repo.getPreferences();
    return _prefs;
  }

  Future<void> _setChannel(NotificationPref pref, bool email, bool push) async {
    setState(() {
      pref.email = email;
      pref.push = push;
    });
    final ok = await _repo.updatePreferences(_prefs);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.tr(ok ? 'notifications_saved' : 'notifications_save_failed')),
        duration: const Duration(milliseconds: 1200),
        backgroundColor: ok ? AppDomain.profile.accentDark : AppColors.error,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: MuntajatAppBar(title: context.tr('notifications_title')),
        body: FutureBuilder<List<NotificationPref>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_prefs.isEmpty) {
              return _EmptyState(isArabic: isArabic);
            }
            return _buildGroupedList(context);
          },
        ),
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    // ترتيب الأقسام حسب أول ظهور.
    final groups = <String, List<NotificationPref>>{};
    for (final p in _prefs) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        Text(
          context.tr('notifications_hint'),
          style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: AppSpacing.base),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
              right: AppSpacing.xs,
              left: AppSpacing.xs,
            ),
            child: Text(
              entry.key,
              style: AppTypography.labelMedium.copyWith(
                color: AppDomain.profile.accentDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...entry.value.map((p) => _PrefCard(
                pref: p,
                onSelect: (email, push) => _setChannel(p, email, push),
              )),
          const SizedBox(height: AppSpacing.base),
        ],
      ],
    );
  }
}

class _PrefCard extends StatelessWidget {
  final NotificationPref pref;
  final void Function(bool email, bool push) onSelect;

  const _PrefCard({required this.pref, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.isArabic;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? pref.label : pref.labelEn,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _segment(context, 'channel_email', Icons.email_outlined,
                  selected: pref.email && !pref.push, onTap: () => onSelect(true, false)),
              const SizedBox(width: AppSpacing.sm),
              _segment(context, 'channel_push', Icons.phone_iphone_rounded,
                  selected: pref.push && !pref.email, onTap: () => onSelect(false, true)),
              const SizedBox(width: AppSpacing.sm),
              _segment(context, 'channel_both', Icons.done_all_rounded,
                  selected: pref.email && pref.push, onTap: () => onSelect(true, true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String labelKey,
    IconData icon, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: selected ? AppDomain.profile.accent : AppColors.background,
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: selected ? AppDomain.profile.accent : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(
                context.tr(labelKey),
                style: AppTypography.labelSmall.copyWith(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isArabic;
  const _EmptyState({required this.isArabic});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 56, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.base),
            Text(
              context.tr('notifications_empty'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
