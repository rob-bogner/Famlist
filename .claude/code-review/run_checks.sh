#!/usr/bin/env bash
# Sammelt die Fakten für den Code-Review. Bewertet nichts.
#
#   .claude/code-review/run_checks.sh [--since <commit>] [--out <ordner>]
#
# Läuft unter Linux (Cloud, ohne Xcode) und macOS. Auf einem Mac mit
# installiertem Periphery kommt zusätzlich ein exakter Tot-Code-Report dazu.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
OUT=".code-review-out"
SINCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *) echo "Unbekannte Option: $1" >&2; exit 2 ;;
  esac
done
mkdir -p "$OUT"
HERE=".claude/code-review"
SOURCES="Famlist FamlistWatch FamlistWatchWidgets"
STATUS="$OUT/status.txt"
: > "$STATUS"
note() { echo "$1" | tee -a "$STATUS"; }

# --- 1. Geänderte Dateien seit dem letzten Review ---------------------------
if [ -n "$SINCE" ] && git cat-file -e "$SINCE^{commit}" 2>/dev/null; then
  git diff --name-only --diff-filter=AMR "$SINCE" HEAD -- '*.swift' > "$OUT/changed_files.txt"
  git diff "$SINCE" HEAD -- '*.swift' > "$OUT/changes.diff"
  git log --oneline "$SINCE"..HEAD > "$OUT/commits.txt"
  note "diff: ok ($(wc -l < "$OUT/changed_files.txt" | tr -d ' ') geänderte Swift-Dateien seit $SINCE)"
else
  : > "$OUT/changed_files.txt"
  note "diff: kein gültiger Basis-Commit – Vollständiger Lauf"
fi

# --- 2. SwiftLint ------------------------------------------------------------
SWIFTLINT="$(command -v swiftlint || true)"
if [ -z "$SWIFTLINT" ] && [ "$(uname -s)" = "Linux" ]; then
  TOOLS="${CODE_REVIEW_TOOLS:-$HOME/.cache/famlist-code-review}"
  if [ ! -x "$TOOLS/swiftlint-static" ]; then
    mkdir -p "$TOOLS"
    curl -fsSL -o "$TOOLS/swiftlint.zip" \
      "https://github.com/realm/SwiftLint/releases/latest/download/swiftlint_linux_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').zip" \
      && unzip -o -q "$TOOLS/swiftlint.zip" -d "$TOOLS"
  fi
  [ -x "$TOOLS/swiftlint-static" ] && SWIFTLINT="$TOOLS/swiftlint-static"
fi
if [ -n "$SWIFTLINT" ]; then
  "$SWIFTLINT" lint --quiet --reporter json > "$OUT/swiftlint.json" 2> "$OUT/swiftlint.err"
  note "swiftlint: ok ($("$SWIFTLINT" version))"
else
  note "swiftlint: FEHLT – nicht installiert und Download fehlgeschlagen"
fi

# --- 3. Doppelter Code -------------------------------------------------------
if command -v npx >/dev/null; then
  # shellcheck disable=SC2086
  if npx --yes jscpd@4 $SOURCES --format swift --min-lines 12 --min-tokens 90 \
      --ignore "**/*Tests/**,**/*UITests/**" --reporters json \
      --output "$OUT/jscpd" --silent > "$OUT/jscpd.log" 2>&1 \
      && [ -f "$OUT/jscpd/jscpd-report.json" ]; then
    mv "$OUT/jscpd/jscpd-report.json" "$OUT/duplicates.json" && rmdir "$OUT/jscpd" 2>/dev/null
    note "duplikate: ok"
  else
    note "duplikate: FEHLER – siehe jscpd.log"
  fi
else
  note "duplikate: FEHLT – npx nicht vorhanden"
fi

# --- 4. Toter Code -----------------------------------------------------------
if python3 "$HERE/dead_code_candidates.py" "$ROOT" > "$OUT/dead_code_candidates.json"; then
  note "tot-code-kandidaten: ok (Heuristik, jeden Treffer gegenprüfen)"
else
  note "tot-code-kandidaten: FEHLER"
fi
if command -v periphery >/dev/null && [ "$(uname -s)" = "Darwin" ]; then
  if periphery scan --project Famlist.xcodeproj --schemes Famlist \
      --format json --quiet > "$OUT/periphery.json" 2> "$OUT/periphery.err"; then
    note "periphery: ok (exakt, hat Vorrang vor der Heuristik)"
  else
    note "periphery: FEHLER – siehe periphery.err"
  fi
else
  note "periphery: nicht verfügbar (braucht Mac mit Xcode)"
fi

# --- 5. Einfache Kennzahlen und Regel-Treffer --------------------------------
{
  echo "## Größte Dateien (Zeilen)"
  # shellcheck disable=SC2086
  find $SOURCES -name '*.swift' -not -path '*Tests*' -print0 | xargs -0 wc -l \
    | sort -rn | grep -v ' total$' | head -15
  echo
  echo "## import Supabase außerhalb der erlaubten Ordner"
  grep -rln '^import Supabase' --include='*.swift' Famlist \
    | grep -Ev '^Famlist/(App|Core/Networking|Core/Sync|Repositories/Implementations|FamlistTests)/' || echo "(keine)"
  echo
  echo "## print( im Produktivcode"
  # shellcheck disable=SC2086
  grep -rnE '^\s*print\(' --include='*.swift' $SOURCES | grep -v Tests \
    | grep -Ev '/Core/Utils/(Logger|UserLogger)\.swift:' || echo "(keine)"
  echo
  echo "## SF Symbols (systemName:)"
  # shellcheck disable=SC2086
  grep -rn 'systemName:' --include='*.swift' $SOURCES | grep -v Tests || echo "(keine)"
  echo
  echo "## Apple-Systemdialoge (Treffer hinter #if DEBUG sind erlaubt – nachlesen)"
  # shellcheck disable=SC2086
  grep -rnE '\.(alert|confirmationDialog|actionSheet)\(' --include='*.swift' $SOURCES | grep -v Tests || echo "(keine)"
  echo
  echo "## TODO / FIXME / HACK"
  # shellcheck disable=SC2086
  grep -rnE '\b(TODO|FIXME|HACK)\b' --include='*.swift' $SOURCES || echo "(keine)"
  echo
  echo "## Neue ObservableObject-Nutzung in geänderten Dateien"
  if [ -s "$OUT/changes.diff" ]; then
    grep -nE '^\+.*\b(ObservableObject|@Published|@StateObject|@ObservedObject)\b' "$OUT/changes.diff" || echo "(keine)"
  else
    echo "(kein Diff)"
  fi
} > "$OUT/metrics.md"
note "kennzahlen: ok"

echo "HEAD=$(git rev-parse HEAD)" >> "$STATUS"
echo "Fertig. Ergebnisse in $OUT/"
