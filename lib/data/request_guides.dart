// Researched snapshots of *how you actually ask* each carrier for an allergy
// accommodation. Companion to airline_policies.dart, which records what the
// carrier will do; this records the door you have to walk through to get it.
//
// READ THIS BEFORE TRUSTING ANY RECORD BELOW.
//
// 1. These are snapshots taken in August 2026 from carrier accessibility,
//    special-assistance and special-meal pages. Every record carries
//    `lastReviewed: '2026-08'`.
// 2. **Airlines change these procedures without notice and without
//    announcement.** Phone numbers get retired, teams get renamed, forms get
//    replaced by chatbots, and nothing tells the passenger. Southwest withdrew
//    allergy pre-boarding in September 2022 and restored it that November.
//    Air Canada's Medical Assistance Desk is now Accessibility Services. Air
//    France's 48-hour meal deadline is now 24 hours. Spirit stopped flying
//    altogether on 2 May 2026. A record that was right last quarter can be
//    wrong today.
// 3. **The app must tell the user to confirm the procedure with the airline
//    before they fly, and must never present these steps as a guarantee.**
//    They exist to tell someone which door to knock on and what a good answer
//    sounds like — never to stand in for the airline's own answer.
//
// On phone numbers. A wrong number in a safety context is worse than no
// number, so `phone` is populated *only* where the number was read on the
// carrier's own site or a page quoting it directly. Where it could not be
// verified it is null and `formUrl` points at the carrier's own contact page
// instead. This matters more than it sounds: searching for an airline
// "disability line" surfaces a large volume of SEO-spam PDFs hosted on
// hijacked .edu and .gov domains carrying fabricated numbers. Several were
// encountered during this research for Southwest, Frontier, Air Canada and
// KLM. Nothing below came from one. The same rule governs `formUrl`, `email`
// and `appPath`: verified or null.
//
// Where a carrier publishes nothing about the procedure, the record says so
// plainly in `gotchas` and gives the realistic fallback rather than inventing
// a process that does not exist.
//
// Two findings run through almost every record and are worth stating once:
//
//   * **Nearly every carrier requires a same-day, in-person, verbal ask.**
//     Whatever you lodge in advance, the accommodation is usually created by a
//     gate agent or a flight attendant on the day. British Airways is the only
//     carrier here that admits this in writing — "there may be instances where
//     crew do not have access to your booking details" — but it is true almost
//     everywhere. Treat every advance notification as best-effort.
//
//   * **Almost no carrier's special-assistance intake has an allergy option.**
//     American, Air Canada, Frontier, Ryanair, Air France (SAPHIR) and KLM
//     (CARES) all have fixed category lists that stop at mobility, vision,
//     hearing and service animals. A passenger who ticks the boxes believes
//     they have asked and has not. easyJet is the only carrier here with a
//     true allergy field. Naming these dead ends saves more time than naming
//     the channels that work.
//
// On the US regulatory floor: DOT Order 2026-3-9 (18 March 2026) dismissed the
// 2022 complaint against Southwest and confirmed that the right to pre-board
// and wipe your seat area is, as the rules currently stand, tied to **nut
// allergies only**. Extending it to sesame, dairy, egg or shellfish would need
// a formal rulemaking. A passenger with a non-nut allergy has no federally
// backed pre-boarding claim on any US carrier and should ask as a courtesy
// rather than as a right.

import '../models/request_guide.dart';

/// How to ask each carrier, keyed by IATA airline code.
///
/// The same twenty carriers as `kAirlinePolicies`.
const Map<String, RequestGuide> kRequestGuides = <String, RequestGuide>{
  // ---------------------------------------------------------------------
  // United States
  // ---------------------------------------------------------------------

  'DL': RequestGuide(
    iata: 'DL',
    primary: ContactMethod.webForm,
    alsoAccepted: <ContactMethod>[
      ContactMethod.phone,
      ContactMethod.gate,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.email,
      ContactMethod.chat,
    ],
    leadTime: 'No allergy deadline published. Delta reviews accessibility '
        'requests filed more than seven days out, so file as soon as the '
        'ticket is issued. The "48 hours for Delta" figure repeated across '
        'allergy guides appears nowhere on delta.com.',
    phone: '404-209-3434',
    phoneLabel: 'Delta Accessibility Services (dial 711 for relay)',
    formUrl: 'https://www.delta.com/my-trips/search',
    steps: <RequestStep>[
      RequestStep(
        'Open My Trips and file an Accessibility Service Request against the '
            'booking.',
        detail: 'Delta’s own wording: visit My Trips to fill out the '
            'Accessibility Service Request form, or call Accessibility '
            'Services. Do not use the standalone Accessibility Service '
            'Request page reached from Contact Us — that one is scoped to '
            'medical devices, special seating and service animals, and '
            'redirects allergy requests back to My Trips.',
      ),
      RequestStep(
        'Or call 404-209-3434 and have the agent read the note back to you.',
        detail: 'Write down the agent’s name and any reference they give '
            'you. This is the only artefact you will have at the gate.',
      ),
      RequestStep(
        'Say the word "peanut" if peanut is your allergen.',
        detail: 'The cabin-wide service hold Delta publishes is peanut-only. '
            'A tree nut, sesame, dairy or shellfish allergy gets early '
            'boarding and help with a seat change — no service hold at all.',
      ),
      RequestStep(
        'On any route touching Canada, ask for a buffer zone in those words.',
        detail: 'Delta’s Canada Accessibility Plan commits to refraining '
            'from serving any notified food allergen within your bank of '
            'seats. It is narrower than the US peanut hold in area but wider '
            'in allergen, and it is the only written Delta commitment a '
            'non-nut allergy can point at.',
      ),
      RequestStep(
        'Contact every partner carrier separately.',
        detail: 'Delta states the notification does not cross to codeshares. '
            'A Delta-booked KLM, Air France or Virgin Atlantic segment '
            'inherits nothing.',
      ),
      RequestStep(
        'At the gate on the day, ask to pre-board to clean your seat area.',
        detail: 'Delta grants this but you must bring your own wipes. It is a '
            'day-of ask; nothing you filed in advance produces it.',
      ),
    ],
    script: 'I have a severe, anaphylactic peanut allergy. I am on Delta '
        'flight [number] on [date], confirmation [code]. Please add an '
        'accessibility service request so that peanuts and peanut products '
        'are not served on that flight, and please note that I will ask to '
        'pre-board to wipe down my seat area. Could you read the note back to '
        'me and give me a reference number for it?',
    gotchas: <String>[
      'Two doors, one of them wrong. The Accessibility Service Request form '
          'reached from Contact Us is not the allergy route and says so; the '
          'one reached from My Trips is. Many allergy guides link to the '
          'wrong one.',
      'The service hold is peanut-only in the US. Delta publishes no '
          'commitment to withhold tree nuts, sesame or anything else '
          'cabin-wide on a US-facing itinerary.',
      'Pre-boarding is never carried on the booking. It has to be asked for at '
          'the gate on every single segment, whatever is in the record.',
      'Delta does not document whether an allergy note survives a schedule '
          'change or an involuntary rebooking. Assume it does not and check '
          'again after any change.',
    ],
    lastReviewed: '2026-08',
  ),

  'UA': RequestGuide(
    iata: 'UA',
    primary: ContactMethod.onboard,
    alsoAccepted: <ContactMethod>[
      ContactMethod.gate,
      ContactMethod.phone,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.app,
      ContactMethod.webForm,
      ContactMethod.chat,
    ],
    leadTime: 'None published, and calling ahead buys nothing United has '
        'committed to in writing. The single exception is a flight to or from '
        'Canada, where the regulator requires at least 48 hours’ notice '
        'for a buffer zone.',
    phone: '1-800-228-2744',
    phoneLabel: 'United Accessibility Desk',
    formUrl: 'https://www.united.com/en/us/fly/contact/travel/special-needs.html',
    email: 'uaaeromed@united.com',
    steps: <RequestStep>[
      RequestStep(
        'Tell a flight attendant before the aircraft pushes back.',
        detail: 'This is not the fallback — it is the only mechanism United '
            'publishes. The crew will ask the passengers seated near you not '
            'to eat allergen-containing food they brought on board. Nothing '
            'you do in advance replaces this step.',
      ),
      RequestStep(
        'Ask at the gate to board early to wipe down.',
        detail: 'United names the surfaces itself: seats, tray tables, the '
            'cabin wall and the window. Bring your own wipes.',
      ),
      RequestStep(
        'On a flight to or from Canada, call 1-800-228-2744 at least 48 hours '
            'out and say "buffer zone" and "ATPDR".',
        detail: 'On Canadian routes the buffer zone is a regulatory '
            'entitlement rather than crew discretion: you must be seated in a '
            'bank of seats free of the allergen, and the other passengers in '
            'that bank must be told which allergen to avoid. Be ready to be '
            'asked for a medical certificate.',
      ),
      RequestStep(
        'Do not go looking for an allergy option in the accessibility flow.',
        detail: 'United lists eighteen accessible-travel categories and '
            'allergies is not a requestable one — it is an information page '
            'with no form, no service request and no booking-flow entry. The '
            'accessible-seating request is for disability seating, not '
            'allergen separation.',
      ),
      RequestStep(
        'Repeat the whole thing on the next aircraft.',
        detail: 'The accommodation is created by a crew member on the day, so '
            'there is nothing on the record to carry across a connection.',
      ),
    ],
    script: 'Hello — I have a severe, anaphylactic tree nut allergy and I '
        'carry an epinephrine auto-injector. Before we push back, could you '
        'ask the passengers in the rows around me not to open any nut '
        'products they have brought on board? I have already wiped my seat '
        'area and I will not be eating anything served on the flight. My seat '
        'is [seat] and my auto-injector is in the seat pocket in front of me.',
    gotchas: <String>[
      'United is unusually blunt that it cannot force other passengers not to '
          'eat their own food. What you get is a request made to your '
          'neighbours, not a service restriction.',
      'uaaeromed@united.com is a general aeromedical mailbox. There is no '
          'evidence it produces an allergy notation the crew will ever see.',
      'A phone call to the Accessibility Desk on a non-Canadian route creates '
          'nothing United has committed to act on. Make it if you want, but '
          'do not board believing it did anything.',
      'United does not board pre-packaged peanuts but says its food may '
          'contain tree nuts — so the neighbour request covers what other '
          'passengers brought, not what the galley serves.',
    ],
    lastReviewed: '2026-08',
  ),

  'AA': RequestGuide(
    iata: 'AA',
    primary: ContactMethod.gate,
    alsoAccepted: <ContactMethod>[
      ContactMethod.onboard,
      ContactMethod.phone,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.app,
      ContactMethod.email,
      ContactMethod.chat,
    ],
    leadTime: 'None, because there is nothing to request in advance. The only '
        'allergy accommodation American gives is a day-of ask at the gate. '
        'The 20-hour special-meal deadline is not an allergy deadline and a '
        'special meal is not an allergen-safe meal.',
    phone: '800-237-7976',
    phoneLabel: 'American Special Assistance — pre-travel arrangements',
    steps: <RequestStep>[
      RequestStep(
        'Go to the gate early and ask the gate agent to let you pre-board to '
            'wipe down your seat.',
        detail: 'This is the whole accommodation. American does not publish '
            'it on its allergy page, so the agent may not know it exists — '
            'the hook on its special-assistance page is that customers '
            'needing special assistance can ask to board early.',
      ),
      RequestStep(
        'If you are refused, use the DOT’s own framing.',
        detail: 'American committed to allergy pre-boarding on 12 December '
            '2018 after a US DOT complaint. The DOT decision held that a '
            'passenger with a severe allergy asking to pre-board to wipe down '
            'seating surfaces is requesting additional time "to be seated" — '
            'which is a protected request. Ask for extra time to be seated, '
            'not for a favour.',
      ),
      RequestStep(
        'Do not ask for a nut hold or a buffer zone.',
        detail: 'American states plainly that it cannot accommodate requests '
            'not to serve certain foods or to provide nut buffer zones. '
            'Asking will be refused and will spend goodwill you need for the '
            'pre-board.',
      ),
      RequestStep(
        'Plan around warmed nuts if you are anywhere near a premium cabin.',
        detail: 'American serves warmed tree nuts in premium cabins and says '
            'meals and snacks may carry trace nut ingredients including '
            'peanut oils. Eat nothing served on board.',
      ),
      RequestStep(
        'Tell the flight attendant once you are seated.',
        detail: 'It changes nothing about the service, but it means somebody '
            'on board knows you are the passenger with the auto-injector.',
      ),
      RequestStep(
        'Call 800-237-7976 only for genuine accessibility arrangements.',
        detail: 'And never 800-892-3624 before a trip — American labels that '
            'one for special-assistance issues on a *previous* trip. Allergy '
            'guides publish it as the pre-flight number. It is not.',
      ),
    ],
    script: 'I have a severe, anaphylactic tree nut allergy. I would like to '
        'pre-board so I have the additional time I need to be seated — I need '
        'to wipe down my seat, the tray table and the cabin wall before the '
        'row fills up. I have my own wipes. I am not asking you to change the '
        'food service; I understand American serves nuts. This is the '
        'accommodation American agreed to provide in December 2018.',
    gotchas: <String>[
      'The "Add special assistance" flow has no allergy option. Its entire '
          'menu is wheelchair service, your own mobility device, hearing / '
          'vision / cognitive / developmental disability, and service '
          'animals. You will hunt for an allergy entry and there is not one.',
      'The online disability form has no allergy subject either — the only '
          'subjects are disability assistance, service animals and wheelchair '
          'or mobility device.',
      '800-892-3624 is a post-flight complaints line, not a pre-trip line, '
          'despite being widely republished as the allergy number.',
      'Nothing is ever recorded, so nothing can be lost — and nothing can be '
          'relied on. Re-ask at every gate, every segment, every time.',
      'American publishes no allergy pre-boarding page, so you will have '
          'nothing on your phone to show a gate agent who says no. Carry the '
          'December 2018 date and the "additional time to be seated" wording '
          'instead.',
    ],
    lastReviewed: '2026-08',
  ),

  'WN': RequestGuide(
    iata: 'WN',
    primary: ContactMethod.gate,
    alsoAccepted: <ContactMethod>[
      ContactMethod.onboard,
      ContactMethod.airportDesk,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.app,
      ContactMethod.email,
      ContactMethod.chat,
    ],
    leadTime: 'Day of travel only. Southwest publishes no advance-notice '
        'channel of any kind for allergies, so contacting them beforehand '
        'accomplishes nothing.',
    formUrl: 'https://support.southwest.com/helpcenter/s/article/Allergies',
    steps: <RequestStep>[
      RequestStep(
        'Self-identify in the gate area and speak to the Operations (boarding) '
            'agent before pre-boarding starts.',
        detail: 'Southwest’s own words. Get there early — once '
            'pre-boarding has begun it is too late to be added to it.',
      ),
      RequestStep(
        'Quote the Allergies article, not the pre-boarding article.',
        detail: 'This is the single most useful thing to know about Southwest. '
            'Its pre-boarding help article does not mention allergies at all '
            '— it lists only extra time to board, stowing accessibility '
            'equipment and being seated. The nut-allergy pre-board lives '
            'solely in the separate Allergies article. A gate agent reading '
            'the pre-boarding page will conclude you do not qualify. Have the '
            'Allergies wording ready: customers who wish to wipe down their '
            'seating area due to a nut allergy may pre-board.',
      ),
      RequestStep(
        'Bring your own wipes and expect to clean the area yourself.',
      ),
      RequestStep(
        'If you are allergic to an animal on board, tell the departure gate.',
        detail: 'Southwest publishes this separately and will reassign you to '
            'an available seat if there is one.',
      ),
      RequestStep(
        'Ask for the Complaints Resolution Official if you are refused.',
        detail: 'A CRO must be made available on request at any airport, in '
            'person or by phone. This is the escalation route, and asking for '
            'one by name changes the conversation.',
      ),
      RequestStep(
        'Tell the flight attendant once you are seated.',
      ),
    ],
    script: 'I have a severe, anaphylactic nut allergy. Under Southwest’s '
        'published allergy policy, customers who wish to wipe down their '
        'seating area due to a nut allergy may pre-board. I have my own '
        'wipes and I just need to be let on before the row fills. If that is '
        'not something you can do, could I speak to a Complaints Resolution '
        'Official?',
    gotchas: <String>[
      'No phone number is recorded here because Southwest publishes none on '
          'its own site, and searches for a "Southwest accessibility line" '
          'return fabricated numbers on spam PDFs. The only numbers Southwest '
          'itself publishes are the US DOT’s disability hotline, which '
          'is a government line, not the airline.',
      'The 2022 withdrawal and restoration is settled but the scope narrowed. '
          'DOT Order 2026-3-9 of 18 March 2026 dismissed the advocacy '
          'groups’ complaint and confirmed that the pre-board-to-clean '
          'right currently attaches to nut allergies only. Southwest’s '
          'own text is nut-only too; other food allergies get "read the '
          'labels" and "bring your own snacks".',
      'Southwest moved to assigned seating in 2026, so pre-boarding no longer '
          'secures you a seat — it only buys time to clean the one you '
          'already have. Adjust your expectations accordingly.',
      'Southwest stopped serving peanuts in 2018 but serves tree nuts '
          'including pistachios and almonds, and no hold on those is '
          'available at any price.',
      'The Contact Us route is post-travel admin — refunds, receipts, '
          'compliments and complaints. Nothing pre-flight, nothing allergy.',
    ],
    lastReviewed: '2026-08',
  ),

  'B6': RequestGuide(
    iata: 'B6',
    primary: ContactMethod.phone,
    alsoAccepted: <ContactMethod>[
      ContactMethod.onboard,
      ContactMethod.app,
      ContactMethod.gate,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.email,
    ],
    leadTime: 'None published — JetBlue says only to book as early as possible '
        'and add the service request then. The buffer zone itself has an '
        'effective deadline of "as you board", because that is when it is '
        'created.',
    phone: '1-855-232-5463',
    phoneLabel: 'JetBlue Disability Assistance Line (1-855-ADA-LINE)',
    appPath: 'Book on jetblue.com or in the JetBlue app → traveler info '
        '→ tick the special-assistance box → service request '
        'dropdowns appear',
    steps: <RequestStep>[
      RequestStep(
        'Call the Disability Assistance Line and ask for a MEDA service '
            'request to be added to the booking.',
        detail: 'JetBlue names the code itself: customers with nut or animal '
            'allergies can contact JetBlue to request a MEDA SSR on their '
            'booking. Ask the agent to confirm it is on the record.',
      ),
      RequestStep(
        'There is no fee for this, whatever the contact page implies.',
        detail: 'JetBlue warns of a per-person fee for phone-serviced '
            'reservations, which puts people off calling. Its accessibility '
            'pages say the opposite for this specific case: there is never a '
            'fee to add a service request to an existing booking.',
      ),
      RequestStep(
        'Then — and this is the part that actually creates the buffer zone — '
            'tell an inflight crew member as you board.',
        detail: 'The SSR alone produces nothing. On request at boarding the '
            'crew create a buffer zone one row in front of you and one row '
            'behind, ask those passengers to refrain from nut products they '
            'brought, and serve no nut products to those rows. If you say '
            'nothing at the door, you get no buffer zone no matter what is on '
            'the booking.',
      ),
      RequestStep(
        'Ask the gate crew member for disability boarding to wipe your seat.',
      ),
      RequestStep(
        'Ask again on the second aircraft.',
        detail: 'The service request persists on the record; the buffer zone '
            'does not. It is created fresh by the crew on each flight, so a '
            'connection means asking twice.',
      ),
    ],
    script: 'Hi — I have a severe, anaphylactic peanut and tree nut allergy. '
        'There is a MEDA service request on my booking. Could you please '
        'create a buffer zone: one row in front of me and one row behind, no '
        'nut products served to those rows, and ask those passengers not to '
        'open any nut products they brought aboard? I am in seat [seat] and I '
        'carry an epinephrine auto-injector.',
    gotchas: <String>[
      'JetBlue explicitly refuses the announcement most people expect: it '
          'makes no formal announcement on board or in the gate area about '
          'restricting nut consumption. Only the buffer rows are spoken to.',
      'Three rows or two? JetBlue says one row in front and one behind, which '
          'is three rows counting yours. Secondary sources say "three-row '
          'buffer". They are the same thing — do not let the wording confuse '
          'a conversation with the crew.',
      'The self-serve dropdown at booking may not contain an allergy option. '
          'JetBlue’s own allergy text tells you to phone for the MEDA '
          'SSR rather than to use the dropdown, so treat the dropdown as '
          'unproven and call.',
      'JetBlue does not serve peanuts but does serve tree nut products.',
      'Whether the MEDA SSR survives a rebooking is not documented. Check the '
          'booking again after any schedule change.',
    ],
    lastReviewed: '2026-08',
  ),

  'AS': RequestGuide(
    iata: 'AS',
    primary: ContactMethod.gate,
    alsoAccepted: <ContactMethod>[
      ContactMethod.phone,
      ContactMethod.airportDesk,
      ContactMethod.onboard,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.app,
      ContactMethod.email,
    ],
    leadTime: 'None published for allergies. Alaska’s own instruction is '
        'to restate it at check-in, in the boarding area, and on the aircraft '
        '— three times, every flight.',
    phone: '1-800-503-0101',
    phoneLabel: 'Alaska Airlines accessible services (relay: dial 711)',
    formUrl:
        'https://www.alaskaair.com/content/travel-info/accessible-services/specialservices-other',
    steps: <RequestStep>[
      RequestStep(
        'Tell the gate agent you would like to pre-board to cleanse your '
            'immediate seating area.',
        detail: 'Use Alaska’s own phrase — "cleanse your immediate '
            'seating area" is the wording on its page and it is what the '
            'agent will recognize.',
      ),
      RequestStep(
        'Say it again at check-in and again to the flight attendant.',
        detail: 'Alaska explicitly asks you to raise special requirements at '
            'all three touchpoints, which is as close as any carrier comes to '
            'admitting the request does not travel.',
      ),
      RequestStep(
        'Call 1-800-503-0101 if you need a seating change or anything '
            'structural.',
        detail: 'Allergy is filed under "other services and information" '
            'rather than among the requestable accessible-services '
            'categories, so the line can help with seating but has no allergy '
            'field to fill in.',
      ),
      RequestStep(
        'Do not order or eat the onboard food.',
        detail: 'Alaska says first-class meals and buy-on-board items may '
            'contain nuts and that attempting to guarantee a nut-free flight '
            'would create a false sense of security. It actively encourages '
            'allergic passengers to bring their own food.',
      ),
    ],
    script: 'I have a severe, anaphylactic peanut allergy. Could I pre-board '
        'to cleanse my immediate seating area? I have my own wipes and I only '
        'need a couple of minutes before the row fills. I have also let '
        'check-in know and I will tell the flight attendant once I am seated.',
    gotchas: <String>[
      'CHECK THIS ONE BEFORE YOU RELY ON IT: Alaska does not currently '
          'publish a buffer zone. The phrase does not appear anywhere in its '
          'accessible-services pages, and the combined Alaska/Hawaiian '
          'contract of carriage contains no reference to allergies, nuts or '
          'buffer zones at all. Older allergy guides — and possibly this '
          'app’s own policy record — credit Alaska with a four-way '
          'buffer around your row. Pre-boarding to wipe is what is published '
          'today. Ask for the buffer anyway, but do not board expecting it.',
      'There is no allergy option in Alaska’s online request flow. '
          'Services can be added to booked tickets through Trips, but not '
          'this one.',
      'Nothing attaches to the booking, so nothing survives a rebooking. The '
          'gate ask is the whole procedure.',
    ],
    lastReviewed: '2026-08',
  ),

  'NK': RequestGuide(
    iata: 'NK',
    primary: ContactMethod.phone,
    notAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.app,
      ContactMethod.email,
      ContactMethod.chat,
      ContactMethod.gate,
      ContactMethod.onboard,
      ContactMethod.airportDesk,
    ],
    leadTime: 'Not applicable. Spirit Airlines ceased all operations on 2 May '
        '2026 and is in liquidation.',
    steps: <RequestStep>[
      RequestStep(
        'There is no request to make: Spirit stopped flying on 2 May 2026.',
        detail: 'The airline began an orderly wind-down effective immediately, '
            'cancelled all flights, shut down customer service and told '
            'customers not to go to the airport.',
      ),
      RequestStep(
        'If you are holding a booking with an NK flight number, find out who '
            'is actually operating it.',
        detail: 'It is either being flown by another carrier under a rebooking '
            'arrangement, or it is not being flown at all. Whichever it is, '
            'the allergy request has to be made to whoever is operating the '
            'aircraft — and their procedure will be nothing like Spirit’s '
            'was.',
      ),
      RequestStep(
        'Ignore anything you find about Spirit’s old allergy policy.',
        detail: 'Its buffer-zone and pre-boarding text is still echoed across '
            'aggregator sites and older allergy guides. It describes a carrier '
            'that no longer exists.',
      ),
    ],
    script: '',
    gotchas: <String>[
      'A trap for anyone checking links automatically: spirit.com sub-pages '
          'still return HTTP 200 with an empty page shell, so a status-code '
          'health check will report Spirit’s special-services page as '
          'live forever. Only the bare domain redirects to the restructuring '
          'site.',
      'The only live phone line is the bankruptcy claims agent. It is not an '
          'airline channel and cannot help with a flight.',
      'This record is kept rather than deleted so that anyone holding an old '
          'Spirit booking, or reading an old guide, gets told plainly rather '
          'than being sent to a dead page.',
    ],
    lastReviewed: '2026-08',
  ),

  'F9': RequestGuide(
    iata: 'F9',
    primary: ContactMethod.onboard,
    alsoAccepted: <ContactMethod>[
      ContactMethod.gate,
      ContactMethod.phone,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.app,
      ContactMethod.email,
    ],
    leadTime: 'None, because nothing exists to submit in advance. Worth '
        'noticing that Frontier does publish a 48-hour rule for service '
        'animals — the absence of an allergy deadline is not an oversight.',
    phone: '602-333-5925',
    phoneLabel: 'Frontier customer service, 24/7',
    formUrl: 'https://www.flyfrontier.com/travel/travel-info/special-services/',
    steps: <RequestStep>[
      RequestStep(
        'Notify a flight attendant on board.',
        detail: 'Frontier’s published position, and the only mechanism it '
            'offers: tell a flight attendant so they can attempt to notify '
            'nearby customers to refrain from eating allergen-containing '
            'products they brought with them. Note the verb — "attempt".',
      ),
      RequestStep(
        'Ask the gate agent to pre-board so you can wipe your seat.',
        detail: 'Frontier does not publish this, but it is the standard US '
            'nut-allergy pre-board and gate agents generally grant it. Bring '
            'your own wipes.',
      ),
      RequestStep(
        'Do not use the online Accessibility Request Form for this.',
        detail: 'Its dropdown offers blind, deaf, meet-and-assist, seating, '
            'assistive device and wheelchair — with no allergy option and no '
            '"other". The form will accept your submission and nothing will '
            'come of it. Frontier’s own accessibility and customer '
            'service pages both point disabled passengers here.',
      ),
      RequestStep(
        'Call 602-333-5925 if you want to try anyway.',
        detail: 'It is a general 24/7 line, not a disability line — Frontier '
            'publishes no accessibility phone number. Ask for a note on the '
            'record and write down who you spoke to, but treat it as best '
            'effort.',
      ),
      RequestStep(
        'Bring all your own food.',
      ),
    ],
    script: 'I have a severe, anaphylactic peanut allergy. Would you be able '
        'to ask the passengers in the rows around me not to open any nut '
        'products they brought on board? I am in seat [seat], I have wiped '
        'the area down, I am not eating anything from the trolley, and my '
        'epinephrine auto-injector is in the seat pocket in front of me.',
    gotchas: <String>[
      'Frontier’s contract of carriage forecloses the ask contractually: '
          'items are not removed from the aircraft to accommodate a '
          'passenger’s allergy. There is no point negotiating this at '
          'the gate.',
      'Some of the numbers on Frontier’s special services page belong to '
          'third-party oxygen vendors, not to Frontier.',
      'A "Frontier ADA line" circulates online. Frontier publishes no such '
          'number and the ones in circulation are spam-sourced and mutually '
          'inconsistent. Do not call them.',
      'Frontier states its snacks contain allergens, that it cannot guarantee '
          'an allergen-free environment, and that it will not stop other '
          'passengers bringing nuts aboard because doing so would create a '
          'false sense of security.',
    ],
    lastReviewed: '2026-08',
  ),

  'HA': RequestGuide(
    iata: 'HA',
    primary: ContactMethod.gate,
    alsoAccepted: <ContactMethod>[
      ContactMethod.phone,
      ContactMethod.onboard,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.app,
      ContactMethod.email,
    ],
    leadTime: 'None published. Day-of ask at the gate, on every segment.',
    phone: '1-800-503-0101',
    phoneLabel: 'Alaska Airlines accessible services — now handles Hawaiian '
        '(Hawaiian reservations: 1-800-367-5320, 24/7)',
    formUrl:
        'https://www.alaskaair.com/content/travel-info/accessible-services/specialservices-other',
    steps: <RequestStep>[
      RequestStep(
        'Follow Alaska’s procedure, not Hawaiian’s.',
        detail: 'The two carriers merged, moved to a single operating '
            'certificate and completed the passenger-system cutover in April '
            '2026. The allergy policy served on hawaiianairlines.com is now '
            'literally Alaska’s page — it reads "Alaska Airlines is '
            'unable to guarantee a nut- or allergen-free flight."',
      ),
      RequestStep(
        'Tell the gate agent you want to pre-board to cleanse your immediate '
            'seating area.',
        detail: 'Bring your own wipes. This is the only accommodation on '
            'offer.',
      ),
      RequestStep(
        'Say it again at check-in and to the flight attendant.',
      ),
      RequestStep(
        'Assume macadamias are on board.',
        detail: 'Macadamia nuts are a signature Hawaiian service item and '
            'nothing published suggests they have been withdrawn. For a tree '
            'nut allergy this is among the hardest cabins on this list. Bring '
            'all your own food.',
      ),
    ],
    script: 'I have a severe, anaphylactic tree nut allergy — including '
        'macadamia. Could I pre-board to cleanse my immediate seating area? I '
        'have my own wipes. I will not be eating anything served on board, '
        'and I carry an epinephrine auto-injector.',
    gotchas: <String>[
      'The old Hawaiian allergy article at hawaiianair.custhelp.com is dead — '
          'the whole subdomain no longer resolves — yet it still ranks in '
          'search results and is still cited by third-party guides.',
      'Two parallel site structures live on hawaiianairlines.com. The '
          'Hawaiian-branded special assistance page contains no mention of '
          'allergies or nuts at all; the policy exists only on the '
          'Alaska-derived pages. Hawaiian’s own navigation points at the '
          'empty one.',
      'Hawaiian’s Contact Us phone list contains no accessibility line, '
          'and 1-800-654-5669 is post-flight guest care only.',
      'Allergy guides published as recently as mid-2025 still credit Hawaiian '
          'with a buffer zone. The current combined policy has none.',
    ],
    lastReviewed: '2026-08',
  ),

  // ---------------------------------------------------------------------
  // Outside the US
  // ---------------------------------------------------------------------

  'AC': RequestGuide(
    iata: 'AC',
    primary: ContactMethod.phone,
    alsoAccepted: <ContactMethod>[
      ContactMethod.email,
      ContactMethod.airportDesk,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.app,
      ContactMethod.webForm,
      ContactMethod.chat,
    ],
    leadTime: 'At least 48 hours before departure, regardless of itinerary. '
        'Inside 48 hours Air Canada promises only a reasonable effort, so the '
        '48-hour mark is a real cliff rather than a guideline.',
    phone: '1-800-667-4732',
    phoneLabel: 'Air Canada Accessibility Services, toll-free Canada and US '
        '(from elsewhere: +1-514-369-7039). Daily 06:00–00:00 ET. TTY '
        '1-833-754-3650',
    formUrl:
        'https://www.aircanada.com/ca/en/aco/home/plan/accessibility/severe-allergies.html',
    email: 'accessible@aircanada.ca',
    steps: <RequestStep>[
      RequestStep(
        'Call Accessibility Services on 1-800-667-4732 at least 48 hours '
            'before departure.',
        detail: 'This team was called the Medical Assistance Desk until '
            'recently and older guides still use that name. Same number.',
      ),
      RequestStep(
        'Ask for a buffer zone as a right, not a favour, and say so.',
        detail: 'Air Canada’s buffer zone exists because the Canadian '
            'Transportation Agency ordered it. The CTA found in 2010 that a '
            'severe peanut or nut allergy is a disability in the air travel '
            'context, and Decision 228-AT-A-2011 required the buffer zone on '
            '48 hours’ notice, plus a crew briefing of the surrounding '
            'passengers and no nut-containing snacks served in the zone. '
            'Decision 134-AT-A-2013 extended it to Jazz and covered non-nut '
            'food allergies through reseating on request. Naming the decision '
            'changes the conversation.',
      ),
      RequestStep(
        'Confirm what the zone covers for your cabin.',
        detail: 'In economy it is your row plus the rows in front and behind, '
            'but not across the aisle. In business it is your bank of seats. '
            'Traces are not excluded.',
      ),
      RequestStep(
        'Check the request appears on your booking confirmation.',
        detail: 'Air Canada commits that requested assistance services are '
            'shown on the confirmation — which makes this one of the very few '
            'allergy requests anywhere that leaves you a document. If it is '
            'not there, it was not recorded.',
      ),
      RequestStep(
        'Email accessible@aircanada.ca if you want it in writing.',
        detail: 'This is a genuine pre-trip channel, not a complaints '
            'mailbox. Air Canada asks for a specific subject line: travel '
            'date as dd/MMM/yyyy, last name, first name, booking reference.',
      ),
      RequestStep(
        'Arrange partner-operated segments with the operating carrier.',
        detail: 'The policy covers flights operated by Air Canada, Air Canada '
            'Rouge and Air Canada Express (Jazz and PAL). A codeshare is '
            'somebody else’s procedure.',
      ),
      RequestStep(
        'Still tell the crew when you board.',
      ),
    ],
    script: 'I am requesting a buffer zone under Canadian Transportation '
        'Agency Decision 228-AT-A-2011. I have a severe, anaphylactic peanut '
        'allergy, I am giving more than 48 hours’ notice, and my booking '
        'reference is [code] for flight [number] on [date]. Please confirm '
        'the buffer zone is recorded on the booking, that it will show on my '
        'confirmation, and that the crew will be briefed. Could I have a '
        'reference number for this request and your name?',
    gotchas: <String>[
      'The booking-flow "Special Needs" selector has no allergy option at all '
          '— the word does not appear in it. A passenger who ticks boxes at '
          'booking will believe they have requested a buffer zone and will '
          'not have.',
      'Air Canada’s own severe-allergies page gives no phone number, and '
          'its contact link loops back through the customer-support directory '
          'to the accessibility page without ever showing the number. This is '
          'why the number is worth carrying in this app.',
      'Special requests generally cannot be completed in Manage My Booking. '
          'Air Canada directs you to call after booking.',
      'Air Canada explicitly will not make a general cabin announcement. The '
          'buffer zone is briefed to the surrounding passengers only.',
      'Searching for this number surfaces spam PDFs on hijacked .edu domains '
          'pushing Air Canada’s general reservations line as the '
          '"accessibility" line. The number above was read on aircanada.com.',
    ],
    lastReviewed: '2026-08',
  ),

  'BA': RequestGuide(
    iata: 'BA',
    primary: ContactMethod.onboard,
    alsoAccepted: <ContactMethod>[
      ContactMethod.gate,
      ContactMethod.phone,
      ContactMethod.webForm,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.app,
      ContactMethod.email,
    ],
    leadTime: 'None published, and British Airways says outright that advance '
        'notice does not reach the crew. The accommodation is same-day and on '
        'request.',
    phone: '1-800-247-9297',
    phoneLabel: 'British Airways US reservations, special assistance is '
        'option 3 (daily 07:00–01:00 ET). TTY 1-866-393-0961',
    formUrl:
        'https://www.britishairways.com/travel/webforms/public/en_us?eId=120001&wfpId=emailus',
    steps: <RequestStep>[
      RequestStep(
        'Take your adrenaline auto-injector out at the gate and ask to '
            'pre-board.',
        detail: 'British Airways requires you to present the auto-injector to '
            'staff at the gate before it will let you board early to clean '
            'and inspect the seat. No injector shown, no pre-board. Bring '
            'your own wipes.',
      ),
      RequestStep(
        'Tell the cabin crew as you board. This is mandatory, not a backup.',
        detail: 'BA states it in its own words: you must tell cabin crew of '
            'your food allergy when boarding, even if you have already '
            'contacted BA, because there may be instances where crew do not '
            'have access to your booking details. Its customer service teams '
            'cannot pass allergen information to cabin crew before your '
            'journey. This is the most honest sentence any airline publishes '
            'about allergy requests and it is worth believing.',
      ),
      RequestStep(
        'Ask the crew for the announcement and the nut-snack suspension.',
        detail: 'On request the crew will make an announcement so other '
            'passengers know about your peanut or tree nut allergy, and will '
            'suspend the serving of loose nut snacks in your cabin of travel. '
            'You have to ask; it is not automatic.',
      ),
      RequestStep(
        'Notify BA in advance anyway, but treat it as advisory.',
        detail: 'If you use the accessibility webform, BA tells you to pick '
            '"Disability & Mobility Assistance" from the Topics dropdown — '
            'there is no allergy topic, so you file an allergy under a '
            'mobility heading.',
      ),
      RequestStep(
        'Contact the operating carrier separately on any partner flight.',
        detail: 'The policy covers British Airways, BA Euroflyer and BA '
            'CityFlyer only. A BA-marketed, American-operated transatlantic '
            'flight is entirely outside it, and American’s procedure is '
            'nothing like this one.',
      ),
    ],
    script: 'Hello — I have a severe, anaphylactic peanut and tree nut '
        'allergy and I carry an adrenaline auto-injector, which I showed at '
        'the gate. Could you please make the announcement asking passengers '
        'to refrain from eating nut products, and suspend the serving of '
        'loose nut snacks in this cabin? I am in seat [seat] and my '
        'auto-injector is in the seat pocket in front of me.',
    gotchas: <String>[
      'The allergy content sits inside a collapsed accordion on the medical '
          'conditions page and is invisible to page search or a screen reader '
          'unless you expand it. It is easy to conclude BA has no allergy '
          'policy at all.',
      'The Passenger Medical Clearance Unit is real, staffed and has its own '
          'form and phone — and allergy is not on its clearance list. Do not '
          'route an allergy through PMCU; it handles recent illness, surgery, '
          'unstable conditions and medical equipment.',
      'The announcement does not make the aircraft nut-free. BA states that '
          'meals containing tree nuts may continue to be served throughout '
          'the aircraft, and tree nut snacks may still be served in other '
          'cabins depending on the aircraft type.',
      'There is no allergen-free meal. BA publishes that it offers no '
          'alternative meals free from sesame, tree nuts, lupin, soya, '
          'sulphites, mustard or celery, and no variation at all for multiple '
          'allergies. Short-haul Euro Traveller has no complimentary meal '
          'anyway.',
    ],
    lastReviewed: '2026-08',
  ),

  'LH': RequestGuide(
    iata: 'LH',
    primary: ContactMethod.email,
    alsoAccepted: <ContactMethod>[
      ContactMethod.onboard,
      ContactMethod.phone,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.app,
      ContactMethod.chat,
    ],
    leadTime: 'None published for allergy — Lufthansa says only "before you '
        'depart". The silence is conspicuous: the same page carries a firm '
        '48-hour rule for oxygen and a 24-hour rule for special meals. Treat '
        'it as meaning there is no guaranteed processing window.',
    phone: '+49 69 696 55077',
    phoneLabel: 'Lufthansa Medical Operation Centre, Frankfurt (no US-facing '
        'medical line is published)',
    email: 'medicaloperation@dlh.de',
    steps: <RequestStep>[
      RequestStep(
        'Email the Medical Operation Centre before you depart.',
        detail: 'Lufthansa’s only named allergy contact: '
            'medicaloperation@dlh.de. Be aware of what it is — an information '
            'desk. Lufthansa’s wording is "if you still have any '
            'questions", and nothing on its site commits it to any action in '
            'response.',
      ),
      RequestStep(
        'READ THIS IF A CHILD OR TEENAGER IS FLYING WITH AN EPIPEN.',
        detail: 'Lufthansa publishes a boarding-eligibility rule, not advice: '
            'children and teenagers who carry an epinephrine auto-injector '
            'may only fly on Lufthansa aircraft if accompanied by someone '
            'familiar with using it. An unaccompanied minor with an EpiPen '
            'can be refused carriage. This is the highest-consequence '
            'sentence on any carrier page in this file and it needs checking '
            'before you book, not at the airport.',
      ),
      RequestStep(
        'Assume you will have to use your own auto-injector.',
        detail: 'Lufthansa states its flight crew cannot administer '
            'medication by means of an epinephrine auto-injector. Travel with '
            'someone who can use yours.',
      ),
      RequestStep(
        'Do not go looking for a nut-free meal. There is not one.',
        detail: 'All eleven Lufthansa special meals are religious, '
            'vegetarian or medical-diet codes — gluten, lactose, low sodium, '
            'low cholesterol, diabetic and so on. None is allergen-targeted. '
            'Secondary sources claiming Lufthansa offers nut-free meals are '
            'wrong. Bring your own food; Lufthansa suggests this itself.',
      ),
      RequestStep(
        'Tell the crew when you board.',
        detail: 'Lufthansa does not publish an announcement policy and '
            'passenger accounts report crews declining, on the grounds that '
            'they cannot tell other passengers what to eat. Ask, but do not '
            'plan around a yes.',
      ),
    ],
    script: 'I have a severe, anaphylactic peanut allergy. I am flying '
        'Lufthansa [flight] on [date], booking reference [code]. I am not '
        'asking you to change the catering — I will bring my own food and I '
        'will not eat anything served on board. I would like the allergy '
        'noted on my booking, and I would like to confirm two things: that '
        'the crew can be told I am carrying an epinephrine auto-injector, and '
        'whether any restriction applies to my booking because of it.',
    gotchas: <String>[
      'MEDIF and the special-assistance information sheet are not an allergy '
          'channel. The IATA form covers stretchers, wheelchairs, escorts, '
          'oxygen and frequent-traveller medical cards; the only place an '
          'allergy fits is a free-text box, and nothing routes it anywhere.',
      'No US-facing allergy or medical number is published, so the Frankfurt '
          'number above is an international call. Email is the practical '
          'route.',
      'Lufthansa does not serve peanuts but will not guarantee that the '
          'aircraft or its catering are free of them, and says the same of '
          'every other allergen.',
      'Nothing documents a link between a Medical Operation Centre email and '
          'anything the crew sees. Assume the crew know nothing until you '
          'tell them.',
      'Lufthansa publishes nothing about whether a Group-operated flight — '
          'Discover, Air Dolomiti, SWISS, Austrian, Brussels — inherits an '
          'allergy notification. Assume it does not and contact them.',
    ],
    lastReviewed: '2026-08',
  ),

  'AF': RequestGuide(
    iata: 'AF',
    primary: ContactMethod.webForm,
    alsoAccepted: <ContactMethod>[
      ContactMethod.email,
      ContactMethod.onboard,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.chat,
      ContactMethod.gate,
    ],
    leadTime: 'No later than 24 hours before the flight. The "order at '
        'booking and at least 48 hours ahead" figure still circulating comes '
        'from an Air France FAQ page that now returns a 404. Kosher is the '
        'only 48-hour exception.',
    formUrl: 'https://wwws.airfrance.us/trip',
    email: 'mail.saphir.medicaldesk@airfrance.fr',
    steps: <RequestStep>[
      RequestStep(
        'Order the allergen-free meal in the booking flow, or afterwards in '
            'My Bookings.',
        detail: 'On flights over about two and a half hours this meal is the '
            'entire accommodation Air France offers. There is no buffer zone, '
            'no cabin announcement and no pre-boarding.',
      ),
      RequestStep(
        'Order it by name. Do NOT order AVML.',
        detail: 'AVML is the IATA code for Asian / Indian Vegetarian Meal — a '
            'spiced vegetarian curry, not an allergen-free tray. Air France '
            'publishes no code for its allergen-free meal, and a passenger '
            'who orders AVML expecting safety gets a meal with no allergen '
            'guarantee whatsoever. Several allergy guides carry this error.',
      ),
      RequestStep(
        'Check your allergen is on the list, because the meal is a fixed '
            'recipe rather than a response to your allergy.',
        detail: 'It excludes gluten grains, shellfish, eggs, fish, peanuts, '
            'soy, milk, nuts (almonds, walnuts, hazelnuts), celery, mustard, '
            'sesame, sulphites above 10 mg/kg, lupin and molluscs. Air France '
            'says outright that if you are allergic to something not on that '
            'list, bring a cold meal with you.',
      ),
      RequestStep(
        'Email the SAPHIR medical desk if you need anything beyond the meal.',
        detail: 'mail.saphir.medicaldesk@airfrance.fr. Note the two '
            'conflicting deadlines Air France publishes for SAPHIR — "at '
            'least 2 working days" on one page and "at least 48 hours" on the '
            'form. Over a weekend those are not the same thing; use the '
            'longer one.',
      ),
      RequestStep(
        'On a partner-operated flight, ring the operating carrier and check '
            'the request arrived.',
        detail: 'Air France is unusually candid here: it says it will '
            'transfer your request to the operating airline and then '
            'recommends you contact that airline to check whether the request '
            'was received. Take the hint.',
      ),
      RequestStep(
        'Tell the crew when you board.',
      ),
    ],
    script: 'I have a severe, anaphylactic peanut and tree nut allergy. I am '
        'travelling on Air France [flight] on [date], booking reference '
        '[code]. Please add the allergen-free meal to my booking — the '
        'allergen-free meal, not the Asian vegetarian meal — and confirm it '
        'is showing. I understand you cannot guarantee the rest of the '
        'service is free of traces, so I will not be eating anything else.',
    gotchas: <String>[
      'The SAPHIR assistance form has no allergy option. Its checkbox list is '
          'deaf or hard of hearing, blind or visually impaired, service dog, '
          'own mobility device, wheelchair, oxygen device, intellectual '
          'disability, and mobility assistance not listed above. There is a '
          'free-text message step, so you can type it, but the form is not '
          'built for this and nothing commits Air France to act on it.',
      'The word "allergy" does not appear on Air France’s passengers '
          'with disabilities page at all.',
      'Everything outside the allergen-free meal is explicitly disclaimed: '
          'Air France states it cannot guarantee the absence of allergen or '
          'peanut traces in any other meal, on board or at the airport.',
      'Allergen labelling is geographically limited — crew provide the lists '
          'only on flights departing Europe and the French overseas '
          'departments.',
      'No US SAPHIR phone number could be verified. The old contact page now '
          'redirects to a contact hub that publishes no number, so nothing is '
          'recorded here rather than guessing one.',
    ],
    lastReviewed: '2026-08',
  ),

  'KL': RequestGuide(
    iata: 'KL',
    primary: ContactMethod.webForm,
    alsoAccepted: <ContactMethod>[
      ContactMethod.socialDm,
      ContactMethod.onboard,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.app,
      ContactMethod.email,
    ],
    leadTime: 'File the assistance form at least 48 hours before your first '
        'flight. Dietary meals close at 24 hours (kosher 48). KLM publishes '
        'no allergy-specific deadline, so treat 48 hours as the operative one '
        'because the allergy has to ride in on the assistance form.',
    formUrl: 'https://www.klm.com/contact/klm-cares',
    steps: <RequestStep>[
      RequestStep(
        'Use the KLM CARES health and assistance request form.',
        detail: 'Contact us → Assistance and accessibility → I would '
            'like to request assistance. This is the only channel that '
            'reaches a KLM team and can be lodged in writing. KLM’s '
            'dietary page tells you to let them know about a peanut allergy '
            'and never says how; this is how.',
      ),
      RequestStep(
        'Put the allergy in the free-text message field at the end.',
        detail: 'The form’s "type of assistance needed" list is hearing, '
            'vision, service dog, own wheelchair, needing a wheelchair, '
            'respiratory difficulties, cognitive impairment, mobility '
            'assistance not listed, and a frequent-traveller medical card. '
            'There is no allergy option. The free-text box is the only way '
            'in.',
      ),
      RequestStep(
        'If you have not ticketed yet, fill the mandatory booking fields with '
            'zeros.',
        detail: 'The form demands a booking code, flight number and flight '
            'date. KLM itself says to enter "000000" if you do not have them '
            'yet.',
      ),
      RequestStep(
        'Say "severe peanut allergy" if that is what you have, because that '
            'is the phrase that triggers the announcement.',
        detail: 'KLM will have the cabin crew announce a severe peanut '
            'allergy to the other passengers. It offers no equivalent for '
            'tree nuts — it says plainly it does not currently offer '
            'alternative meals for tree nut allergies, and almonds are still '
            'served.',
      ),
      RequestStep(
        'Expect the announcement and nothing else.',
        detail: 'KLM attaches a hard limit to the same paragraph: it cannot '
            'deviate from its regular service on board. The nuts stay on the '
            'trolley.',
      ),
      RequestStep(
        'Tell the crew as you board.',
        detail: 'Nothing documents that a free-text note on a CARES form '
            'reaches the manifest. Assume it did not.',
      ),
    ],
    script: 'I would like to notify you of a severe peanut allergy — '
        'anaphylactic — for KLM flight [number] on [date], booking reference '
        '[code]. Please record it on the booking and ask the cabin crew to '
        'make the announcement to other passengers about the peanut allergy. '
        'I understand you cannot change the onboard service, so I will bring '
        'my own food. Could you confirm in writing that this is on the '
        'booking?',
    gotchas: <String>[
      'The dietary-meal page is headed "Food allergies and medical diets" and '
          'the dropdown beneath it offers only low-fat, low-salt, diabetic, '
          'gluten-intolerance, lactose-intolerance and the religious and '
          'vegetarian codes. Nothing allergen-free. The heading promises what '
          'the menu does not deliver.',
      'Allergy has no entry on KLM’s assistance and health hub at all — '
          'it is filed under meals, not assistance — which is why the form '
          'route is not obvious.',
      'KLM meals contain no whole peanuts, ground peanuts or peanut paste, '
          'but are prepared in kitchens that also handle peanuts.',
      'Allergen information is available on all European flights but on '
          'intercontinental flights only when departing Amsterdam.',
      'Dietary meals are intercontinental only, and cover the main meal — not '
          'any further meal or snack on the same flight.',
      'No KLM phone number is recorded here. KLM’s contact hub routes to '
          'topic pages rather than publishing numbers, and every US number in '
          'search results traces back to SEO spam rather than to klm.com.',
    ],
    lastReviewed: '2026-08',
  ),

  'EK': RequestGuide(
    iata: 'EK',
    primary: ContactMethod.onboard,
    alsoAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.phone,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.app,
      ContactMethod.email,
      ContactMethod.chat,
      ContactMethod.gate,
    ],
    leadTime: 'None published, and there is nothing to lodge. The 24-hour '
        'dietary-meal deadline exists but no Emirates meal is allergen-safe, '
        'so it is not an allergy deadline.',
    phone: '+1 800 777 3999',
    phoneLabel: 'Emirates US contact center — general, not an accessibility '
        'or medical line (TTY +1 888 320 1576)',
    formUrl:
        'https://www.emirates.com/us/english/help/forms/special-assistance-and-wellness/',
    steps: <RequestStep>[
      RequestStep(
        'Understand before you start that there is no accommodation to '
            'request.',
        detail: 'Emirates is unusually frank about this: it serves nuts and '
            'foods containing allergens on all its flights, and — its own '
            'words — unless required by applicable law, Emirates will not '
            'make inflight announcements for passengers with allergies. '
            'Asking for a nut hold, a buffer zone or an announcement will be '
            'refused. Planning around a refusal is the whole strategy here.',
      ),
      RequestStep(
        'Bring all your own food, and bring it shelf-stable.',
        detail: 'This is Emirates’ own published recommendation: bring '
            'meals that need no refrigeration, heating or other special '
            'handling on board.',
      ),
      RequestStep(
        'Talk to your doctor and travel with your prescribed medication.',
        detail: 'Also Emirates’ own advice: discuss travel and allergy '
            'action plans with your doctor before you fly, and carry your '
            'prescribed medication including epinephrine auto-injectors.',
      ),
      RequestStep(
        'Notify Emirates anyway, through the special assistance and wellness '
            'form or your local Emirates office.',
        detail: 'Emirates encourages passengers with severe allergies to '
            'inform it in advance so it can "provide guidance and take '
            'reasonable steps, where possible". Read those verbs carefully. '
            'It is a notification channel, not a request channel — but it '
            'costs nothing and it is the only paper trail available.',
      ),
      RequestStep(
        'Wipe your own seat and tell the crew once you are seated.',
        detail: 'Emirates does not publish either of these — they are sensible '
            'additions, not Emirates policy, so do not quote them back as if '
            'they were. The point of telling the crew is not to change the '
            'service; it is so somebody knows where you are sitting and what '
            'is in your bag.',
      ),
      RequestStep(
        'Ignore the special meal menu.',
        detail: 'Every dietary meal is religious or medical, none is '
            'allergen-targeted, and Emirates disclaims all of them: they are '
            'produced in facilities handling a wide range of allergens and no '
            'meal is guaranteed free of allergenic ingredients or traces. '
            'Even the gluten option is branded "gluten-friendly" rather than '
            'gluten-free because the caterers are not dedicated facilities.',
      ),
    ],
    script: 'I am not asking you to change the service — I know Emirates '
        'serves nuts on every flight and I have brought all my own food. I '
        'want you to know that I have a severe, anaphylactic peanut allergy, '
        'I am in seat [seat], and my epinephrine auto-injector is in the seat '
        'pocket in front of me. If I tell you I am reacting, please bring it '
        'to me and treat it as a medical emergency.',
    gotchas: <String>[
      'The special assistance and wellness form is real and submittable, but '
          'it is a generic free-text box with no allergy category — its only '
          'structured guidance concerns service dogs travelling to Dubai.',
      'Emirates points you to "your local Emirates office" for allergy '
          'questions, and that link opens a city picker rather than a direct '
          'contact.',
      'Emirates notes that other passengers may bring their own food aboard, '
          'so traces may be present in the cabin air or on surfaces, and it '
          'will not restrict them.',
      'The number above is the general US contact center. Emirates publishes '
          'no separate allergy or medical line, so expect a general agent '
          'with no allergy field to fill in.',
    ],
    lastReviewed: '2026-08',
  ),

  'QR': RequestGuide(
    iata: 'QR',
    primary: ContactMethod.phone,
    alsoAccepted: <ContactMethod>[
      ContactMethod.email,
      ContactMethod.onboard,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.app,
      ContactMethod.chat,
      ContactMethod.gate,
    ],
    leadTime: 'Declare at the time of reservation. The medical form window is '
        'bounded at both ends — no less than 48 hours and no more than seven '
        'days before departure — and it is per flight, so a multi-sector trip '
        'means submitting again for each sector.',
    formUrl:
        'https://www.qatarairways.com/tradeportal/en/policies/Allergy-Policy.html',
    email: 'medaccc@qatarairways.com.qa',
    steps: <RequestStep>[
      RequestStep(
        'DECLARE THE ALLERGY WHEN YOU BOOK. This is the one carrier where '
            'staying quiet can cost you the flight.',
        detail: 'Qatar Airways states that customers who do not disclose a '
            'severe allergy at the time of reservation and declare it instead '
            'at check-in or on board may be denied boarding on safety '
            'grounds, and that such passengers travel at their own risk with '
            'no obligation on the airline. Everywhere else late disclosure is '
            'merely useless. Here it is dangerous to the booking.',
      ),
      RequestStep(
        'Expect paperwork rather than protection.',
        detail: 'The medical form goes to the reservations team and is '
            'assessed by Qatar Airways’ medical and catering functions '
            'to decide whether you are safe to accept on the flight and '
            'whether appropriate catering can be arranged. The outcome is '
            'permission to fly. It is never a nut-free cabin or a nut-free '
            'meal.',
      ),
      RequestStep(
        'Be ready to sign an indemnity or waiver form.',
        detail: 'Qatar requires it for all allergies, including mild ones, '
            'except on flights to and from the United States. It goes to '
            'medaccc@qatarairways.com.qa at least 48 hours before departure.',
      ),
      RequestStep(
        'Do not expect an announcement. Qatar rules it out in writing.',
        detail: 'Its policy states that no announcement is to be made for a '
            'passenger with an allergy, either at the boarding gate or on '
            'board, and that it will serve nuts and normal meals regardless.',
      ),
      RequestStep(
        'Bring your own food, wipes and mask.',
        detail: 'Qatar’s own advice is to use sanitiser wipes, face '
            'masks and appropriate medication. Own food must need no heating '
            'or refrigeration and should not be strongly scented.',
      ),
      RequestStep(
        'Tell the crew once you are seated so they know who you are.',
      ),
    ],
    script: 'I need to declare a severe, anaphylactic peanut allergy at the '
        'time of reservation, for [flight] on [date]. Please record the '
        'declaration on the booking now and tell me exactly which forms you '
        'need from me — the medical information form and the allergy '
        'indemnity form — and where to send them. I understand Qatar Airways '
        'does not provide nut-free meals or announcements; I am declaring it '
        'so that I am not refused boarding later. Could I have a reference '
        'number for this declaration?',
    gotchas: <String>[
      'The Manage Booking meal dropdown is religious and dietary only. There '
          'is no allergy or nut-free option, and Qatar states plainly that it '
          'does not provide nut-free meals and does not guarantee against '
          'nut cross-contamination anywhere in its network.',
      'A "confirmed" special meal means nothing here — Qatar says it cannot '
          'be guaranteed 100% allergen-free.',
      'The medical form is stated as applying per flight, so it does not '
          'carry across sectors of the same trip.',
      'No phone number is recorded. Qatar directs you to your local Qatar '
          'Airways office rather than publishing a single line, and nothing '
          'verifiable was found. Use the office finder on qatarairways.com '
          'rather than a number from a search result.',
    ],
    lastReviewed: '2026-08',
  ),

  'SQ': RequestGuide(
    iata: 'SQ',
    primary: ContactMethod.phone,
    alsoAccepted: <ContactMethod>[
      ContactMethod.onboard,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.app,
      ContactMethod.chat,
      ContactMethod.email,
    ],
    leadTime: 'At least 48 hours before departure for the nut-free meal, and '
        'it is subject to availability. General special meals close at 24 '
        'hours, but some departure cities have longer cut-offs — around 32 '
        'hours for cities including Bangkok, Jakarta, Denpasar and '
        'Barcelona, and 56 hours for Bengaluru, Mumbai, Kolkata and Delhi. '
        'Take whichever deadline is longer. The "56 hours for NFMLA" figure '
        'in circulation is a misreading: 56 hours is a departure-city rule, '
        'not a meal rule.',
    formUrl:
        'https://www.singaporeair.com/en_UK/us/travel-info/requests/passengers-with-nut-allergy/',
    steps: <RequestStep>[
      RequestStep(
        'Call Singapore Airlines or your travel agent at least 48 hours '
            'ahead. Do not rely on Manage Booking.',
        detail: 'Singapore Airlines describes the nut-free meal only through '
            'a "contact us" instruction, never as a self-service selection, '
            'and the Manage Booking meal flow is framed around religious and '
            'dietary needs. Treat the nut-free meal as call-required.',
      ),
      RequestStep(
        'Ask for NFMLA by name — and ask about MAML too.',
        detail: 'NFMLA is the nut-free meal, excluding peanuts and tree nuts '
            'as ingredients. MAML is the minimal allergen meal and is much '
            'broader: free of gluten, egg, dairy, crustaceans, fish, soy, '
            'peanuts and tree nuts. If your allergies go beyond nuts, MAML is '
            'the one to ask about.',
      ),
      RequestStep(
        'Understand that NFMLA is explicitly non-strict.',
        detail: 'Singapore Airlines states it cannot guarantee its nut-free '
            'meals are free from all traces of nuts, because of environmental '
            'factors including preparation in a shared kitchen. It is a '
            'reduced-risk meal, not a safe meal.',
      ),
      RequestStep(
        'Screen the menu before you fly.',
        detail: 'The digital inflight menu is published about six weeks '
            'ahead. That is a genuinely useful pre-trip screening tool and '
            'almost no other carrier offers it — look up your actual flight '
            'and see what is being served around you.',
      ),
      RequestStep(
        'Assume nuts in the cabin regardless.',
        detail: 'Cashews and almonds are served across all cabin classes, and '
            'signature dishes including satay and nasi lemak contain peanuts. '
            'The meal order changes your tray, not the cabin.',
      ),
      RequestStep(
        'Tell the crew when you board.',
        detail: 'There is no allergy notification separate from the meal '
            'order — the meal is the entire mechanism — so the crew will not '
            'know anything else about you unless you say so.',
      ),
    ],
    script: 'I would like to order a nut-free meal, NFMLA, for Singapore '
        'Airlines flight [number] on [date], booking reference [code]. I have '
        'a severe, anaphylactic peanut and tree nut allergy. Could you also '
        'tell me whether the minimal allergen meal, MAML, is available on '
        'this flight? I understand neither is guaranteed free of traces, so '
        'please also note the allergy on the booking so the crew are aware.',
    gotchas: <String>[
      'There is no allergy flag distinct from the meal order. If the meal '
          'cannot be loaded, nothing is recorded about you at all.',
      'NFMLA is subject to availability, which means a confirmed booking is '
          'not a confirmed meal. Reconfirm at check-in.',
      'Singapore Airlines stopped serving peanuts as a snack after a 2017 '
          'incident, but this did not make it a nut-free carrier — the tree '
          'nuts stayed.',
      'No phone number is recorded here. Singapore Airlines publishes '
          'regional numbers rather than one line, and no allergy or meal line '
          'could be verified. Use the contact page for your region.',
    ],
    lastReviewed: '2026-08',
  ),

  'QF': RequestGuide(
    iata: 'QF',
    primary: ContactMethod.onboard,
    alsoAccepted: <ContactMethod>[
      ContactMethod.webForm,
      ContactMethod.app,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.email,
      ContactMethod.chat,
    ],
    leadTime: 'Dietary meals close 24 hours out, kosher 36 hours, and '
        'cancelling one needs 48 hours. Codeshares operated by LATAM or '
        'Aircalin need at least three days. Qantas publishes no '
        'allergy-notification deadline at all.',
    formUrl: 'https://help.qantas.com/support/s/article/Peanuts-onboard-Qantas-flights',
    steps: <RequestStep>[
      RequestStep(
        'Ask the crew, on the day, for the announcement and for loose nut '
            'snacks to be suspended in your cabin.',
        detail: 'Widely reported as Qantas practice: on request the crew will '
            'announce the allergy and stop serving loose nut snacks in your '
            'cabin of travel. That is broader than a seat buffer. But see the '
            'first gotcha before you count on it.',
      ),
      RequestStep(
        'Re-check your meal after any flight change. Qantas says outright it '
            'will be cancelled.',
        detail: 'Dietary meal requests are attached to each flight sector and '
            'are cancelled if the flight changes — you have to request again. '
            'If you change inside 24 hours (36 for kosher), or take a '
            'confirmed upgrade inside that window, the meal simply will not '
            'be available on the new flight. This is the clearest documented '
            'case anywhere in this file of a request being destroyed by a '
            'rebooking.',
      ),
      RequestStep(
        'If you have been using a religious meal as a nut-free workaround, '
            'stop.',
        detail: 'From 1 October 2024 Qantas removed the nut-free guarantee '
            'from the diabetic (DBML), Jain vegetarian (VJML), kosher (KSML), '
            'Muslim (MOML) and Hindu (HNML) meals. Only the '
            'gluten-intolerant meal (GFML), the fruit platter (FPML) and the '
            'child meal (CHML) are still nut-free. Nobody will tell you your '
            'usual meal stopped being safe.',
      ),
      RequestStep(
        'Note that nut-free does not mean coconut-free.',
        detail: 'Qantas states that coconut is not a tree nut and that its '
            'tree-nut-free meals may therefore contain coconut.',
      ),
      RequestStep(
        'Check whether a dietary meal exists on your flight at all.',
        detail: 'They are unavailable on economy flights under three and a '
            'half hours, on Dash 8 QantasLink services, and on several '
            'international routes.',
      ),
    ],
    script: 'I have a severe, anaphylactic tree nut allergy and I carry an '
        'adrenaline auto-injector. Could you please make an announcement to '
        'the cabin about the allergy, and suspend the serving of loose nut '
        'snacks in this cabin for the flight? I am in seat [seat] and my '
        'auto-injector is in the seat pocket in front of me. I have brought '
        'my own food and will not be eating from the service.',
    gotchas: <String>[
      'ASK, BUT VERIFY: the announcement and loose-nut-suspension wording is '
          'quoted everywhere in allergy journalism, but as of this review it '
          'could not be found on any current qantas.com or help.qantas.com '
          'page. Qantas’s live peanuts article and both its consumer and '
          'travel-agent dietary pages say nothing about announcements. It may '
          'come from Qantas correspondence or a since-revised page. Ask the '
          'crew for it — but do not board assuming it is policy.',
      'The dietary meal dropdown has no allergy option of any kind. It is '
          'medical, religious, vegetarian and child meals only.',
      'Qantas removed peanuts as a bar snack across flights and lounges but '
          'still serves almonds, cashews and macadamias across all cabins, '
          'and warns of trace nut ingredients including peanut oils.',
      'No phone number is recorded here — none could be verified for an '
          'allergy or specific-assistance line.',
    ],
    lastReviewed: '2026-08',
  ),

  'FR': RequestGuide(
    iata: 'FR',
    primary: ContactMethod.onboard,
    alsoAccepted: <ContactMethod>[
      ContactMethod.phone,
      ContactMethod.gate,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.app,
      ContactMethod.webForm,
      ContactMethod.email,
    ],
    leadTime: 'None. The mechanism is reactive: you tell the crew as you '
        'board and the announcement and the halt on nut sales follow. The '
        '48-hour and 12-hour windows on Ryanair’s assistance pages are '
        'for airport mobility assistance and have nothing to do with '
        'allergies.',
    phone: '+353 1 575 7852',
    phoneLabel: 'Ryanair Assisted Travel line, local rate — Mon–Fri '
        '09:00–22:00, Sat 09:00–19:00, Sun 10:00–19:00 CET',
    formUrl:
        'https://help.ryanair.com/hc/en-gb/articles/12894491842577-Can-I-travel-with-a-nut-allergy',
    steps: <RequestStep>[
      RequestStep(
        'Board early and tell the cabin crew at the door.',
        detail: 'Ryanair’s entire published mechanism, in its own words: '
            'customers with nut allergies are asked to inform cabin crew when '
            'boarding, and a public address is then made informing other '
            'customers that no products containing nuts will be sold on '
            'board.',
      ),
      RequestStep(
        'Boarding early is not optional here — it is the whole risk.',
        detail: 'Because the mechanism is reactive, a late boarding or a gate '
            'change can mean the crew are already busy and the announcement '
            'never happens. Being at the door early is what makes this work.',
      ),
      RequestStep(
        'Do not go looking for an allergy option at booking. There is not '
            'one.',
        detail: 'Ryanair’s special assistance list is complete and '
            'closed: WCHR, WCHC, WCHS, BLND, BDGR, BLDP, DPNA, DEAF, SVAN and '
            'OXYG. No allergy code exists, so you cannot declare it at '
            'booking however hard you try.',
      ),
      RequestStep(
        'The chatbot can reach a human, but the human has nowhere to put it.',
        detail: 'Ryanair’s assistant escalates to live agents during '
            'opening hours, and the Assisted Travel line above is a real '
            'staffed number. But with no allergy field in the system, the '
            'outcome still routes back to telling the crew at the door.',
      ),
      RequestStep(
        'Understand what the halt covers.',
        detail: 'Ryanair stops its own sale of nuts and nut-containing '
            'products for the flight. Other passengers are only asked not to '
            'open theirs, and Ryanair states it cannot guarantee a '
            'peanut-free aircraft.',
      ),
    ],
    script: 'Hello — I have a severe, anaphylactic nut allergy. Could you '
        'please make the public address announcement and stop the sale of '
        'nuts and nut products on this flight? I am in seat [seat] and I '
        'carry an adrenaline auto-injector. I boarded early so you would have '
        'time to do this before the cabin fills.',
    gotchas: <String>[
      'The reputation that Ryanair has no phone line is wrong for this '
          'specific case — the Assisted Travel line above is published and '
          'staffed. It just cannot log an allergy, because no allergy field '
          'exists.',
      'Ryanair sells packaged nuts and nut spreads from its inflight menu by '
          'default. Nothing happens unless you ask.',
      'Nothing is ever recorded on the booking, so there is nothing to lose '
          'on a rebooking and nothing to carry to a second sector. Ask again '
          'at every door.',
    ],
    lastReviewed: '2026-08',
  ),

  'U2': RequestGuide(
    iata: 'U2',
    primary: ContactMethod.app,
    alsoAccepted: <ContactMethod>[
      ContactMethod.phone,
      ContactMethod.onboard,
      ContactMethod.webForm,
    ],
    notAccepted: <ContactMethod>[
      ContactMethod.chat,
      ContactMethod.email,
    ],
    leadTime: 'Declare at booking. easyJet’s general special-assistance '
        'window is at least 48 hours before departure, and it commits to '
        '"all reasonable efforts" if you did not ask in advance — but the '
        'pre-boarding wipe-down is granted only "if pre-advised". This is the '
        'one carrier here where asking early demonstrably buys you something '
        'concrete.',
    phone: '+44 800 2606686',
    phoneLabel: 'easyJet Special Assistance, UK — free from landlines, daily '
        '08:00–20:00 (France +33 800 949393, Germany +49 800 0000077, '
        'Italy +39 800 922239, Spain +34 900 801 801)',
    appPath: 'Booking flow → Special Assistance → select the '
        'statement "I have a nut allergy"',
    formUrl:
        'https://www.easyjet.com/en/help/boarding-and-flying/special-assistance/contact-us',
    steps: <RequestStep>[
      RequestStep(
        'When booking, request Special Assistance and tick "I have a nut '
            'allergy".',
        detail: 'easyJet is the only carrier in this file with a genuine, '
            'allergy-specific selectable option. Its own wording: the '
            'information is added to your booking and ground crew and cabin '
            'crew will be aware of your nut allergy.',
      ),
      RequestStep(
        'If you have already booked, call the Special Assistance line.',
        detail: 'easyJet invites you to call to talk through your needs and '
            'options. Whether the nut-allergy statement is self-selectable '
            'inside Manage Bookings is unclear, so phone is the reliable '
            'post-booking route.',
      ),
      RequestStep(
        'Call the Special Assistance number, not the general one.',
        detail: 'The general contact numbers are a sales-charged line — that '
            'page warns a service fee applies to anything you add to your '
            'booking. The Special Assistance numbers are separate and free '
            'from landlines.',
      ),
      RequestStep(
        'Ask to wipe down your seat area at the start of boarding.',
        detail: 'easyJet grants this "if pre-advised", which is the concrete '
            'payoff for having declared it at booking rather than at the '
            'door.',
      ),
      RequestStep(
        'You must still tell the cabin manager when you board.',
        detail: 'easyJet mandates this in the same paragraph as the booking '
            'declaration. The flag is belt-and-braces, never fire-and-forget.',
      ),
      RequestStep(
        'Know what you get: an announcement, a sales halt and a nut-free '
            'onboard range.',
        detail: 'Crew announce and ask other customers not to eat nut '
            'products for the duration of the flight; easyJet stops the sale '
            'of anything containing nut traces; and its onboard eat-and-drink '
            'range is nut free — easyJet withdrew nut products from sale '
            'across its network in 2019. It still says it cannot guarantee a '
            'nut-free aircraft.',
      ),
    ],
    script: 'Hello — I am the passenger in seat [seat] with the nut allergy '
        'declared on the booking. It is a severe, anaphylactic allergy and I '
        'carry an adrenaline auto-injector. Could you please make the '
        'announcement asking other customers not to eat nut products during '
        'the flight? I was also pre-advised for wiping down my seat area at '
        'the start of boarding.',
    gotchas: <String>[
      'The Special Assistance landing page is framed entirely around '
          'disability and reduced mobility, and the allergy content lives in '
          'a collapsed accordion on a different page about medicine and '
          'medical conditions. Passengers reasonably conclude allergy is not '
          'covered and give up.',
      'easyJet crew are trained to recognize anaphylaxis and to administer an '
          'auto-injector, but easyJet states that if you are travelling with '
          'family or friends they will be expected to help you first. Brief '
          'whoever you are travelling with.',
      'What happens to the nut-allergy flag on a rebooking is not documented. '
          'Check the booking again after any change.',
    ],
    lastReviewed: '2026-08',
  ),
};

/// Look up a carrier's request procedure by IATA code.
///
/// Case-insensitive and whitespace-tolerant, matching `policyFor` — the code
/// arrives from a text field the user typed, so `' u2 '` must find easyJet.
///
/// Returns `null` when there is no researched record. Callers should fall back
/// to [kGenericRequestGuide], which is written to be useful on its own — unlike
/// `policyFor`, where a null must never be papered over with a default, a
/// missing *procedure* is exactly the moment someone needs generic advice most.
RequestGuide? guideFor(String iata) {
  final key = iata.trim().toUpperCase();
  if (key.isEmpty) return null;
  return kRequestGuides[key];
}

/// The fallback for a carrier we have no record of.
///
/// This is deliberately the longest and most concrete guide in the file. A
/// carrier nobody has researched is precisely when a passenger has the least to
/// go on, so this must stand alone rather than apologise for the missing
/// record.
const RequestGuide kGenericRequestGuide = RequestGuide(
  iata: '',
  primary: ContactMethod.phone,
  alsoAccepted: <ContactMethod>[
    ContactMethod.webForm,
    ContactMethod.email,
    ContactMethod.gate,
    ContactMethod.onboard,
  ],
  notAccepted: <ContactMethod>[
    ContactMethod.chat,
    ContactMethod.socialDm,
  ],
  leadTime: 'Ask 48 to 72 hours before departure. Earlier than that and the '
      'note often has not been attached to the flight yet; later and most '
      'carriers will only promise a reasonable effort. If the carrier '
      'publishes its own deadline, that one wins.',
  steps: <RequestStep>[
    RequestStep(
      'Find the special assistance or accessibility line, not general '
          'reservations.',
      detail: 'Search the carrier’s own site for "special assistance", '
          '"accessibility", "disability assistance" or "medical desk". '
          'Reservations agents sell tickets and usually have no field in '
          'which to record an allergy. The accessibility team does. Take the '
          'number from the airline’s own website — searching for an '
          'airline "disability line" returns a large volume of fabricated '
          'numbers on spam pages.',
    ),
    RequestStep(
      'Call rather than email, then follow up in writing.',
      detail: 'A phone call gets you a person who can put a note on the '
          'booking today. Email queues are measured in days and often route '
          'to post-travel complaints. Call first for the action, then email '
          'or use the web form for the paper trail.',
    ),
    RequestStep(
      'Name the allergen and the accommodation. Never say "I have '
          'allergies".',
      detail: '"I have a severe, anaphylactic peanut allergy and I am asking '
          'for a buffer zone and to pre-board to wipe my seat" gets a '
          'materially different answer from "I have allergies". Say the '
          'allergen, say the severity, say the specific thing you want.',
    ),
    RequestStep(
      'Use the airline’s own vocabulary.',
      detail: 'The phrases that agents recognize are "buffer zone", '
          '"pre-board to clean my seat area", "special service request", '
          '"special assistance" and "accessibility request". Using their '
          'words gets you routed to the right team; using yours gets you '
          'transferred.',
    ),
    RequestStep(
      'Get a reference or case number, and the agent’s name. Every '
          'time.',
      detail: 'This is the single most important step and the one most often '
          'skipped. Without a reference number you have no way to show at the '
          'gate that the conversation happened, and the airline has no way to '
          'find it either. Ask them to read the note back to you before you '
          'hang up.',
    ),
    RequestStep(
      'Reconfirm at check-in and again at the gate.',
      detail: 'Requests routinely fail to travel with the booking. They get '
          'dropped by a rebooking, a schedule change, an aircraft swap or an '
          'upgrade, and on many carriers they never reach the crew at all. '
          'Assume it has been lost and be pleasantly surprised.',
    ),
    RequestStep(
      'Ask the gate agent to note it on the manifest.',
      detail: 'This is the step that gets the information from the ground to '
          'the aircraft. Ask in those words — put it on the manifest — and '
          'ask them to confirm they have done it.',
    ),
    RequestStep(
      'Tell the cabin crew yourself once you are seated.',
      detail: 'Do not wait for them to have been told. Tell them your '
          'allergen, your seat number and where your auto-injector is. On '
          'many carriers this is the only step that actually creates the '
          'accommodation.',
    ),
    RequestStep(
      'On a codeshare, ask the airline that is flying the aircraft.',
      detail: 'The carrier on your ticket is often not the carrier operating '
          'the flight, and allergy notifications very rarely cross between '
          'them. Several airlines say so explicitly and recommend you check '
          'with the operating carrier yourself.',
    ),
    RequestStep(
      'Log every one of these in this app as you go.',
      detail: 'Who you spoke to, when, what they said, the reference number. '
          'A request nobody recorded is a request that did not happen.',
    ),
  ],
  script: 'Hello — I am calling about a food allergy accommodation for '
      '[flight] on [date], booking reference [code]. I have a severe, '
      'anaphylactic [allergen] allergy. I would like to ask for three things: '
      'that the allergy is recorded on the booking so the crew are told; that '
      '[the allergen] is not served in the seats around me if that is '
      'something you can do; and that I can pre-board to wipe down my seat '
      'area. Could you tell me which of those you are able to do, read back '
      'what you have put on the booking, and give me a reference number and '
      'your name?',
  gotchas: <String>[
    'We have no researched record for this carrier, so nothing here is '
        'specific to them. Treat it as a starting point and confirm '
        'everything with the airline directly.',
    'Assume the carrier will not remove any food from the aircraft and will '
        'not stop other passengers eating what they brought. Almost none do. '
        'Bring all your own food and plan on eating nothing served on board.',
    'Assume no announcement will be made unless the carrier confirms one, and '
        'assume no cabin is nut-free even when the airline says it has '
        'stopped serving nuts.',
    'Ask if the medical kit has epinephrine, whether it is an auto-injector '
        'or a vial, and whether the crew can give it. US airlines must carry '
        'epinephrine, usually as a vial. Other airlines vary, and at least one '
        'says its crew cannot give it at all. Always carry your own.',
    'If you are refused something you believe you are entitled to, ask for '
        'the person whose job is to hear that — a Complaints Resolution '
        'Official in the US, or the accessibility team elsewhere. Asking for '
        'them by name changes the conversation.',
  ],
  lastReviewed: '2026-08',
);

/// A carrier-agnostic tutorial for someone who has never asked before.
///
/// Distinct from [kGenericRequestGuide], which is the fallback record for an
/// unknown airline. This is the teaching material: the method, in order, that
/// works everywhere.
const List<RequestStep> kGeneralRequestTutorial = <RequestStep>[
  RequestStep(
    'Ask as early as you can, and get it in writing wherever the carrier '
        'allows it.',
    detail: 'Book, then ask. Most airlines want 48 to 72 hours; some take it '
        'at booking and some only on the day. A written channel — a web form, '
        'an accessibility email, a chat transcript you save — leaves you '
        'something to point at. A phone call leaves you nothing unless you '
        'write it down yourself.',
  ),
  RequestStep(
    'Name the allergen and the exact accommodation. "I have allergies" is not '
        'a request.',
    detail: 'Compare the two. "I have allergies, is that OK?" invites a shrug. '
        '"I have a severe, anaphylactic peanut allergy. I am asking for a '
        'buffer zone in the rows around me and to pre-board so I can wipe my '
        'seat" is a request an agent can act on and record. Say the allergen. '
        'Say the severity. Say the specific thing you want.',
  ),
  RequestStep(
    'Use the airline’s own vocabulary, not your own.',
    detail: 'The phrases that get you routed correctly are "buffer zone", '
        '"pre-board to clean my seat area", "special assistance", "special '
        'service request" and "accessibility request". If the carrier has a '
        'code — a MEDA service request, a nut-free meal code — use the code. '
        'Speaking their language is the difference between being helped and '
        'being transferred.',
  ),
  RequestStep(
    'Always get a reference or case number, and the agent’s name.',
    detail: 'Do not end the call without both. Ask the agent to read the note '
        'back to you exactly as they typed it, then write down the reference, '
        'their name, and the date and time. This is what turns a conversation '
        'into evidence. Without it, at the gate, it is your word against an '
        'empty screen.',
  ),
  RequestStep(
    'Reconfirm at check-in, and then again at the gate.',
    detail: 'This is not belt-and-braces caution — the request genuinely and '
        'frequently does not travel with the booking. Schedule changes, '
        'aircraft swaps, upgrades and rebookings all drop it, and on several '
        'carriers the request never reaches the crew even on an unchanged '
        'booking. At each point, ask them to confirm they can see it. If they '
        'cannot, make it again.',
  ),
  RequestStep(
    'Ask the gate agent to put it on the manifest.',
    detail: 'The gate is the handover point between the ground staff who took '
        'your request and the crew who have to act on it. Ask in those exact '
        'words — please note it on the manifest — and ask them to confirm '
        'they have. This is the step that most often closes the gap.',
  ),
  RequestStep(
    'Tell the cabin crew yourself, once you are seated.',
    detail: 'Never assume they were told. Find a crew member before the doors '
        'close and give them three things: your allergen, your seat number, '
        'and where your auto-injector is. On several airlines this is not a '
        'backup step — it is the only step that actually creates the '
        'accommodation, and everything you did in advance was preparation for '
        'this thirty-second conversation.',
  ),
  RequestStep(
    'Ask again on the next aircraft.',
    detail: 'A connection means starting over. Even where the note is on your '
        'booking, the accommodation itself is usually created by a specific '
        'crew on a specific flight, so it does not follow you down the jet '
        'bridge.',
  ),
  RequestStep(
    'Log every one of these in this app as you go.',
    detail: 'Who you spoke to, when, through which channel, what they agreed '
        'to, and the reference number. Do it while you are still standing '
        'there — a fortnight later you will not remember whether the agent '
        'said yes or said they would try. A request nobody recorded is a '
        'request that did not happen.',
  ),
];
