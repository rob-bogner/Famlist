/*
 WatchListSummary.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Zeile im Screen „Listen“: Name, Status („4 von 6 offen“, „3 offen“, „erledigt“),
   Anteil erledigt für den Ring, Favorit.
 ------------------------------------------------------------------------
 */

import Foundation

struct WatchListSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let status: String
    /// Anteil erledigter Artikel (0…1).
    let fraction: Double
    var isFavorite = false
}
