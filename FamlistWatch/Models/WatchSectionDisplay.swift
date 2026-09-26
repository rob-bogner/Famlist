/*
 WatchSectionDisplay.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Abschnitt der Einkaufsliste (Kategorie in Ladenweg-Reihenfolge) mit seinen Artikeln.
 ------------------------------------------------------------------------
 */

import Foundation

struct WatchSectionDisplay: Identifiable, Hashable {
    /// Kategoriename; eindeutig innerhalb einer Liste.
    var id: String { title }
    let title: String
    let items: [WatchItemDisplay]
}
