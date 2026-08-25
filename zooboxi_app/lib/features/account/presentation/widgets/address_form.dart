import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/zb_colors.dart';
import '../../../../app/theme/zooboxi_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// The three preset labels, plus a free-text escape hatch.
enum AddressLabelChoice { home, work, other }

/// The written half of an address: who receives it, where exactly, what to
/// call it. The map owns the coordinates; this owns everything a driver reads.
class AddressForm extends StatelessWidget {
  const AddressForm({
    super.key,
    required this.name,
    required this.phone,
    required this.city,
    required this.district,
    required this.line,
    required this.customLabel,
    required this.labelChoice,
    required this.onLabelChoice,
    this.resolving = false,
    this.enabled = true,
  });

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController city;
  final TextEditingController district;
  final TextEditingController line;
  final TextEditingController customLabel;

  final AddressLabelChoice labelChoice;
  final ValueChanged<AddressLabelChoice> onLabelChoice;

  /// True while the pin's city/district are still being reverse-geocoded.
  final bool resolving;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.addressLabelTitle, style: context.tt.labelLarge),
        Gap.h8,
        Wrap(
          spacing: 8,
          children: [
            for (final choice in AddressLabelChoice.values)
              _LabelChip(
                label: switch (choice) {
                  AddressLabelChoice.home => l.addressLabelHome,
                  AddressLabelChoice.work => l.addressLabelWork,
                  AddressLabelChoice.other => l.addressLabelOther,
                },
                icon: switch (choice) {
                  AddressLabelChoice.home => Icons.home_rounded,
                  AddressLabelChoice.work => Icons.work_rounded,
                  AddressLabelChoice.other => Icons.push_pin_rounded,
                },
                selected: labelChoice == choice,
                onTap: enabled ? () => onLabelChoice(choice) : null,
              ),
          ],
        ),
        if (labelChoice == AddressLabelChoice.other) ...[
          Gap.h12,
          TextField(
            controller: customLabel,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.addressLabelTitle,
              hintText: l.commonOptional,
            ),
          ),
        ],
        Gap.h20,

        TextField(
          controller: name,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l.addressNameLabel),
        ),
        Gap.h12,
        TextField(
          controller: phone,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          // The store only ships inside Saudi Arabia, so the number is always
          // a 10-digit 05x — anything else is a typo, not a foreign customer.
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            labelText: l.addressPhoneLabel,
            hintText: l.authPhoneHint,
          ),
        ),
        Gap.h12,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: city,
                enabled: enabled,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.addressCityLabel,
                  suffixIcon: resolving
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Gap.w12,
            Expanded(
              child: TextField(
                controller: district,
                enabled: enabled,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.addressDistrictLabel),
              ),
            ),
          ],
        ),
        if (resolving) ...[
          Gap.h8,
          Text(
            l.addressResolving,
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        Gap.h12,
        TextField(
          controller: line,
          enabled: enabled,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l.addressLineLabel,
            hintText: l.addressLineHint,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return ChoiceChip(
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
      ),
      label: Text(label),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZbTokens.rPill),
        side: BorderSide(color: selected ? Colors.transparent : cs.outlineVariant),
      ),
    );
  }
}
