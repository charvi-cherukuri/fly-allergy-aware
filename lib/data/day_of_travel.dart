import '../models/travel.dart';

// What to ask for on the day of travel, and who to ask.
//
// The request guides cover asking the airline in advance. This covers the part
// that actually makes the accommodation happen: almost every carrier creates a
// pre-board, a buffer zone or an announcement on the day, through a gate agent
// or a flight attendant, whatever was lodged beforehand (see the note at the
// top of request_guides.dart). So the day of travel gets its own guide, in the
// order the day goes.
//
// Scripts are templates. `{name}`, `{allergens}`, `{seat}`, `{flight}` and
// `{pen}` are filled from the profile, the flight and the auto-injector list
// by [fillDayScript]; anything unknown becomes a bracketed blank the traveler
// can see and say aloud, never an invented fact.
//
// These are requests, not entitlements. Every ask is worded as a question, and
// no script claims the airline has to say yes.

/// One thing to ask for.
class DayAsk {
  const DayAsk({
    required this.type,
    required this.title,
    required this.why,
    required this.script,
  });

  /// What it is, for logging it as a request.
  final AccommodationType type;
  final String title;

  /// One or two sentences on why it is worth asking.
  final String why;

  /// The words to say, as a template.
  final String script;
}

/// One part of the day: who you are talking to, when, and what to ask them.
class DayStage {
  const DayStage({
    required this.title,
    required this.who,
    required this.when,
    required this.channel,
    required this.asks,
    this.tips = const <String>[],
  });

  final String title;

  /// Who to ask, e.g. "The gate agent".
  final String who;

  /// When to ask, e.g. "Before boarding starts — arrive 45 minutes early".
  final String when;

  /// How a request made at this stage is logged.
  final RequestChannel channel;

  final List<DayAsk> asks;

  /// Things worth knowing that are not requests.
  final List<String> tips;
}

const List<DayStage> kDayOfTravel = <DayStage>[
  DayStage(
    title: 'At the airport',
    who: 'The check-in or bag-drop agent',
    when: 'When you check in',
    channel: RequestChannel.checkIn,
    asks: <DayAsk>[
      DayAsk(
        type: AccommodationType.crewNotified,
        title: 'Check your allergy is on the booking',
        why: 'Requests made earlier often don’t reach the gate or the crew.',
        script: 'Hi. {name} has a severe {allergens} allergy. Is it on our '
            'booking for flight {flight}? Can the gate and the crew see it?',
      ),
    ],
    tips: <String>[
      'Keep your auto-injectors in your carry-on bag. A checked bag is out of '
          'reach, and the cold can damage them.',
      'Auto-injectors are allowed through security. Keep them in the pharmacy '
          'box and tell the officer what they are.',
      'Pack your own food for the whole trip, including delays.',
    ],
  ),
  DayStage(
    title: 'Before boarding',
    who: 'The agent at the gate',
    when: 'Get to the gate early, about 45 minutes before the flight',
    channel: RequestChannel.gate,
    asks: <DayAsk>[
      DayAsk(
        type: AccommodationType.preboardToWipe,
        title: 'Ask to board early and wipe your seat',
        why: 'Seats and tray tables are rarely cleaned between flights.',
        script: 'Hi. We are on flight {flight}, seat {seat}. {name} has a '
            'severe {allergens} allergy. Can we board early to wipe down our '
            'seats?',
      ),
      DayAsk(
        type: AccommodationType.crewNotified,
        title: 'Ask the agent to tell the crew',
        why: 'The crew will know before you get on.',
        script: 'Could you please tell the crew about the allergy in seat '
            '{seat}?',
      ),
    ],
    tips: <String>[
      'If the agent says no, ask if the crew can help once you are on board.',
    ],
  ),
  DayStage(
    title: 'Boarding',
    who: 'A flight attendant, ideally the lead flight attendant',
    when: 'As soon as you sit down, before the snacks come out',
    channel: RequestChannel.onboard,
    asks: <DayAsk>[
      DayAsk(
        type: AccommodationType.crewNotified,
        title: 'Tell the crew about the allergy',
        why: 'Crew who already know can act faster if a reaction starts.',
        script: 'Hi. We are in {seat}. {name} has a severe {allergens} allergy. '
            'The epinephrine is {pen}.',
      ),
      DayAsk(
        type: AccommodationType.bufferZone,
        title: 'Ask for a buffer zone',
        why: 'People nearby are asked not to eat your allergen.',
        script: 'Could you ask the rows near us not to eat {allergens} on this '
            'flight?',
      ),
      DayAsk(
        type: AccommodationType.cabinAnnouncement,
        title: 'Ask for an announcement',
        why: 'It reaches everyone on the plane.',
        script: 'Could you make an announcement asking people not to eat '
            '{allergens} on this flight?',
      ),
      DayAsk(
        type: AccommodationType.noNutService,
        title: 'Ask if the snacks contain your allergen',
        why: 'The crew may be able to hold them, at least near your seat.',
        script: 'Will any snacks with {allergens} be served? If so, could they '
            'be held near our row?',
      ),
      DayAsk(
        type: AccommodationType.epiOnBoard,
        title: 'Ask what is in the medical kit',
        why: 'Not every plane carries an auto-injector. Many have only a vial '
            'and syringe.',
        script: 'Does the medical kit have epinephrine? Is it an auto-injector '
            'or a vial? Where is it kept?',
      ),
    ],
    tips: <String>[
      'Use “Show to crew” so you don’t have to repeat everything.',
      'If you couldn’t board early, wipe your seat now.',
    ],
  ),
  DayStage(
    title: 'During the flight',
    who: 'The flight attendants',
    when: 'Whenever you need help',
    channel: RequestChannel.onboard,
    asks: <DayAsk>[
      DayAsk(
        type: AccommodationType.seatChange,
        title: 'Get help if someone nearby opens your allergen',
        why: 'The crew can move you or ask them to put it away.',
        script: 'Someone near us opened something with {allergens}. Could you '
            'help us move, or ask them to put it away?',
      ),
    ],
    tips: <String>[
      'Eat the food you brought.',
      'Log anything that happens while you remember it.',
    ],
  ),
];

/// The values a script is filled with. Null means unknown.
class DayScriptValues {
  const DayScriptValues({
    this.name,
    this.allergens,
    this.seat,
    this.flight,
    this.pen,
    this.plural = false,
  });

  final String? name;
  final String? allergens;
  final String? seat;
  final String? flight;
  final String? pen;

  /// True when [name] takes "have" — "I", or more than one person.
  final bool plural;
}

/// Fills a script template. Anything unknown becomes a visible bracketed
/// blank — "[seat]" — rather than a guess.
String fillDayScript(String template, DayScriptValues v) {
  String or(String? value, String blank) =>
      (value == null || value.trim().isEmpty) ? '[$blank]' : value.trim();
  final String t = v.plural ? template.replaceAll('{name} has ', '{name} have ') : template;
  return t
      .replaceAll('{name}', or(v.name, 'name'))
      .replaceAll('{allergens}', or(v.allergens, 'allergen'))
      .replaceAll('{seat}', or(v.seat, 'seat'))
      .replaceAll('{flight}', or(v.flight, 'flight number'))
      .replaceAll('{pen}', v.pen == null || v.pen!.trim().isEmpty
          ? 'in [where you keep it]'
          : v.pen!.trim());
}
