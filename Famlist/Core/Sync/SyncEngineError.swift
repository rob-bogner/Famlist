/*
 SyncEngineError.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fehler der SyncEngine selbst (nicht vom Server).

 📝 Last Change:
 - Aus SyncEngine.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

/// Fehler der SyncEngine selbst (nicht vom Server).
enum SyncEngineError: Error {
    /// Die Server-Antwort hat nicht genau einen Eintrag je Auftrag.
    case responseCountMismatch
    /// Die Liste des Artikels wurde offline angelegt und ist noch nicht auf dem Server.
    case listNotYetCreated
}
