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
            container = try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create SwiftData container: \(error.localizedDescription)")
        }
    }
}
