/*
 OpenSwipeRow.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Welche Artikel-Zeile gerade aufgewischt ist und auf welcher Seite.

 🔰 Notes for Beginners:
 - Gehört der Liste (ShoppingListView), damit immer höchstens eine Zeile offen ist.
 - Reiner Anzeigezustand, wird weder gespeichert noch synchronisiert.

 📝 Last Change:
 - Initial creation (Rechts-Wischen zweistufig: Zeile kann auch rechts offen stehen).
 ------------------------------------------------------------------------
 */

import Foundation

/// The single swiped-open row of the list and its open side.
struct OpenSwipeRow: Equatable {
    let id: String
    let rest: SwipeRevealPhysics.Rest
}
