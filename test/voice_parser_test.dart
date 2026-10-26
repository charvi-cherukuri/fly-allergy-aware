import 'package:flutter_test/flutter_test.dart';
import 'package:trace_allergy/models/allergen.dart';
import 'package:trace_allergy/models/profile.dart';
import 'package:trace_allergy/models/travel.dart';
import 'package:trace_allergy/models/trip.dart';
import 'package:trace_allergy/services/voice_parser.dart';

void main() {
  final maya = Profile(
    id: 'maya',
    name: 'Maya',
    allergens: <Allergen, Severity>{Allergen.peanut: Severity.severe},
  );
  final ashok = Profile(id: 'me', name: 'Ashok');
  final people = <Profile>[maya, ashok];
  final now = DateTime(2026, 10, 17); // a Saturday

  group('Trips', () {
    test('country, dates and who, from one sentence', () {
      final heard = VoiceParser.trip(
        'Flying United from Newark to Tokyo on March 12th to March 20th with Maya and me',
        now: now,
        profiles: people,
        meId: 'me',
      );
      expect(heard.countryCode, 'JP');
      expect(heard.startsOn, DateTime(2027, 3, 12));
      expect(heard.endsOn, DateTime(2027, 3, 20));
      expect(heard.travelerIds, <String>{'maya', 'me'});
    });

    test('the place after "to" is the destination, not the one left', () {
      expect(VoiceParser.countryIn('from London to Paris'), 'FR');
      expect(VoiceParser.countryIn('we are going to Italy'), 'IT');
      expect(VoiceParser.countryIn('a week in the UK'), 'GB');
    });

    test('day-first dates, "to the 20th" and a length', () {
      expect(
        VoiceParser.trip('12th of November to the 19th', now: now, profiles: people).endsOn,
        DateTime(2026, 11, 19),
      );
      final heard = VoiceParser.trip('Lisbon tomorrow for a week', now: now, profiles: people);
      expect(heard.countryCode, 'PT');
      expect(heard.startsOn, DateTime(2026, 10, 18));
      expect(heard.endsOn, DateTime(2026, 10, 25));
    });

    test('next Friday', () {
      expect(VoiceParser.datesIn('leaving next friday', now).single, DateTime(2026, 10, 23));
    });
  });

  group('Exposures', () {
    test('who, what, how, where, row and actions', () {
      final heard = VoiceParser.exposure(
        'Maya touched a tray table with peanut crumbs in row 14, washed her hands, no symptoms',
        people: people,
      );
      expect(heard.profileId, 'maya');
      expect(heard.allergens, <String>['Peanut']);
      expect(heard.route, ExposureRoute.surface);
      expect(heard.place, ExposurePlace.flight);
      expect(heard.row, 14);
      expect(heard.actions, contains('Washed hands'));
      expect(heard.outcome, ExposureOutcome.noSymptoms);
    });

    test('peanuts said as nuts are not also logged as tree nuts', () {
      expect(
        VoiceParser.allergensIn('the man next to us opened a bag of peanuts'),
        <String>['Peanut'],
      );
      expect(
        VoiceParser.allergensIn('trail mix with cashews and peanuts'),
        containsAll(<String>['Peanut', 'Tree nuts']),
      );
    });

    test('eating at a restaurant, with symptoms', () {
      final heard = VoiceParser.exposure(
        'Ate a pastry from the hotel breakfast buffet and got hives',
        people: people,
      );
      expect(heard.route, ExposureRoute.ingested);
      expect(heard.place, ExposurePlace.hotel);
      expect(heard.outcome, ExposureOutcome.symptoms);
    });
  });

  group('Reactions', () {
    test('symptoms, epinephrine and care', () {
      final heard = VoiceParser.reaction(
        'Her lips were swelling and she was wheezing, we used the EpiPen and called an ambulance',
      );
      expect(heard.symptoms, containsAll(<String>['Swelling (lips, face, eyes)', 'Wheezing']));
      expect(heard.epiUsed, isTrue);
      expect(heard.soughtCare, isTrue);
    });

    test('suspected food after eating', () {
      expect(VoiceParser.reaction('hives after eating pad thai').suspectedFood, 'pad thai');
    });
  });

  group('Incidents', () {
    test('kinds on and off a flight', () {
      expect(
        VoiceParser.incidentKind('they refused boarding because of the epipen', onFlight: true),
        IncidentKind.refusedBoarding,
      );
      expect(
        VoiceParser.incidentKind('the buffer zone was never announced', onFlight: true),
        IncidentKind.accommodationFailure,
      );
      expect(
        VoiceParser.incidentKind('the waiter ignored the chef card', onFlight: false),
        IncidentKind.venueFailure,
      );
    });
  });

  group('Emergency commands', () {
    test('clear commands act', () {
      expect(VoiceParser.emergencyCommand('Epinephrine given'), EmergencyCommand.epinephrineGiven);
      expect(VoiceParser.emergencyCommand('second dose'), EmergencyCommand.epinephrineGiven);
      expect(VoiceParser.emergencyCommand('call for help'), EmergencyCommand.callForHelp);
      expect(VoiceParser.emergencyCommand('yes, call'), EmergencyCommand.confirmCall);
      expect(VoiceParser.emergencyCommand('text my family'), EmergencyCommand.textFamily);
      expect(VoiceParser.emergencyCommand('show the crew'), EmergencyCommand.showCrew);
    });

    test('descriptions never trigger an action', () {
      expect(
        VoiceParser.emergencyCommand(
          'she says she does not want the epinephrine given yet because her lips are only a little swollen',
        ),
        EmergencyCommand.note,
      );
      expect(VoiceParser.emergencyCommand('lips swelling'), EmergencyCommand.note);
      expect(
        VoiceParser.emergencyCommand('the flight attendant said yes she will bring the kit now'),
        EmergencyCommand.note,
      );
    });
  });
}
