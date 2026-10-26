import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trace_allergy/data/safety_copy.dart';
import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/flight.dart';
import 'package:trace_allergy/models/flight_experience.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/models/trip.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/services/database.dart';
import 'package:trace_allergy/services/trip_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Safety wording', () {
    test('five prevention tips, each with a reason', () {
      expect(kFlightPreventionTips, hasLength(5));
      for (final tip in kFlightPreventionTips) {
        expect(tip.advice.trim(), isNotEmpty);
        expect(tip.reason.trim(), isNotEmpty, reason: tip.advice);
      }
    });

    test('at least five airlines with auto-injectors, every one sourced', () {
      expect(kAirlineEpinephrine.length, greaterThanOrEqualTo(5));
      for (final a in kAirlineEpinephrine) {
        expect(a.url, startsWith('https://'), reason: a.airline);
        expect(a.source.trim(), isNotEmpty, reason: a.airline);
      }
    });

    test('the kit facts say vials are the norm and landing may be needed', () {
      final facts = kMedicalKitFacts.join(' ');
      expect(facts, contains('vial'));
      expect(facts, contains('land'));
      expect(facts, contains('carry your own'));
    });

    test('the medical note says reactions change fast and to see a doctor', () {
      expect(kMedicalNoteLong, contains('change fast'));
      expect(kMedicalNoteLong, contains('doctor'));
      expect(kMedicalNoteLong, contains('not medical advice'));
    });

    test('strictness labels no longer read like reaction levels', () {
      expect(Severity.values.map((s) => s.label),
          <String>['Prefer to avoid', 'Avoid', 'Strict']);
      expect(Severity.severe.blocksOnTrace, isTrue);
    });
  });

  group('Flight experience', () {
    test('round-trips every field', () {
      final x = FlightExperience(
        id: 'x',
        flightId: 'f1',
        tripId: 't1',
        recordedAt: DateTime(2026, 3, 13),
        foodRating: Rating.poor,
        foodNotes: 'No ingredient list',
        staffRating: Rating.good,
        concerns: 'Nuts in row 12',
        askedAboutKit: true,
        kitEpinephrine: KitEpinephrine.vial,
        suggestions: 'Ask for the buffer zone at the gate',
      );
      final back = FlightExperience.fromMap(x.toMap());
      expect(back.foodRating, Rating.poor);
      expect(back.staffRating, Rating.good);
      expect(back.askedAboutKit, isTrue);
      expect(back.kitEpinephrine, KitEpinephrine.vial);
      expect(back.suggestions, 'Ask for the buffer zone at the gate');
      expect(back.isEmpty, isFalse);
      expect(FlightExperience(id: 'y', flightId: 'f', recordedAt: DateTime(2026)).isEmpty, isTrue);
    });

    test('shows in the timeline after the flight it describes', () {
      final leg = Flight(
        id: 'f1',
        airlineIata: 'DL',
        flightNumber: '1',
        origin: 'JFK',
        destination: 'LHR',
        departsAt: DateTime(2026, 3, 12, 20),
        arrivesAt: DateTime(2026, 3, 13, 8),
      );
      final entries = TripJournal.entries(
        legs: <Flight>[leg],
        requests: const [],
        exposures: const [],
        reactions: const [],
        incidents: const [],
        wipeDowns: const [],
        profiles: const <Profile>[],
        experiences: <FlightExperience>[
          FlightExperience(
            id: 'x',
            flightId: 'f1',
            recordedAt: DateTime(2026, 3, 20),
            kitEpinephrine: KitEpinephrine.autoInjector,
          ),
        ],
      );
      expect(entries.map((e) => e.kind), <JournalKind>[JournalKind.flight, JournalKind.experience]);
      expect(entries.last.title, 'Flight experience: DL1');
      expect(entries.last.detail, contains('Kit: Auto-injector'));
    });

    test('the trip card asks about a flight that landed this week', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final tmp = Directory.systemTemp.createTempSync('experience');
      final db = TraceDatabase.atPath('${tmp.path}/x.db');
      final app = AppState(database: db);
      await app.init();
      final now = DateTime(2026, 3, 14, 12);
      await app.saveTrip(Trip(
        id: 't1',
        name: 'London',
        startsOn: DateTime(2026, 3, 12),
        endsOn: DateTime(2026, 3, 20),
      ));
      await app.saveFlight(Flight(
        id: 'f1',
        airlineIata: 'DL',
        flightNumber: '1',
        origin: 'JFK',
        destination: 'LHR',
        departsAt: DateTime(2026, 3, 12, 20),
        arrivesAt: DateTime(2026, 3, 13, 8),
        tripId: 't1',
      ));
      expect(app.flightAwaitingExperience('t1', now)?.id, 'f1');
      await app.saveExperience(FlightExperience(id: 'x', flightId: 'f1', recordedAt: now));
      expect(app.flightAwaitingExperience('t1', now), isNull);

      // Survives a restart, from the v7 table.
      final again = AppState(database: db);
      await again.init();
      expect(again.experienceFor('f1')?.id, 'x');
      await db.close();
      tmp.deleteSync(recursive: true);
    });
  });

  group('Child card', () {
    test('defaults to the suggested wording and a short version', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final tmp = Directory.systemTemp.createTempSync('child');
      final db = TraceDatabase.atPath('${tmp.path}/c.db');
      final app = AppState(database: db);
      await app.init();
      expect(app.childCardText, startsWith('Please do not give my child any food'));
      expect(app.childCardShort.length, lessThan(app.childCardText.length));
      await app.setChildCard(full: 'Ask me first, please.', short: '');
      expect(app.childCardText, 'Ask me first, please.');
      expect(app.childCardShort, kChildCardShortDefault, reason: 'empty restores the default');
      await db.close();
      tmp.deleteSync(recursive: true);
    });
  });
}
