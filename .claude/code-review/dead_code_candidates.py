#!/usr/bin/env python3
"""Tot-Code-KANDIDATEN für Famlist, ohne Xcode-Build.

Zählt für jede Deklaration (Typ, Funktion, Property, Enum-Case), wie oft der
Name im gesamten Swift-Code vorkommt. Kommt er nur in seiner eigenen
Deklaration vor, ist er ein Kandidat.

Das ist eine Heuristik auf Namensebene, kein Compiler-Wissen:
- Falsch-positiv möglich bei Aufrufen über Strings, Selektoren, Codable,
  Protokoll-Konformität, SwiftUI-/SwiftData-Makros, App Intents, Widgets.
- Falsch-negativ, sobald irgendwo ein gleichnamiges Symbol existiert.
- `own_file_only`: Typen, die nur in ihrer eigenen Datei vorkommen. Das sind
  oft Views, die nur noch ihre #Preview aufruft – aber auch der App-Einstieg
  oder Typen, die das System über ihren Namen findet.
Jeder Treffer muss vor dem Melden von Hand geprüft werden.

Aufruf: dead_code_candidates.py <repo-root> > dead_code_candidates.json
"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
SOURCE_DIRS = ["Famlist", "FamlistWatch", "FamlistWatchWidgets",
               "FamlistWatchTests", "FamlistUITests"]
TEST_MARKERS = ("Tests/", "UITests/")

COMMENT_RE = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)
STRING_RE = re.compile(r'"""(?:.|\n)*?"""|"(?:\\.|[^"\\\n])*"')
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
DECL_RE = re.compile(
    r"^(?P<prefix>[ \t]*(?:@[\w.]+(?:\([^)]*\))?[ \t\n]*)*"
    r"(?:(?:public|internal|fileprivate|private|open|final|static|class|"
    r"nonisolated|mutating|lazy|weak|unowned|override|indirect|convenience|"
    r"required|dynamic|isolated)(?:\([^)]*\))?[ \t]+)*)"
    r"(?P<kind>func|var|let|class|struct|enum|protocol|actor|typealias|case)"
    r"[ \t]+(?P<name>`?[A-Za-z_][A-Za-z0-9_]*`?)",
    re.M,
)

# Namen, die das Framework aufruft und die deshalb nie "ungenutzt" sind.
FRAMEWORK_NAMES = {
    "body", "main", "init", "deinit", "id", "hash", "description",
    "debugDescription", "errorDescription", "localizedDescription",
    "encode", "decode", "CodingKeys", "previews", "makeBody", "makeUIView",
    "updateUIView", "makeUIViewController", "updateUIViewController",
    "makeCoordinator", "placeholder", "snapshot", "timeline", "getSnapshot",
    "getTimeline", "perform", "title", "openAppWhenRun", "parameterSummary",
    "typeDisplayRepresentation", "displayRepresentation", "defaultValue",
    "reduce", "sizeThatFits", "placeSubviews", "path", "animatableData",
    "setUp", "tearDown", "setUpWithError", "tearDownWithError",
    "schemaEntities", "versionIdentifier", "models", "stages", "schemas",
    "allCases", "rawValue", "wrappedValue", "projectedValue", "subscript",
    "application", "scene", "userNotificationCenter", "session",
    # DropDelegate / Transferable / Layout – werden von SwiftUI aufgerufen
    "dropEntered", "dropUpdated", "dropExited", "performDrop", "validateDrop",
    "transferRepresentation", "explicitAlignment", "makeCache", "updateCache",
    # Delegate-Methoden (Kamera, Foto-Auswahl, WatchConnectivity)
    "photoOutput", "captureOutput", "imagePickerController",
    "imagePickerControllerDidCancel", "picker", "sessionDidDeactivate",
    "sessionDidBecomeInactive", "sessionReachabilityDidChange",
    "applicationDidFinishLaunching", "applicationDidBecomeActive",
}
SKIP_ATTRS = ("@objc", "@IBAction", "@IBOutlet", "@main", "@Test", "@Suite",
              "@Model", "@AppStorage", "@Environment", "@Parameter",
              "@NSManaged", "@UIApplicationDelegateAdaptor",
              "@WKApplicationDelegateAdaptor")


def strip(text, keep_strings=False):
    text = COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    if not keep_strings:
        text = STRING_RE.sub(lambda m: '""' + "\n" * m.group(0).count("\n"), text)
    return text


def main():
    files = []
    for d in SOURCE_DIRS:
        files += sorted((ROOT / d).rglob("*.swift")) if (ROOT / d).exists() else []

    prod_refs, test_refs = Counter(), Counter()
    refs_by_file = defaultdict(Counter)
    decls = defaultdict(list)

    for f in files:
        rel = f.relative_to(ROOT).as_posix()
        is_test = any(m in rel for m in TEST_MARKERS)
        code = strip(f.read_text(encoding="utf-8", errors="replace"))
        idents = IDENT_RE.findall(code)
        (test_refs if is_test else prod_refs).update(idents)
        if is_test:
            continue
        refs_by_file[rel].update(idents)
        for m in DECL_RE.finditer(code):
            name = m.group("name").strip("`")
            prefix, kind = m.group("prefix"), m.group("kind")
            if name in FRAMEWORK_NAMES or name.startswith("_"):
                continue
            if "override" in prefix or any(a in prefix for a in SKIP_ATTRS):
                continue
            if kind == "case" and not re.match(r"[a-z]", name):
                continue
            indent = len(prefix) - len(prefix.lstrip(" \t"))
            modifiers = prefix.strip()
            # Lokale Variablen in Funktionen sind kein Tot-Code-Thema.
            if kind in ("let", "var") and indent >= 8 and not modifiers:
                continue
            line = code.count("\n", 0, m.start("kind")) + 1
            decls[name].append({"file": rel, "line": line, "kind": kind,
                                "private": "private" in prefix})

    unused, test_only, own_file_only = [], [], []
    for name, items in decls.items():
        declared = len(items)
        prod = prod_refs[name] - declared
        if prod > 0:
            # Typ, der nur in der eigenen Datei vorkommt (z. B. nur in #Preview).
            own = {it["file"] for it in items}
            elsewhere = sum(c[name] for f, c in refs_by_file.items() if f not in own)
            if elsewhere == 0 and test_refs[name] == 0:
                for it in items:
                    if it["kind"] in ("struct", "class", "actor") and not it["private"]:
                        own_file_only.append({"name": name, **it})
            continue
        target = test_only if test_refs[name] > 0 else unused
        for it in items:
            target.append({"name": name, **it,
                           "test_refs": test_refs[name]})

    key = lambda x: (x["file"], x["line"])
    out = {
        "hinweis": "Kandidaten auf Namensebene, kein Beweis. Vor dem Melden "
                   "jeden Treffer mit grep gegenprüfen.",
        "files_scanned": len(files),
        "unused": sorted(unused, key=key),
        "own_file_only": sorted(own_file_only, key=key),
        "test_only": sorted(test_only, key=key),
    }
    json.dump(out, sys.stdout, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
