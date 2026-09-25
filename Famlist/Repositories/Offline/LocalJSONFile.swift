/*
 LocalJSONFile.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lesen und Schreiben der lokalen JSON-Dateien der Offline-Warteschlangen (Listen, Artikelstamm).

 🔰 Notes for Beginners:
 - Vorher wurden Fehler mit `try?` verschluckt: Scheiterte das Schreiben, überstand eine offline angelegte
   Liste keinen Neustart, ohne dass es irgendwo auffiel (Audit 2, Befund Q8). Jetzt wird jeder Fehler
   protokolliert; eine unlesbare Datei wird als „.broken“ beiseitegelegt statt bei jedem Start zu scheitern.
 - Fehlt die Datei, ist das kein Fehler (noch nichts gespeichert).
 ------------------------------------------------------------------------
 */

import Foundation

enum LocalJSONFile {
    static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: Data(contentsOf: url))
        } catch {
            logVoid(params: (action: "localJSON.readFailed", file: url.lastPathComponent,
                             error: (error as NSError).localizedDescription))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("broken"))
            try? FileManager.default.moveItem(at: url, to: url.appendingPathExtension("broken"))
            return nil
        }
    }

    static func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            logVoid(params: (action: "localJSON.writeFailed", file: url.lastPathComponent,
                             error: (error as NSError).localizedDescription))
        }
    }
}
