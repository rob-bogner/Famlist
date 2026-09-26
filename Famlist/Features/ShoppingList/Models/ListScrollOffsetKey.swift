/*
 ListScrollOffsetKey.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Scroll-Position der Einkaufsliste (für den kompakten Kopf) samt Schwellenwerten.

 🔰 Notes for Beginners:
 - iOS 17 hat kein onScrollGeometryChange → Position per GeometryReader + PreferenceKey messen.
 - Wert = wie weit der Inhalt nach oben geschoben ist (0 = ganz oben, negativ beim Pull-to-Refresh).
 - Nur Fallback für iOS 17; ab iOS 18 liefert onScrollGeometryChange den Wert (ShoppingListView).
 - Den Übergang des Kopfs berechnet CollapsingListHeader.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ListScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static let coordinateSpace = "shoppingListScroll"
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }

}
