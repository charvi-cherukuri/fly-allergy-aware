#!/usr/bin/env bash
# Archive, export and upload Fly Allergy Safe to TestFlight.
#
#   ./tool/testflight.sh              # auto build number from the timestamp
#   ./tool/testflight.sh 7            # explicit build number
#   ./tool/testflight.sh 7 --no-upload   # archive and export only
#
# Needs, one time only (see TESTFLIGHT.md):
#   - an Apple Distribution certificate in the login keychain
#   - the bundle ID registered and an app record in App Store Connect
#   - an App Store Connect API key at ~/.appstoreconnect/private_keys/
#     plus ASC_KEY_ID and ASC_ISSUER_ID exported in your shell
#
# Every TestFlight upload needs a build number higher than the last one, so the
# default is a UTC timestamp — monotonic, and you never have to remember what
# you shipped last.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
TEAM_ID="4DX8JKBYV3"
SCHEME="Runner"
ARCHIVE="$ROOT/build/ios/archive/Runner.xcarchive"
EXPORT_DIR="$ROOT/build/ios/ipa"

BUILD_NUMBER="${1:-$(date -u +%y%m%d%H%M)}"
[[ "${1:-}" == --* ]] && BUILD_NUMBER="$(date -u +%y%m%d%H%M)"
NO_UPLOAD=false
for a in "$@"; do [[ "$a" == "--no-upload" ]] && NO_UPLOAD=true; done

VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//' | cut -d'+' -f1)"

say() { printf '\n\033[1;36m==>\033[0m %s\n' "$1"; }
die() { printf '\n\033[1;31mx\033[0m %s\n' "$1" >&2; exit 1; }

# The build directory is a symlink to somewhere outside iCloud, because iCloud
# stamps files with com.apple.FinderInfo and codesign refuses to sign those.
# flutter clean deletes it. See README.md.
if [[ ! -e build ]]; then
  say "Recreating the build symlink (flutter clean removes it)"
  mkdir -p ~/Library/Developer/FlyAllergySafeBuild
  ln -s ~/Library/Developer/FlyAllergySafeBuild build
fi

say "Version $VERSION, build $BUILD_NUMBER"

say "Checking for a distribution certificate"
if ! security find-identity -v -p codesigning | grep -q "Apple Distribution"; then
  die "No 'Apple Distribution' certificate in the keychain.
   Xcode > Settings > Accounts > [your Apple ID] > Manage Certificates > + > Apple Distribution.
   See TESTFLIGHT.md."
fi

say "Building the Flutter bundle"
flutter build ios --release --no-codesign \
  --build-name="$VERSION" --build-number="$BUILD_NUMBER"

say "Archiving"
rm -rf "$ARCHIVE"
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  MARKETING_VERSION="$VERSION" \
  archive

say "Exporting the .ipa"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates

IPA="$(find "$EXPORT_DIR" -name '*.ipa' -maxdepth 1 | head -1)"
[[ -n "$IPA" ]] || die "No .ipa produced. Check the export log above."
say "Built $(basename "$IPA") ($(du -h "$IPA" | cut -f1))"

if $NO_UPLOAD; then
  say "Stopping before upload (--no-upload). The .ipa is at:"
  echo "  $IPA"
  exit 0
fi

: "${ASC_KEY_ID:?Set ASC_KEY_ID (App Store Connect API key id). See TESTFLIGHT.md}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (App Store Connect issuer id). See TESTFLIGHT.md}"

say "Validating with App Store Connect"
xcrun altool --validate-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

say "Uploading to TestFlight"
xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

say "Uploaded. Processing usually takes 5-15 minutes."
echo "   App Store Connect > Fly Allergy Safe > TestFlight"
echo "   Build $BUILD_NUMBER will appear there once processing finishes."
