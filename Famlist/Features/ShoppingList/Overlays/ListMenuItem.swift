/*
 ListMenuItem.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einträge des Kontext-Menüs ☰ oben rechts.

 🔰 Notes for Beginners:
 - SPEC §3.5 nennt vier Einträge. Robert hat am 24.09.2026 zwei ergänzt:
   „Kassenzettel scannen“ (Einstieg nicht gestaltet) und „Aus Zwischenablage importieren“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import Foundation

/// Entries of the ☰ list menu.
enum ListMenuItem: CaseIterable {
    case members
    case manageItems
    case manageCategories
    case receipt
    case importClipboard
    case settings
}
