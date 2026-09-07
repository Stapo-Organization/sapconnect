import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/zb_colors.dart';
import '../../../app/theme/zooboxi_tokens.dart';
import '../../../core/icons/zb_icons.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';

/// The one search affordance in the app, and the flight that connects its two
/// ends.
///
/// A full-width field on the home canvas spends the most valuable strip in the
/// store on a control nobody has used yet. So home carries a **button**, and
/// the button *becomes* the field: a container transform, which is the one
/// transition that answers "where did this screen come from?" without a word.
/// The pill grows out of the icon's own circle, the glyph slides to the
/// leading edge as the hint fades in behind it, and the keyboard arrives to a
/// field that is already there.
/// One tag per place a search button lives.
///
/// A single shared tag cannot work: go_router keeps every visited tab alive
/// behind the current one, and a hero in a hidden branch is still collected
/// when a flight starts. A gate written from a post-frame callback is a frame
/// too late to save it — a push in the same frame as a tab switch reads the
/// previous branch. Distinct tags make the collision impossible instead of
/// merely unlikely: the search screen adopts the tag of the tab it was opened
/// from, and every other button is a hero nobody is flying to.
///
/// One consequence worth knowing: a button placed on a *pushed* page rather
/// than in a tab would find the screen adopting the active branch's tag, not
/// its own, and simply would not fly. Such a site should carry its tag in the
/// route instead of reading it from the shell.
String searchHeroTagFor(int branch) => 'zb-search-field-$branch';

/// Rounded like the field it turns into, not like a chip — the two ends of
/// one object. 44 is also the smallest square a thumb should be asked to hit.
const double _buttonSize = 44;

/// The leading glyph's box in the landed field, which the flight has to end
/// on exactly or the icon jumps on arrival.
const double _fieldGlyphBox = 44;

/// Builds the object in mid-flight: one pill whose corner radius, colour and
/// contents travel between the button and the field.
///
/// The real destination (an autofocusing `TextField`) never flies — a field
/// that is being laid out inside a moving rect fights its own text layout, and
/// the customer would see the caret skate across the screen.
Widget searchFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) {
  final cs = Theme.of(flightContext).colorScheme;
  final tt = Theme.of(flightContext).textTheme;
  final l = L.of(flightContext);

  // `animation` already means the same thing in both directions — 1 is the
  // field, 0 is the button — and it already carries the flight's own curve.
  // Reversing or re-easing it here is how a collapse turns into a snap.
  final push = direction == HeroFlightDirection.push;
  final buttonEnd = _materialColor(push ? fromContext : toContext);
  final fieldEnd = _materialColor(push ? toContext : fromContext);
  // A translucent well sits on the hero canvas and wants a light glyph; an
  // opaque one is the field, whose glyph is grey.
  final buttonInk = (buttonEnd?.a ?? 1) < 0.6 ? Colors.white : cs.onSurfaceVariant;

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final v = animation.value.clamp(0.0, 1.0);
      final ink = Color.lerp(buttonInk, cs.onSurfaceVariant, v)!;
      return Material(
        color: Color.lerp(
          buttonEnd ?? cs.surfaceContainerHigh,
          fieldEnd ?? cs.surfaceContainerHighest,
          v,
        ),
        elevation: lerpDouble(0, 2, v)!,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(
          lerpDouble(_buttonSize / 2, ZbTokens.rMd, v)!,
        ),
        clipBehavior: Clip.antiAlias,
        // A Stack, not a Row: the rect this paints into is being animated
        // every frame, and a Row would spend some of those frames asserting
        // that its children no longer fit.
        child: Stack(
          children: [
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: 0,
              width: lerpDouble(_buttonSize, _fieldGlyphBox, v),
              child: Center(child: ZbIcon(ZbIconKind.search, size: 20, ink: ink)),
            ),
            PositionedDirectional(
              top: 0,
              bottom: 0,
              start: lerpDouble(_buttonSize, _fieldGlyphBox, v),
              end: 8,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Opacity(
                  opacity: (v * 1.6 - 0.6).clamp(0, 1),
                  child: Text(
                    l.searchHint,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The colour of the first `Material` inside a hero's subtree — the flight
/// starts and ends on the real surfaces rather than on an assumption about
/// them, so the translucent well on the canvas does not flash white.
Color? _materialColor(BuildContext context) {
  Color? found;
  void visit(Element element) {
    if (found != null) return;
    final widget = element.widget;
    if (widget is Material) {
      found = widget.color;
      return;
    }
    element.visitChildren(visit);
  }

  (context as Element).visitChildren(visit);
  return found;
}

/// The home header's search control: a round button that opens the search
/// screen by turning into its field.
class SearchHeroButton extends StatelessWidget {
  const SearchHeroButton({super.key, required this.branch, this.onCanvas = false});

  /// On the hero canvas the button is a translucent well in the colour, the
  /// same treatment the wishlist beside it gets.
  final bool onCanvas;

  /// Which shell tab this button lives in. It names the hero, so two tabs can
  /// each carry a button without ever colliding — and a new site that forgets
  /// to say where it is simply will not compile.
  final int branch;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final cs = context.cs;
    final ink = onCanvas
        ? (context.isDark ? ZbTokens.inkDark : Colors.white)
        : cs.onSurfaceVariant;
    final fill = onCanvas
        ? Colors.white.withValues(alpha: context.isDark ? 0.12 : 0.18)
        : cs.surfaceContainerHigh;

    return HeroMode(
      // Tickers are the one signal that flips in the *same* build as the tab
      // switch: go_router wraps each branch in a TickerMode, and reading it
      // here subscribes this button to that change. Anything written after
      // the frame — a provider set in a post-frame callback, say — is read
      // too late by a flight that starts in the same frame, and the pill
      // sails toward a header on the tab the customer just left.
      enabled: TickerMode.valuesOf(context).enabled,
      child: Hero(
      tag: searchHeroTagFor(branch),
      // The arc is what makes it read as one object moving rather than two
      // things cross-fading.
      createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
      flightShuttleBuilder: searchFlightShuttle,
      child: Material(
        color: fill,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: l.searchTitle,
          child: InkWell(
            onTap: () {
              Haptics.light();
              context.push('/search');
            },
            child: Tooltip(
              message: l.searchTitle,
              // The Semantics above already says the name; a tooltip that
              // repeats it makes VoiceOver read the button twice.
              excludeFromSemantics: true,
              child: SizedBox(
                width: _buttonSize,
                height: _buttonSize,
                child: Center(child: ZbIcon(ZbIconKind.search, size: 20, ink: ink)),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
