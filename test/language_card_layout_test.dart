import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trace_allergy/models/trip.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/services/database.dart';
import 'package:trace_allergy/services/translator.dart';
import 'package:trace_allergy/theme.dart';
import 'package:trace_allergy/widgets/language_suggestion_card.dart';

/// Nothing installed, so the card has packs to suggest.
class _NothingInstalled implements TranslationBackend {
  @override
  Future<bool> isDownloaded(String code) async => false;
  @override
  Future<bool> download(String code, {required bool wifiOnly}) async => false;
  @override
  Future<bool> delete(String code) async => false;
  @override
  Future<String?> translate({
    required String text,
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async =>
      null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The app theme makes filled and outlined buttons full-width. A button in a
  // list tile's trailing slot then squeezed the title to one letter per line.
  testWidgets('language names get real width at iPhone size', (tester) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final tmp = Directory.systemTemp.createTempSync('lang_card');
    final db = TraceDatabase.atPath('${tmp.path}/t.db');
    late AppState app;
    await tester.runAsync(() async {
      app = AppState(
        database: db,
        translator: TranslatorService(backend: _NothingInstalled()),
      );
      await app.init();
    });
    final now = DateTime.now();
    final trip = Trip(
      id: 't',
      name: 'Tokyo',
      destinationCountry: 'JP',
      startsOn: now.add(const Duration(days: 2)),
      endsOn: now.add(const Duration(days: 9)),
    );

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[LanguageSuggestionCard(trip: trip)],
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    final name = find.text('Japanese · 日本語');
    expect(name, findsOneWidget);
    // The test font draws every glyph as a wide square, so real text is
    // narrower than this; the bug being guarded against left about 10 px.
    expect(tester.getSize(name).width, greaterThan(100));
    expect(tester.takeException(), isNull);

    final switchRow = find.textContaining('Show the chef card');
    expect(switchRow, findsOneWidget);
    expect(tester.getSize(switchRow).width, greaterThan(100));

    await tester.runAsync(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });
  });
}
