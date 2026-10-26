import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/action_plan.dart';
import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/flight_experience.dart';
import '../models/product.dart';
import '../models/profile.dart';
import '../models/profile_revision.dart';
import '../models/scan_record.dart';
import '../models/travel.dart';
import '../models/trip.dart';
import '../models/verdict.dart';

/// The local store. Everything the app knows lives here — profiles, the
/// offline product cache, scan history, the emergency records and, from v2,
/// flights and the travel accountability trail — so the app works with no
/// signal at all.
class TraceDatabase {
  TraceDatabase._([this._path]);

  static final TraceDatabase instance = TraceDatabase._();

  factory TraceDatabase() => instance;

  /// A database at [path] rather than the app's own — for tests that need to
  /// open an old schema and watch it upgrade.
  @visibleForTesting
  factory TraceDatabase.atPath(String path) => TraceDatabase._(path);

  final String? _path;

  Database? _db;
  Future<Database>? _opening;

  /// Opens `trace.db` once. The in-flight future is cached so two concurrent
  /// callers during startup cannot each open their own handle.
  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    try {
      return await (_opening ??= _open());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  /// Bumped to 2 for Fly Allergy Safe: flights, accommodation requests,
  /// incident reports, seat cleaning logs and snack reports.
  ///
  /// Bumped to 3 for FRD Section 1: `profile_revisions` (1.2, an auditable
  /// trail of profile edits) and `action_plans` (1.3, airline-specific
  /// anaphylaxis plans).
  ///
  /// Bumped to 4 for the translator: `products.translatedFrom`. A machine
  /// translation must never be re-read as label text, and the language it came
  /// from is part of what makes that visible.
  ///
  /// Bumped to 5 for the travel journal: `trips` and `exposures`, a `tripId`
  /// on flights, incidents and reactions, and on reactions the epinephrine
  /// dose times and a timestamped timeline. Every existing flight becomes a
  /// trip of its own and every cabin snack report becomes an exposure, so the
  /// upgrade loses nothing the old travel screens showed.
  ///
  /// Bumped to 6 for `profiles.homeCountry`, which tells a domestic trip from
  /// an international one.
  ///
  /// Bumped to 7 for `flight_experiences`: how each flight went, recorded
  /// after landing.
  /// Bumped to 8 for ingredient language. Legacy text stays unverified.
  static const int schemaVersion = 8;

  Future<Database> _open() async {
    final path = _path ?? p.join(await getDatabasesPath(), 'trace.db');
    final database = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    _db = database;
    _opening = null;
    return database;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _opening = null;
  }

  Future<void> _createSchema(Database d, int version) async {
    final batch = d.batch();

    batch.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        name TEXT,
        allergens TEXT,
        customAllergens TEXT DEFAULT '[]',
        avoidPalWhenUnsure INTEGER,
        notes TEXT,
        isChild INTEGER
      )
    ''');

    // The offline cache. A product scanned once resolves forever after.
    batch.execute('''
      CREATE TABLE products (
        barcode TEXT PRIMARY KEY,
        name TEXT,
        brand TEXT,
        quantity TEXT,
        imageUrl TEXT,
        ingredientsText TEXT,
        allergenTags TEXT,
        tracesTags TEXT,
        additivesTags TEXT,
        labelsTags TEXT,
        source TEXT,
        ingredientsComplete INTEGER,
        fetchedAt INTEGER,
        ingredientsLanguage TEXT,
        translatedFrom TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE scans (
        id TEXT PRIMARY KEY,
        barcode TEXT,
        level TEXT,
        headline TEXT,
        scannedAt INTEGER,
        profileId TEXT,
        saved INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE epipens (
        id TEXT PRIMARY KEY,
        label TEXT,
        expiresOn INTEGER,
        brand TEXT,
        location TEXT,
        remindDaysBefore INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE contacts (
        id TEXT PRIMARY KEY,
        name TEXT,
        phone TEXT,
        relationship TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE reactions (
        id TEXT PRIMARY KEY,
        profileId TEXT,
        occurredAt INTEGER,
        symptoms TEXT,
        suspectedFood TEXT,
        barcode TEXT,
        epiUsed INTEGER,
        soughtCare INTEGER,
        notes TEXT,
        severityRating INTEGER
      )
    ''');

    batch.execute('CREATE INDEX idx_scans_scannedAt ON scans (scannedAt DESC)');
    batch.execute('CREATE INDEX idx_scans_barcode ON scans (barcode)');
    batch.execute(
      'CREATE INDEX idx_reactions_occurredAt ON reactions (occurredAt DESC)',
    );

    _addV2Tables(batch);

    batch.execute('''
      CREATE TABLE IF NOT EXISTS profile_revisions (
        id TEXT PRIMARY KEY,
        profileId TEXT,
        revision INTEGER,
        snapshot TEXT,
        changedAt INTEGER,
        changeSummary TEXT
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_revisions_profile '
      'ON profile_revisions(profileId, revision DESC)',
    );

    batch.execute('''
      CREATE TABLE IF NOT EXISTS action_plans (
        id TEXT PRIMARY KEY,
        title TEXT,
        airlineIataCode TEXT,
        airlineName TEXT,
        isDefault INTEGER DEFAULT 0,
        patient TEXT,
        epinephrine TEXT,
        medications TEXT,
        symptomSteps TEXT,
        emergencyContacts TEXT,
        physician TEXT,
        createdAt INTEGER,
        updatedAt INTEGER,
        version INTEGER DEFAULT 1
      )
    ''');

    await batch.commit(noResult: true);

    await _applyV5(d);
    await _applyV6(d);
    await _applyV7(d);
  }

  /// Migrates in place. A user's allergen profile and reaction history are the
  /// two things in here that cannot be recreated — dropping and rebuilding the
  /// schema would throw both away, so every step here is additive.
  Future<void> _upgradeSchema(Database d, int from, int to) async {
    if (from < 4) {
      // Additive. Existing rows get NULL, which is correct: nothing saved before
      // this version could have been a translation.
      await d.execute('ALTER TABLE products ADD COLUMN translatedFrom TEXT');
    }

    if (from < 3) {
      // FRD 1.2 and 1.3. Both are additive: an existing install keeps every
      // profile and simply starts its revision history from the next edit.
      final batch = d.batch();

      batch.execute('''
      CREATE TABLE IF NOT EXISTS profile_revisions (
        id TEXT PRIMARY KEY,
        profileId TEXT,
        revision INTEGER,
        snapshot TEXT,
        changedAt INTEGER,
        changeSummary TEXT
      )
    ''');
      batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_revisions_profile '
        'ON profile_revisions(profileId, revision DESC)',
      );

      batch.execute('''
      CREATE TABLE IF NOT EXISTS action_plans (
        id TEXT PRIMARY KEY,
        title TEXT,
        airlineIataCode TEXT,
        airlineName TEXT,
        isDefault INTEGER DEFAULT 0,
        patient TEXT,
        epinephrine TEXT,
        medications TEXT,
        symptomSteps TEXT,
        emergencyContacts TEXT,
        physician TEXT,
        createdAt INTEGER,
        updatedAt INTEGER,
        version INTEGER DEFAULT 1
      )
    ''');
      await batch.commit(noResult: true);
    }

    if (from < 2) {
      final batch = d.batch();

      // The profile gains user-defined triggers. Existing rows get an empty
      // JSON list, which is exactly what Profile.fromMap already tolerates.
      batch.execute(
        "ALTER TABLE profiles ADD COLUMN customAllergens TEXT DEFAULT '[]'",
      );
      batch.execute(
        "UPDATE profiles SET customAllergens = '[]' WHERE customAllergens IS NULL",
      );

      _addV2Tables(batch);

      await batch.commit(noResult: true);
    }

    // Last, because it alters tables the steps above may have only just
    // created when upgrading from a very old install.
    if (from < 5) {
      await _applyV5(d);
      await _carryFlightsIntoTrips(d);
    }
    if (from < 6) await _applyV6(d);
    if (from < 7) await _applyV7(d);
    if (from < 8) {
      final columns = await d.rawQuery('PRAGMA table_info(products)');
      if (!columns.any((c) => c['name'] == 'ingredientsLanguage')) {
        await d.execute(
          'ALTER TABLE products ADD COLUMN ingredientsLanguage TEXT',
        );
      }
    }
  }

  Future<void> _applyV7(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS flight_experiences (
        id TEXT PRIMARY KEY,
        flightId TEXT,
        tripId TEXT,
        recordedAt INTEGER,
        foodRating TEXT,
        foodNotes TEXT,
        staffRating TEXT,
        staffNotes TEXT,
        concerns TEXT,
        askedAboutKit INTEGER,
        kitEpinephrine TEXT,
        medicationNotes TEXT,
        suggestions TEXT
      )
    ''');
  }

  /// Existing profiles get an empty home country; the app fills it from the
  /// phone's region on the next launch.
  Future<void> _applyV6(Database d) async {
    await _addColumnIfMissing(d, 'profiles', 'homeCountry', 'TEXT');
  }

  /// The v5 schema: shared by fresh installs and upgrades, like
  /// [_addV2Tables], and safe to run twice for the same reason.
  Future<void> _applyV5(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS trips (
        id TEXT PRIMARY KEY,
        name TEXT,
        destinationCountry TEXT,
        startsOn INTEGER,
        endsOn INTEGER,
        travelerIds TEXT,
        notes TEXT,
        createdAt INTEGER
      )
    ''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS exposures (
        id TEXT PRIMARY KEY,
        tripId TEXT,
        profileId TEXT,
        flightId TEXT,
        occurredAt INTEGER,
        allergenNames TEXT,
        route TEXT,
        source TEXT,
        place TEXT,
        placeName TEXT,
        "row" INTEGER,
        actions TEXT,
        outcome TEXT,
        reactionId TEXT,
        notes TEXT
      )
    ''');

    await _addColumnIfMissing(d, 'flights', 'tripId', 'TEXT');
    await _addColumnIfMissing(d, 'incident_reports', 'tripId', 'TEXT');
    await _addColumnIfMissing(d, 'reactions', 'tripId', 'TEXT');
    await _addColumnIfMissing(d, 'reactions', 'exposureId', 'TEXT');
    await _addColumnIfMissing(d, 'reactions', 'epiDoses', 'TEXT');
    await _addColumnIfMissing(d, 'reactions', 'timeline', 'TEXT');

    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_trips_startsOn ON trips (startsOn)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_exposures_tripId ON exposures (tripId)',
    );
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_flights_tripId ON flights (tripId)',
    );
  }

  /// `ALTER TABLE ... ADD COLUMN` fails if the column exists, and an upgrade
  /// interrupted after adding it would otherwise fail forever on the retry.
  Future<void> _addColumnIfMissing(
    Database d,
    String table,
    String column,
    String type,
  ) async {
    final columns = await d.rawQuery('PRAGMA table_info($table)');
    if (columns.any((c) => c['name'] == column)) return;
    await d.execute('ALTER TABLE $table ADD COLUMN $column $type');
  }

  /// Gives every flight from before v5 a trip of its own, and turns the old
  /// cabin snack reports into exposures on that trip.
  ///
  /// Ids are derived from the source rows (`trip-<flightId>`,
  /// `snack-<reportId>`) so a retried upgrade finds what it already wrote
  /// instead of writing it twice.
  Future<void> _carryFlightsIntoTrips(Database d) async {
    await d.transaction((Transaction txn) async {
      final flights = await txn.query('flights', where: 'tripId IS NULL');
      for (final row in flights) {
        final flight = Flight.fromMap(row);
        final tripId = 'trip-${flight.id}';
        final trip = Trip(
          id: tripId,
          name: flight.origin.isEmpty && flight.destination.isEmpty
              ? flight.label
              : flight.route,
          startsOn: flight.departsAt,
          endsOn: flight.arrivesAt.isBefore(flight.departsAt)
              ? flight.departsAt
              : flight.arrivesAt,
          createdAt: flight.departsAt,
        );
        await txn.insert(
          'trips',
          trip.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.update(
          'flights',
          <String, Object?>{'tripId': tripId},
          where: 'id = ?',
          whereArgs: <Object?>[flight.id],
        );
        await txn.update(
          'incident_reports',
          <String, Object?>{'tripId': tripId},
          where: 'flightId = ? AND tripId IS NULL',
          whereArgs: <Object?>[flight.id],
        );
      }

      // Every flight now has a trip, including any that were given one by an
      // earlier, interrupted run of this method.
      final tripOf = <String, String>{
        for (final r in await txn.query('flights', columns: ['id', 'tripId']))
          if (r['tripId'] != null) r['id'] as String: r['tripId'] as String,
      };

      for (final row in await txn.query('snack_reports')) {
        final snack = SnackReport.fromMap(row);
        final tripId = tripOf[snack.flightId];
        if (tripId == null) continue; // its flight was deleted long ago
        final exposure = Exposure(
          id: 'snack-${snack.id}',
          tripId: tripId,
          flightId: snack.flightId,
          occurredAt: snack.reportedAt,
          allergenNames: snack.allergenNames,
          route: ExposureRoute.observedNearby,
          source: snack.description,
          place: ExposurePlace.flight,
          row: snack.row > 0 ? snack.row : null,
          notes: snack.selfReported
              ? 'Imported from the cabin view (declared as your own snack).'
              : 'Imported from the cabin view.',
        );
        await txn.insert(
          'exposures',
          exposure.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// The v2 tables, written once and used by both the fresh-install path and
  /// the upgrade path so the two can never drift apart.
  ///
  /// `IF NOT EXISTS` because an upgrade that was interrupted midway leaves a
  /// database that is partly migrated but still reports the old version.
  void _addV2Tables(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS flights (
        id TEXT PRIMARY KEY,
        airlineIata TEXT,
        flightNumber TEXT,
        origin TEXT,
        destination TEXT,
        departsAt INTEGER,
        arrivesAt INTEGER,
        aircraftType TEXT,
        seat TEXT,
        priorArrivalAt INTEGER,
        booked INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS accommodation_requests (
        id TEXT PRIMARY KEY,
        flightId TEXT,
        type TEXT,
        requestedAt INTEGER,
        channel TEXT,
        reference TEXT,
        agentName TEXT,
        status TEXT,
        responseNotes TEXT,
        resolvedAt INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS incident_reports (
        id TEXT PRIMARY KEY,
        flightId TEXT,
        createdAt INTEGER,
        kind TEXT,
        narrative TEXT,
        requestIds TEXT,
        reactionId TEXT,
        filedWith TEXT,
        filedAt INTEGER
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS seat_cleaning_logs (
        id TEXT PRIMARY KEY,
        flightId TEXT,
        cleanedAt INTEGER,
        surfaces TEXT,
        byWhom TEXT,
        notes TEXT
      )
    ''');

    // "row" is a SQLite keyword, hence the quoting. sqflite escapes it for us
    // on insert and query, so SnackReport.toMap needs no special casing.
    batch.execute('''
      CREATE TABLE IF NOT EXISTS snack_reports (
        id TEXT PRIMARY KEY,
        flightId TEXT,
        "row" INTEGER,
        allergenNames TEXT,
        reportedAt INTEGER,
        description TEXT,
        selfReported INTEGER
      )
    ''');

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_flights_departsAt ON flights (departsAt)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_requests_flightId ON accommodation_requests (flightId)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_incidents_flightId ON incident_reports (flightId)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_cleaning_flightId ON seat_cleaning_logs (flightId)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_snacks_flightId ON snack_reports (flightId)',
    );
  }

  // ---------------------------------------------------------------- profiles

  Future<List<Profile>> listProfiles() async {
    final rows = await (await db).query(
      'profiles',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Profile.fromMap).toList();
  }

  Future<void> upsertProfile(Profile profile) async {
    await (await db).insert(
      'profiles',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProfile(String id) async {
    await (await db).delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------- products

  Future<void> upsertProduct(Product product) async {
    await (await db).insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The cached copy of a product, or null if it has never been fetched.
  /// Freshness is the caller's business — a stale row is still worth having.
  Future<Product?> cachedProduct(String barcode) async {
    final rows = await (await db).query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  // ------------------------------------------------------------------- scans

  Future<void> upsertScan(ScanRecord record) async {
    await (await db).insert('scans', {
      'id': record.id,
      'barcode': record.product.barcode,
      'level': record.level.name,
      'headline': record.headline,
      'scannedAt': record.scannedAt.millisecondsSinceEpoch,
      'profileId': record.profileId,
      'saved': record.saved ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Scan history newest first, joined to the cached product row so each
  /// record carries the full product it was made against.
  Future<List<ScanRecord>> scanHistory({int limit = 200}) async {
    final rows = await (await db).rawQuery(
      '''
      SELECT s.id AS s_id,
             s.barcode AS s_barcode,
             s.level AS s_level,
             s.headline AS s_headline,
             s.scannedAt AS s_scannedAt,
             s.profileId AS s_profileId,
             s.saved AS s_saved,
             p.*
      FROM scans s
      LEFT JOIN products p ON p.barcode = s.barcode
      ORDER BY s.scannedAt DESC
      LIMIT ?
      ''',
      [limit],
    );

    return rows.map(_scanFromJoinedRow).toList();
  }

  ScanRecord _scanFromJoinedRow(Map<String, Object?> row) {
    final barcode = (row['s_barcode'] as String?) ?? '';

    // A scan whose product row was evicted still deserves to appear in
    // history; rebuild the thinnest possible product rather than dropping it.
    final product = row['barcode'] == null
        ? Product(barcode: barcode, name: '', source: ProductSource.cache)
        : Product.fromMap(Map<String, dynamic>.from(row));

    return ScanRecord(
      id: (row['s_id'] as String?) ?? barcode,
      product: product,
      level: VerdictLevel.values.firstWhere(
        (l) => l.name == row['s_level'],
        orElse: () => VerdictLevel.unknown,
      ),
      headline: (row['s_headline'] as String?) ?? '',
      scannedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['s_scannedAt'] as int?) ?? 0,
      ),
      profileId: (row['s_profileId'] as String?) ?? '',
      saved: ((row['s_saved'] as int?) ?? 0) == 1,
    );
  }

  Future<void> setSaved(String barcode, bool saved) async {
    await (await db).update(
      'scans',
      {'saved': saved ? 1 : 0},
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  /// Clears history but keeps the user's safe list — the saved rows are a
  /// curated list someone built by hand, not history to be swept away.
  Future<void> clearScans() async {
    await (await db).delete('scans', where: 'saved = 0');
  }

  // ----------------------------------------------------------------- epipens

  Future<List<EpiPen>> listEpiPens() async {
    final rows = await (await db).query('epipens', orderBy: 'expiresOn ASC');
    return rows.map(EpiPen.fromMap).toList();
  }

  Future<void> upsertEpiPen(EpiPen pen) async {
    await (await db).insert(
      'epipens',
      pen.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteEpiPen(String id) async {
    await (await db).delete('epipens', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------- contacts

  Future<List<EmergencyContact>> listContacts() async {
    final rows = await (await db).query(
      'contacts',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(EmergencyContact.fromMap).toList();
  }

  Future<void> upsertContact(EmergencyContact contact) async {
    await (await db).insert(
      'contacts',
      contact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteContact(String id) async {
    await (await db).delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  // --------------------------------------------------------------- reactions

  Future<List<ReactionLog>> listReactions() async {
    final rows = await (await db).query(
      'reactions',
      orderBy: 'occurredAt DESC',
    );
    return rows.map(ReactionLog.fromMap).toList();
  }

  Future<void> upsertReaction(ReactionLog log) async {
    await (await db).insert(
      'reactions',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReaction(String id) async {
    await (await db).delete('reactions', where: 'id = ?', whereArgs: [id]);
  }

  // ----------------------------------------------------------------- flights

  /// Soonest first — the flight you are about to take is the one that matters.
  Future<List<Flight>> listFlights() async {
    final rows = await (await db).query('flights', orderBy: 'departsAt ASC');
    return rows.map(Flight.fromMap).toList();
  }

  Future<void> upsertFlight(Flight flight) async {
    await (await db).insert(
      'flights',
      flight.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFlight(String id) async {
    await (await db).delete('flights', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------------- trips

  /// Soonest first.
  Future<List<Trip>> listTrips() async {
    final rows = await (await db).query('trips', orderBy: 'startsOn ASC');
    return rows.map(Trip.fromMap).toList();
  }

  Future<void> upsertTrip(Trip trip) async {
    await (await db).insert(
      'trips',
      trip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTrip(String id) async {
    await (await db).delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  // --------------------------------------------------------------- exposures

  /// Newest first.
  Future<List<Exposure>> listExposures() async {
    final rows = await (await db).query(
      'exposures',
      orderBy: 'occurredAt DESC',
    );
    return rows.map(Exposure.fromMap).toList();
  }

  Future<void> upsertExposure(Exposure exposure) async {
    await (await db).insert(
      'exposures',
      exposure.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExposure(String id) async {
    await (await db).delete('exposures', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------ flight experiences

  Future<List<FlightExperience>> listExperiences() async {
    final rows = await (await db).query(
      'flight_experiences',
      orderBy: 'recordedAt DESC',
    );
    return rows.map(FlightExperience.fromMap).toList();
  }

  Future<void> upsertExperience(FlightExperience e) async {
    await (await db).insert(
      'flight_experiences',
      e.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExperience(String id) async {
    await (await db).delete(
      'flight_experiences',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --------------------------------------------------- accommodation requests

  Future<List<AccommodationRequest>> listRequests() async {
    final rows = await (await db).query(
      'accommodation_requests',
      orderBy: 'requestedAt DESC',
    );
    return rows.map(AccommodationRequest.fromMap).toList();
  }

  Future<void> upsertRequest(AccommodationRequest request) async {
    await (await db).insert(
      'accommodation_requests',
      request.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteRequest(String id) async {
    await (await db).delete(
      'accommodation_requests',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // -------------------------------------------------------- incident reports

  Future<List<IncidentReport>> listIncidents() async {
    final rows = await (await db).query(
      'incident_reports',
      orderBy: 'createdAt DESC',
    );
    return rows.map(IncidentReport.fromMap).toList();
  }

  Future<void> upsertIncident(IncidentReport report) async {
    await (await db).insert(
      'incident_reports',
      report.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteIncident(String id) async {
    await (await db).delete(
      'incident_reports',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------------------------------------------------------ seat cleaning logs

  Future<List<SeatCleaningLog>> listCleaningLogs() async {
    final rows = await (await db).query(
      'seat_cleaning_logs',
      orderBy: 'cleanedAt DESC',
    );
    return rows.map(SeatCleaningLog.fromMap).toList();
  }

  Future<void> upsertCleaningLog(SeatCleaningLog log) async {
    await (await db).insert(
      'seat_cleaning_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCleaningLog(String id) async {
    await (await db).delete(
      'seat_cleaning_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------- FRD 1.2

  /// Appends the pre-edit state of a profile to its history.
  Future<void> insertRevision(ProfileRevision r) async {
    await (await db).insert(
      'profile_revisions',
      r.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Newest first.
  Future<List<ProfileRevision>> revisionsFor(String profileId) async {
    final rows = await (await db).query(
      'profile_revisions',
      where: 'profileId = ?',
      whereArgs: <Object?>[profileId],
      orderBy: 'revision DESC',
    );
    return rows.map(ProfileRevision.fromMap).toList();
  }

  /// The highest revision number recorded for a profile, or 0 if none.
  Future<int> latestRevision(String profileId) async {
    final rows = await (await db).rawQuery(
      'SELECT MAX(revision) AS m FROM profile_revisions WHERE profileId = ?',
      <Object?>[profileId],
    );
    final v = rows.isEmpty ? null : rows.first['m'];
    return (v as int?) ?? 0;
  }

  // ---------------------------------------------------------------- FRD 1.3

  Future<void> upsertActionPlan(ActionPlan plan) async {
    await (await db).insert(
      'action_plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ActionPlan>> allActionPlans() async {
    final rows = await (await db).query(
      'action_plans',
      orderBy: 'updatedAt DESC',
    );
    return rows.map(ActionPlan.fromMap).toList();
  }

  Future<void> deleteActionPlan(String id) async {
    await (await db).delete(
      'action_plans',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  /// Clears `isDefault` on every plan except [keepId], in one transaction so
  /// two plans can never both claim to be the default.
  Future<void> clearDefaultExcept(String keepId) async {
    final database = await db;
    await database.transaction((Transaction txn) async {
      await txn.update(
        'action_plans',
        <String, Object?>{'isDefault': 0},
        where: 'id != ?',
        whereArgs: <Object?>[keepId],
      );
      await txn.update(
        'action_plans',
        <String, Object?>{'isDefault': 1},
        where: 'id = ?',
        whereArgs: <Object?>[keepId],
      );
    });
  }
}
