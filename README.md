# Fly Allergy Safe

An offline-first platform for travelling with severe food allergies: a trip journal for
exposures, reactions and incidents, airline accountability, an emergency mode that knows
where you are, voice input, on-device label analysis, and guidance that works with no
signal at all.

Built in Flutter/Dart. Evolved from **Trace**, a grocery scanner whose allergen matching
engine is still the core of this app.

## The rule everything follows

**An app that doesn't work when you need it is worth zero.**

You need this at 38,000 feet, in a jet bridge, in a country whose language you don't read.
So there is no backend, no account, no login, no paywall, and no network call on any
safety-critical path. Airline policies, aircraft data and allergen tables are compiled
into the binary. The language model runs on the phone. Every screen works in airplane mode.

A phone still gets handed around, so by default — after setup, on any iPhone with a passcode — the app opens behind the iPhone's own unlock —
Face ID, with the system passcode sheet behind it. The app stores your on/off choice and never
sees a secret: nothing to forget with no way to reset, nothing to brute-force, nothing to
half-write and brick the app with. That lock is on the app, not on the file it keeps, and
the copy never claims otherwise.

## What it does

| FRD | Feature | Where |
|---|---|---|
| 1.1 | Custom allergens beyond the regulated fourteen — alpha-gal, corn, seeds — with 10 curated starter vocabularies | `custom_allergens_screen.dart` |
| 1.2 | Profiles are editable at any time, per-allergen severity | `profile_screen.dart` |
| 1.3 | Stored anaphylaxis action plan, shown first in an emergency | `emergency_screen.dart` |
| 2.1 | **Trip journal** — trips with their flights, travelers and destination; a timeline of everything logged; a shareable trip report | `trip_detail_screen.dart`, `trip_journal.dart` |
| 2.2 | Dated accommodation request log with airline reference numbers | `accommodations_screen.dart` |
| 2.2 | **How to actually ask** — per-carrier request procedure for all 20 airlines, plus a general tutorial | `request_guides.dart` |
| 2.3 | Compiled incident reports for the airline or US DOT | `incident_composer.dart` |
| 3.1 | Allergen exposure log — who, what, how, where (flight row or a named place), what was done, and whether symptoms followed, linked to the reaction | `exposure_edit_screen.dart` |
| 3.1 | "Show to crew" card per flight — allergy, seat, what the airline confirmed, where the epinephrine is | `crew_card_screen.dart` |
| 3.2 | Pre-boarding request workflow and seat wipe-down log | `seat_cleaning_screen.dart` |
| 4.1 | ML Kit OCR of airport food labels | `ocr_screen.dart` |
| 5.2 | Emergency medical kit location by aircraft family | `emk_locations.dart` |
| 5.4 | **Emergency mode** — epinephrine dose timer, the local ambulance number, a crew alert on a plane, prefilled texts, a record kept as it happens, and a handover summary for paramedics | `emergency_mode_screen.dart` |
| 5.5 | **Voice input**, on-device only — trips, exposures, reactions, incidents and emergency commands; "Hey Siri, Fly Allergy Aware emergency" | `speech.dart`, `voice_parser.dart`, `SpeechBridge.swift` |
| 5.3 | Offline step-by-step anaphylaxis guidance | `clinical_guidance_screen.dart` |
| 6.1 | Emergency phrases in 12 languages — what to say when a reaction starts somewhere you don't speak the language | `emergency_phrases.dart` |
| 6.1 | Offline translator, 39 downloadable languages — read a foreign menu or ingredient list with no connection | `translator.dart` |
| 6.1 | Language packs suggested from the destination and each airline's crew languages — never downloaded without a tap | `language_suggestions.dart` |
| 2.4 | **At the airport and on board** — what to ask at check-in, before boarding, boarding and during the flight, with the words to say and one-tap logging; five prevention tips with reasons | `day_of_travel.dart`, `safety_copy.dart` |
| 5.6 | Medical kits on planes — vials are the norm; airlines reported to carry auto-injectors, each with a source | `medical_kits_screen.dart`, `docs/SOURCES.md` |
| 3.3 | "Please don't feed my child" card — editable, short version, full screen | `child_card_screen.dart` |
| 2.5 | Record your flight experience — food information, staff help, medication on board, ideas for next time | `flight_experience_screen.dart` |
| 5.1 | **Parked** — see `ROADMAP.md` | — |

Carried over from Trace: barcode scanning with a four-tier verdict, offline product cache,
scan history and safe list, chef cards in 12 languages, reaction log, auto-injector expiry
tracking with reminders.

## Four tabs

**Travel** (your trips, with emergency mode on the one you are on) · **Scan** · **Emergency**
· **Profile**.

A phone holds four tabs before the labels stop being read. Travel is a journal: each trip
holds its flights, the requests made to the airline, and every exposure, reaction and
incident along the way, and the trip you are on carries the button into emergency mode.
Emergency keeps a fixed position so it can be found without reading the labels, which is
the only state that matters when someone opens it during a reaction.

One language setting, set once per trip, drives every hand-written translated surface: the
chef card, the emergency phrases and the allergen names on a scan result. Separately, the
**translator** handles everything nobody could write in advance — a menu, a label, what a
flight attendant just said — in 39 languages, from packs downloaded before you fly. Emergency contacts can be
called or texted; the message is prefilled and opened in Messages, and the user presses
send.

## The two architectural decisions that matter

### A translation can raise an alarm. It can never clear a label.

The on-device translator reads foreign labels, and translated text can be run through the
allergen check. That check is capped: it can return "do not eat" or "cross-contact risk",
and it can never return "no match found". Google documents these models as intended for
casual translation, and any pair that is not English-to-something pivots through English —
so a word the translator drops is a word the matcher never sees, and a word it never sees
reads as an absence. Absence is the one thing this app will not infer from a weaker source.
`AllergenMatcher` enforces the cap, not the UI.

Language packs are about 30 MB each, downloaded on request over Wi-Fi, and work with no
connection afterwards. Nothing downloads on its own: a traveler on a roaming plan decides.

### Rules decide. AI never does.

`AllergenMatcher` — 684 terms across 14 allergens (597 that declare the allergen, 87 that
only hint), 45 exclusions, 37 precautionary phrases, word-boundary matched, exclusion pass
first — makes every safety call deterministically. No AI model is involved in a verdict.

This is not caution for its own sake. Nosher, a competitor that reads labels with AI, has
App Store reviews documenting it scanning three animal products clean for an alpha-gal
user, and flagging "not a significant source of fiber" as gluten. A generative model is
the wrong instrument for a yes/no safety question. Apple's on-device model is used only to
fill in forms from what a traveler says, and every value it returns is checked against
what the form allows.

### The journal records. It does not predict.

An earlier version scored flights 0–100 from published airline policies. Those policies
are vague, change without notice and are applied differently by every crew, so the number
read as more certain than anything behind it. It was removed. What a traveler can rely on
is what they asked for, what happened, and what they did about it — so that is what the
Travel tab keeps, with the airline's own request procedure one tap away.

### Voice is on-device, or not offered.

Speech recognition runs with `requiresOnDeviceRecognition`. On a phone or language that
cannot do that, the microphone is hidden rather than sending audio to a server. Built-in
English rules turn speech into form fields on every phone; on Apple Intelligence phones
the on-device model fills only what the rules left empty, and every value is checked
against what the form allows. Voice never saves anything — it fills a form the user
reads. In emergency mode, anything that is not clearly a command becomes a note, and a
call always needs "yes, call" or a tap.

## Honest limits, stated in the app itself

- **The emergency number table is curated.** It lists the ambulance number for the
  countries where that number is well established. Anywhere else the app offers 112 and
  says it is a fallback. Review `countries.dart` before each release.
- **Voice rules understand English.** On other languages only the on-device model can
  help, and on phones without it the form is filled by hand.
- **EMK location is curated guidance, not a map pin.** No public database maps medical
  kit stowage per tail number. The app gives per-aircraft-family guidance and tells you
  the definitive answer is to ask a flight attendant.
- **Everything stays on one phone.** With no backend, a family travelling together sees
  only what was logged on the phone in hand.
- **Airline policies change without notice.** Every record carries a `lastReviewed` date
  and the app tells you to confirm with the carrier.
- **Phone numbers are shown only when verified on the carrier's own site.** Six of the
  twenty had no number we could confirm, so the app shows the contact page instead of a
  number. Searching for airline disability lines surfaces SEO-spam PDFs on hijacked
  domains carrying fabricated numbers; a wrong number in a safety context is worse than
  no number at all.
- **Antihistamines are demoted, deliberately.** They appear only after epinephrine, in a
  visually separated block, with an explicit warning that they do not treat anaphylaxis
  and must never delay it. Reaching for diphenhydramine instead of epinephrine is a
  recognized contributor to fatal outcomes.

## Build

```bash
flutter pub get && flutter run --release -d <your-iphone>
```

Or open `ios/Runner.xcworkspace` — **the workspace, not the `.xcodeproj`**.

Flutter 3.38+, iOS 15.5+ (ML Kit floor), Xcode 26+. The on-device model needs iOS 26+ and
an Apple Intelligence device; everything else runs anywhere.

### Three environment quirks

**`build/` is a symlink, on purpose.** This project lives under `~/Desktop`, which iCloud
Drive syncs, and iCloud stamps files with `com.apple.FinderInfo`. `codesign` refuses to
sign anything carrying it — surfaced only as the useless `Command CodeSign failed`. A
build phase that strips the attribute loses a race with iCloud's daemon, so `build/`
symlinks to `~/Library/Developer/FlyAllergySafeBuild`, which is not synced. **`flutter
clean` deletes the symlink** — recreate it with:

```bash
rm -rf build && ln -s ~/Library/Developer/FlyAllergySafeBuild build
```

The Podfile `post_install` xattr patch and the "Strip iCloud xattrs before signing" build
phase are both still in place as belt and braces.

**Simulator builds fail on Apple Silicon.** ML Kit ships no arm64 simulator slice, and
the Podfile's `post_install` therefore forces `EXCLUDED_ARCHS = arm64` for the simulator.
Flutter reads that back off the pod targets and writes it into `Generated.xcconfig`, so
the whole app builds x86_64 — which an iOS 26+ simulator refuses to install ("needs to be
updated by the developer"). Test on hardware. To drive the UI in a simulator anyway, work
in a throwaway copy of the project: drop `google_mlkit_text_recognition` and
`flutter_local_notifications` from the pubspec, stub `ocr_screen.dart` and
`notifications.dart`, and delete that `EXCLUDED_ARCHS` line. Never do this in the real
project.

**CocoaPods needs a UTF-8 locale.** `LANG=en_US.UTF-8 pod install`, or it dies inside its
own error reporter.

## Layout

```
lib/
  models/     allergen, custom_allergen, profile, product, verdict, scan_record,
              emergency, flight, travel, trip
  data/       allergen keywords, PAL phrases, airline policies and crew languages,
              countries and emergency numbers, EMK locations, chef card
              translations, emergency phrases, translator languages
  services/   matcher, incident_composer, trip_journal, emergency_actions,
              emergency_summary, language_suggestions, speech, voice_parser,
              voice_fill, on_device_ai, food_api, database, app_state, app_lock,
              handoff, translator, notifications
  screens/    35 screens
  widgets/    language_picker, country_picker, trip_card,
              trip_actions, language_suggestion_card, voice_input, travel_format
ios/Runner/   FoundationModelsBridge.swift, SpeechBridge.swift, EmergencyIntent.swift
test/         205 tests (matcher, travel journal and the v5 upgrade, voice rules,
              app lock, device auth, translations, translator)
```

`CONTRACT.md` is the internal API contract. `PLAN.md` has the original market research.
`ROADMAP.md` explains what was parked and why.

## Data and attribution

Open Food Facts (ODbL, attribution shipped in-app) and USDA FoodData Central (public
domain) for products. Airline policies are researched snapshots from carrier pages,
cited per record.

## Safety

This app assists. It does not replace reading the label, asking the crew, or following
your allergist's plan. The clinical guidance is general first-aid information reflecting
standard published anaphylaxis guidance — not personalized medical advice. Where it
differs from your own action plan or ground-based medical direction, follow theirs.
