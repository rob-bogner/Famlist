/*
 WatchFrequentItem.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Eintrag unter „Oft gekauft“ (Artikelstamm, Migration 022): Name und Detailzeile
   (Kategorie, sonst Menge – wie im Design „Milchprodukte“ / „10 Stück“).
 ------------------------------------------------------------------------
 */

import Foundation

struct WatchFrequentItem: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let detail: String
}
