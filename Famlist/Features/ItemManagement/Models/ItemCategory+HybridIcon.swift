/*
 ItemCategory+HybridIcon.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ordnet jeder Kategorie ein Kontur-Icon aus dem Hybrid-Icon-Katalog zu.

 🔰 Notes for Beginners:
 - Das Design liefert Icons für Obst & Gemüse, Milchprodukte, Backwaren und Sonstiges.
   Die übrigen vier (Getränke, Haushalt, Tiefkühl, Fleisch & Fisch) sind im selben Stil ergänzt.
 - `icon` (SF Symbol) bleibt für bestehende Stellen außerhalb des Redesigns erhalten.

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import Foundation

extension ItemCategory {
    /// Vector icon used by the Hybrid design (section headers, category chips).
    var svgIcon: [SVGElement] {
        switch self {
        case .obstGemuese: return Icon.leaf
        case .milch:       return Icon.drop
        case .backwaren:   return Icon.cutlery
        case .getraenke:   return Icon.glass
        case .haushalt:    return Icon.home
        case .tiefkuehl:   return Icon.snowflake
        case .fleisch:     return Icon.flame
        case .sonstiges:   return Icon.tag
        }
    }
}
