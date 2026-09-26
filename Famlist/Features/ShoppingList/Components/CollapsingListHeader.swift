/*
 CollapsingListHeader.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Listenkopf, der beim Scrollen fließend vom großen in den kompakten Zustand übergeht
   (ein einziger Kopf, kein zweiter, der von oben einfährt).

 🔰 Notes for Beginners:
 - Vorlagen: Hybrid.dc.html (groß) und „Liste – Kopf kompakt“ (Hybrid.dc.html, header = "compact").
 - Fortschritt p = Scroll-Weg / Übergangsstrecke (0 = oben, 1 = kompakt). Alle Höhen wechseln linear mit p,
   dadurch schrumpft der Kopf genau so schnell, wie die Liste scrollt: die erste Karte klebt an seiner
   Unterkante, es entsteht weder Lücke noch Überlappung.
 - Übergänge: Titel 30 → 22 pt (Skalierung), Suchleiste klappt weg und blendet aus, der Such-Knopf blendet
   neben ☰ ein, die Fortschrittskarte schrumpft auf 40 pt und blendet in die schmale Leiste über.
 - Der Kopf liegt als erstes Element in der ScrollView (nicht im LazyVStack) und wird per Offset oben gehalten.
   Beim Hochscrollen geht er erst in der letzten Übergangsstrecke vor dem Listenanfang wieder auf.

 📝 Last Change:
 - Initial creation (ersetzt den separat einfahrenden kompakten Kopf).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CollapsingListHeader: View {
    let t: ListTheme
    let title: String
    let checked: Int
    let total: Int
    var totalPrice: Double? = nil
    @Binding var filter: ItemFilter
    /// Scroll-Weg der Liste (0 = ganz oben, negativ beim Pull-to-Refresh). Nur dieser Kopf liest ihn.
    let scroll: ListScrollState
    private var scrollOffset: CGFloat { scroll.offset }
    var onShowLists: () -> Void = {}
    var onSearch: () -> Void = {}
    var onScan: () -> Void = {}
    var onMenu: () -> Void = {}

    @State private var heroHeight: CGFloat = 128
    @State private var tabsHeight: CGFloat = 43

    static let rowHeight: CGFloat = 44
    static let gap: CGFloat = 18
    static let searchHeight: CGFloat = 52
    static let barHeight: CGFloat = 40

    /// Übergangsstrecke: Suchleiste + Abstand + (Karte − Leiste).
    static func collapseRange(heroHeight: CGFloat) -> CGFloat {
        searchHeight + gap + max(heroHeight - barHeight, 0)
    }

    /// 0…1; negativ (Ziehen) → 0, über die Strecke hinaus → 1.
    static func progress(offset: CGFloat, range: CGFloat) -> CGFloat {
        guard range > 0 else { return 0 }
        return min(max(offset / range, 0), 1)
    }

    private var p: CGFloat { Self.progress(offset: scrollOffset, range: Self.collapseRange(heroHeight: heroHeight)) }
    private var fullHeight: CGFloat {
        Self.rowHeight + Self.gap + Self.searchHeight + Self.gap + heroHeight + Self.gap + tabsHeight
    }
    private func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * p }
    /// Teilbereich von p auf 0…1 abbilden (für gestaffeltes Ein-/Ausblenden).
    private func phase(_ from: CGFloat, _ to: CGFloat) -> CGFloat { min(max((p - from) / (to - from), 0), 1) }

    var body: some View {
        let background = t.isDark ? Color.hex("#071012") : Color.white
        let pinned = max(scrollOffset, 0)

        VStack(spacing: 0) {
            topRow
            searchBlock
            heroBlock
                .padding(.top, Self.gap)
            ListFilterTabs(t: t, selection: $filter)
                .padding(.top, Self.gap)
                .background { GeometryReader { g in Color.clear.onAppear { tabsHeight = g.size.height }
                    .onChange(of: g.size.height) { _, h in tabsHeight = h } } }
        }
        .background(alignment: .top) {
            // Deckt beim Scrollen die Karten darunter ab (auch hinter der Statusleiste), unten weicher Übergang.
            VStack(spacing: 0) {
                background
                LinearGradient(colors: [background, background.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 16)
            }
            .padding(.top, -120)
            .padding(.bottom, -16)
            .padding(.horizontal, -20)
            .opacity(min(pinned / 8, 1))
            .allowsHitTesting(false)
        }
        .offset(y: pinned)                                 // bleibt oben stehen, während die Liste scrollt
        .frame(height: fullHeight, alignment: .top)        // Platz in der Liste: immer die volle Höhe
        .zIndex(1)
    }

    // MARK: - Titelzeile

    private var topRow: some View {
        HStack(spacing: 12) {
            Button(action: onShowLists) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(AppFont.outfit(30, 700))
                        .tracking(-0.6)
                        .foregroundStyle(t.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    SVGIcon(Icon.chevronDown, size: 18, color: t.sub, lineWidth: 2.2)
                }
                .scaleEffect(lerp(1, 22.0 / 30.0), anchor: .leading)   // 30 → 22 pt
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Liste wechseln, aktuell \(title)")

            Button(action: onMenu) {
                RoundHeaderIcon(t: t, icon: Icon.menu)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mehr")
            .overlay(alignment: .trailing) {
                // Such-Knopf links neben ☰ (Abstand 10) – blendet in der zweiten Hälfte ein
                let s = phase(0.45, 0.9)
                Button(action: onSearch) {
                    SVGIcon(Icon.search, size: 20, color: t.icon, lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .background(CSSBox(shape: Circle(), paint: t.round, border: 1, borderColor: t.roundBorder,
                                           shadows: t.roundShadow))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .scaleEffect(0.7 + 0.3 * s)
                .opacity(s)
                .offset(x: -54)
                .allowsHitTesting(s > 0.5)
                .accessibilityHidden(s < 0.5)
                .accessibilityLabel("Artikel suchen oder hinzufügen")
            }
        }
        .frame(height: Self.rowHeight)
    }

    // MARK: - Suchleiste

    /// Suchleiste + Abstand klappen linear auf 0 zusammen, die Leiste blendet in der ersten Hälfte aus.
    private var searchBlock: some View {
        let fade = 1 - phase(0, 0.5)
        return ListSearchBar(t: t, action: onSearch, onScan: onScan)
            .padding(.top, Self.gap)
            .opacity(fade)
            .frame(height: (Self.gap + Self.searchHeight) * (1 - p), alignment: .bottom)
            .mask(Rectangle().padding(.horizontal, -24).padding(.bottom, -24))   // Schatten seitlich/unten behalten
            .allowsHitTesting(fade > 0.5)
            .accessibilityHidden(fade < 0.5)
    }

    // MARK: - Fortschritt

    /// Eine Fläche, die von der Kartenhöhe auf 40 pt schrumpft; Inhalte blenden über (Karte → Leiste).
    private var heroBlock: some View {
        let big = 1 - phase(0.15, 0.6)
        let small = phase(0.5, 0.95)
        let radius = lerp(28, 20)
        return ZStack(alignment: .top) {
            ProgressHero(t: t, checked: checked, total: total, totalPrice: totalPrice)
                .fixedSize(horizontal: false, vertical: true)
                .background { GeometryReader { g in Color.clear.onAppear { heroHeight = g.size.height }
                    .onChange(of: g.size.height) { _, h in heroHeight = h } } }
                .opacity(big)
                .accessibilityHidden(big < 0.5)
            CompactProgressBar(t: t, checked: checked, total: total, totalPrice: totalPrice)
                .opacity(small)
                .accessibilityHidden(small < 0.5)
        }
        .frame(height: lerp(heroHeight, Self.barHeight), alignment: .top)
        .clipShape(RR(radius))
        .background(CSSBox(shape: RR(radius), paint: t.heroBg, shadows: t.heroShadow))
    }
}

#Preview("Kopf – Übergang") {
    @Previewable @State var filter = ItemFilter.all
    @Previewable @State var scroll = ListScrollState()
    VStack {
        CollapsingListHeader(t: ListTheme(.light), title: "Edeka", checked: 34, total: 38, totalPrice: 1.19,
                             filter: $filter, scroll: scroll)
        Slider(value: $scroll.offset, in: -40...300)
    }
    .padding(20)
}

#Preview("Kopf – Übergang Dark") {
    @Previewable @State var filter = ItemFilter.all
    @Previewable @State var scroll = ListScrollState()
    VStack {
        CollapsingListHeader(t: ListTheme(.dark), title: "Edeka", checked: 2, total: 5,
                             filter: $filter, scroll: scroll)
        Slider(value: $scroll.offset, in: -40...300)
    }
    .padding(20)
    .background(Color.hex("#071012"))
}
