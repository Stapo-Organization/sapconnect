import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/account/presentation/widgets/map_pin_picker.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      theme: AppTheme.light(const Locale('ar')),
      localizationsDelegates: const [
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar')],
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The bug the owner caught on build 8: the pin floated well above the point
  /// the camera reports, so the customer aimed at their door and the store was
  /// told about the neighbour's. The tip is the address — assert it.
  testWidgets('the pin stands on the coordinate, not above it', (tester) async {
    await tester.pumpWidget(
      _host(
        const MapPinPicker(
          initial: LatLng(24.7136, 46.6753),
          height: 400,
        ),
      ),
    );
    await tester.pump();

    final centre = tester.getCenter(find.byType(MapPinPicker));

    // The ground mark — the thing that says "here" — is on the centre itself.
    final mark = tester.getCenter(find.byType(AnimatedScale));
    expect(mark.dy, closeTo(centre.dy, 0.5));
    expect(mark.dx, closeTo(centre.dx, 0.5));

    // And the glyph's tip, which sits about 46% below its own box centre,
    // comes down on the same line.
    final icon = tester.getRect(find.byIcon(Icons.location_on_rounded));
    expect(icon.center.dy + icon.height * 0.46, closeTo(centre.dy, 1.0));
    // The pin body is above the point, never below it.
    expect(icon.top, lessThan(centre.dy));
  });

  testWidgets('a preview strip carries the same pin, sized to fit',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const MapPinPicker(
          initial: LatLng(24.7136, 46.6753),
          height: 104,
          interactive: false,
        ),
      ),
    );
    await tester.pump();

    final centre = tester.getCenter(find.byType(MapPinPicker));
    final icon = tester.getRect(find.byIcon(Icons.location_on_rounded));
    expect(icon.height, lessThan(44));
    expect(icon.center.dy + icon.height * 0.46, closeTo(centre.dy, 1.0));
    // A still preview offers no controls to press.
    expect(find.byIcon(Icons.my_location_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the map can be switched to satellite and back', (tester) async {
    await tester.pumpWidget(
      _host(
        const MapPinPicker(initial: LatLng(24.7136, 46.6753), height: 400),
      ),
    );
    await tester.pump();

    expect(find.textContaining('OpenStreetMap'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.satellite_alt_rounded));
    await tester.pump();

    // The credit follows the tiles it belongs to.
    expect(find.textContaining('Esri'), findsOneWidget);
    expect(find.byIcon(Icons.map_rounded), findsOneWidget);
  });
}
