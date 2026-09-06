import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/catalog/data/catalog_models.dart';
import 'package:zooboxi_app/features/home/presentation/widgets/scope_band.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
      locale: const Locale('ar'),
      theme: brightness == Brightness.light
          ? AppTheme.light(const Locale('ar'))
          : AppTheme.dark(const Locale('ar')),
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
  group('CatalogScope.maybe', () {
    test('is null when the server sends nothing, or a scope with no sentence', () {
      expect(CatalogScope.maybe(null), isNull);
      expect(CatalogScope.maybe(const <String, dynamic>{}), isNull);
      expect(CatalogScope.maybe({'tier': 'express'}), isNull);
    });

    test('reads the shelf the server picked', () {
      final scope = CatalogScope.maybe({
        'tier': 'express',
        'warehouse_name': 'فرع الملك فهد - الرياض',
        'label': 'توصيل خلال ساعتين',
        'icon': '⚡',
        'date': 'اليوم',
        'note': 'نعرض ما يمكن أن يصلك خلال ساعتين من فرع الملك فهد - الرياض',
      });
      expect(scope, isNotNull);
      expect(scope!.tier, 'express');
      expect(scope.label, 'توصيل خلال ساعتين');
      expect(scope.note, contains('ساعتين'));
    });
  });

  group('HomePayload', () {
    test('carries the scope, and stays null on a server that sends none', () {
      final scoped = HomePayload.fromJson({
        'scope': {'tier': 'same_day', 'note': 'نعرض ما يمكن أن يصلك غدًا'},
      });
      expect(scoped.scope?.tier, 'same_day');
      expect(HomePayload.fromJson(const <String, dynamic>{}).scope, isNull);
    });
  });

  testWidgets('the band states the promise in both themes', (tester) async {
    final scope = CatalogScope.maybe({
      'tier': 'shipping',
      'icon': '📦',
      'note': 'نعرض ما يمكن شحنه إليك ووصوله الخميس 10 سبتمبر',
    })!;

    for (final brightness in Brightness.values) {
      await tester.pumpWidget(_app(ScopeBand(scope: scope), brightness: brightness));
      await tester.pump();
      expect(find.textContaining('الخميس 10 سبتمبر'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('a long note wraps instead of overflowing a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);

    final scope = CatalogScope.maybe({
      'tier': 'express',
      'icon': '⚡',
      'note': 'نعرض ما يمكن أن يصلك خلال ساعتين من فرع الملك فهد - الرياض',
    })!;

    await tester.pumpWidget(_app(ScopeBand(scope: scope)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
