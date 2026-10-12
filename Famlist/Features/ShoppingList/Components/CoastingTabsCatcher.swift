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
 - Deshalb liegt hier dieselbe Tab-Reihe noch einmal genau über der sichtbaren: unsichtbar, aber treffbar.
 - Sie muss eine eigene UIKit-Ansicht sein (`TouchFirstHost`). Als reine SwiftUI-Ansicht im Overlay der Liste
   bekam sie die Berührung im Nachlauf nicht – der Tipp hielt weiter nur das Scrollen an (Gerät iOS 27 und
   Messung im Simulator iOS 26.5, 12.10.2026). Das Dock (SwiftUI, eigene Ebene) bekommt sie dagegen.
 - Nur aktiv, wenn die Liste ohne Finger läuft UND der Kopf ganz eingeklappt ist. Dann steht die Tab-Reihe fest
   an einer bekannten Stelle (`CollapsingListHeader.compactTabsTop`). Sonst bleibt alles wie bisher: Ein Wisch,
   der auf den Tabs beginnt, scrollt die Liste.
 - `TrackListCoasting` meldet den Nachlauf (iOS 18+, `onScrollPhaseChange`). Unter iOS 17 gibt es die Meldung
   nicht; dort bleibt das alte Verhalten.

 📝 Last Change:
 - Tab-Reihe als UIKit-Ansicht (`TouchFirstHost`), Anhalten des Nachlaufs (`StopListCoasting`) (12.10.2026).
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
            tabs
                .hidden()                                        // gibt nur die Größe vor
                .overlay { TouchFirstHost(content: tabs.opacity(0.011)) }   // unsichtbar, aber treffbar (0 wäre es nicht)
                .padding(.horizontal, 20)                        // wie der Listeninhalt
                .padding(.top, CollapsingListHeader.compactTabsTop)
                .accessibilityHidden(true)                       // VoiceOver nutzt die sichtbaren Tabs
        }
    }

    private var tabs: ListFilterTabs {
        ListFilterTabs(t: t, selection: $selection, openCount: openCount, doneCount: doneCount)
    }
}

/// Stellt SwiftUI-Inhalt als eigene UIKit-Ansicht über die Scroll-Ansicht. So bekommt er die Berührung, während
/// die Liste nachläuft; die Liste läuft dabei weiter (gemessen 12.10.2026, Simulator iOS 26.5).
private struct TouchFirstHost<Content: View>: UIViewRepresentable {
    let content: Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        context.coordinator.host = host
        return host.view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.host?.rootView = content
    }

    final class Coordinator {
        var host: UIHostingController<Content>?
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

/// Liegt im Inhalt der Liste und sucht von dort die umgebende UIScrollView. Über `ListScrollState.stopMotion`
/// hält ein Tab-Wechsel damit den Nachlauf an. `ScrollViewProxy.scrollTo` allein tut das nicht: Die Liste sprang
/// nach oben und lief von dort noch 1 s weiter (gemessen 12.10.2026, Simulator iOS 26.5).
struct StopListCoasting: UIViewRepresentable {
    let scroll: ListScrollState

    func makeUIView(context: Context) -> FinderView {
        let view = FinderView()
        view.isUserInteractionEnabled = false
        view.scroll = scroll
        return view
    }

    func updateUIView(_ uiView: FinderView, context: Context) {}

    final class FinderView: UIView {
        var scroll: ListScrollState?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            Task { [weak self] in self?.connect() }          // erst im nächsten Durchlauf hängt die Ansicht in der Liste
        }

        private func connect() {
            var view = superview
            while let current = view, !(current is UIScrollView) { view = current.superview }
            guard let scrollView = view as? UIScrollView else { return }
            scroll?.stopMotion = { [weak scrollView] in
                if #available(iOS 17.4, *) { scrollView?.stopScrollingAndZooming() }
            }
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
