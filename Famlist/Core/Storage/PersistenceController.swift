/*
 PersistenceController.swift
 Famlist
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Provides the SwiftData model container for ListEntity and ItemEntity.
 🛠 Includes: Shared/live container, in-memory preview container, schema registration.
 🔰 Notes for Beginners: Use shared for production, preview for SwiftUI previews or tests.
 📝 Last Change: Beschädigte Datenbank wird beiseitegelegt und neu angelegt statt still im Arbeitsspeicher
   weiterzulaufen (Audit 25.09.2026).
 ------------------------------------------------------------------------
*/

import Foundation
import SwiftData

/// Centralises SwiftData container creation for the local-first stack.
struct PersistenceController {
    /// Shared controller used at runtime (disk backed).
    static let shared = PersistenceController()

    /// In-memory flavour useful for previews/tests.
    static let preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    /// Underlying model container registered with our entities.
    let container: ModelContainer

    static let schema = Schema([
        ListEntity.self,
        ItemEntity.self,
        SyncOperation.self
    ])

    /// Builds a model container for the application schema.
    /// - Parameter storeURL: nur für Tests; sonst der Standardort von SwiftData.
    init(inMemory: Bool = false, storeURL: URL? = nil) {
        if inMemory {
            container = Self.makeInMemory()
            return
        }
        let configuration = storeURL.map { ModelConfiguration("Default", url: $0) } ?? ModelConfiguration("Default")
        do {
            container = try ModelContainer(for: Self.schema, configurations: configuration)
        } catch {
            container = Self.recover(from: error, configuration: configuration)
        }
    }

    /// Die Datenbank ließ sich nicht öffnen (z. B. beschädigt). Früher lief die App dann still im
    /// Arbeitsspeicher weiter, und alles danach Eingetragene war beim nächsten Start verloren (Audit P9).
    /// Jetzt: Datei beiseitelegen (bleibt für die Fehlersuche erhalten), neue Datenbank auf dem Gerät
    /// anlegen; die Listen kommen beim nächsten Abgleich vom Server zurück. Nur wenn auch das scheitert,
    /// bleibt der Arbeitsspeicher als letzter Ausweg.
    private static func recover(from error: Error, configuration: ModelConfiguration) -> ModelContainer {
        logVoid(params: (action: "containerOpenFailed", error: error.localizedDescription))
        let backup = moveAside(configuration.url)
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            logVoid(params: (action: "containerRecreated", backup: backup?.lastPathComponent ?? "-"))
            return container
        } catch {
            logVoid(params: (action: "containerFallbackInMemory", error: error.localizedDescription))
            return makeInMemory()
        }
    }

    /// Verschiebt die Datenbank samt -wal/-shm nach „<Name>.broken-<Zeitstempel>“.
    @discardableResult
    static func moveAside(_ url: URL) -> URL? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }
        let stamp = Int(Date().timeIntervalSince1970)
        let target = url.deletingLastPathComponent().appendingPathComponent("\(url.lastPathComponent).broken-\(stamp)")
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            guard fm.fileExists(atPath: source.path) else { continue }
            try? fm.moveItem(at: source, to: URL(fileURLWithPath: target.path + suffix))
        }
        return target
    }

    private static func makeInMemory() -> ModelContainer {
        do {
            return try ModelContainer(for: schema,
                                      configurations: ModelConfiguration("InMemory", isStoredInMemoryOnly: true))
        } catch {
            fatalError("SwiftData container creation failed even in-memory: \(error.localizedDescription)")
        }
    }
}
