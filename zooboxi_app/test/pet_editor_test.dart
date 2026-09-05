import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zooboxi_app/app/theme/app_theme.dart';
import 'package:zooboxi_app/features/pets/data/pet_models.dart';
import 'package:zooboxi_app/features/pets/data/pets_repository.dart';
import 'package:zooboxi_app/features/pets/presentation/pet_editor_screen.dart';
import 'package:zooboxi_app/features/pets/presentation/widgets/species_avatar.dart';
import 'package:zooboxi_app/l10n/app_localizations.dart';

/// The editor asks for one thing (a name) and rewards everything else. These
/// lock that bargain: nothing is sent without a name, nothing else is ever
/// demanded, and a save never reaches the network on an invalid form.

/// Fails loudly if the screen tries to write while the form is invalid.
class _RefusingRepository implements PetsRepository {
  int writes = 0;

  @override
  Future<PetsPayload> pets() async => PetsPayload.empty;

  @override
  Future<PetWrite> create(Pet pet) async {
    writes++;
    return PetWrite(pet: pet);
  }

  @override
  Future<PetWrite> update(int id, Pet pet) async {
    writes++;
    return PetWrite(pet: pet);
  }

  @override
  Future<List<Pet>> remove(int id) async {
    writes++;
    return const [];
  }
}

late _RefusingRepository _repository;

Widget _host({int? petId, Pet? initial}) => ProviderScope(
      overrides: [petsRepositoryProvider.overrideWithValue(_repository)],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.light(const Locale('ar')),
        localizationsDelegates: const [
          L.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        home: PetEditorScreen(petId: petId, initial: initial),
      ),
    );

void main() {
  setUp(() => _repository = _RefusingRepository());

  testWidgets('a nameless pet is refused, and nothing is sent', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('حفظ'));
    await tester.pump();

    expect(find.text('اكتب اسم صديقك'), findsOneWidget);
    expect(_repository.writes, 0);
  });

  testWidgets('typing a name clears the refusal as you type', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('حفظ'));
    await tester.pump();
    expect(find.text('اكتب اسم صديقك'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'مشمش');
    await tester.pump();
    expect(find.text('اكتب اسم صديقك'), findsNothing);
  });

  testWidgets('whitespace is not a name', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.text('حفظ'));
    await tester.pump();

    expect(find.text('اكتب اسم صديقك'), findsOneWidget);
    expect(_repository.writes, 0);
  });

  testWidgets('all seven species are offered, drawn rather than written',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 300));

    for (final label in const [
      'قط',
      'كلب',
      'طائر',
      'سمك',
      'قارض',
      'زاحف',
      'غير ذلك',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byType(SpeciesAvatar), findsNWidgets(PetSpecies.values.length));
  });

  testWidgets('weight starts unset and steps in 100-gram notches',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('غير مسجّل'), findsNWidgets(2)); // weight and birth date

    // Arabic keeps Western digits but its own decimal mark — the app's rule.
    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pump();
    expect(find.text('4٫1 كجم'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_rounded).first);
    await tester.tap(find.byIcon(Icons.remove_rounded).first);
    await tester.pump();
    expect(find.text('3٫9 كجم'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump();
    expect(find.text('غير مسجّل'), findsNWidgets(2));
  });

  testWidgets('an existing pet opens filled in, with a delete', (tester) async {
    final pet = Pet(
      id: 7,
      name: 'مشمش',
      species: PetSpecies.dog,
      breed: 'هاسكي',
      sex: 'f',
      weightKg: 12.5,
      birthDate: DateTime(2024, 6, 14),
      neutered: true,
    );

    await tester.pumpWidget(_host(petId: 7, initial: pet));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ملف مشمش'), findsOneWidget);
    expect(find.text('مشمش'), findsWidgets);
    expect(find.text('هاسكي'), findsOneWidget);
    expect(find.text('12٫5 كجم'), findsOneWidget);

    // The switch and the delete live at the far end of the form, out of
    // thumb's way — the list has to be walked to reach them.
    await tester.scrollUntilVisible(
      find.text('حذف الملف'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('حذف الملف'), findsOneWidget);

    final neutered = tester.widget<Switch>(find.byType(Switch));
    expect(neutered.value, isTrue);
  });

  testWidgets('a new pet has no delete to press by accident', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('صديق جديد'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('حذف الملف'), findsNothing);
    expect(find.text('معقّم'), findsOneWidget);
  });
}
