import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/chef_card_translations.dart';
import '../data/countries.dart';
import '../data/safety_copy.dart';
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
import 'app_lock.dart';
import 'privacy_channel.dart';
import 'translator.dart';
import 'database.dart';
import 'food_api.dart';
import 'matcher.dart';

/// The single hub the whole UI reads from.
///
/// Changes remain usable in memory during storage failures. Failed writes are
/// queued in order, with a visible warning and an explicit retry.
class AppState extends ChangeNotifier {
  AppState({
    TraceDatabase? database,
    FoodApi? api,
    AppLock? lock,
    TranslatorService? translator,
  }) : _db = database ?? TraceDatabase.instance,
       _api = api ?? FoodApi(),
       _lock = lock ?? AppLock(),
       _translator = translator ?? TranslatorService();

  final TraceDatabase _db;
  final FoodApi _api;
  final AppLock _lock;
  final TranslatorService _translator;
  final Random _random = Random();

  static const String _kActiveProfileId = 'activeProfileId';
  static const String _kOnboardingComplete = 'onboardingComplete';
  static const String _kThemeMode = 'themeMode';
  static const String _kActionPlan = 'actionPlan';
  static const String _kTravelLanguage = 'travelLanguage';
  static const String _kLanguagePromptDismissed = 'languagePromptDismissed';
  static const String _kChildCardText = 'childCardText';
  static const String _kChildCardShort = 'childCardShort';

  /// How long a cached product is treated as current. Ingredient lists change
  /// slowly; a week is long enough to be useful offline and short enough that a
  /// reformulation gets picked up on the next shop.
  static const Duration cacheTtl = Duration(days: 7);

  List<Profile> _profiles = [];
  String? _activeProfileId;
  List<ScanRecord> _history = [];
  List<EpiPen> _epiPens = [];
  List<EmergencyContact> _contacts = [];
  List<ReactionLog> _reactions = [];
  List<Flight> _flights = [];
  List<AccommodationRequest> _requests = [];
  List<IncidentReport> _incidents = [];
  List<SeatCleaningLog> _cleaning = [];
  List<Trip> _trips = [];
  List<Exposure> _exposures = [];
  List<FlightExperience> _experiences = [];
  String _actionPlan = '';
  String _travelLanguage = 'en';
  bool _authInFlight = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _onboardingComplete = false;
  bool _loading = true;

  SharedPreferences? _prefs;

  // ------------------------------------------------------------------ startup

  /// Opens the database, loads everything and settles the app into a usable
  /// state. Always leaves [loading] false, even when storage fails.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('AppState: preferences unavailable ($e)');
    }

    _profiles = await _guard(_db.listProfiles) ?? [];
    _epiPens = await _guard(_db.listEpiPens) ?? [];
    _contacts = await _guard(_db.listContacts) ?? [];
    _reactions = await _guard(_db.listReactions) ?? [];
    _history = await _guard(() => _db.scanHistory()) ?? [];
    _flights = await _guard(_db.listFlights) ?? [];
    _requests = await _guard(_db.listRequests) ?? [];
    _incidents = await _guard(_db.listIncidents) ?? [];
    _cleaning = await _guard(_db.listCleaningLogs) ?? [];
    _trips = await _guard(_db.listTrips) ?? [];
    _exposures = await _guard(_db.listExposures) ?? [];
    _experiences = await _guard(_db.listExperiences) ?? [];
    _sortFlights();
    _sortTrips();

    final prefs = _prefs;
    if (prefs != null) {
      _activeProfileId = prefs.getString(_kActiveProfileId);
      _onboardingComplete = prefs.getBool(_kOnboardingComplete) ?? false;
      _actionPlan = prefs.getString(_kActionPlan) ?? '';
      _travelLanguage = prefs.getString(_kTravelLanguage) ?? _deviceLanguage();
      final mode = prefs.getString(_kThemeMode);
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      );
    }

    // First run: there is always exactly one person until the user says
    // otherwise, and that person is whoever is holding the phone.
    if (_profiles.isEmpty) {
      final me = Profile(
        id: _newId(),
        name: 'Me',
        homeCountry: _deviceRegion(),
      );
      _profiles = [me];
      _activeProfileId = me.id;
      await _writeStore(() => _db.upsertProfile(me));
      await _setString(_kActiveProfileId, me.id);
    } else if (!_profiles.any((p) => p.id == _activeProfileId)) {
      _activeProfileId = _profiles.first.id;
      await _setString(_kActiveProfileId, _profiles.first.id);
    }

    // Profiles from before home countries existed: assume the phone's region,
    // which the user can correct in the profile.
    final String region = _deviceRegion();
    if (region.isNotEmpty) {
      for (final Profile p in _profiles.where(
        (Profile p) => p.homeCountry.isEmpty,
      )) {
        p.homeCountry = region;
        await _writeStore(() => _db.upsertProfile(p));
      }
    }
    await _renameGeneratedTrips();

    await _guard(() => _lock.init(_prefs));
    await PrivacyChannel.setLockActive(_lock.isEnabled);
    // The lock is on by default, but before onboarding there is no profile
    // for it to protect. The first launch opens straight into setup; the gate
    // applies from the next launch on.
    if (!_onboardingComplete) _lock.openForSetup();

    // FRD 1.2 / 1.3 — history and action plans for the active profile.
    _actionPlans
      ..clear()
      ..addAll(await _db.allActionPlans());
    _sortActionPlans();
    _revisions = await _db.revisionsFor(activeProfile.id);

    _loading = false;
    notifyListeners();
  }

  bool get loading => _loading;

  // ----------------------------------------------------------------- profiles

  List<Profile> get profiles => List.unmodifiable(_profiles);

  /// Never throws and never returns null. Falls back to the first profile, and
  /// to a transient in-memory "Me" only if storage failed so badly that there
  /// are no profiles at all.
  Profile get activeProfile {
    if (_profiles.isEmpty) {
      final fallback = Profile(id: _activeProfileId ?? 'me', name: 'Me');
      _profiles = [fallback];
      _activeProfileId = fallback.id;
      return fallback;
    }
    for (final p in _profiles) {
      if (p.id == _activeProfileId) return p;
    }
    return _profiles.first;
  }

  Future<void> setActiveProfile(String id) async {
    if (!_profiles.any((p) => p.id == id)) return;
    _activeProfileId = id;
    await _setString(_kActiveProfileId, id);
    notifyListeners();
  }

  /// Saves a profile, appending the previous state to its history first.
  ///
  /// FRD 1.2 asks for profiles that change over time. Read literally that is
  /// just an edit screen, which the app already had — but an allergy profile is
  /// a medical record, and a destructive overwrite silently loses the fact that
  /// something used to be listed as anaphylactic. Every edit is now auditable.
  ///
  /// Pass [changeSummary] to annotate the edit. Pass `recordHistory: false`
  /// only for saves that are not user edits (creating the first profile,
  /// restoring a revision, which writes its own entry).
  Future<void> saveProfile(
    Profile p, {
    String changeSummary = '',
    bool recordHistory = true,
  }) async {
    final i = _profiles.indexWhere((e) => e.id == p.id);
    final Profile? previous = i >= 0 ? _profiles[i] : null;

    if (previous != null && recordHistory) {
      final diff = ProfileDiff.between(previous, p);
      if (!diff.isEmpty) {
        final revisionId = _newId();
        final changedAt = DateTime.now();
        await _writeStore(() async {
          final next = await _db.latestRevision(p.id) + 1;
          await _db.insertRevision(
            ProfileRevision(
              id: revisionId,
              profileId: p.id,
              revision: next,
              snapshot: previous,
              changedAt: changedAt,
              changeSummary: changeSummary,
            ),
          );
        });
      }
    }

    if (i >= 0) {
      _profiles[i] = p;
    } else {
      _profiles.add(p);
    }
    await _writeStore(() => _db.upsertProfile(p));
    // Guarded like every other DB call here: a dead database must not take the
    // save down with it, and history is the less critical half.
    await _guard(() => _refreshRevisions(p.id));
    // A changed home country can turn a trip from international to domestic.
    if (previous?.homeCountry != p.homeCountry) await _renameGeneratedTrips();
    notifyListeners();
  }

  // ------------------------------------------------------- FRD 1.2 history

  List<ProfileRevision> _revisions = <ProfileRevision>[];

  /// History for the active profile, newest first.
  List<ProfileRevision> get revisions => List.unmodifiable(_revisions);

  Future<void> _refreshRevisions(String profileId) async {
    if (profileId != activeProfile.id) return;
    _revisions = await _db.revisionsFor(profileId);
  }

  /// Reloads history for whichever profile is active.
  Future<void> refreshRevisions() async {
    _revisions = await _db.revisionsFor(activeProfile.id);
    notifyListeners();
  }

  /// Restores an earlier version.
  ///
  /// This creates a NEW revision rather than rewriting history — the fact that
  /// you rolled back is itself part of the record.
  Future<void> restoreRevision(ProfileRevision r) async {
    final current = activeProfile;
    final restored = Profile.fromMap(r.snapshot.toMap())
      ..name = current.name
      ..isChild = current.isChild;
    await saveProfile(
      restored,
      changeSummary: 'Restored version ${r.revision}',
    );
  }

  // ---------------------------------------------------- FRD 1.3 action plans

  final List<ActionPlan> _actionPlans = <ActionPlan>[];

  /// Airline-specific anaphylaxis plans, most recently updated first.
  List<ActionPlan> get actionPlans => List.unmodifiable(_actionPlans);

  /// The plan marked default, or the only plan, or null.
  ActionPlan? get defaultActionPlan {
    for (final p in _actionPlans) {
      if (p.isDefault) return p;
    }
    return _actionPlans.isEmpty ? null : _actionPlans.first;
  }

  /// Plans whose auto-injector expires within 60 days.
  List<ActionPlan> get expiringActionPlans =>
      _actionPlans.where((p) => p.isExpiringSoon).toList();

  Future<void> saveActionPlan(ActionPlan plan) async {
    plan.updatedAt = DateTime.now();
    final i = _actionPlans.indexWhere((e) => e.id == plan.id);
    if (i >= 0) {
      _actionPlans[i] = plan;
    } else {
      _actionPlans.insert(0, plan);
    }
    await _writeStore(() => _db.upsertActionPlan(plan));
    if (plan.isDefault) {
      await _writeStore(() => _db.clearDefaultExcept(plan.id));
      for (final other in _actionPlans) {
        other.isDefault = other.id == plan.id;
      }
    }
    _sortActionPlans();
    notifyListeners();
  }

  Future<void> deleteActionPlan(String id) async {
    _actionPlans.removeWhere((e) => e.id == id);
    await _writeStore(() => _db.deleteActionPlan(id));
    notifyListeners();
  }

  /// Makes one plan the default and unsets every other, in one transaction.
  Future<void> setDefaultActionPlan(String id) async {
    await _writeStore(() => _db.clearDefaultExcept(id));
    for (final p in _actionPlans) {
      p.isDefault = p.id == id;
    }
    _sortActionPlans();
    notifyListeners();
  }

  /// A blank plan with the physician's ladder pre-filled, ready to edit.
  ActionPlan newActionPlan() {
    final now = DateTime.now();
    return ActionPlan(
      id: _newId(),
      title: '',
      createdAt: now,
      updatedAt: now,
      patient: PatientInfo(name: activeProfile.name),
      symptomSteps: defaultSymptomLadder(),
      isDefault: _actionPlans.isEmpty,
    );
  }

  void _sortActionPlans() {
    _actionPlans.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  /// A no-op on the last profile — the app is meaningless without one.
  Future<void> deleteProfile(String id) async {
    if (_profiles.length == 1) return;
    if (!_profiles.any((p) => p.id == id)) return;

    _profiles.removeWhere((p) => p.id == id);
    await _writeStore(() => _db.deleteProfile(id));

    if (_activeProfileId == id && _profiles.isNotEmpty) {
      _activeProfileId = _profiles.first.id;
      await _setString(_kActiveProfileId, _profiles.first.id);
    }
    notifyListeners();
  }

  Future<Profile> createProfile(String name) async {
    final trimmed = name.trim();
    // A new household member most likely lives where the rest do.
    final String home = activeProfile.homeCountry.isNotEmpty
        ? activeProfile.homeCountry
        : _deviceRegion();
    final p = Profile(
      id: _newId(),
      name: trimmed.isEmpty ? 'New profile' : trimmed,
      homeCountry: home,
    );
    _profiles.add(p);
    await _writeStore(() => _db.upsertProfile(p));
    notifyListeners();
    return p;
  }

  // --------------------------------------------------------------- onboarding

  bool get onboardingComplete => _onboardingComplete;

  Future<void> completeOnboarding() async {
    _onboardingComplete = true;
    await _setBool(_kOnboardingComplete, true);
    notifyListeners();
  }

  // ----------------------------------------------------------------- scanning

  /// Cache first, network second, stale cache last.
  Future<ScanOutcome> lookupBarcode(String barcode) async {
    final normalised = normaliseBarcode(barcode);
    final rawDigits = barcode.replaceAll(RegExp(r'[^0-9]'), '');

    Product? cached = await _guard<Product?>(
      () => _db.cachedProduct(normalised),
    );
    if (cached == null && rawDigits.isNotEmpty && rawDigits != normalised) {
      cached = await _guard<Product?>(() => _db.cachedProduct(rawDigits));
    }

    if (cached != null && _isFresh(cached)) {
      return ScanOutcome.cached(cached);
    }

    final outcome = await _api.lookup(barcode);

    if (outcome.hasProduct) {
      final product = outcome.product;
      if (product != null) {
        await _writeStore(() => _db.upsertProduct(product));
      }
      return outcome;
    }

    // Offline or erroring with a stale row in hand: return the stale row. A
    // week-old ingredient list is very nearly always still correct, and a
    // stale answer beats no answer when someone is standing in a shop deciding
    // whether to put the packet in the basket.
    if (cached != null &&
        (outcome.status == ScanStatus.offline ||
            outcome.status == ScanStatus.error)) {
      return ScanOutcome.cached(cached);
    }

    return outcome;
  }

  bool _isFresh(Product p) {
    final fetched = p.fetchedAt;
    if (fetched == null) return false;
    return DateTime.now().difference(fetched) < cacheTtl;
  }

  /// Pure and synchronous — the UI can call this in `build` without awaiting.
  Verdict evaluate(Product product, {Profile? profile}) {
    return AllergenMatcher.evaluate(
      product: product,
      profile: profile ?? activeProfile,
    );
  }

  Future<void> recordScan(Product product, Verdict verdict) async {
    final record = ScanRecord(
      id: _newId(),
      product: product,
      level: verdict.level,
      headline: verdict.headline,
      scannedAt: DateTime.now(),
      profileId: activeProfile.id,
    );

    await _writeStore(() => _db.upsertProduct(product));
    await _writeStore(() => _db.upsertScan(record));

    final refreshed = await _guard(() => _db.scanHistory());
    if (refreshed != null) {
      _history = refreshed;
    } else {
      _history = [record, ..._history];
    }
    notifyListeners();
  }

  // ------------------------------------------------------- history + safelist

  List<ScanRecord> get history => List.unmodifiable(_history);

  List<ScanRecord> get savedItems =>
      List.unmodifiable(_history.where((r) => r.saved));

  Future<void> toggleSaved(String barcode) async {
    final current = _history.any(
      (r) => r.product.barcode == barcode && r.saved,
    );
    final next = !current;

    _history = _history
        .map((r) => r.product.barcode == barcode ? r.copyWith(saved: next) : r)
        .toList();

    await _writeStore(() => _db.setSaved(barcode, next));
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _writeStore(_db.clearScans);
    _history = _history.where((r) => r.saved).toList();
    notifyListeners();
  }

  // ---------------------------------------------------------------- emergency

  List<EpiPen> get epiPens => List.unmodifiable(_epiPens);

  Future<void> saveEpiPen(EpiPen e) async {
    final i = _epiPens.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _epiPens[i] = e;
    } else {
      _epiPens.add(e);
    }
    _epiPens.sort((a, b) => a.expiresOn.compareTo(b.expiresOn));
    await _writeStore(() => _db.upsertEpiPen(e));
    notifyListeners();
  }

  Future<void> deleteEpiPen(String id) async {
    _epiPens.removeWhere((x) => x.id == id);
    await _writeStore(() => _db.deleteEpiPen(id));
    notifyListeners();
  }

  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);

  Future<void> saveContact(EmergencyContact c) async {
    final i = _contacts.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      _contacts[i] = c;
    } else {
      _contacts.add(c);
    }
    await _writeStore(() => _db.upsertContact(c));
    notifyListeners();
  }

  Future<void> deleteContact(String id) async {
    _contacts.removeWhere((x) => x.id == id);
    await _writeStore(() => _db.deleteContact(id));
    notifyListeners();
  }

  /// Newest first.
  List<ReactionLog> get reactions => List.unmodifiable(_reactions);

  Future<bool> saveReaction(ReactionLog r) async {
    final i = _reactions.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      _reactions[i] = r;
    } else {
      _reactions.add(r);
    }
    _reactions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final saved = await _writeStore(() => _db.upsertReaction(r));
    notifyListeners();
    return saved;
  }

  Future<void> deleteReaction(String id) async {
    _reactions.removeWhere((x) => x.id == id);
    await _writeStore(() => _db.deleteReaction(id));
    notifyListeners();
  }

  /// The doctor's written plan, kept verbatim.
  String get actionPlan => _actionPlan;

  Future<void> setActionPlan(String text) async {
    _actionPlan = text;
    await _setString(_kActionPlan, text);
    notifyListeners();
  }

  // ------------------------------------------------------------------ flights

  /// Soonest first, past flights included — the trip you just took is still
  /// the one you file a complaint about.
  List<Flight> get flights => List.unmodifiable(_flights);

  /// The flight the app should be talking about right now: the one in the
  /// air, otherwise the next one to depart.
  Flight? get activeFlight {
    final Flight? flying = flightInProgress();
    if (flying != null) return flying;
    final now = DateTime.now();
    for (final f in _flights) {
      if (f.departsAt.isAfter(now)) return f;
    }
    return null;
  }

  Future<void> saveFlight(Flight f) async {
    final i = _flights.indexWhere((x) => x.id == f.id);
    if (i >= 0) {
      _flights[i] = f;
    } else {
      _flights.add(f);
    }
    _sortFlights();
    await _writeStore(() => _db.upsertFlight(f));
    notifyListeners();
  }

  /// Removes one flight leg and its seat wipe-down logs. Accommodation
  /// requests and incident reports are deliberately left alone: they are the
  /// evidentiary trail of what the airline was asked for and what it did, and
  /// correcting an itinerary is not a decision to give that up. Deleting the
  /// whole trip ([deleteTrip]) is, and removes them too.
  Future<void> deleteFlight(String id) async {
    _flights.removeWhere((x) => x.id == id);

    for (final e in _experiences.where((x) => x.flightId == id).toList()) {
      await _writeStore(() => _db.deleteExperience(e.id));
    }
    _experiences.removeWhere((x) => x.flightId == id);

    for (final c in _cleaning.where((x) => x.flightId == id).toList()) {
      await _writeStore(() => _db.deleteCleaningLog(c.id));
    }
    _cleaning.removeWhere((x) => x.flightId == id);

    await _writeStore(() => _db.deleteFlight(id));

    notifyListeners();
  }

  void _sortFlights() {
    _flights.sort((a, b) => a.departsAt.compareTo(b.departsAt));
  }

  /// The leg being flown right now, if any.
  ///
  /// Emergency mode leads with the cabin steps — the crew, the on-board kit —
  /// when this is non-null, and with the local emergency number when it is
  /// null. The window opens 30 minutes before departure because boarding and
  /// taxiing are on the aircraft too, and stays open 30 minutes after arrival
  /// for the same reason at the other end.
  Flight? flightInProgress([DateTime? at]) {
    final now = at ?? DateTime.now();
    const slack = Duration(minutes: 30);
    for (final f in _flights) {
      if (!now.isBefore(f.departsAt.subtract(slack)) &&
          !now.isAfter(f.arrivesAt.add(slack))) {
        return f;
      }
    }
    return null;
  }

  // -------------------------------------------------------------------- trips

  /// Soonest first, past trips included.
  List<Trip> get trips => List.unmodifiable(_trips);

  Trip? tripById(String? id) {
    if (id == null) return null;
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The trip the Travel tab leads with: one that is underway, otherwise the
  /// next one coming up. When two overlap, the one that started most recently
  /// wins — it is the one the traveler is on now.
  Trip? activeTrip([DateTime? at]) {
    final now = at ?? DateTime.now();
    Trip? underway;
    for (final t in _trips) {
      if (t.isUnderway(now) &&
          (underway == null || t.startsOn.isAfter(underway.startsOn))) {
        underway = t;
      }
    }
    if (underway != null) return underway;
    for (final t in _trips) {
      if (t.isUpcoming(now)) return t;
    }
    return null;
  }

  /// Legs of a trip, in the order they are flown.
  List<Flight> flightsFor(String tripId) =>
      List.unmodifiable(_flights.where((f) => f.tripId == tripId).toList());

  Future<void> saveTrip(Trip t) async {
    final i = _trips.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      _trips[i] = t;
    } else {
      _trips.add(t);
    }
    _sortTrips();
    await _writeStore(() => _db.upsertTrip(t));
    notifyListeners();
  }

  /// Deletes a trip and everything recorded on it: its flights, requests,
  /// wipe-downs, exposures and incidents. Reactions are kept — they are part
  /// of the person's medical history and stay in the reaction log — but are
  /// unlinked from the trip that no longer exists.
  ///
  /// The screen that calls this says exactly what will go before asking.
  Future<void> deleteTrip(String id) async {
    final legIds = _flights
        .where((f) => f.tripId == id)
        .map((f) => f.id)
        .toSet();

    for (final legId in legIds) {
      for (final r in _requests.where((x) => x.flightId == legId).toList()) {
        await _writeStore(() => _db.deleteRequest(r.id));
      }
      _requests.removeWhere((x) => x.flightId == legId);
      await deleteFlight(legId);
    }

    for (final e in _exposures.where((x) => x.tripId == id).toList()) {
      await _writeStore(() => _db.deleteExposure(e.id));
    }
    _exposures.removeWhere((x) => x.tripId == id);

    for (final r
        in _incidents
            .where((x) => x.tripId == id || legIds.contains(x.flightId))
            .toList()) {
      await _writeStore(() => _db.deleteIncident(r.id));
    }
    _incidents.removeWhere(
      (x) => x.tripId == id || legIds.contains(x.flightId),
    );

    for (final r in _reactions.where((x) => x.tripId == id)) {
      r.tripId = null;
      await _writeStore(() => _db.upsertReaction(r));
    }

    _trips.removeWhere((x) => x.id == id);
    await _writeStore(() => _db.deleteTrip(id));
    notifyListeners();
  }

  /// Whether the user said "Don't ask for this trip" to its language pack
  /// suggestion. Kept per trip: declining for a weekend in London says
  /// nothing about a month in Japan.
  bool languagePromptDismissed(String tripId) =>
      (_prefs?.getStringList(_kLanguagePromptDismissed) ?? const <String>[])
          .contains(tripId);

  Future<void> dismissLanguagePrompt(String tripId) async {
    final current =
        _prefs?.getStringList(_kLanguagePromptDismissed) ?? const <String>[];
    if (current.contains(tripId)) return;
    try {
      await _prefs?.setStringList(_kLanguagePromptDismissed, <String>[
        ...current,
        tripId,
      ]);
    } catch (e) {
      debugPrint('AppState: could not persist prompt dismissal ($e)');
    }
    notifyListeners();
  }

  /// The home country a trip is measured against: the first traveler who has
  /// one, otherwise whoever is holding the phone.
  String homeCountryFor({required List<String> travelerIds}) {
    for (final Profile p in _profiles) {
      if (travelerIds.contains(p.id) && p.homeCountry.isNotEmpty) {
        return p.homeCountry;
      }
    }
    return activeProfile.homeCountry;
  }

  /// The name a trip gets until the user types one.
  String generatedTripName({
    required String destination,
    required List<String> travelerIds,
  }) => tripNameFor(
    destination: destination,
    home: homeCountryFor(travelerIds: travelerIds),
    countryName: (String code) => countryFor(code)?.name,
  );

  /// Brings every app-generated trip name up to date — the old "Trip to
  /// United States" style included. Names the user typed are never touched.
  Future<void> _renameGeneratedTrips() async {
    for (final Trip t in _trips) {
      if (!isGeneratedTripName(t.name) || t.destinationCountry.isEmpty) {
        continue;
      }
      final String name = generatedTripName(
        destination: t.destinationCountry,
        travelerIds: t.travelerIds,
      );
      if (name == t.name) continue;
      t.name = name;
      await _writeStore(() => _db.upsertTrip(t));
    }
  }

  /// The phone's region, when it is a country the app knows.
  static String _deviceRegion() {
    final String code = (PlatformDispatcher.instance.locale.countryCode ?? '')
        .toUpperCase();
    return countryFor(code) == null ? '' : code;
  }

  void _sortTrips() {
    _trips.sort((a, b) => a.startsOn.compareTo(b.startsOn));
  }

  // ------------------------------------------------------- flight experiences

  /// The experience recorded for a flight, if any.
  FlightExperience? experienceFor(String flightId) {
    for (final FlightExperience e in _experiences) {
      if (e.flightId == flightId) return e;
    }
    return null;
  }

  Future<void> saveExperience(FlightExperience e) async {
    final i = _experiences.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _experiences[i] = e;
    } else {
      _experiences.add(e);
    }
    await _writeStore(() => _db.upsertExperience(e));
    notifyListeners();
  }

  /// The most recent leg of [tripId] that has landed in the last week and has
  /// no experience recorded — what the trip card asks about.
  Flight? flightAwaitingExperience(String tripId, [DateTime? at]) {
    final DateTime now = at ?? DateTime.now();
    Flight? found;
    for (final Flight f in _flights.where((Flight f) => f.tripId == tripId)) {
      final bool landed = f.arrivesAt.isBefore(now);
      final bool recent =
          now.difference(f.arrivesAt) <= const Duration(days: 7);
      if (landed && recent && experienceFor(f.id) == null) found = f;
    }
    return found;
  }

  // ---------------------------------------------------------------- exposures

  /// Newest first.
  List<Exposure> get exposures => List.unmodifiable(_exposures);

  List<Exposure> exposuresFor(String tripId) =>
      List.unmodifiable(_exposures.where((e) => e.tripId == tripId).toList());

  Future<void> saveExposure(Exposure e) async {
    final i = _exposures.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      _exposures[i] = e;
    } else {
      _exposures.add(e);
    }
    _exposures.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    await _writeStore(() => _db.upsertExposure(e));
    notifyListeners();
  }

  Future<void> deleteExposure(String id) async {
    _exposures.removeWhere((x) => x.id == id);
    await _writeStore(() => _db.deleteExposure(id));
    notifyListeners();
  }

  /// Reactions recorded on a trip, newest first.
  List<ReactionLog> reactionsFor(String tripId) =>
      List.unmodifiable(_reactions.where((r) => r.tripId == tripId).toList());

  /// Incidents on a trip, including ones filed against one of its flights
  /// before incidents carried a trip of their own.
  List<IncidentReport> incidentsFor(String tripId) {
    final legIds = _flights
        .where((f) => f.tripId == tripId)
        .map((f) => f.id)
        .toSet();
    return List.unmodifiable(
      _incidents
          .where((r) => r.tripId == tripId || legIds.contains(r.flightId))
          .toList(),
    );
  }

  // --------------------------------------------- accommodations + incidents

  /// Newest request first.
  List<AccommodationRequest> requestsFor(String flightId) => List.unmodifiable(
    _requests.where((r) => r.flightId == flightId).toList(),
  );

  Future<void> saveRequest(AccommodationRequest r) async {
    final i = _requests.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      _requests[i] = r;
    } else {
      _requests.add(r);
    }
    _requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    await _writeStore(() => _db.upsertRequest(r));
    notifyListeners();
  }

  Future<void> deleteRequest(String id) async {
    _requests.removeWhere((x) => x.id == id);
    await _writeStore(() => _db.deleteRequest(id));
    notifyListeners();
  }

  /// Newest first.
  List<IncidentReport> get incidents => List.unmodifiable(_incidents);

  Future<void> saveIncident(IncidentReport r) async {
    final i = _incidents.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      _incidents[i] = r;
    } else {
      _incidents.add(r);
    }
    _incidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writeStore(() => _db.upsertIncident(r));
    notifyListeners();
  }

  Future<void> deleteIncident(String id) async {
    _incidents.removeWhere((x) => x.id == id);
    await _writeStore(() => _db.deleteIncident(id));
    notifyListeners();
  }

  // ------------------------------------------------------------- wipe-downs

  /// Newest first.
  List<SeatCleaningLog> cleaningFor(String flightId) => List.unmodifiable(
    _cleaning.where((c) => c.flightId == flightId).toList(),
  );

  Future<void> saveCleaningLog(SeatCleaningLog l) async {
    final i = _cleaning.indexWhere((x) => x.id == l.id);
    if (i >= 0) {
      _cleaning[i] = l;
    } else {
      _cleaning.add(l);
    }
    _cleaning.sort((a, b) => b.cleanedAt.compareTo(a.cleanedAt));
    await _writeStore(() => _db.upsertCleaningLog(l));
    notifyListeners();
  }

  // ----------------------------------------------------------------- settings

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    await _setString(_kThemeMode, m.name);
    notifyListeners();
  }

  /// The device's own language when the app ships translations for it.
  ///
  /// A user whose phone is in Spanish should not have to find the setting
  /// before their card is legible to them.
  /// The phone's own language, whether or not the app has card translations
  /// for it. Language pack suggestions leave it out.
  String get deviceLanguage =>
      PlatformDispatcher.instance.locale.languageCode.toLowerCase();

  static String _deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    for (final l in kCardLanguages) {
      if (l.code == code) return l.code;
    }
    return 'en';
  }

  /// The language of wherever you are going, as an ISO 639-1 code.
  ///
  /// One setting drives every translated surface — the chef card, the emergency
  /// phrases, the allergen names on a scan result. Someone flying to Tokyo sets
  /// it once; they should not have to pick Japanese again inside a reaction.
  String get travelLanguage => _travelLanguage;

  Future<void> setTravelLanguage(String code) async {
    if (code == _travelLanguage) return;
    _travelLanguage = code;
    await _setString(_kTravelLanguage, code);
    notifyListeners();
  }

  // --------------------------------------------------------- child food card

  /// The "please don't feed my child" message, as the parent last edited it.
  String get childCardText {
    final String? v = _prefs?.getString(_kChildCardText);
    return (v == null || v.trim().isEmpty) ? kChildCardDefault : v;
  }

  String get childCardShort {
    final String? v = _prefs?.getString(_kChildCardShort);
    return (v == null || v.trim().isEmpty) ? kChildCardShortDefault : v;
  }

  /// Saves both versions. An empty one goes back to the original wording.
  Future<void> setChildCard({
    required String full,
    required String short,
  }) async {
    await _setString(_kChildCardText, full.trim());
    await _setString(_kChildCardShort, short.trim());
    notifyListeners();
  }

  final List<Future<void> Function()> _pendingWrites = [];
  Future<bool>? _flushingWrites;
  bool _storageWriteFailed = false;
  bool get hasUnsavedChanges =>
      _storageWriteFailed && _pendingWrites.isNotEmpty;

  Future<bool> _writeStore(Future<void> Function() operation) async {
    _pendingWrites.add(operation);
    await retryPendingStorage();
    return !_pendingWrites.contains(operation);
  }

  /// Replay in order: a later edit must never be overwritten by an older retry.
  Future<bool> retryPendingStorage() {
    return _flushingWrites ??= _flushWrites();
  }

  Future<bool> _flushWrites() async {
    // Ensure the future is assigned before a synchronously throwing operation.
    await Future<void>.delayed(Duration.zero);
    try {
      while (_pendingWrites.isNotEmpty) {
        try {
          await _pendingWrites.first();
          _pendingWrites.removeAt(0);
        } catch (e) {
          _storageWriteFailed = true;
          debugPrint('AppState: write pending ($e)');
          return false;
        }
      }
      _storageWriteFailed = false;
      return true;
    } finally {
      _flushingWrites = null;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ helpers

  /// A fresh record id, for screens that create trips, exposures and the like.
  String newId() => _newId();

  /// Time-ordered and collision-resistant without pulling in a uuid package.
  String _newId() {
    final suffix = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  /// Runs a storage call and returns null instead of throwing, so a failed
  /// write never propagates into the widget tree.
  Future<T?> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (e) {
      debugPrint('AppState: storage call failed ($e)');
      return null;
    }
  }

  Future<void> _setString(String key, String value) async {
    await _writeStore(() async {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      if (!await prefs.setString(key, value)) {
        throw StateError('Preferences unavailable');
      }
    });
  }

  Future<void> _setBool(String key, bool value) async {
    await _writeStore(() async {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      if (!await prefs.setBool(key, value)) {
        throw StateError('Preferences unavailable');
      }
    });
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------- lock

  /// True when the user has asked for the app to be locked.
  bool get lockIsEnabled => _lock.isEnabled;

  /// True when the app is currently gated behind the device's own prompt.
  bool get isLocked => _lock.isLocked;

  /// Whether this iPhone can identify its owner at all. False on a phone with
  /// no passcode set, where there is nothing to lock the app with.
  Future<bool> lockAvailable() => _lock.isAvailable();

  /// "Face ID", "Touch ID", or "your passcode" — whatever iOS will actually put
  /// in front of the user.
  Future<String> lockMethodLabel() => _lock.methodLabel();

  /// True while iOS's own authentication sheet is up.
  ///
  /// That sheet drives the app `inactive`, which is also the signal used to
  /// cover the screen before it reaches the app switcher. Without this, every
  /// unlock would flash the cover underneath the prompt and read as a crash.
  bool get authInFlight => _authInFlight;

  Future<LockOutcome> _ask(Future<LockOutcome> Function() op) async {
    _authInFlight = true;
    try {
      return await op();
    } finally {
      _authInFlight = false;
      // Enabling, disabling and a phone that lost its passcode all change
      // whether native screens must be closed on the way out.
      await PrivacyChannel.setLockActive(_lock.isEnabled);
      notifyListeners();
    }
  }

  Future<LockOutcome> enableLock() => _ask(_lock.enable);

  Future<LockOutcome> disableLock() => _ask(_lock.disable);

  Future<LockOutcome> unlock() => _ask(_lock.unlock);

  /// Puts the gate back up — on a cold start, and when the app has been in the
  /// background long enough that someone else could be holding the phone.
  void lockNow() {
    // Not during onboarding: there is no profile behind the gate yet, and a
    // new user stepping away mid-setup should not come back to a lock screen.
    if (!_onboardingComplete) return;
    if (!_lock.isEnabled || _lock.isLocked) return;
    _lock.lock();
    notifyListeners();
  }

  /// On-device translation. Shared here so the list of downloaded packs is
  /// read from the platform once rather than on every screen build.
  TranslatorService get translator => _translator;

  /// Keeps the lock down for [AppLock.emergencyWindow].
  ///
  /// Every emergency action leaves the app — the 911 call, the text to a
  /// contact — and those trips run long and get interrupted by callbacks.
  /// Coming back to a lock screen mid-reaction is the app failing at the one
  /// moment it exists for. In memory only: see [AppLock.emergencyWindow].
  void startEmergencyWindow() => _lock.startEmergencyWindow();
}
