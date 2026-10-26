# Shipping a TestFlight prototype

> **Out of date — read this first.** This walks through the original setup on Shray's
> team (`F5FNHQRTCU`) with bundle ID `com.shraybagga.flyallergysafe`. On 4 October 2026
> the app moved to Ashok's team: it is now **Fly Allergy Aware**, team `4DX8JKBYV3`,
> bundle ID `com.symphonize.flyallergysafe`, and its App Store Connect and TestFlight
> record belong to that team. The team, bundle ID and App Store Connect steps below no
> longer apply as written. `tool/testflight.sh` already uses the new team.

Everything that can be automated is. What's left needs your Apple ID, and I can't
do those steps — they need a password and 2FA.

## Where things stand

| | Status |
|---|---|
| Paid Apple Developer Program on team `F5FNHQRTCU` | ✅ Confirmed — there are existing App Store profiles for RightTrack, SaberJournal and superModel, which only a paid membership gets |
| Bundle ID `com.shraybagga.flyallergysafe` | ✅ Set in the project (was `traceAllergy`, renamed while it was still free to do) |
| App icon, no alpha channel | ✅ Verified RGB — an alpha channel is a silent App Store rejection |
| Export compliance | ✅ `ITSAppUsesNonExemptEncryption = false` — the app only uses HTTPS, which is exempt, so you won't be asked on every upload |
| Release archive | ✅ Verified building end to end |
| `ExportOptions.plist` + upload script | ✅ Written |
| Bundle ID registered on developer.apple.com | ✅ Done — "Fly Allergy Safe" → `com.shraybagga.flyallergysafe`, explicit, no capabilities |
| App record in App Store Connect | ✅ Done — **App ID 6797381645**, iOS, English (U.S.), SKU `flyallergysafe-ios-001`, status "1.0 Prepare for Submission" |
| Privacy manifest | ✅ `ios/Runner/PrivacyInfo.xcprivacy` — no data collected, no tracking, no required-reason APIs. Verified shipping inside the built `.app` |
| **App Store Connect API access** | ⛔ **Blocked on you.** Not yet enabled for the team. The opt-in has an agreement checkbox — I won't accept terms in your name |
| **Apple Distribution certificate** | ❌ Follows from the API key |

**One thing is in your way.** App Store Connect API access has never been turned on for
team `F5FNHQRTCU`. Enabling it means ticking "I agree to use the App Store Connect API
for internal development, testing, and reporting purposes within my team only" — a legal
agreement, so it has to be you.

[appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
→ Request Access → tick the box → Submit. Apple's wording says requests are reviewed, so
it may not be instant.

Once that's through, do step 3. With an API key, `xcodebuild -allowProvisioningUpdates`
creates the distribution certificate for you and you never sign in to Xcode at all —
steps 1 and 2 become unnecessary.

## One-time setup

### 1. Sign in to Xcode

Xcode → Settings → Accounts → **+** → Apple ID. Use the Apple ID that owns team
`F5FNHQRTCU` (a family Apple Developer account — if that account isn't yours,
whoever holds it needs to do these steps or add you as an Admin).

### 2. Create the distribution certificate

Same screen: select the account → **Manage Certificates…** → **+** → **Apple
Distribution**. It installs into your login keychain automatically.

Verify it worked:

```bash
security find-identity -v -p codesigning | grep "Apple Distribution"
```

### ~~3. Register the bundle ID~~ — done

`com.shraybagga.flyallergysafe`, explicit, no capabilities. Nothing to do.

### ~~4. Create the App Store Connect record~~ — done

App ID **6797381645**. "Fly Allergy Safe" was available. If you settle on a different
name later, change it in App Store Connect → App Information — it's only what testers
see and doesn't have to match `CFBundleDisplayName`.

### 3. Create an App Store Connect API key

This is what lets the upload run from the terminal instead of clicking through Xcode.

[appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
→ Team Keys → **+** → name it "CI", access **App Manager** → Generate.

Download the `.p8` **once** — Apple will not let you download it again — and put it
where the tooling looks for it:

```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
```

Then add the key ID and issuer ID (both shown on that page) to your shell profile:

```bash
echo 'export ASC_KEY_ID=XXXXXXXXXX' >> ~/.zshrc
echo 'export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' >> ~/.zshrc
source ~/.zshrc
```

## Every release after that

```bash
./tool/testflight.sh
```

That's the whole thing. It builds, archives, exports, validates and uploads. The
build number defaults to a UTC timestamp, so it always increments — TestFlight
rejects a build number it has seen before, and this is the usual way people get
stuck.

To check the archive without uploading:

```bash
./tool/testflight.sh --no-upload
```

Processing on Apple's side takes 5–15 minutes. The build then shows up under
App Store Connect → your app → TestFlight.

## Internal vs external testers — pick the right one

This is the decision that actually matters for a prototype.

**Internal testing.** Up to 100 people, but each must be added to your App Store
Connect team as a user first. **No review, available within minutes of processing.**
Use this for yourself, family, a teacher, anyone you can be bothered to add as a
team member.

**External testing.** Up to 10,000 people via a public link you can just send. But it
needs **Beta App Review** (usually about a day, sometimes longer for the first
submission) and App Store Connect will ask for:

- a **privacy policy URL** — required, and you don't have one yet
- what to test, and a beta description
- a demo account if anything is behind a login (nothing here is)

For handing a prototype to a handful of people this week, use **internal**. Set up
external only when you want to send a link to people you can't add individually —
and budget a day for the first review.

### Review notes worth writing

Beta App Review reads these. Two things about this app are worth pre-empting, because
both look like problems from the outside:

- The app displays **clinical anaphylaxis guidance including epinephrine dosing**.
  Say plainly that it reproduces standard published first-aid guidance, is labelled
  as general information rather than personalized medical advice, and defers to the
  user's own action plan.
- The demo flights are **clearly labelled sample data**, not live schedules, so nobody
  thinks the app claims a flight data feed it doesn't have.

## Things that will bite you

- **Builds expire after 90 days.** A prototype you handed out in August is dead by
  November unless you upload again.
- **`flutter clean` deletes the `build` symlink**, and without it codesigning fails on
  the iCloud FinderInfo problem described in the README. The script recreates it
  automatically, but if you build by hand, recreate it yourself.
- **The dev build on your phone is now a separate app.** The bundle ID changed from
  `com.shraybagga.traceAllergy`, so the old icon will still be sitting on your home
  screen. Delete it.
- **The on-device AI won't work for every tester.** Apple's Foundation Models needs
  iPhone 15 Pro or newer with Apple Intelligence enabled. Everyone else silently gets
  the built-in template wording, which is by design — but if a tester says "the
  explanation looks basic", that's why.
- **Simulator builds still fail on Apple Silicon** (ML Kit ships no arm64 simulator
  slice). Irrelevant to TestFlight, but don't be surprised.
