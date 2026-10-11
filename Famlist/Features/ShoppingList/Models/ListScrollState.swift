/*
 ListScrollState.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Scroll-Weg der Einkaufsliste als @Observable-Objekt.

 🔰 Notes for Beginners:
 - Ändert sich bei jedem Scroll-Frame. Als @State in ShoppingListView würde jede Änderung die ganze Liste
   neu berechnen (ruckelt). So liest nur CollapsingListHeader den Wert und nur der Kopf wird neu gezeichnet.

 📝 Last Change:
 - `isCoasting`, `isHeaderCompact` für Tab-Tipps im Nachlauf (CoastingTabsCatcher, 12.10.2026).
 - Initial creation.
 ------------------------------------------------------------------------
 */

import Observation
import CoreGraphics

@MainActor
@Observable
final class ListScrollState {
    /// 0 = ganz oben, negativ beim Pull-to-Refresh.
    var offset: CGFloat = 0
    /// Die Liste läuft ohne Finger (Nachlauf nach einem Wisch oder programmatisches Scrollen).
    var isCoasting = false
    /// Der Kopf ist ganz eingeklappt (Scroll-Weg ≥ Übergangsstrecke). Wechselt selten – anders als `offset`.
    private(set) var isHeaderCompact = false
    /// Übergangsstrecke des Kopfs; CollapsingListHeader trägt sie ein, sobald die Kartenhöhe gemessen ist.
    @ObservationIgnored var collapseRange: CGFloat = .infinity
    /// Tab-Wechsel im Nachlauf: Sobald die Liste steht, noch einmal ganz nach oben (falls der Nachlauf weiterlief).
    @ObservationIgnored var returnToTopWhenIdle = false

    /// Neuer Scroll-Weg. `isHeaderCompact` wird nur geschrieben, wenn es sich ändert (sonst würde jede
    /// Ansicht, die es liest, in jedem Frame neu berechnet).
    func update(offset new: CGFloat) {
        offset = new
        let compact = new >= collapseRange
        if compact != isHeaderCompact { isHeaderCompact = compact }
    }
}
