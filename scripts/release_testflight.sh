#!/usr/bin/env bash
# release_testflight.sh
# Famlist – TestFlight-Build hochladen: Build-Nummer +1 in allen Targets, optional neue Version, Archiv bauen,
# Nummern im Archiv prüfen, zu App Store Connect hochladen, danach committen.
#
# Aufruf:  scripts/release_testflight.sh              → Build-Nummer +1, Version bleibt
#          scripts/release_testflight.sh 1.1          → Build-Nummer +1 und Version 1.1
#          scripts/release_testflight.sh --dry-run    → alles außer Upload; die Änderung wird danach zurückgenommen
#
# Warum ein Skript: iPhone-App, Uhr-App und Widgets müssen dieselbe Build-Nummer tragen, sonst lehnt App Store
# Connect den Upload ab. Die Nummer im Repo soll immer der Nummer in TestFlight entsprechen; deshalb ist beim
# Export manageAppVersionAndBuildNumber = NO (Xcode würde sonst nur das hochgeladene Paket ändern).
#
# Voraussetzungen: In Xcode angemeldetes Konto des Teams YHSZ8G8RWJ; keine offenen Änderungen an Code und Projekt
# (design-handoff/ und unversionierte Dateien sind erlaubt). Gepusht wird nicht.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$ROOT/Famlist.xcodeproj/project.pbxproj"
TEAM_ID="YHSZ8G8RWJ"
DRY_RUN=0
VERSION=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *)
      [[ "$arg" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]] || { echo "Ungültige Version: $arg (erwartet z. B. 1.1 oder 1.1.2)"; exit 1; }
      VERSION="$arg" ;;
  esac
done

cd "$ROOT"

# Nur ein sauberer Stand wird hochgeladen: Der Build muss einem Commit entsprechen.
if ! git diff --quiet HEAD -- Famlist Famlist.xcodeproj FamlistUITests supabase migrations scripts; then
  echo "Abbruch: offene Änderungen an Code oder Projekt. Bitte erst committen:"
  git status --short -- Famlist Famlist.xcodeproj FamlistUITests supabase migrations scripts
  exit 1
fi

# Aktuelle Build-Nummer: alle Targets müssen gleich sein.
NUMBERS=$(grep -oE 'CURRENT_PROJECT_VERSION = [0-9]+;' "$PBXPROJ" | grep -oE '[0-9]+' | sort -u)
if [[ $(echo "$NUMBERS" | wc -l | tr -d ' ') -ne 1 ]]; then
  echo "Abbruch: Build-Nummern der Targets sind unterschiedlich: $(echo $NUMBERS)"
  exit 1
fi
CURRENT="$NUMBERS"
NEXT=$((CURRENT + 1))
OLD_VERSION=$(grep -oE 'MARKETING_VERSION = [0-9.]+;' "$PBXPROJ" | head -1 | grep -oE '[0-9.]+[0-9]')
NEW_VERSION="${VERSION:-$OLD_VERSION}"

echo "Build-Nummer: $CURRENT → $NEXT · Version: $OLD_VERSION → $NEW_VERSION · Branch: $(git branch --show-current)"

restore_project() { git checkout -- "$PBXPROJ"; }

sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT;/CURRENT_PROJECT_VERSION = $NEXT;/g" "$PBXPROJ"
if [[ -n "$VERSION" ]]; then
  sed -i '' -E "s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = $VERSION;/g" "$PBXPROJ"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/famlist-release.XXXXXX")"
ARCHIVE="$WORK/Famlist.xcarchive"
echo "Arbeitsordner (Logs, Archiv): $WORK"

echo "Archiv wird gebaut …"
if ! xcodebuild archive -project Famlist.xcodeproj -scheme Famlist -configuration Release \
      -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" > "$WORK/archive.log" 2>&1; then
  restore_project
  echo "Abbruch: Archiv fehlgeschlagen. Log: $WORK/archive.log"
  grep -E "error:" "$WORK/archive.log" | sort -u | head -10 || true
  exit 1
fi

# Nummern im Archiv prüfen (iPhone-App und eingebettete Uhr-App).
APP="$ARCHIVE/Products/Applications/Famlist.app"
for plist in "$APP/Info.plist" "$APP/Watch/FamlistWatch.app/Info.plist"; do
  [[ -f "$plist" ]] || continue
  BUILT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist")
  SHORT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
  if [[ "$BUILT" != "$NEXT" || "$SHORT" != "$NEW_VERSION" ]]; then
    restore_project
    echo "Abbruch: $(basename "$(dirname "$plist")") hat $SHORT ($BUILT) statt $NEW_VERSION ($NEXT)."
    exit 1
  fi
  echo "  ✓ $(basename "$(dirname "$plist")"): $SHORT ($BUILT)"
done

if [[ $DRY_RUN -eq 1 ]]; then
  restore_project
  echo "Probelauf: Archiv in Ordnung, nichts hochgeladen, Build-Nummer zurückgesetzt."
  exit 0
fi

cat > "$WORK/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>teamID</key><string>$TEAM_ID</string>
	<key>signingStyle</key><string>automatic</string>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

echo "Upload zu App Store Connect …"
if ! xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$WORK/ExportOptions.plist" \
      -exportPath "$WORK/export" -allowProvisioningUpdates > "$WORK/export.log" 2>&1 \
   || ! grep -q "Upload succeeded" "$WORK/export.log"; then
  restore_project
  echo "Abbruch: Upload fehlgeschlagen, Build-Nummer zurückgesetzt. Log: $WORK/export.log"
  grep -iE "error" "$WORK/export.log" | sort -u | head -10 || true
  exit 1
fi

git add "$PBXPROJ"
git commit -q -m "BUILD(testflight): Build $NEXT (Version $NEW_VERSION) hochgeladen"
echo "Fertig: Version $NEW_VERSION ($NEXT) ist bei App Store Connect; Commit $(git rev-parse --short HEAD) (nicht gepusht)."
