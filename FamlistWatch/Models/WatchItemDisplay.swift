/*
 WatchItemDisplay.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Anzeigedaten einer Artikelzeile (Name, Mengentext, erledigt). Die Screens kennen nur diese Werte,
   nie SwiftData-Objekte (Projektregel: keine @Model-Instanzen über Schichten reichen).
 ------------------------------------------------------------------------
 */

import Foundation

struct WatchItemDisplay: Identifiable, Hashable {
    let id: String
    let name: String
    /// z. B. „6 Stück“, „500 g“.
    let quantity: String
    let isChecked: Bool
}
