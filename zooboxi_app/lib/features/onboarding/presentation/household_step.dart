part of 'onboarding_screen.dart';

// ── Step 2 · «مين معك في البيت؟» ───────────────────────────────────────
//
// One tap per animal, no typing: the answer the whole app is arranged around.
// Two phases on one page — pick the family, then (optionally) name them, each
// name written on the sign the animal holds up as it is typed. Everything is
// skippable; the store never waits on it.

/// «مين معك في البيت؟» for a customer who is already past the welcome — every
/// existing install, and anyone who tapped «لاحقًا». The same step on the same
/// brand canvas, as its own page.
class HouseholdScreen extends ConsumerStatefulWidget {
  const HouseholdScreen({super.key});

  @override
  ConsumerState<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends ConsumerState<HouseholdScreen> {
  final ValueNotifier<bool> _naming = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _naming.dispose();
    super.dispose();
  }

  Future<void> _done(List<HouseholdMember> members, {bool shopsForOthers = false}) async {
    final l = L.of(context);
    await ref
        .read(householdProvider.notifier)
        .describe(members, shopsForOthers: shopsForOthers, unnamed: (s) => speciesLabel(l, s));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: context.zb.brandGradient),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _naming,
                    builder: (context, naming, _) => Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        color: fg,
                        tooltip: naming
                            ? MaterialLocalizations.of(context).backButtonTooltip
                            : MaterialLocalizations.of(context).closeButtonTooltip,
                        onPressed: () => naming ? _naming.value = false : context.pop(),
                        icon: Icon(
                          naming
                              ? (context.isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded)
                              : Icons.close_rounded,
                          size: naming ? 18 : 24,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _HouseholdStep(
                    naming: _naming,
                    onDone: (members, {shopsForOthers = false}) =>
                        unawaited(_done(members, shopsForOthers: shopsForOthers)),
                    onSkip: () => context.pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The species the picker offers, in the order a pet store is browsed.
const List<PetSpecies> _pickable = [
  PetSpecies.cat,
  PetSpecies.dog,
  PetSpecies.bird,
  PetSpecies.fish,
  PetSpecies.small,
  PetSpecies.reptile,
];

/// The family ceiling the store keeps (`/pets` max).
const int _familyMax = 3;

class _HouseholdStep extends StatefulWidget {
  const _HouseholdStep({required this.naming, required this.onDone, required this.onSkip});

  /// True while the names are being asked — the top bar's back returns to the
  /// picker rather than leaving the step.
  final ValueNotifier<bool> naming;

  final void Function(List<HouseholdMember> members, {bool shopsForOthers}) onDone;
  final VoidCallback onSkip;

  @override
  State<_HouseholdStep> createState() => _HouseholdStepState();
}

class _HouseholdStepState extends State<_HouseholdStep> {
  final Map<PetSpecies, int> _counts = {};
  List<HouseholdMember> _members = const [];
  int _current = 0;
  final TextEditingController _name = TextEditingController();

  int get _total => _counts.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    widget.naming.addListener(_onNaming);
  }

  @override
  void dispose() {
    widget.naming.removeListener(_onNaming);
    _name.dispose();
    super.dispose();
  }

  void _onNaming() => setState(() {});

  void _add(PetSpecies species) {
    if (_total >= _familyMax) return;
    Haptics.selection();
    setState(() => _counts[species] = (_counts[species] ?? 0) + 1);
  }

  void _remove(PetSpecies species) {
    Haptics.selection();
    setState(() {
      final n = (_counts[species] ?? 0) - 1;
      if (n <= 0) {
        _counts.remove(species);
      } else {
        _counts[species] = n;
      }
    });
  }

  void _toNames() {
    Haptics.light();
    final previous = _members;
    final next = <HouseholdMember>[
      for (final species in _pickable)
        for (var i = 0; i < (_counts[species] ?? 0); i++) HouseholdMember(species: species),
    ];
    // Coming back from the names keeps the ones already typed.
    for (var i = 0; i < next.length && i < previous.length; i++) {
      if (previous[i].species == next[i].species) next[i] = previous[i];
    }
    setState(() {
      _members = next;
      _current = 0;
      _name.text = next.first.name;
    });
    widget.naming.value = true;
  }

  void _commitName() {
    _members = [
      for (var i = 0; i < _members.length; i++)
        i == _current ? _members[i].copyWith(name: _name.text.trim()) : _members[i],
    ];
  }

  void _focus(int index) {
    if (index == _current) return;
    Haptics.selection();
    setState(() {
      _commitName();
      _current = index;
      _name.text = _members[index].name;
    });
  }

  void _setSex(String sex) {
    Haptics.selection();
    setState(() {
      _members = [
        for (var i = 0; i < _members.length; i++)
          i == _current ? _members[i].copyWith(sex: _members[i].sex == sex ? '' : sex) : _members[i],
      ];
    });
  }

  void _nextName() {
    _commitName();
    if (_current < _members.length - 1) {
      _focus(_current + 1);
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onDone(_members);
  }

  @override
  Widget build(BuildContext context) => widget.naming.value ? _names(context) : _picker(context);

  // ── The family ──────────────────────────────────────────────────────

  Widget _picker(BuildContext context) {
    final l = L.of(context);
    final fg = _canvasFg(context);
    final total = _total;
    final chosen = [
      for (final species in _pickable)
        for (var i = 0; i < (_counts[species] ?? 0); i++) species,
    ];

    return _StepBody(
      content: [
        Text(
          l.onbPetsTitle,
          style: context.tt.headlineSmall?.copyWith(color: fg, fontWeight: FontWeight.w900),
        ),
        Gap.h8,
        Text(l.onbPetsBody, style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.86), height: 1.5)),
        Gap.h16,
        _Lineup(chosen: chosen),
        Gap.h16,
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.42,
          children: [
            for (final species in _pickable)
              _SpeciesTile(
                species: species,
                count: _counts[species] ?? 0,
                full: total >= _familyMax,
                onAdd: () => _add(species),
                onRemove: () => _remove(species),
              ),
          ],
        ),
        if (total >= _familyMax) ...[
          Gap.h12,
          Text(
            l.onbPetsMax(Fmt.number(_familyMax, locale: Localizations.localeOf(context).languageCode, decimals: 0)),
            textAlign: TextAlign.center,
            style: context.tt.bodySmall?.copyWith(color: fg.withValues(alpha: 0.86)),
          ),
        ],
        Gap.h8,
        _CanvasTextAction(
          label: l.onbPetsForOthers,
          onPressed: () => widget.onDone(const [], shopsForOthers: true),
        ),
      ],
      footer: [
        if (total > 0) _CanvasButton(label: l.onbPetsNext(total), onPressed: _toNames),
        _CanvasTextAction(label: l.onbLater, onPressed: widget.onSkip),
      ],
    );
  }

  // ── The names ───────────────────────────────────────────────────────

  Widget _names(BuildContext context) {
    final l = L.of(context);
    final fg = _canvasFg(context);
    final member = _members[_current];
    final cast = castForSpecies(member.species) ?? ZbCast.cat;
    final signs = cast == ZbCast.cat || cast == ZbCast.dog;
    final typed = _name.text.trim();
    final last = _current == _members.length - 1;
    final title = switch (member.sex) {
      'f' => l.onbPetsNameShe,
      'm' => l.onbPetsNameBoy,
      _ => l.onbPetsNameHe,
    };

    return _StepBody(
      content: [
        if (_members.length > 1) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _members.length,
              separatorBuilder: (_, _) => Gap.w8,
              itemBuilder: (context, i) => _NamePill(
                label: _pillLabel(l, i),
                selected: i == _current,
                onTap: () => _focus(i),
              ),
            ),
          ),
          Gap.h16,
        ],
        Text(title, style: context.tt.headlineSmall?.copyWith(color: fg, fontWeight: FontWeight.w900)),
        Gap.h16,
        Center(
          child: SizedBox(
            height: 250,
            child: signs
                ? SignHolder(key: ValueKey(_current), cast: cast, text: typed.isEmpty ? '؟' : typed, height: 246)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ZbSticker.cast(cast, ZbPose.sitUp, key: ValueKey(_current), height: 170),
                      Gap.h12,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(color: ZbTokens.creamLogo, borderRadius: BorderRadius.circular(14)),
                        child: Text(
                          typed.isEmpty ? '؟' : typed,
                          style: const TextStyle(color: Color(0xFF5A2C2F), fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Gap.h20,
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _nextName(),
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          maxLength: 24,
          style: context.tt.titleMedium?.copyWith(color: ZbTokens.ink, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            counterText: '',
            hintText: l.onbPetsNameHint,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.96),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        Gap.h16,
        Text.rich(
          TextSpan(
            text: '${l.onbPetsSexQuestion} ',
            children: [TextSpan(text: l.onbPetsOptional, style: const TextStyle(fontWeight: FontWeight.w400))],
          ),
          style: context.tt.labelLarge?.copyWith(color: fg.withValues(alpha: 0.88), fontWeight: FontWeight.w700),
        ),
        Gap.h8,
        Row(
          children: [
            Expanded(child: _NamePill(label: l.onbPetsGirl, selected: member.sex == 'f', onTap: () => _setSex('f'), tall: true)),
            Gap.w12,
            Expanded(child: _NamePill(label: l.onbPetsBoy, selected: member.sex == 'm', onTap: () => _setSex('m'), tall: true)),
          ],
        ),
      ],
      footer: [
        _CanvasButton(label: last ? l.onbPetsDone : l.onbContinue, onPressed: _nextName),
        _CanvasTextAction(
          label: l.onbPetsSkip,
          onPressed: () {
            _commitName();
            FocusScope.of(context).unfocus();
            widget.onDone(_members);
          },
        ),
      ],
    );
  }

  /// «القطة ١», «القطة ٢», «الكلب» — numbered only where a kind repeats.
  String _pillLabel(L l, int index) {
    final member = _members[index];
    if (member.name.isNotEmpty && index != _current) return member.name;
    final kind = speciesLabel(l, member.species);
    final same = _members.where((m) => m.species == member.species).length;
    if (same == 1) return kind;
    final nth = _members.take(index + 1).where((m) => m.species == member.species).length;
    return '$kind ${Fmt.number(nth, locale: Localizations.localeOf(context).languageCode, decimals: 0)}';
  }
}

/// The family as it is being described: each animal pops onto one ground
/// line the moment it is added. Empty, three soft places wait.
class _Lineup extends StatelessWidget {
  const _Lineup({required this.chosen});

  final List<PetSpecies> chosen;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    const heights = [104.0, 88.0, 98.0];
    return SizedBox(
      height: 118,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: -6,
            child: Container(
              width: 250,
              height: 24,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.16),
                borderRadius: const BorderRadius.all(Radius.elliptical(125, 12)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (chosen.isEmpty)
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fg.withValues(alpha: 0.10),
                        border: Border.all(color: fg.withValues(alpha: 0.32), width: 1.5),
                      ),
                      child: Icon(Icons.add_rounded, color: fg.withValues(alpha: 0.6)),
                    ),
                  )
              else
                for (var i = 0; i < chosen.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Companion(
                      i == 0 ? ZbPose.wave : ZbPose.sitUp,
                      // A new arrival pops in; the ones already there stay put.
                      key: ValueKey('$i-${chosen[i].key}'),
                      cast: castForSpecies(chosen[i]) ?? ZbCast.cat,
                      height: heights[i % heights.length] * (chosen[i] == PetSpecies.fish || chosen[i] == PetSpecies.reptile ? 0.7 : 1),
                      idle: i == 0 ? ZbIdle.hop : ZbIdle.breathe,
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeciesTile extends StatelessWidget {
  const _SpeciesTile({
    required this.species,
    required this.count,
    required this.full,
    required this.onAdd,
    required this.onRemove,
  });

  final PetSpecies species;
  final int count;
  final bool full;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  String _label(L l) => switch (species) {
        PetSpecies.cat => l.onbPetsCats,
        PetSpecies.dog => l.onbPetsDogs,
        PetSpecies.bird => l.onbPetsBirds,
        PetSpecies.fish => l.onbPetsFish,
        PetSpecies.small => l.onbPetsSmall,
        PetSpecies.reptile => l.onbPetsReptiles,
        PetSpecies.other => l.petSpeciesOther,
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _tile(context, box.maxWidth));

  Widget _tile(BuildContext context, double width) {
    final l = L.of(context);
    final fg = _canvasFg(context);
    final on = count > 0;
    // The animal gives way on a narrow phone: the stepper and the name need
    // the width more than the drawing needs its size.
    final artHeight = (width * 0.46).clamp(44.0, 78.0);
    final cast = castForSpecies(species) ?? ZbCast.cat;
    final wide = species == PetSpecies.fish || species == PetSpecies.reptile;
    final full4 = cast == ZbCast.cat || cast == ZbCast.dog;
    final radius = BorderRadius.circular(22);

    final art = PositionedDirectional(
      end: 8,
      bottom: wide ? 16 : 6,
      child: ZbSticker.cast(
        cast,
        on && full4 ? ZbPose.wave : ZbPose.sitUp,
        key: ValueKey('$species-$on'),
        height: wide ? artHeight * 0.64 : artHeight,
        idle: on ? ZbIdle.breathe : ZbIdle.none,
        entrance: on,
      ),
    );
    final label = PositionedDirectional(
      start: 14,
      top: 12,
      end: artHeight * 0.62,
      child: Text(
        _label(l),
        style: context.tt.titleSmall?.copyWith(color: on ? _onSolid : fg, fontWeight: FontWeight.w900, height: 1.2),
      ),
    );

    if (!on) {
      final disabled = full;
      return Semantics(
        button: true,
        enabled: !disabled,
        label: '${l.onbPetsAdd} ${_label(l)}',
        excludeSemantics: true,
        child: Opacity(
          opacity: disabled ? 0.5 : 1,
          child: PressScale(
            borderRadius: radius,
            onTap: disabled ? null : onAdd,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                borderRadius: radius,
                border: Border.all(color: fg.withValues(alpha: 0.32)),
              ),
              child: Stack(
                children: [
                  label,
                  art,
                  PositionedDirectional(
                    start: 12,
                    bottom: 12,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: fg.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.add_rounded, size: 20, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final locale = Localizations.localeOf(context).languageCode;
    Widget step(IconData icon, String tip, VoidCallback? onTap) => SizedBox(
          width: 34,
          height: 34,
          child: IconButton(
            onPressed: onTap,
            tooltip: tip,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(backgroundColor: ZbTokens.tealTint, foregroundColor: _onSolid),
            icon: Icon(icon, size: 18),
          ),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fg,
        borderRadius: radius,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          label,
          art,
          PositionedDirectional(
            start: 10,
            bottom: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                step(Icons.add_rounded, l.onbPetsAdd, full ? null : onAdd),
                SizedBox(
                  width: 26,
                  child: Text(
                    Fmt.number(count, locale: locale, decimals: 0),
                    textAlign: TextAlign.center,
                    style: context.tt.titleMedium?.copyWith(color: _onSolid, fontWeight: FontWeight.w900),
                  ),
                ),
                step(Icons.remove_rounded, l.onbPetsRemove, onRemove),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NamePill extends StatelessWidget {
  const _NamePill({required this.label, required this.selected, required this.onTap, this.tall = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final fg = _canvasFg(context);
    return Semantics(
      selected: selected,
      button: true,
      child: PressScale(
        borderRadius: BorderRadius.circular(tall ? 14 : 999),
        onTap: onTap,
        child: Container(
          height: tall ? 48 : 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? fg : fg.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(tall ? 14 : 999),
            border: selected ? null : Border.all(color: fg.withValues(alpha: 0.32)),
          ),
          child: Text(
            label,
            style: context.tt.labelLarge?.copyWith(color: selected ? _onSolid : fg, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
