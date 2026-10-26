/// How to actually ask a given airline for an accommodation.
///
/// Knowing that a carrier offers a buffer zone is useless if you do not know
/// that it is a phone-only request taken no earlier than 48 hours out, by a
/// team that closes at 6pm, and that the web form will silently do nothing.
/// Every carrier routes these differently and none of them explain it in one
/// place — which is why passengers so often arrive at the gate believing they
/// asked, and find no record of it.
library;

/// A way of reaching the airline. Distinct from `RequestChannel` in
/// travel.dart, which records how a request was *actually* made after the
/// fact; this describes what the carrier will *accept*.
enum ContactMethod {
  phone('Phone', 'Call the accessibility or special assistance line'),
  webForm('Web form', 'A form on the airline’s site, usually under special assistance'),
  app('Airline app', 'In the booking, under special assistance or requests'),
  email('Email', 'A monitored accessibility or customer relations address'),
  chat('Web chat', 'Live chat with an agent, transcript worth saving'),
  socialDm('Social DM', 'Public-platform direct message, often the fastest reply'),
  airportDesk('Airport desk', 'Check-in or special assistance desk on the day'),
  gate('At the gate', 'The gate agent, once boarding is being set up'),
  onboard('On board', 'The cabin crew, after you are seated');

  const ContactMethod(this.label, this.description);
  final String label;
  final String description;

  /// Whether this method leaves the passenger with something they can point
  /// at later. A phone call with a reference number is evidence; a verbal
  /// word from a gate agent is not.
  bool get leavesARecord =>
      this == ContactMethod.webForm ||
      this == ContactMethod.email ||
      this == ContactMethod.chat ||
      this == ContactMethod.socialDm ||
      this == ContactMethod.app;
}

/// One instruction in a carrier's request procedure.
class RequestStep {
  const RequestStep(this.text, {this.detail});

  final String text;

  /// Optional elaboration shown smaller beneath the step.
  final String? detail;
}

/// The complete "how to ask" record for one carrier.
class RequestGuide {
  const RequestGuide({
    required this.iata,
    required this.primary,
    required this.steps,
    required this.leadTime,
    this.alsoAccepted = const [],
    this.notAccepted = const [],
    this.phone,
    this.phoneLabel,
    this.formUrl,
    this.appPath,
    this.email,
    this.script = '',
    this.gotchas = const [],
    this.lastReviewed = '',
  });

  final String iata;

  /// The channel that actually works. Carriers frequently advertise several
  /// and honour one.
  final ContactMethod primary;

  final List<ContactMethod> alsoAccepted;

  /// Channels that look like they should work and do not — a web form that
  /// routes nowhere, an app screen with no allergy option. Naming these saves
  /// more time than naming the ones that work.
  final List<ContactMethod> notAccepted;

  /// The carrier's procedure, in order.
  final List<RequestStep> steps;

  /// e.g. "At least 48 hours before departure".
  final String leadTime;

  /// Only ever populated when verified on the carrier's own site. A wrong
  /// number in a safety context is worse than no number, so an unverified one
  /// is left null and the UI sends the user to the contact page instead.
  final String? phone;
  final String? phoneLabel;

  final String? formUrl;

  /// Where it lives in the airline's own app, e.g.
  /// "My trips → Passenger details → Special assistance".
  final String? appPath;

  final String? email;

  /// Wording the passenger can read out or paste. Being specific about the
  /// allergen and the accommodation, in the carrier's own vocabulary, gets a
  /// materially better result than "I have allergies".
  final String script;

  /// Carrier-specific traps.
  final List<String> gotchas;

  /// When this procedure was last checked against the carrier's published
  /// information. Procedures change; a stale record is not a fact.
  final String lastReviewed;

  bool get hasDirectContact =>
      phone != null || formUrl != null || email != null;

}
