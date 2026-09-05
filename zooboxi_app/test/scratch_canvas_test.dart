import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/features/loyalty/presentation/widgets/scratch_canvas.dart';

/// The scratch card's one hard promise: the prize is revealed by the finger,
/// and the reveal happens exactly once no matter how long the finger keeps
/// going. A second call would post a second `reveal` and — on a bad day —
/// settle a prize twice.

Widget _host(Widget child, {Size size = const Size(320, 180)}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );

/// Rubs a horizontal band across the card at [fraction] of its height.
Future<void> _rub(WidgetTester tester, Finder card, double fraction) async {
  final topLeft = tester.getTopLeft(card);
  final size = tester.getSize(card);
  final y = topLeft.dy + size.height * fraction;

  final gesture = await tester.startGesture(Offset(topLeft.dx + 12, y));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(Offset(topLeft.dx + size.width * 0.5, y));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.moveTo(Offset(topLeft.dx + size.width - 12, y));
  await tester.pump(const Duration(milliseconds: 16));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('a finger uncovers the prize and reveals exactly once',
      (tester) async {
    var reveals = 0;

    await tester.pumpWidget(
      _host(
        ScratchCanvas(
          label: 'اخدش واربح',
          hint: 'امسح البطاقة بإصبعك',
          onRevealed: () => reveals++,
          child: const Center(child: Text('50 بصمة')),
        ),
      ),
    );

    final card = find.byType(ScratchCanvas);

    // One band is not most of the card: nothing has been revealed yet.
    await _rub(tester, card, 0.22);
    expect(reveals, 0);

    // Two more bands take it past the 55% threshold.
    await _rub(tester, card, 0.52);
    await _rub(tester, card, 0.82);
    expect(reveals, 1);

    // Keep rubbing — and keep rubbing after the foil has melted away.
    await _rub(tester, card, 0.36);
    await _rub(tester, card, 0.66);
    await tester.pumpAndSettle();
    await _rub(tester, card, 0.5);
    expect(reveals, 1);
  });

  testWidgets('the prize is behind the foil the whole time', (tester) async {
    await tester.pumpWidget(
      _host(
        ScratchCanvas(
          label: 'اخدش واربح',
          onRevealed: () {},
          child: const Center(child: Text('هدية صغيرة')),
        ),
      ),
    );

    // The prize is a real child, not something built on reveal — the foil
    // punches holes in a layer above it.
    expect(find.text('هدية صغيرة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an already-revealed card shows no foil and never fires',
      (tester) async {
    var reveals = 0;

    await tester.pumpWidget(
      _host(
        ScratchCanvas(
          revealed: true,
          label: 'اخدش واربح',
          onRevealed: () => reveals++,
          child: const Center(child: Text('300 بصمة')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _rub(tester, find.byType(ScratchCanvas), 0.5);
    await _rub(tester, find.byType(ScratchCanvas), 0.5);
    expect(reveals, 0);
    expect(find.text('300 بصمة'), findsOneWidget);
  });

  testWidgets('opening it from outside melts the foil without firing again',
      (tester) async {
    var reveals = 0;

    Widget build(bool revealed) => _host(
          ScratchCanvas(
            revealed: revealed,
            label: 'اخدش واربح',
            onRevealed: () => reveals++,
            child: const Center(child: Text('توصيل مجاني')),
          ),
        );

    await tester.pumpWidget(build(false));
    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();

    expect(reveals, 0);
    expect(tester.takeException(), isNull);
  });
}
