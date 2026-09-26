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
}
