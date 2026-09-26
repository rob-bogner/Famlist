#!/bin/zsh
# watch_design_shots.sh
# Famlist – Pixelvergleich der Watch-Screens: baut die Uhr-App, fotografiert jeden Screen im
# 46-mm-Simulator (208 × 248 pt, @2x) und rendert die zugehörige Watch*.dc.html daneben.
#
# Aufruf:  zsh scripts/watch_design_shots.sh <Ausgabeordner> [Simulator-ID]
# Ergebnis: <Ordner>/<screen>.png (Simulator) und <Ordner>/<screen>-ref.png (Design)

set -euo pipefail
OUT=${1:?Ausgabeordner fehlt}
SIM=${2:-1766A235-DEB5-4D91-99BB-91A79EE51899}   # Apple Watch Series 11 (46mm)
ROOT=${0:A:h:h}
SIMCTL=/Applications/Xcode.app/Contents/Developer/usr/bin/simctl
DD=$OUT/dd
mkdir -p $OUT

xcodebuild build -project $ROOT/Famlist.xcodeproj -scheme FamlistWatch \
  -destination "platform=watchOS Simulator,id=$SIM" -derivedDataPath $DD -quiet
$SIMCTL boot $SIM 2>/dev/null || true
$SIMCTL install $SIM $DD/Build/Products/Debug-watchsimulator/FamlistWatch.app

typeset -A REF=(list WatchList item WatchItem add WatchAdd done WatchDone lists WatchLists)
for screen in list item add done lists; do
  $SIMCTL terminate $SIM com.roxo.famlist.watchkitapp 2>/dev/null || true
  $SIMCTL launch $SIM com.roxo.famlist.watchkitapp -watchDesignScreen $screen >/dev/null
  sleep 3
  $SIMCTL io $SIM screenshot $OUT/$screen.png >/dev/null 2>&1
  node $ROOT/scripts/render_dc.mjs $ROOT/design-handoff/Design/html/${REF[$screen]}.dc.html $OUT/$screen-ref.png >/dev/null
  echo "$screen: $OUT/$screen.png ↔ $OUT/$screen-ref.png"
done
