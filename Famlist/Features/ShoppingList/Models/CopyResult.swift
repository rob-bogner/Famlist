/*
 CopyResult.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ergebnis des Kopierens für Dock-Zustand „Kopiert“ und Toast „Liste kopiert“ (2 s).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import Foundation

/// What was copied to the clipboard (drives the 2-second confirmation).
struct CopyResult: Equatable {
    let id = UUID()
    let count: Int
    let scope: ListClipboardFormatter.Scope
}
