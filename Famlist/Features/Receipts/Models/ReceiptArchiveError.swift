/*
 ReceiptArchiveError.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fehler des Kassenzettel-Archivs, die kein Netzfehler sind (zählen als Fehlversuch in der Warteschlange).

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptArchiveError: Error, Equatable {
    /// Die lokale Fotodatei eines wartenden Bons fehlt (z. B. vom System gelöscht).
    case photoMissing(String)
}
