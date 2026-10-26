import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trace_allergy/data/airline_policies.dart';
import 'package:trace_allergy/data/countries.dart';
import 'package:trace_allergy/data/day_of_travel.dart';
import 'package:trace_allergy/data/translator_languages.dart';
import 'package:trace_allergy/models/emergency.dart';
import 'package:trace_allergy/models/flight.dart';
import 'package:trace_allergy/models/travel.dart';
import 'package:trace_allergy/models/trip.dart';
import 'package:trace_allergy/services/app_state.dart';
import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/screens/crew_card_screen.dart';
import 'package:trace_allergy/services/database.dart';
import 'package:trace_allergy/services/emergency_actions.dart';
import 'package:trace_allergy/services/emergency_summary.dart';
import 'package:trace_allergy/services/incident_composer.dart';
import 'package:trace_allergy/services/trip_journal.dart';
import 'package:trace_allergy/services/language_suggestions.dart';
import 'package:trace_allergy/widgets/travel_format.dart';
import 'package:trace_allergy/widgets/trip_card.dart';

/// The v4 tables the v5 and v6 upgrades touch, exactly as v4 created them.
Future<void> _createV4(Database d) async {
  await d.execute('CREATE TABLE products (barcode TEXT PRIMARY KEY, translatedFrom TEXT)');
  await d.execute('''
    CREATE TABLE profiles (
      id TEXT PRIMARY KEY, name TEXT, allergens TEXT,
      customAllergens TEXT DEFAULT '[]', avoidPalWhenUnsure INTEGER, notes TEXT,
      isChild INTEGER
    )''');
  await d.execute('''
    CREATE TABLE flights (
      id TEXT PRIMARY KEY, airlineIata TEXT, flightNumber TEXT, origin TEXT,
      destination TEXT, departsAt INTEGER, arrivesAt INTEGER,
      aircraftType TEXT, seat TEXT, priorArrivalAt INTEGER, booked INTEGER
    )''');
  await d.execute('''
    CREATE TABLE incident_reports (
      id TEXT PRIMARY KEY, flightId TEXT, createdAt INTEGER, kind TEXT,
      narrative TEXT, requestIds TEXT, reactionId TEXT, filedWith TEXT,
      filedAt INTEGER
    )''');
  await d.execute('''
    CREATE TABLE snack_reports (
      id TEXT PRIMARY KEY, flightId TEXT, "row" INTEGER, allergenNames TEXT,
      reportedAt INTEGER, description TEXT, selfReported INTEGER
    )''');
  await d.execute('''
    CREATE TABLE reactions (
      id TEXT PRIMARY KEY, profileId TEXT, occurredAt INTEGER, symptoms TEXT,
      suspectedFood TEXT, barcode TEXT, epiUsed INTEGER, soughtCare INTEGER,
      notes TEXT, severityRating INTEGER
    )''');
}

final DateTime _dep = DateTime(2026, 3, 12, 9, 30);
final DateTime _arr = DateTime(2026, 3, 12, 21, 10);

Future<void> _seedV4(Database d) async {
  await d.insert('flights', <String, Object?>{
    'id': 'f1',
    'airlineIata': 'UA',
    'flightNumber': '837',
    'origin': 'SFO',
    'destination': 'NRT',
    'departsAt': _dep.millisecondsSinceEpoch,
    'arrivesAt': _arr.millisecondsSinceEpoch,
    'aircraftType': '787-9',
    'seat': '31C',
    'booked': 1,
  });
  await d.insert('snack_reports', <String, Object?>{
    'id': 's1',
    'flightId': 'f1',
    'row': 30,
    'allergenNames': 'Peanuts|Tree nuts',
    'reportedAt': _dep.add(const Duration(hours: 2)).millisecondsSinceEpoch,
    'description': 'Mixed nuts',
    'selfReported': 0,
  });
  await d.insert('snack_reports', <String, Object?>{
    'id': 's2',
    'flightId': 'gone',
    'row': 4,
    'allergenNames': 'Sesame',
    'reportedAt': _dep.millisecondsSinceEpoch,
    'description': '',
    'selfReported': 1,
  });
  await d.insert('incident_reports', <String, Object?>{
    'id': 'i1',
    'flightId': 'f1',
    'createdAt': _arr.millisecondsSinceEpoch,
    'kind': 'accommodationFailure',
    'narrative': 'Buffer zone not provided',
    'requestIds': '',
    'filedWith': 'airline',
  });
  await d.insert('reactions', <String, Object?>{
    'id': 'r1',
    'profileId': 'p1',
    'occurredAt': _arr.millisecondsSinceEpoch,
    'symptoms': 'Hives / rash',
    'epiUsed': 0,
    'soughtCare': 0,
    'severityRating': 2,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('travel_journal_test');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('Trip', () {
    test('round-trips through a map, dropping the time of day', () {
      final t = Trip(
        id: 't1',
        name: 'Tokyo',
        destinationCountry: 'JP',
        startsOn: DateTime(2026, 3, 12, 15, 45),
        endsOn: DateTime(2026, 3, 20),
        travelerIds: <String>['p1', 'p2'],
        notes: 'Spring break',
      );
      final back = Trip.fromMap(t.toMap());
      expect(back.name, 'Tokyo');
      expect(back.destinationCountry, 'JP');
      expect(back.startsOn, DateTime(2026, 3, 12));
      expect(back.travelerIds, <String>['p1', 'p2']);
      expect(back.notes, 'Spring break');
    });

    test('knows whether it is upcoming, underway or past', () {
      final t = Trip(
        id: 't',
        name: 'x',
        startsOn: DateTime(2026, 3, 12),
        endsOn: DateTime(2026, 3, 20),
      );
      expect(t.isUpcoming(DateTime(2026, 3, 11, 23)), isTrue);
      expect(t.daysUntil(DateTime(2026, 3, 9)), 3);
      expect(t.isUnderway(DateTime(2026, 3, 12, 0, 1)), isTrue);
      expect(t.isUnderway(DateTime(2026, 3, 20, 23, 59)), isTrue);
      expect(t.isPast(DateTime(2026, 3, 21)), isTrue);
      expect(t.isUnderway(DateTime(2026, 3, 21)), isFalse);
    });
  });

  group('Exposure', () {
    test('round-trips every field', () {
      final e = Exposure(
        id: 'e1',
        tripId: 't1',
        profileId: 'p1',
        flightId: 'f1',
        occurredAt: DateTime(2026, 3, 12, 11),
        allergenNames: <String>['Peanuts'],
        route: ExposureRoute.surface,
        source: 'Crumbs on the tray table',
        place: ExposurePlace.flight,
        row: 14,
        actions: <String>['Wiped the surface', 'Washed hands'],
        outcome: ExposureOutcome.symptoms,
        reactionId: 'r1',
        notes: 'Itchy hand',
      );
      final back = Exposure.fromMap(e.toMap());
      expect(back.route, ExposureRoute.surface);
      expect(back.place, ExposurePlace.flight);
      expect(back.row, 14);
      expect(back.actions, <String>['Wiped the surface', 'Washed hands']);
      expect(back.outcome, ExposureOutcome.symptoms);
      expect(back.reactionId, 'r1');
      expect(back.allergenNames, <String>['Peanuts']);
    });

    test('a damaged actions list does not lose the exposure', () {
      final map = Exposure(
        id: 'e1',
        tripId: 't1',
        occurredAt: DateTime(2026),
      ).toMap()
        ..['actions'] = 'not json';
      final back = Exposure.fromMap(map);
      expect(back.id, 'e1');
      expect(back.actions, isEmpty);
    });
  });

  group('ReactionLog', () {
    test('keeps epinephrine dose times and the timeline', () {
      final r = ReactionLog(
        id: 'r1',
        profileId: 'p1',
        occurredAt: DateTime(2026, 3, 12, 10),
        symptoms: <String>['Wheezing'],
        tripId: 't1',
        exposureId: 'e1',
        epiDoses: <DateTime>[
          DateTime(2026, 3, 12, 10, 2),
          DateTime(2026, 3, 12, 10, 14),
        ],
        timeline: <TimelineNote>[
          TimelineNote(at: DateTime(2026, 3, 12, 10, 5), text: 'Lips swelling'),
        ],
      );
      final back = ReactionLog.fromMap(r.toMap());
      expect(back.tripId, 't1');
      expect(back.exposureId, 'e1');
      expect(back.epiDoses, r.epiDoses);
      expect(back.timeline.single.text, 'Lips swelling');
      expect(back.timeline.single.at, DateTime(2026, 3, 12, 10, 5));
    });

    test('a row from before v5 loads with empty new fields', () {
      final back = ReactionLog.fromMap(<String, dynamic>{
        'id': 'r1',
        'profileId': 'p1',
        'occurredAt': 0,
        'symptoms': 'Hives / rash',
      });
      expect(back.tripId, isNull);
      expect(back.epiDoses, isEmpty);
      expect(back.timeline, isEmpty);
    });
  });

  group('Country table', () {
    test('codes are unique and the list is sorted by name', () {
      final codes = kCountries.map((c) => c.code).toList();
      expect(codes.toSet().length, codes.length);
      final names = kCountries.map((c) => c.name).toList();
      expect(names, List<String>.of(names)..sort());
    });

    test('every number is dialable digits', () {
      final digits = RegExp(r'^\d{2,5}$');
      for (final c in kCountries) {
        expect(digits.hasMatch(c.emergency), isTrue, reason: c.name);
        for (final n in c.alsoWorks) {
          expect(digits.hasMatch(n), isTrue, reason: '${c.name} $n');
        }
      }
    });

    test('every language is one the translator offers', () {
      final offered = kTranslatorLanguages.map((l) => l.code).toSet();
      for (final c in kCountries) {
        for (final l in c.languages) {
          expect(offered, contains(l), reason: '${c.name}: $l');
        }
      }
      for (final entry in kAirlineCrewLanguages.entries) {
        for (final l in entry.value) {
          expect(offered, contains(l), reason: '${entry.key}: $l');
        }
      }
    });

    test('every carrier with a policy has crew languages', () {
      for (final iata in kAirlinePolicies.keys) {
        expect(kAirlineCrewLanguages, contains(iata));
      }
    });

    test('medical numbers come first, and unknown places fall back to 112', () {
      expect(emergencyNumberFor('jp').number, '119');
      expect(emergencyNumberFor('JP').isFallback, isFalse);
      expect(emergencyNumberFor('GB').number, '999');
      expect(emergencyNumberFor('').number, '112');
      expect(emergencyNumberFor('').isFallback, isTrue);
      expect(emergencyNumberFor('ZZ').isFallback, isTrue);
      expect(countryFor('jp')!.flag, '🇯🇵');
    });
  });

  group('Database v4 to v5', () {
    test('turns each flight into a trip and snack reports into exposures',
        () async {
      final path = '${tmp.path}/trace.db';
      final old = await openDatabase(path, version: 4, onCreate: (d, _) async {
        await _createV4(d);
        await _seedV4(d);
      });
      await old.close();

      final db = TraceDatabase.atPath(path);
      final trips = await db.listTrips();
      expect(trips, hasLength(1));
      expect(trips.single.id, 'trip-f1');
      expect(trips.single.name, 'SFO → NRT');
      expect(trips.single.startsOn, DateTime(2026, 3, 12));
      expect(trips.single.travelerIds, isEmpty);

      final flight = (await db.listFlights()).single;
      expect(flight.tripId, 'trip-f1');

      final incident = (await db.listIncidents()).single;
      expect(incident.tripId, 'trip-f1');

      // s2 belonged to a flight that no longer exists, so it has no trip.
      final exposures = await db.listExposures();
      expect(exposures, hasLength(1));
      final e = exposures.single;
      expect(e.id, 'snack-s1');
      expect(e.tripId, 'trip-f1');
      expect(e.flightId, 'f1');
      expect(e.row, 30);
      expect(e.route, ExposureRoute.observedNearby);
      expect(e.allergenNames, <String>['Peanuts', 'Tree nuts']);
      expect(e.source, 'Mixed nuts');
      expect(e.profileId, isEmpty);

      final reaction = (await db.listReactions()).single;
      expect(reaction.symptoms, <String>['Hives / rash']);
      expect(reaction.epiDoses, isEmpty);
      await db.close();
    });

    test('an upgrade that runs twice writes nothing twice', () async {
      final path = '${tmp.path}/trace.db';
      final old = await openDatabase(path, version: 4, onCreate: (d, _) async {
        await _createV4(d);
        await _seedV4(d);
      });
      await old.close();

      var db = TraceDatabase.atPath(path);
      await db.listTrips();
      await db.close();

      // Pretend the version bump never landed, as after a crash mid-upgrade.
      final raw = await openDatabase(path);
      await raw.setVersion(4);
      await raw.close();

      db = TraceDatabase.atPath(path);
      expect(await db.listTrips(), hasLength(1));
      expect(await db.listExposures(), hasLength(1));
      await db.close();
    });

    test('a fresh install has the v5 tables and columns', () async {
      final db = TraceDatabase.atPath('${tmp.path}/fresh.db');
      await db.upsertTrip(Trip(
        id: 't1',
        name: 'Lisbon',
        destinationCountry: 'PT',
        startsOn: DateTime(2026, 6, 1),
        endsOn: DateTime(2026, 6, 8),
      ));
      await db.upsertFlight(Flight(
        id: 'f1',
        airlineIata: 'TP',
        flightNumber: '1',
        origin: 'EWR',
        destination: 'LIS',
        departsAt: DateTime(2026, 6, 1, 20),
        arrivesAt: DateTime(2026, 6, 2, 8),
        tripId: 't1',
      ));
      await db.upsertExposure(Exposure(
        id: 'e1',
        tripId: 't1',
        occurredAt: DateTime(2026, 6, 3),
        place: ExposurePlace.restaurant,
        placeName: 'Café on Rua Augusta',
      ));
      await db.upsertReaction(ReactionLog(
        id: 'r1',
        profileId: 'p1',
        occurredAt: DateTime(2026, 6, 3),
        symptoms: <String>[],
        tripId: 't1',
        epiDoses: <DateTime>[DateTime(2026, 6, 3, 12)],
      ));
      expect((await db.listTrips()).single.destinationCountry, 'PT');
      expect((await db.listFlights()).single.tripId, 't1');
      expect((await db.listExposures()).single.placeName, 'Café on Rua Augusta');
      expect((await db.listReactions()).single.epiDoses, hasLength(1));
      await db.close();
    });
  });

  group('AppState travel journal', () {
    late AppState app;
    late TraceDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      db = TraceDatabase.atPath('${tmp.path}/app.db');
      app = AppState(database: db);
      await app.init();
    });

    tearDown(() async {
      await db.close();
    });

    Trip trip(String id, DateTime start, DateTime end) =>
        Trip(id: id, name: id, startsOn: start, endsOn: end);

    test('leads with the trip underway, then the next one', () async {
      await app.saveTrip(trip('past', DateTime(2026, 1, 1), DateTime(2026, 1, 5)));
      await app.saveTrip(trip('next', DateTime(2026, 5, 1), DateTime(2026, 5, 9)));
      await app.saveTrip(trip('later', DateTime(2026, 8, 1), DateTime(2026, 8, 9)));

      expect(app.activeTrip(DateTime(2026, 3, 1))!.id, 'next');
      expect(app.activeTrip(DateTime(2026, 5, 4))!.id, 'next');
      expect(app.activeTrip(DateTime(2026, 9, 1)), isNull);

      // Overlapping trips: the one that started most recently is the one
      // the traveler is on.
      await app.saveTrip(trip('side', DateTime(2026, 5, 3), DateTime(2026, 5, 5)));
      expect(app.activeTrip(DateTime(2026, 5, 4))!.id, 'side');
    });

    test('knows which leg is being flown, boarding and arrival included',
        () async {
      final f = Flight(
        id: 'f1',
        airlineIata: 'UA',
        flightNumber: '837',
        origin: 'SFO',
        destination: 'NRT',
        departsAt: _dep,
        arrivesAt: _arr,
      );
      await app.saveFlight(f);
      expect(app.flightInProgress(_dep.subtract(const Duration(minutes: 20)))?.id, 'f1');
      expect(app.flightInProgress(_arr.add(const Duration(minutes: 20)))?.id, 'f1');
      expect(app.flightInProgress(_dep.subtract(const Duration(hours: 2))), isNull);
    });

    test('deleting a trip removes its records but keeps reactions', () async {
      final t = trip('t1', DateTime(2026, 3, 12), DateTime(2026, 3, 20));
      await app.saveTrip(t);
      await app.saveFlight(Flight(
        id: 'f1',
        airlineIata: 'UA',
        flightNumber: '837',
        origin: 'SFO',
        destination: 'NRT',
        departsAt: _dep,
        arrivesAt: _arr,
        tripId: 't1',
      ));
      await app.saveRequest(AccommodationRequest(
        id: 'q1',
        flightId: 'f1',
        type: AccommodationType.bufferZone,
        requestedAt: DateTime(2026, 3, 1),
      ));
      await app.saveExposure(Exposure(
        id: 'e1',
        tripId: 't1',
        occurredAt: DateTime(2026, 3, 13),
      ));
      await app.saveIncident(IncidentReport(
        id: 'i1',
        flightId: '',
        tripId: 't1',
        createdAt: DateTime(2026, 3, 14),
        kind: IncidentKind.venueFailure,
      ));
      await app.saveReaction(ReactionLog(
        id: 'r1',
        profileId: app.activeProfile.id,
        occurredAt: DateTime(2026, 3, 13),
        symptoms: <String>['Hives / rash'],
        tripId: 't1',
      ));

      expect(app.flightsFor('t1'), hasLength(1));
      expect(app.exposuresFor('t1'), hasLength(1));
      expect(app.incidentsFor('t1'), hasLength(1));
      expect(app.reactionsFor('t1'), hasLength(1));

      await app.deleteTrip('t1');

      expect(app.trips, isEmpty);
      expect(app.flights, isEmpty);
      expect(app.requestsFor('f1'), isEmpty);
      expect(app.exposures, isEmpty);
      expect(app.incidents, isEmpty);
      expect(app.reactions.single.tripId, isNull);
      expect((await db.listReactions()).single.tripId, isNull);
      expect(await db.listRequests(), isEmpty);
    });
  });

  group('Language suggestions', () {
    Trip tokyo() => Trip(
          id: 't',
          name: 'Tokyo',
          destinationCountry: 'JP',
          startsOn: DateTime(2026, 3, 12),
          endsOn: DateTime(2026, 3, 20),
        );
    Flight leg(String iata) => Flight(
          id: iata,
          airlineIata: iata,
          flightNumber: '1',
          origin: 'AAA',
          destination: 'BBB',
          departsAt: DateTime(2026, 3, 12, 9),
          arrivesAt: DateTime(2026, 3, 12, 20),
        );

    test('destination first, then crew languages, without the phone language',
        () {
      final packs = LanguageSuggestions.packsFor(
        trip: tokyo(),
        legs: <Flight>[leg('LH'), leg('UA')],
        deviceLanguage: 'en',
      );
      expect(packs, <String>['ja', 'de']);
    });

    test('a Spanish-speaking phone is offered English for a US carrier', () {
      final packs = LanguageSuggestions.packsFor(
        trip: tokyo(),
        legs: <Flight>[leg('UA')],
        deviceLanguage: 'es',
      );
      expect(packs, <String>['ja', 'en']);
    });

    test('an unknown destination suggests only crew languages', () {
      final t = tokyo()..destinationCountry = '';
      expect(
        LanguageSuggestions.packsFor(
          trip: t,
          legs: <Flight>[leg('AF')],
          deviceLanguage: 'en',
        ),
        <String>['fr'],
      );
    });

    test('offers the chef card language only when it would change', () {
      expect(
        LanguageSuggestions.cardLanguageFor(
          trip: tokyo(),
          currentCardLanguage: 'en',
        ),
        'ja',
      );
      expect(
        LanguageSuggestions.cardLanguageFor(
          trip: tokyo(),
          currentCardLanguage: 'ja',
        ),
        isNull,
      );
      // Hindi has no hand-written card, so India offers nothing.
      expect(
        LanguageSuggestions.cardLanguageFor(
          trip: tokyo()..destinationCountry = 'IN',
          currentCardLanguage: 'en',
        ),
        isNull,
      );
    });

    test('starts suggesting a week out and stops when the trip ends', () {
      final t = tokyo();
      expect(LanguageSuggestions.isTimely(t, DateTime(2026, 3, 1)), isFalse);
      expect(LanguageSuggestions.isTimely(t, DateTime(2026, 3, 5)), isTrue);
      expect(LanguageSuggestions.isTimely(t, DateTime(2026, 3, 18)), isTrue);
      expect(LanguageSuggestions.isTimely(t, DateTime(2026, 3, 21)), isFalse);
    });
  });

  group('Trip wording', () {
    test('date ranges read naturally', () {
      expect(
        formatTripDates(DateTime(2026, 3, 12), DateTime(2026, 3, 20)),
        '12–20 Mar 2026',
      );
      expect(
        formatTripDates(DateTime(2026, 3, 28), DateTime(2026, 4, 3)),
        '28 Mar – 3 Apr 2026',
      );
      expect(
        formatTripDates(DateTime(2026, 12, 30), DateTime(2027, 1, 4)),
        '30 Dec 2026 – 4 Jan 2027',
      );
      expect(
        formatTripDates(DateTime(2026, 5, 2), DateTime(2026, 5, 2)),
        '2 May 2026',
      );
    });

    test('status says how far away, which day, or when it ended', () {
      final t = Trip(
        id: 't',
        name: 'x',
        startsOn: DateTime(2026, 3, 12),
        endsOn: DateTime(2026, 3, 19),
      );
      expect(tripStatusLine(t, DateTime(2026, 3, 9)), 'In 3 days');
      expect(tripStatusLine(t, DateTime(2026, 3, 11)), 'Tomorrow');
      expect(tripStatusLine(t, DateTime(2026, 3, 12, 8)), 'Day 1 of 8');
      expect(tripStatusLine(t, DateTime(2026, 3, 19, 22)), 'Day 8 of 8');
      expect(tripStatusLine(t, DateTime(2026, 3, 25)), 'Ended 19 Mar');
    });
  });

  group('Trip journal', () {
    final maya = Profile(
      id: 'p1',
      name: 'Maya',
      allergens: <Allergen, Severity>{Allergen.peanut: Severity.severe},
    );
    final leg = Flight(
      id: 'f1',
      airlineIata: 'UA',
      flightNumber: '837',
      origin: 'SFO',
      destination: 'NRT',
      departsAt: DateTime(2026, 3, 12, 11),
      arrivesAt: DateTime(2026, 3, 13, 15),
      seat: '31C',
      tripId: 't1',
    );

    List<JournalEntry> build() => TripJournal.entries(
          legs: <Flight>[leg],
          requests: <AccommodationRequest>[
            AccommodationRequest(
              id: 'q1',
              flightId: 'f1',
              type: AccommodationType.bufferZone,
              requestedAt: DateTime(2026, 3, 1, 9),
              status: RequestStatus.confirmed,
              reference: 'ABC123',
            ),
          ],
          exposures: <Exposure>[
            Exposure(
              id: 'e1',
              tripId: 't1',
              profileId: 'p1',
              flightId: 'f1',
              occurredAt: DateTime(2026, 3, 12, 14),
              allergenNames: <String>['Peanut'],
              route: ExposureRoute.surface,
              place: ExposurePlace.flight,
              row: 31,
            ),
          ],
          reactions: <ReactionLog>[
            ReactionLog(
              id: 'r1',
              profileId: 'p1',
              occurredAt: DateTime(2026, 3, 12, 14, 20),
              symptoms: <String>['Hives / rash'],
              severityRating: 2,
              epiDoses: <DateTime>[DateTime(2026, 3, 12, 14, 25)],
            ),
          ],
          incidents: const <IncidentReport>[],
          wipeDowns: <SeatCleaningLog>[
            SeatCleaningLog(
              id: 'w1',
              flightId: 'f1',
              cleanedAt: DateTime(2026, 3, 12, 10, 40),
              surfaces: <String>['Armrests', 'Tray table (both sides)'],
            ),
          ],
          profiles: <Profile>[maya],
        );

    test('orders everything by time and says who and where', () {
      final entries = build();
      expect(entries.map((e) => e.kind).toList(), <JournalKind>[
        JournalKind.request,
        JournalKind.wipeDown,
        JournalKind.flight,
        JournalKind.exposure,
        JournalKind.reaction,
      ]);
      final exposure = entries[3];
      expect(exposure.title, 'Maya: Peanut');
      expect(exposure.detail, contains('UA837 row 31'));
      expect(entries[0].detail, contains('Ref ABC123'));
      expect(entries[4].detail, contains('epinephrine 14:25'));
    });

    test('the report groups entries by day', () {
      final trip = Trip(
        id: 't1',
        name: 'Tokyo',
        destinationCountry: 'JP',
        startsOn: DateTime(2026, 3, 12),
        endsOn: DateTime(2026, 3, 20),
      );
      final text = TripJournal.report(
        trip: trip,
        entries: build(),
        travelers: 'Maya',
      );
      expect(text, startsWith('Tokyo\n12–20 Mar 2026\nTravelers: Maya'));
      expect(text, contains('Destination: Japan'));
      expect(text, contains('Sun 1 Mar 2026'));
      expect(text, contains('Thu 12 Mar 2026'));
      expect(text, contains('14:00  EXPOSURES: Maya: Peanut'));
    });
  });

  group('Crew card', () {
    final maya = Profile(
      id: 'p1',
      name: 'Maya',
      allergens: <Allergen, Severity>{Allergen.peanut: Severity.severe},
    );
    final leg = Flight(
      id: 'f1',
      airlineIata: 'LH',
      flightNumber: '455',
      origin: 'SFO',
      destination: 'FRA',
      departsAt: DateTime(2026, 3, 12, 11),
      arrivesAt: DateTime(2026, 3, 13, 7),
      seat: '31C',
    );
    AccommodationRequest req(String id, AccommodationType t, RequestStatus s) =>
        AccommodationRequest(
          id: id,
          flightId: 'f1',
          type: t,
          requestedAt: DateTime(2026, 3, 1),
          status: s,
          reference: id == 'q1' ? 'XYZ9' : '',
        );

    test('shows what was agreed and asked, never what was refused', () {
      final text = composeCrewCard(
        flight: leg,
        travelers: <Profile>[maya],
        requests: <AccommodationRequest>[
          req('q1', AccommodationType.bufferZone, RequestStatus.confirmed),
          req('q2', AccommodationType.preboardToWipe, RequestStatus.pending),
          req('q3', AccommodationType.noNutService, RequestStatus.refused),
        ],
        pens: <EpiPen>[
          EpiPen(
            id: 'e',
            label: 'Pen',
            expiresOn: DateTime(2027),
            location: 'Blue backpack, front pocket',
          ),
        ],
      );
      expect(text, contains('Maya has a severe food allergy to peanut.'));
      expect(text, contains('anaphylaxis'));
      expect(text, contains('seat 31C'));
      expect(text, contains('Nut-free buffer zone (ref. XYZ9)'));
      expect(text, contains('I have asked for:'));
      expect(text, contains('Pre-board to wipe down seat area'));
      expect(text, isNot(contains('Suspend nut service')));
      expect(text, contains('Blue backpack, front pocket'));
    });
  });

  group('Incidents off a flight', () {
    test('are written to the venue, not an airline or regulator', () {
      expect(IncidentKind.venueFailure.concernsFlight, isFalse);
      expect(IncidentKind.crewConduct.concernsFlight, isTrue);
      final text = IncidentComposer.compose(
        report: IncidentReport(
          id: 'i1',
          flightId: '',
          createdAt: DateTime(2026, 3, 14),
          kind: IncidentKind.venueFailure,
          narrative: 'Told the waiter twice; the sauce had peanuts.',
        ),
        flight: null,
        profile: Profile(
          id: 'p1',
          name: 'Maya',
          allergens: <Allergen, Severity>{Allergen.peanut: Severity.severe},
        ),
        requests: const <AccommodationRequest>[],
      );
      expect(text, startsWith('To: [The manager'));
      expect(text, contains('Told the waiter twice'));
      expect(text, isNot(contains('Customer Relations')));
      expect(text, isNot(contains('Department of Transportation')));
      expect(text, isNot(contains('FLIGHT')));
    });
  });

  group('Emergency number', () {
    final japan = Trip(
      id: 't',
      name: 'Tokyo',
      destinationCountry: 'JP',
      startsOn: DateTime(2026, 3, 12),
      endsOn: DateTime(2026, 3, 20),
    );

    test('a trip underway beats the phone region', () {
      final n = resolveEmergencyNumber(underwayTrip: japan, deviceRegion: 'US');
      expect(n.number, '119');
      expect(n.where, 'Japan');
      expect(n.isFallback, isFalse);
    });

    test('no trip uses the phone region', () {
      expect(resolveEmergencyNumber(deviceRegion: 'GB').number, '999');
      expect(resolveEmergencyNumber(deviceRegion: 'AU').number, '000');
    });

    test('a trip with no country falls through to the region', () {
      final n = resolveEmergencyNumber(
        underwayTrip: japan..destinationCountry = '',
        deviceRegion: 'FR',
      );
      expect(n.number, '15');
    });

    test('nothing known falls back to 911, marked as a fallback', () {
      final n = resolveEmergencyNumber(deviceRegion: null);
      expect(n.number, '911');
      expect(n.isFallback, isTrue);
    });
  });

  group('Emergency summary', () {
    final maya = Profile(
      id: 'p1',
      name: 'Maya',
      allergens: <Allergen, Severity>{Allergen.peanut: Severity.severe},
    );
    final start = DateTime(2026, 3, 12, 14, 0);
    final record = ReactionLog(
      id: 'r1',
      profileId: 'p1',
      occurredAt: start,
      symptoms: <String>['Wheezing', 'Swelling (lips, face, eyes)'],
      epiUsed: true,
      epiDoses: <DateTime>[
        DateTime(2026, 3, 12, 14, 2),
        DateTime(2026, 3, 12, 14, 12),
      ],
      timeline: <TimelineNote>[
        TimelineNote(at: DateTime(2026, 3, 12, 14, 5), text: 'Lips swelling'),
      ],
    );
    final leg = Flight(
      id: 'f1',
      airlineIata: 'UA',
      flightNumber: '837',
      origin: 'SFO',
      destination: 'NRT',
      departsAt: DateTime(2026, 3, 12, 11),
      arrivesAt: DateTime(2026, 3, 13, 15),
      seat: '31C',
    );

    test('the handover gives each dose time and how long ago', () {
      final text = EmergencySummary.handover(
        profile: maya,
        record: record,
        now: DateTime(2026, 3, 12, 14, 20),
        flight: leg,
      );
      expect(text, contains('Patient: Maya'));
      expect(text, contains('Allergies: Peanut'));
      expect(text, contains('Epinephrine dose 1: 14:02 (18 min ago)'));
      expect(text, contains('Epinephrine dose 2: 14:12 (8 min ago)'));
      expect(text, contains('Symptoms: Wheezing'));
      expect(text, contains('14:05  Lips swelling'));
      expect(text, contains('Flight: UA837 SFO to NRT, seat 31C'));
    });

    test('no dose recorded is said plainly', () {
      final text = EmergencySummary.handover(
        profile: maya,
        record: ReactionLog(
          id: 'r2',
          profileId: 'p1',
          occurredAt: start,
          symptoms: <String>[],
        ),
        now: start,
      );
      expect(text, contains('Epinephrine: none recorded'));
    });

    test('the text to a contact says what, when and where', () {
      final text = EmergencySummary.textToContact(
        name: 'Maya',
        doses: record.epiDoses,
        flight: leg,
      );
      expect(
        text,
        'EMERGENCY: Maya is having a severe allergic reaction. Epinephrine '
        'given at 14:02 and 14:12. On flight UA837 SFO to NRT, seat 31C. I '
        'will update you.',
      );
      expect(
        EmergencySummary.textToContact(
          name: 'Maya',
          doses: const <DateTime>[],
          country: 'Japan',
        ),
        'EMERGENCY: Maya is having a severe allergic reaction. We are in '
        'Japan. I will update you.',
      );
    });
  });

  group('Home country and trip names', () {
    String? name(String code) => countryFor(code)?.name;

    test('domestic, international, or unknown', () {
      expect(tripNameFor(destination: 'US', home: 'US', countryName: name),
          'Domestic travel');
      expect(tripNameFor(destination: 'JP', home: 'US', countryName: name),
          'International travel to Japan');
      expect(tripNameFor(destination: 'JP', home: '', countryName: name),
          'Travel to Japan');
      expect(tripNameFor(destination: '', home: 'US', countryName: name), 'Travel');
    });

    test('knows which names the app made up', () {
      expect(isGeneratedTripName('Trip to United States'), isTrue);
      expect(isGeneratedTripName('International travel to Japan'), isTrue);
      expect(isGeneratedTripName('Domestic travel'), isTrue);
      expect(isGeneratedTripName("Grandma's 80th"), isFalse);
    });

    test('the profile keeps its home country', () {
      final p = Profile(id: 'p', name: 'Maya', homeCountry: 'GB');
      expect(Profile.fromMap(p.toMap()).homeCountry, 'GB');
      expect(Profile.fromMap(<String, dynamic>{'id': 'p', 'name': 'x'}).homeCountry, '');
    });

    test('at home, the emergency number follows the home country', () {
      expect(resolveEmergencyNumber(homeCountry: 'AU', deviceRegion: 'US').number, '000');
      expect(resolveEmergencyNumber(homeCountry: '', deviceRegion: 'GB').number, '999');
    });

    test('old generated names are renamed; typed names are not', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final db = TraceDatabase.atPath('${tmp.path}/names.db');
      var app = AppState(database: db);
      await app.init();
      final home = app.activeProfile.homeCountry;
      expect(home, isNotEmpty, reason: 'filled from the test locale');
      final abroad = home == 'JP' ? 'FR' : 'JP';

      for (final (String id, String country, String name) in <(String, String, String)>[
        ('a', home, 'Trip to ${countryFor(home)!.name}'),
        ('b', abroad, 'Trip to ${countryFor(abroad)!.name}'),
        ('c', abroad, "Grandma's 80th"),
      ]) {
        await db.upsertTrip(Trip(
          id: id,
          name: name,
          destinationCountry: country,
          startsOn: DateTime(2026, 11, 1),
          endsOn: DateTime(2026, 11, 5),
        ));
      }

      app = AppState(database: db);
      await app.init();
      expect(app.tripById('a')!.name, 'Domestic travel');
      expect(app.tripById('b')!.name, 'International travel to ${countryFor(abroad)!.name}');
      expect(app.tripById('c')!.name, "Grandma's 80th");

      // Moving home turns the domestic trip international.
      await app.saveProfile(
        Profile(id: app.activeProfile.id, name: 'Me', homeCountry: abroad),
        recordHistory: false,
      );
      expect(app.tripById('b')!.name, 'Domestic travel');
      await db.close();
    });
  });

  group('At the airport and on board', () {
    test('every script fills every placeholder', () {
      const v = DayScriptValues(
        name: 'Maya',
        allergens: 'peanut',
        seat: '31C',
        flight: 'UA837',
        pen: 'in the blue backpack',
      );
      for (final stage in kDayOfTravel) {
        expect(stage.asks, isNotEmpty, reason: stage.title);
        for (final ask in stage.asks) {
          final text = fillDayScript(ask.script, v);
          expect(text, isNot(contains('{')), reason: ask.title);
          expect(text, isNot(contains('[')), reason: ask.title);
        }
      }
    });

    test('unknown details become visible blanks, never guesses', () {
      final text = fillDayScript(
        'We are in {seat} on {flight}. The epinephrine is {pen}.',
        const DayScriptValues(),
      );
      expect(text, 'We are in [seat] on [flight number]. The epinephrine is '
          'in [where you keep it].');
    });

    test('grammar follows who is speaking', () {
      const template = '{name} has a severe {allergens} allergy.';
      expect(
        fillDayScript(template, const DayScriptValues(name: 'Maya', allergens: 'peanut')),
        'Maya has a severe peanut allergy.',
      );
      expect(
        fillDayScript(template,
            const DayScriptValues(name: 'I', allergens: 'peanut', plural: true)),
        'I have a severe peanut allergy.',
      );
      expect(
        fillDayScript(template, const DayScriptValues(
            name: 'Maya and Leo', allergens: 'peanut and sesame', plural: true)),
        'Maya and Leo have a severe peanut and sesame allergy.',
      );
    });

    test('the day runs check-in, gate, on board, in flight', () {
      expect(kDayOfTravel.map((s) => s.channel).toList(), <RequestChannel>[
        RequestChannel.checkIn,
        RequestChannel.gate,
        RequestChannel.onboard,
        RequestChannel.onboard,
      ]);
      expect(
        kDayOfTravel[1].asks.map((a) => a.type),
        contains(AccommodationType.preboardToWipe),
      );
    });
  });
}
