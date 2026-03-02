/*
 PersistenceController.swift
 Famlist
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Provides the SwiftData model container for ListEntity and ItemEntity.
 🛠 Includes: Shared/live container, in-memory preview container, schema registration.
 🔰 Notes for Beginners: Use shared for production, preview for SwiftUI previews or tests.
 📝 Last Change: Initial creation to bootstrap the local-first SwiftData stack.
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

    /// Builds a model container for the application schema.
    init(inMemory: Bool = false) {
        let schema = Schema([
            ListEntity.self,
            ItemEntity.self,
            SyncOperation.self
        ])
        let configuration = ModelConfiguration(
            "Default",
            isStoredInMemoryOnly: inMemory
        )
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Erster Versuch fehlgeschlagen (z. B. beschädigte Datenbank).
            // Fallback auf In-Memory-Container, damit die App nicht crasht.
            // Daten werden nicht über Neustarts persistiert; der Fehler wird geloggt.
            logVoid(params: (action: "containerFallback", error: error.localizedDescription))
            let fallback = ModelConfiguration("Fallback", isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: fallback)
            } catch let fallbackError {
                fatalError("SwiftData container creation failed even in-memory: \(fallbackError.localizedDescription)")
            }
        }
    }
}
