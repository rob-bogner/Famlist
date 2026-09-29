/*
 ActionCardContent.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Inhalt einer Aktionskarte (ersetzt iOS-Systemdialoge): Symbol, Ton, Titel, Text, Zusatzinhalt, Knöpfe.

 🔰 Notes for Beginners:
 - Design: ItemSyncFailedDialog, DeleteListDialog, ReceiptAssignDialog … (Canvas, seit 29.09.2026).
 - Knopf-Rollen: `.primary` = CTA (Akzent), `.destructive` = rote Glas-Pille, `.slide` = „Schieben zum
   Löschen“ (endgültiges Löschen), `.secondary` = neutrale Glas-Pille (optional eigene Textfarbe),
   `.cancel` = neutrale Glas-Pille „Abbrechen“ (seit 29.09.2026 nicht mehr genutzt – Schließen per ✕).
 - `closable`: ✕ oben rechts + Tipp auf die Abdunkelung schließen (false z. B. bei „Artikelpreise
   aktualisieren?“, dort speichern beide Wege).
 - Jede Knopf-Aktion läuft erst NACH dem Ausblenden der Karte (z. B. damit danach ein Sheet öffnen kann).
 - `accessory` bekommt `close` – Zusatzinhalte (Auswahl-Zeilen, Kacheln) schließen damit die Karte
   und geben die Folgeaktion mit.

 📝 Last Change:
 - ✕ statt „Abbrechen“, Rolle `.slide` (Schieben zum Löschen).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Farbton der Symbol-Kachel oben links.
enum ActionCardTone {
    case danger, warn, info
}

/// Ein Knopf unten in der Aktionskarte.
struct ActionCardButton {
    enum Role { case primary, destructive, slide, secondary, cancel }

    let title: String
    var icon: [SVGElement]? = nil
    var role: Role = .secondary
    /// Abweichende Textfarbe für `.secondary` (z. B. Akzent bei „Als neuen Artikel speichern“, Rot bei „Zeile ignorieren“).
    var tint: Color? = nil
    var isEnabled = true
    var action: () -> Void = {}

    /// „Abbrechen“ – neutrale Glas-Pille, schließt nur.
    static func cancel(_ action: @escaping () -> Void = {}) -> ActionCardButton {
        ActionCardButton(title: "Abbrechen", role: .cancel, action: action)
    }
}

/// Alles, was eine Aktionskarte anzeigt.
struct ActionCardContent {
    /// Schließt die Karte; die übergebene Aktion läuft, sobald sie ausgeblendet ist.
    typealias Close = (_ then: (() -> Void)?) -> Void

    let icon: [SVGElement]
    let tone: ActionCardTone
    let title: String
    var message: String? = nil
    var buttons: [ActionCardButton] = []
    /// Zusatzinhalt zwischen Text und Knöpfen (Kacheln, Auswahl, Eingabefeld).
    var accessory: ((_ close: @escaping Close) -> AnyView)? = nil
    /// ✕ oben rechts und Tipp auf die Abdunkelung schließen die Karte.
    var closable = true
}
