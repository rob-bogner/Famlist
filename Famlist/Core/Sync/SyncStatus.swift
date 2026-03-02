/*
 SyncStatus.swift
 Famlist
 Created on: 02.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustandsenum für den SyncEngine-Status.

 📝 Last Change:
 - Aus SyncEngine.swift extrahiert (One Type per File).
 ------------------------------------------------------------------------
*/

/// Mögliche Zustände der SyncEngine.
enum SyncStatus: Equatable {
    case idle
    case syncing
    case paused
    case error(String)
}
