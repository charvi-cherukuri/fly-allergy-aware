import '../data/countries.dart';
import '../models/action_plan.dart';
import '../models/emergency.dart';
import '../models/flight.dart';
import '../models/profile.dart';
import '../models/trip.dart';
import '../widgets/travel_format.dart';

/// The words emergency mode hands to other people: the handover summary for
/// paramedics or the emergency department, and the text to a family member.
///
/// Records only. Nothing here interprets symptoms or suggests treatment — it
/// says what was logged and when, which is what a clinician taking over needs
/// and the one thing a frightened person cannot reconstruct afterwards.
class EmergencySummary {
  const EmergencySummary._();

  /// "14:02 (12 min ago)".
  static String _when(DateTime at, DateTime now) {
    final int mins = now.difference(at).inMinutes;
    final String ago = mins < 1 ? 'just now' : '$mins min ago';
    return '${formatFlightTime(at)} ($ago)';
  }

  /// One screen, written to be read by someone who has never seen the app.
  static String handover({
    required Profile profile,
    required ReactionLog record,
    required DateTime now,
    ActionPlan? plan,
    Flight? flight,
    Trip? trip,
    Exposure? cause,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln('ALLERGIC REACTION — HANDOVER')
      ..writeln()
      ..writeln('Patient: ${profile.name}');

    final PatientInfo? patient = plan?.patient;
    if (patient?.dateOfBirth != null) {
      b.writeln('Date of birth: ${formatFlightDate(patient!.dateOfBirth!)}');
    }
    if (patient?.weightKg != null) {
      b.writeln('Weight: ${patient!.weightKg!.toStringAsFixed(0)} kg');
    }
    b.writeln('Allergies: ${profile.isEmpty ? 'not recorded' : profile.summary}');
    b.writeln();

    b.writeln('Started: ${_when(record.occurredAt, now)}, '
        '${formatFlightDate(record.occurredAt)}');
    if (record.epiDoses.isEmpty) {
      b.writeln(record.epiUsed
          ? 'Epinephrine: given (time not recorded)'
          : 'Epinephrine: none recorded');
    } else {
      for (int i = 0; i < record.epiDoses.length; i++) {
        b.writeln('Epinephrine dose ${i + 1}: ${_when(record.epiDoses[i], now)}');
      }
    }
    final EpinephrineInfo? epi = plan?.epinephrine;
    if (epi != null && (epi.brand.trim().isNotEmpty || epi.doseMg != null)) {
      b.writeln('Device: ${<String>[
        if (epi.brand.trim().isNotEmpty) epi.brand.trim(),
        if (epi.doseMg != null) '${epi.doseMg} mg',
      ].join(', ')}');
    }

    if (record.symptoms.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Symptoms: ${record.symptoms.join(', ')}');
    }
    if (cause != null) {
      b
        ..writeln()
        ..writeln('Suspected exposure: ${<String>[
          if (cause.allergenNames.isNotEmpty) cause.allergenNames.join(', '),
          if (cause.source.trim().isNotEmpty) cause.source.trim(),
          cause.route.label.toLowerCase(),
          'at ${formatFlightTime(cause.occurredAt)}',
        ].join(' — ')}');
    } else if (record.suspectedFood.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('Suspected cause: ${record.suspectedFood.trim()}');
    }

    if (record.timeline.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Timeline:');
      for (final TimelineNote n in record.timeline) {
        b.writeln('  ${formatFlightTime(n.at)}  ${n.text}');
      }
    }

    final List<Medication> meds = plan?.medications ?? const <Medication>[];
    if (meds.isNotEmpty) {
      b
        ..writeln()
        ..writeln('Prescribed medications (from the action plan):');
      for (final Medication m in meds) {
        b.writeln('  ${<String>[
          m.name,
          if (m.doseMg != null) '${m.doseMg} mg',
          if (m.route.trim().isNotEmpty) m.route.trim(),
        ].join(', ')}');
      }
    }
    final PhysicianInfo? doc = plan?.physician;
    if (doc != null && (doc.name.trim().isNotEmpty || doc.phone.trim().isNotEmpty)) {
      b
        ..writeln()
        ..writeln('Doctor: ${<String>[
          if (doc.name.trim().isNotEmpty) doc.name.trim(),
          if (doc.phone.trim().isNotEmpty) doc.phone.trim(),
        ].join(', ')}');
    }

    if (flight != null) {
      b
        ..writeln()
        ..writeln('Flight: ${flight.label} ${flight.origin} to '
            '${flight.destination}'
            '${flight.seat.trim().isEmpty ? '' : ', seat ${flight.seat.trim()}'}');
    } else if (trip != null) {
      final Country? c = countryFor(trip.destinationCountry);
      if (c != null) {
        b
          ..writeln()
          ..writeln('Travelling in ${c.name}.');
      }
    }

    b
      ..writeln()
      ..writeln('Recorded on the patient\'s phone as it happened.');
    return b.toString().trimRight();
  }

  /// The prefilled text to a family member. Short, factual, and with where
  /// they are — the first thing anyone receiving it will ask.
  static String textToContact({
    required String name,
    required List<DateTime> doses,
    Flight? flight,
    String? country,
  }) {
    final StringBuffer b = StringBuffer(
      'EMERGENCY: $name is having a severe allergic reaction.',
    );
    if (doses.isNotEmpty) {
      b.write(' Epinephrine given at ${formatFlightTime(doses.first)}'
          '${doses.length > 1 ? ' and ${formatFlightTime(doses.last)}' : ''}.');
    }
    if (flight != null) {
      b.write(' On flight ${flight.label} ${flight.origin} to '
          '${flight.destination}'
          '${flight.seat.trim().isEmpty ? '' : ', seat ${flight.seat.trim()}'}.');
    } else if (country != null && country.isNotEmpty) {
      b.write(' We are in $country.');
    }
    b.write(' I will update you.');
    return b.toString();
  }
}
