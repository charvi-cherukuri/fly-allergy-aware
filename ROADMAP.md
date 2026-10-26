# Parked

## FRD 5.1 — Offline emergency mesh network

**Status: deferred. Not attempted in v1.**

The requirement is to "instantly alert participating cabin crew and registered
medical professionals" over Bluetooth or a local mesh when a user is having
anaphylaxis.

### Why it is parked

The blocker is not the radio. It is that **there are no participating cabin crew.**
No airline has integrated with this app, no crew member is running it, and no
medical professional is registered. A mesh network with no other nodes alerts
nobody. Shipping it would mean shipping a button that looks like it summons help
and does nothing — the worst possible failure mode in an emergency feature.

The secondary blockers are real but solvable, and only matter once the first one is:

- **iOS restricts background BLE advertising.** A backgrounded app can advertise
  only in a stripped "overflow" area that other iOS devices can see but which
  carries no service UUID in the usual way. Reliable alerting would need the app
  foregrounded on both devices.
- **There is no iOS mesh primitive.** `MultipeerConnectivity` gives peer-to-peer
  over Bluetooth/Wi-Fi but is single-hop and caps out around 8 peers. True
  multi-hop relay across a 200-seat cabin would have to be built from scratch.
- **Aircraft are a hostile RF environment**, and cabin crew are required to ask
  passengers to keep devices in airplane mode, which many read as Bluetooth off.

### What would make it real

In rough order of difficulty:

1. An airline pilot programme — a single carrier willing to run the crew side on
   crew devices. Without this the feature is theatre.
2. Foreground-only peer alerting between passenger devices, honestly labelled as
   "alerts other app users nearby", not "alerts the crew".
3. A registered-clinician flow with actual verification, which is a credentialing
   problem, not an engineering one.

### What ships instead in v1

The emergency screen already covers the parts that work with no network and no
other participants:

- the FAA-required emergency medical kit location by aircraft family, with the
  instruction to ask a flight attendant (see FRD 5.2);
- step-by-step clinical guidance for a companion or volunteering clinician,
  offline, with correct IM epinephrine dosing (see FRD 5.3);
- the passenger's own auto-injector inventory, locations and expiry;
- emergency contacts and the stored action plan.

That is the honest version of "offline emergency coordination": everything that
does not depend on a counterparty who does not exist yet.

## Parked: replacing Google ML Kit with Apple frameworks

**Decided 27 September 2026: keep ML Kit and declare its data collection** (see BETA.md,
App Privacy). Recorded here because it is the only route to "Data Not Collected".

ML Kit sends Google diagnostic data by default and has no supported off switch. Both
ML Kit plugins pull in the same telemetry library, so removing one changes nothing; only
removing both does. The replacement, researched and checked the same day:

- **Label reading → Apple Vision** (`VNRecognizeTextRequest`, iOS 13+). Small: about 15
  lines of Dart and a 60–80 line Swift channel, since `ocr_screen.dart` reads only
  `result.text`. Works on the arm64 simulator. Reads more scripts than the Latin-only ML
  Kit recognizer used now — but Hindi only from iOS 27. Use the accurate level; pass
  recognition languages explicitly, Chinese first when mixed with English.
- **Translation → Apple Translation** (programmatic from iOS 18; gate with `#available`
  as `FoundationModelsBridge.swift` already does, no need to raise the deployment
  target). All seven priority languages are supported, but the list drops from 39 to 19
  (25 on Apple Intelligence phones). Downloads go through Apple's own prompt: no
  Wi-Fi-only switch, no delete. Does not translate in the simulator.
- **The risk:** on iOS 18, and for any download, a `TranslationSession` comes only from
  SwiftUI's `.translationTask`, so it needs a hidden `UIHostingController` over the
  Flutter view that stays mounted while translating. Not known to have been done in
  Flutter. Build and prove this first if the swap is ever picked up.
- **Result:** nothing sent to Google, 18 of 20 pods removed, about 48 MB smaller. Not
  literally zero: Apple's Translation "may collect API usage and performance metrics
  including the app bundle ID" and the language pair, and barcode lookups still go to
  Open Food Facts.

