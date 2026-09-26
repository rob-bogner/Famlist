/*
 WatchWidgets.swift
 Famlist Watch – Design-Referenz (WatchFace.dc.html: Zifferblatt & Smart Stack)

 WidgetKit-Views für ein Widget-Extension-Target des Watch-Targets (watchOS 10+):
 - Smart-Stack-Karte (.accessoryRectangular): „FAMLIST“ · „My List · 4 offen“ · Balken
 - Komplikation Ring (.accessoryCircular): offene Anzahl im Fortschrittsring
 - Komplikation Plus (.accessoryCircular): öffnet „Hinzufügen“ (Deep Link famlist://watch/add)
 Timeline-Provider und Datenquelle (App Group) baut die Umsetzung.
 */

import SwiftUI
import WidgetKit

/// Smart Stack: Innenabstand 10/12, Radius 20 (vom System), Kopf DM 11/600 Großbuchstaben accentText + Wagen-Icon 12,
/// Titel Outfit 16/600, Balken 5 – Abstand 5.
struct WatchSmartStackView: View {
    var w = WatchTheme()
    var listName = "My List"
    var open = 4
    var fraction = 1.0 / 3.0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("FAMLIST", systemImage: "cart")
                .font(WatchFont.dm(11, .semibold)).tracking(0.66).foregroundStyle(w.accentText)
            Text("\(listName) · \(open) offen").font(WatchFont.outfit(16)).lineLimit(1)
            WatchProgressBar(w: w, fraction: fraction)
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

/// Runde Komplikation: Ring 38 / Strich 4, Zahl DM 11/600.
struct WatchRingComplicationView: View {
    var w = WatchTheme()
    var open = 4
    var fraction = 1.0 / 3.0
    var body: some View {
        WatchRing(w: w, fraction: fraction, size: 38, lineWidth: 4, label: "\(open)")
            .containerBackground(for: .widget) { Color.white.opacity(0.1) }
            .widgetURL(URL(string: "famlist://watch/list"))
    }
}

/// Plus-Komplikation: Plus 20 / Strich 2,4 in accentText auf weiß .1.
struct WatchAddComplicationView: View {
    var w = WatchTheme()
    var body: some View {
        Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundStyle(w.accentText)
            .containerBackground(for: .widget) { Color.white.opacity(0.1) }
            .widgetURL(URL(string: "famlist://watch/add"))
            .accessibilityLabel("Artikel hinzufügen")
    }
}
