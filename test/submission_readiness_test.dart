import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/data/countries.dart';
import 'package:trace_allergy/models/emergency.dart';
import 'package:trace_allergy/models/product.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/models/scan_record.dart';
import 'package:trace_allergy/screens/emergency_mode_screen.dart';
import 'package:trace_allergy/services/app_lock.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/services/database.dart';
import 'package:trace_allergy/services/emergency_actions.dart';
import 'package:trace_allergy/services/food_api.dart';
import 'package:trace_allergy/services/matcher.dart';

class _Device implements DeviceAuth {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<String> methodLabel() async => 'Passcode';
  @override
  Future<LockOutcome> authenticate(String reason) async => LockOutcome.unlocked;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final milkProfile = Profile(
    id: 'milk',
    name: 'Milk allergy',
    allergens: {Allergen.milk: Severity.severe},
  );

  group('Ingredient language', () {
    test('foreign and unverified direct text never clears a milk allergy', () {
      for (final text in ['Ingredientes: leche, azúcar', 'sugar']) {
        final verdict = AllergenMatcher.evaluate(
          product: Product.fromOcr(text),
          profile: milkProfile,
        );
        expect(verdict.level.name, 'unknown');
      }
    });
    test('unverified text still raises an alarm', () {
      final verdict = AllergenMatcher.evaluate(
        product: Product.fromOcr('milk, sugar'),
        profile: milkProfile,
      );
      expect(verdict.level.name, 'unsafe');
    });
    test('confirmed English survives cache and copying', () {
      final product = Product.fromOcr('rice, water', ingredientsLanguage: 'en');
      final restored = Product.fromMap(product.toMap()).copyWith(name: 'Rice');
      expect(restored.ingredientsLanguage, 'en');
      expect(
        restored.copyWith(ingredientsText: 'leche').ingredientsLanguage,
        isNull,
      );
      expect(
        AllergenMatcher.evaluate(
          product: restored,
          profile: milkProfile,
        ).level.name,
        'clear',
      );
      final legacy = product.toMap()..remove('ingredientsLanguage');
      expect(
        AllergenMatcher.evaluate(
          product: Product.fromMap(legacy),
          profile: milkProfile,
        ).level.name,
        'unknown',
      );
    });
  });

  group('Food lookup', () {
    for (final returnedCode in ['999999999999', '', null, 'invalid']) {
      test('USDA rejects mismatched or missing GTIN: $returnedCode', () async {
        final api = FoodApi(
          client: MockClient((request) async {
            if (request.url.host.contains('openfoodfacts')) {
              return http.Response('{"status":0}', 200);
            }
            return http.Response(
              jsonEncode({
                'foods': [
                  {
                    'gtinUpc': returnedCode,
                    'description': 'Wrong food',
                    'ingredients': 'milk',
                  },
                ],
              }),
              200,
            );
          }),
        );
        addTearDown(api.dispose);
        expect((await api.lookup('012345678905')).status, ScanStatus.notFound);
      });
    }
    test('USDA accepts the same GTIN with leading zero padding', () async {
      final api = FoodApi(
        client: MockClient((request) async {
          if (request.url.host.contains('openfoodfacts')) {
            return http.Response('{"status":0}', 200);
          }
          return http.Response(
            jsonEncode({
              'foods': [
                {
                  'gtinUpc': '00012345678905',
                  'description': 'Right food',
                  'ingredients': 'milk',
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(api.dispose);
      expect((await api.lookup('012345678905')).product?.name, 'Right food');
    });
    test('native OFF text keeps its language and cannot clear', () async {
      final api = FoodApi(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'code': '012345678905',
                'ingredients_text': 'leche, azúcar',
                'lang': 'es',
                'states_tags': ['en:ingredients-completed'],
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(api.dispose);
      final product = (await api.lookup('012345678905')).product!;
      expect(product.ingredientsLanguage, 'es');
      expect(
        AllergenMatcher.evaluate(
          product: product,
          profile: milkProfile,
        ).level.name,
        'unknown',
      );
    });
  });

  group('Storage and emergency voice', () {
    late Directory temp;
    late TraceDatabase db;
    late AppState app;
    late AppLock lock;
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() async {
      SharedPreferences.setMockInitialValues({'onboardingComplete': true});
      temp = await Directory.systemTemp.createTemp('submission_review_');
      db = TraceDatabase.atPath('${temp.path}/test.db');
      lock = AppLock(device: _Device());
      app = AppState(database: db, lock: lock);
      await app.init();
      await app.unlock();
    });
    tearDown(() async {
      app.dispose();
      await db.close();
      await temp.delete(recursive: true);
    });
    test(
      'write failure is reported; ordered retry persists the latest edit',
      () async {
        final raw = await db.db;
        await raw.execute(
          "CREATE TRIGGER fail_save BEFORE INSERT ON reactions BEGIN SELECT RAISE(ABORT, 'disk unavailable'); END",
        );
        ReactionLog record(String notes) => ReactionLog(
          id: 'r',
          profileId: app.activeProfile.id,
          occurredAt: DateTime(2026, 10, 24),
          notes: notes,
          symptoms: [],
        );
        expect(await app.saveReaction(record('first')), isFalse);
        expect(app.hasUnsavedChanges, isTrue);
        expect(await app.saveReaction(record('latest')), isFalse);
        expect(app.reactions.single.notes, 'latest');
        await raw.execute('DROP TRIGGER fail_save');
        expect(await app.retryPendingStorage(), isTrue);
        expect(app.hasUnsavedChanges, isFalse);
        await db.close();
        expect((await db.listReactions()).single.notes, 'latest');
      },
    );
    test(
      'v7 cached products migrate without inventing an English language',
      () async {
        final product = Product.fromOcr('leche, azúcar');
        await db.upsertProduct(product);
        final raw = await db.db;
        await raw.execute(
          'ALTER TABLE products DROP COLUMN ingredientsLanguage',
        );
        await raw.setVersion(7);
        await db.close();
        final restored = await db.cachedProduct(product.barcode);
        expect(restored, isNotNull);
        expect(restored!.ingredientsLanguage, isNull);
        expect(
          AllergenMatcher.evaluate(
            product: restored,
            profile: milkProfile,
          ).level.name,
          'unknown',
        );
      },
    );
    testWidgets(
      'emergency call asks for current country and allows correction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => callEmergency(
                  context,
                  const LocalEmergencyNumber(
                    number: '119',
                    where: 'Japan',
                    isFallback: false,
                  ),
                ),
                child: const Text('Help'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Help'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm your current country'), findsOneWidget);
        expect(
          find.text('Call 119 for an ambulance in Japan.'),
          findsOneWidget,
        );
        await tester.tap(find.byType(DropdownButtonFormField<Country>));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('United States'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('United States').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Call 911 for an ambulance in United States.'),
          findsOneWidget,
        );
        // Cancel never starts a call, regardless of the destination suggestion.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm your current country'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      'locking emergency mode stops voice and discards queued speech',
      (tester) async {
        final methods = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('fly_allergy_safe/speech'),
          (call) async {
            methods.add(call.method);
            return call.method == 'availability' ? 'available' : null;
          },
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('fly_allergy_safe/speech/events'),
          (_) async => null,
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(
            const MethodChannel('fly_allergy_safe/speech'),
            null,
          );
          messenger.setMockMethodCallHandler(
            const MethodChannel('fly_allergy_safe/speech/events'),
            null,
          );
        });
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: app,
            child: const MaterialApp(home: EmergencyModeScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(methods, contains('start'));
        app.lockNow();
        await tester.pump();
        expect(methods.last, 'stop');
        final startCount = methods.where((m) => m == 'start').length;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await messenger.handlePlatformMessage(
          'fly_allergy_safe/speech/events',
          const StandardMethodCodec().encodeSuccessEnvelope({
            'type': 'segment',
            'text': 'epinephrine given',
          }),
          (_) {},
        );
        await tester.pump();
        expect(app.reactions, isEmpty);
        expect(methods.where((m) => m == 'start').length, startCount);
        await tester.runAsync(() => app.unlock());
        await tester.pump();
        await tester.pump();
        expect(methods.where((m) => m == 'start').length, startCount + 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
