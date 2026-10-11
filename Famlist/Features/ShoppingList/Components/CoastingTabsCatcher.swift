/*
 CoastingTabsCatcher.swift
 Famlist
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zweite, unsichtbare Tab-Reihe ÜBER der Liste. Sie nimmt Tipps auf „Alle · Offen · Erledigt“ an, solange die
   Liste nach einem Wisch noch nachläuft.

 🔰 Notes for Beginners:
 - Die sichtbaren Tabs liegen im Listenkopf und damit IN der Scroll-Ansicht. Läuft die Liste nach, hält die
   erste Berührung dort nur das Scrollen an und erreicht den Tab nicht (Systemverhalten jeder Scroll-Ansicht).
   Robert musste warten und ein zweites Mal tippen (Gerät, 12.10.2026).
 - Ansichten ÜBER der Scroll-Ansicht bekommen die Berührung sofort – wie das Dock. Deshalb liegt hier dieselbe
   Tab-Reihe noch einmal genau über der sichtbaren: unsichtbar, aber treffbar.
 - Nur aktiv, wenn die Liste ohne Finger läuft UND der Kopf ganz eingeklappt ist. Dann steht die Tab-Reihe fest
   an einer bekannten Stelle (`CollapsingListHeader.compactTabsTop`). Sonst bleibt alles wie bisher: Ein Wisch,
   der auf den Tabs beginnt, scrollt die Liste.
 - `TrackListCoasting` meldet den Nachlauf (iOS 18+, `onScrollPhaseChange`). Unter iOS 17 gibt es die Meldung
   nicht; dort bleibt das alte Verhalten.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CoastingTabsCatcher: View {
    let t: ListTheme
    @Binding var selection: ItemFilter
    let openCount: Int
    let doneCount: Int
    /// Nur diese Ansicht liest `isCoasting` / `isHeaderCompact` – die Liste selbst wird dadurch nicht neu berechnet.
    let scroll: ListScrollState
    /// Aus im Filter-Modus (dort zeigt der Kopf keine Tabs).
    var isEnabled = true

    var body: some View {
        if isEnabled && scroll.isCoasting && scroll.isHeaderCompact {
            ListFilterTabs(t: t, selection: $selection, openCount: openCount, doneCount: doneCount)
                .opacity(0.011)                                  // unsichtbar, aber treffbar (0 wäre nicht treffbar)
                .padding(.horizontal, 20)                        // wie der Listeninhalt
                .padding(.top, CollapsingListHeader.compactTabsTop)
                .accessibilityHidden(true)                       // VoiceOver nutzt die sichtbaren Tabs
        }
    }
}

/// Meldet, ob die Liste ohne Finger läuft (Nachlauf nach einem Wisch oder programmatisches Scrollen).
struct TrackListCoasting: ViewModifier {
    let onChange: @MainActor (Bool) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                onChange(phase == .decelerating || phase == .animating)
            }
        } else {
            content
        }
    }
}

/// Zustand für die Vorschau: Liste läuft nach, Kopf ist eingeklappt.
@MainActor
private func coastingPreviewState() -> ListScrollState {
    let scroll = ListScrollState()
    scroll.isCoasting = true
    scroll.collapseRange = 0
    scroll.update(offset: 1)
    return scroll
}

#Preview("Trefferfläche sichtbar gemacht") {
    @Previewable @State var filter = ItemFilter.all
    CoastingTabsCatcher(t: ListTheme(.light), selection: $filter, openCount: 3, doneCount: 13,
                        scroll: coastingPreviewState())
        .opacity(90)                                             // nur in der Vorschau sichtbar
        .frame(maxHeight: .infinity, alignment: .top)
}

#Preview("Trefferfläche sichtbar gemacht – Dark") {
    @Previewable @State var filter = ItemFilter.done
    CoastingTabsCatcher(t: ListTheme(.dark), selection: $filter, openCount: 3, doneCount: 13,
                        scroll: coastingPreviewState())
        .opacity(90)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.hex("#071012"))
}
