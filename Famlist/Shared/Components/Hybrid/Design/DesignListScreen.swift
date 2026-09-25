/*
 DesignListScreen.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Statische Design-Liste mit Beispieldaten. Dient nur als Hintergrund in Vorschauen der Sheets und Overlays.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ListScreen.swift (ListScreen → DesignListScreen, private Bausteine mit Präfix „Design“; Glow-Kreise liegen in ListBackground der App).
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct DesignListScreen: View {
    let appearance: Appearance
    let accentHex: String?
    let state: ListRowState
    /// Optional: echter Hintergrund-Blur unter dem Dock (im Design `backdrop-filter`).
    /// Im statischen Design liegt nichts hinter dem Dock – deshalb standardmäßig aus.
    let liveDockBlur: Bool

    @State private var query = ""

    init(appearance: Appearance, accentHex: String? = nil, state: ListRowState = .normal, liveDockBlur: Bool = false) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.state = state
        self.liveDockBlur = liveDockBlur
    }

    /// pillState im HTML: empty → .empty, checked → .allDone, sonst .open
    private var dockPill: DockPill {
        switch state {
        case .empty: .empty
        case .checked: .allDone
        case .normal, .swipe: .open
        }
    }

    var body: some View {
        let t = ListTheme(appearance, accentHex: accentHex)
        ZStack(alignment: .topLeading) {
            ListBackground(t: t)

            VStack(alignment: .leading, spacing: 0) {
                DesignListTopBar(t: t)
                DesignListSearchField(t: t, query: $query)
                    .padding(.top, 18)
                DesignProgressHero(t: t, state: state)
                    .padding(.top, 18)
                DesignListTabs(t: t)
                    .padding(.top, 18)
                if state == .empty {
                    DesignListEmptyState(t: t)
                        .padding(.top, 44)             // gap 18 + margin-top 26
                } else {
                    DesignSectionHeader(t: t, checked: state == .checked)
                        .padding(.top, 16)             // gap 18 + margin-top −2
                    DesignItemRow(t: t, state: state)
                        .padding(.top, 12)             // gap 18 + margin-top −6
                }
            }
            .padding(.top, 62)
            .padding(.horizontal, 20)

            // position: absolute; left: 20; bottom: 34; 350 × 64
            DockView(appearance: appearance, accentHex: accentHex, active: .none, pill: dockPill, liveBlur: liveDockBlur)
                .frame(height: 64)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .ignoresSafeArea()
    }
}

// MARK: - Kopfzeile

private struct DesignListTopBar: View {
    let t: ListTheme

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: {}) {
                HStack(spacing: 6) {
                    Text("My List")
                        .font(AppFont.outfit(30, 700))
                        .tracking(-0.6)                      // -0.02em × 30
                        .foregroundStyle(t.text)
                    SVGIcon(Icon.chevronDown, size: 18, color: t.sub, lineWidth: 2.2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Liste wechseln")

            Spacer(minLength: 0)

            // Nur noch EIN runder Knopf („Ansicht wechseln“ entfällt)
            DesignRoundHeaderButton(t: t, icon: Icon.menu, label: "Mehr")
        }
    }
}

private struct DesignRoundHeaderButton: View {
    let t: ListTheme
    let icon: [SVGElement]
    let label: String

    var body: some View {
        Button(action: {}) {
            SVGIcon(icon, size: 20, color: t.icon, lineWidth: 1.9)
                .frame(width: 44, height: 44)
                .background(CSSBox(shape: Circle(), paint: t.round, border: 1, borderColor: t.roundBorder, shadows: t.roundShadow))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Suche

private struct DesignListSearchField: View {
    let t: ListTheme
    @Binding var query: String

    var body: some View {
        HStack(spacing: 12) {
            SVGIcon(Icon.search, size: 20, color: t.sub, lineWidth: 2)
            TextField("", text: $query,
                      // input::placeholder { color: inherit } → Farbe des Inputs = text
                      prompt: Text("Artikel suchen oder hinzufügen").foregroundStyle(t.text))
                .font(AppFont.dm(15, 400))
                .foregroundStyle(t.text)
                .tint(t.accent)
                .accessibilityLabel("Artikel suchen oder hinzufügen")
            Button(action: {}) {
                SVGIcon(Icon.scan, size: 18, color: t.accentText, lineWidth: 2)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(t.scanBg))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Barcode scannen")
        }
        .padding(.leading, 19)   // 1 border + 18 padding
        .padding(.trailing, 9)   // 1 border + 8 padding
        .frame(height: 52)
        .background(CSSBox(shape: RR(26), paint: .color(t.search), border: 1, borderColor: t.searchBorder, shadows: t.searchShadow))
    }
}

// MARK: - Fortschritt (Glas-Karte, ohne Chips)

private struct DesignProgressHero: View {
    let t: ListTheme
    let state: ListRowState

    private var checked: Bool { state == .checked }

    private var label: String {
        switch state {
        case .empty: "0 von 0 Artikeln"
        case .checked: "1 von 1 Artikel"
        case .normal, .swipe: "0 von 1 Artikeln"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                // Icon-Kachel: 48 + 1px Rahmen (content-box) = 50 × 50
                SVGIcon(Icon.basket, size: 24, color: .white, lineWidth: 1.9)
                    .frame(width: 50, height: 50)
                    .background(CSSBox(
                        shape: RR(16),
                        paint: .linear(160, [stop(.rgba(255, 255, 255, 0.4), 0), stop(.rgba(255, 255, 255, 0.14), 1)]),
                        border: 1, borderColor: .rgba(255, 255, 255, 0.45),
                        shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.6)),
                                  .drop(0, 8, 18, -6, .rgba(0, 30, 34, 0.45))]))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Fortschritt")
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(Color.rgba(255, 255, 255, 0.86))
                    Text(label)
                        .font(AppFont.dm(16, 600))
                        .foregroundStyle(Color.white)
                }

                Spacer(minLength: 0)

                Text("\(Text(checked ? "100" : "0").font(AppFont.outfit(34, 600)).foregroundStyle(Color.white))\(Text(" %").font(AppFont.outfit(17, 600)).foregroundStyle(Color.white.opacity(0.8)))")
                    .tracking(-1.02)                                   // -0.03em × 34 (vererbt)
                    .shadow(color: .rgba(0, 30, 34, 0.25), radius: 6, x: 0, y: 2) // text-shadow 0 2px 12px
            }

            DesignProgressTrack(filled: checked)
        }
        .padding(18)
        .background {
            // Deko-Ebenen (overflow: hidden). Color.clear übernimmt exakt die Kartengröße,
            // die Overlays beeinflussen das Layout nicht.
            Color.clear
                .overlay(alignment: .topLeading) {
                    // left -70, top -110, 300×220, radial-gradient(closest-side, rgba(255,255,255,.45), transparent)
                    CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                                      stops: [stop(.rgba(255, 255, 255, 0.45), 0), stop(.rgba(255, 255, 255, 0), 1)])
                        .frame(width: 300, height: 220)
                        .offset(x: -70, y: -110)
                }
                .overlay(alignment: .bottomTrailing) {
                    // right -50, bottom -80, 200×200 + 1px Rahmen (content-box) = 202×202
                    Circle()
                        .strokeBorder(Color.rgba(255, 255, 255, 0.16), lineWidth: 1)
                        .frame(width: 202, height: 202)
                        .offset(x: 50, y: 80)
                }
                .overlay(alignment: .top) {
                    // Oberkanten-Lichtlinie, 1 pt
                    LinearGradient(stops: [stop(.rgba(255, 255, 255, 0), 0),
                                           stop(.rgba(255, 255, 255, 0.7), 0.5),
                                           stop(.rgba(255, 255, 255, 0), 1)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(height: 1)
                }
                .clipShape(RR(28))
                .allowsHitTesting(false)
        }
        .background(CSSBox(shape: RR(28), paint: t.heroBg, shadows: t.heroShadow))
    }
}

private struct DesignProgressTrack: View {
    let filled: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if filled {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CSSBox(
                        shape: Pill,
                        paint: .linear(90, [stop(.rgba(255, 255, 255, 0.75), 0), stop(.white, 1)]),
                        shadows: [.drop(0, 0, 12, 2, .rgba(255, 255, 255, 0.6)),
                                  .inner(0, -1, 0, 0, .rgba(0, 40, 45, 0.15))]))
            } else {
                // left 1, top 1, 8 × 8
                Color.clear
                    .frame(width: 8, height: 8)
                    .background(CSSBox(shape: Circle(), paint: .color(.white),
                                       shadows: [.drop(0, 0, 10, 3, .rgba(255, 255, 255, 0.75))]))
                    .padding(.leading, 1)
                    .padding(.top, 1)
            }
        }
        .frame(height: 10)
        .frame(maxWidth: .infinity)
        .background(CSSBox(shape: Pill, paint: .color(.rgba(0, 35, 40, 0.3)),
                           shadows: [.inner(0, 1, 3, 0, .rgba(0, 25, 28, 0.5)),
                                     .drop(0, 1, 0, 0, .rgba(255, 255, 255, 0.25))]))
        .accessibilityHidden(true)
    }
}

// MARK: - Tabs

private struct DesignListTabs: View {
    let t: ListTheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 26) {
                tab("Alle", active: true)
                tab("Offen", active: false)
                tab("Erledigt", active: false)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zIndex(1) // Unterstrich liegt über der Trennlinie
            Rectangle()
                .fill(t.line)
                .frame(height: 1)
        }
    }

    private func tab(_ title: String, active: Bool) -> some View {
        Button(action: {}) {
            Text(title)
                .font(AppFont.dm(15, active ? 600 : 500))
                .foregroundStyle(active ? t.accentText : t.sub)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    if active {
                        UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3, style: .circular)
                            .fill(t.accent)
                            .frame(height: 3)
                            .shadow(color: t.accentGlow, radius: 6)   // 0 0 12px rgba(accent,.6)
                            .offset(y: 1)                              // bottom: -1px
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

// MARK: - Sektions-Kopf

private struct DesignSectionHeader: View {
    let t: ListTheme
    let checked: Bool

    var body: some View {
        if checked {
            HStack(spacing: 10) {
                SVGIcon(Icon.check, size: 16, color: t.sub, lineWidth: 2.2)
                    .frame(width: 30, height: 30)
                    .background(CSSBox(shape: RR(10), paint: .color(t.search), border: 1, borderColor: t.searchBorder))
                Text("Abgehakte Artikel")
                    .font(AppFont.outfit(20, 600))
                    .foregroundStyle(t.sub)
                Text("1")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(t.sub)
            }
            .frame(minHeight: 38)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    SVGIcon(Icon.tag, size: 16, color: .white, lineWidth: 2.1)
                        .frame(width: 30, height: 30)
                        .background(CSSBox(shape: RR(10), paint: t.chipGrad, shadows: t.chipShadow))
                    Text("Sonstiges")
                        .font(AppFont.outfit(20, 600))
                        .foregroundStyle(t.text)
                    Text("1")
                        .font(AppFont.dm(14, 600))
                        .foregroundStyle(t.sub)
                }
                Spacer(minLength: 0)
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text("Alle abhaken")
                            .font(AppFont.dm(14, 600))
                            .foregroundStyle(t.accentText)
                        SVGIcon(Icon.chevronRight, size: 16, color: t.accentText, lineWidth: 2.2)
                    }
                    .padding(.vertical, 10)
                    .padding(.leading, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Artikel-Zeile (Karte + Wisch-Aktionen)

private struct DesignItemRow: View {
    let t: ListTheme
    let state: ListRowState

    private var cardOffset: CGFloat {
        switch state {
        case .normal, .empty: 0
        case .checked: -86
        case .swipe: -256
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if state == .checked {
                DesignUndoAction(t: t)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if state == .swipe {
                DesignSwipeActions(t: t)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            DesignItemCard(t: t, checked: state == .checked)
                .offset(x: cardOffset)
        }
        .frame(height: 94)
    }
}

private struct DesignItemCard: View {
    let t: ListTheme
    let checked: Bool

    var body: some View {
        HStack(spacing: 16) {
            SVGIcon(Icon.cameraOff, size: 24, color: t.thumbIcon, lineWidth: 1.7)
                .frame(width: 64, height: 64)
                .background(CSSBox(shape: RR(18), paint: t.thumb, shadows: t.thumbShadow))
                .opacity(checked ? 0.55 : 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Butter")
                    .font(AppFont.outfit(19, 600))
                    .foregroundStyle(t.text)
                    .strikethrough(checked, color: t.text)
                Text("1 Packung")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(t.accentText)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 11)
                    .background(CSSBox(shape: Pill, paint: .color(t.chipBg), shadows: t.chipInset))
            }
            .opacity(checked ? 0.55 : 1)

            Spacer(minLength: 0)

            if checked {
                Button(action: {}) {
                    SVGIcon(Icon.check, size: 20, color: .white, lineWidth: 2.6)
                        .frame(width: 44, height: 44)
                        .background(CSSBox(shape: Circle(), paint: t.fabBg,
                                           shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45)),
                                                     .drop(0, 6, 14, -6, t.accentGlow)]))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Butter ist abgehakt")
            } else {
                Button(action: {}) {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .background(CSSBox(shape: Circle(), paint: .color(t.checkBg), border: 2,
                                           borderColor: t.checkRing, shadows: t.checkShadow))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Butter abhaken")
            }
        }
        .padding(15)                      // 1 border + 14 padding
        .frame(maxWidth: .infinity)
        .frame(height: 94)
        .background(CSSBox(shape: RR(24), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
    }
}

private struct DesignUndoAction: View {
    let t: ListTheme

    var body: some View {
        VStack(spacing: 6) {
            Button(action: {}) {
                SVGIcon(Icon.undo, size: 22, color: .hex("#4A3300"), lineWidth: 2.2)
                    .frame(width: 56, height: 56)
                    .background(alignment: .top) {
                        GlossEllipse(opacity: 0.65)
                            .frame(height: 20)
                            .padding(.horizontal, 10)
                            .padding(.top, 3)
                    }
                    .clipShape(Circle())
                    .background(CSSBox(
                        shape: Circle(),
                        paint: .radialCircle(UnitPoint(x: 0.32, y: 0.24),
                                             [stop(.hex("#FFE38A"), 0), stop(.hex("#F5B521"), 0.55), stop(.hex("#C98A06"), 1)]),
                        shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.6)),
                                  .inner(0, -3, 8, 0, .rgba(120, 70, 0, 0.25)),
                                  .drop(0, 10, 20, -8, .rgba(201, 138, 6, 0.7))]))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zurück auf die Liste")

            Text("Zurück")
                .font(AppFont.dm(12, 600))
                .foregroundStyle(t.sub)
        }
        .frame(width: 76, height: 94)
    }
}

private struct DesignSwipeActions: View {
    let t: ListTheme

    private struct Action: Identifiable {
        let id: String
        let icon: [SVGElement]
        let c1: String
        let c2: String
        let c3: String
        let glow: Color
    }

    private let actions: [Action] = [
        Action(id: "Löschen", icon: Icon.trashAction, c1: "#FF8A80", c2: "#E5484D", c3: "#B4232A",
               glow: .rgba(229, 72, 77, 0.6)),
        Action(id: "Bearbeiten", icon: Icon.pencil, c1: "#8DB8FF", c2: "#3B7BF6", c3: "#1F4FC0",
               glow: .rgba(59, 123, 246, 0.6)),
        Action(id: "Nicht verfügbar", icon: Icon.unavailable, c1: "#FFC08A", c2: "#F08A2C", c3: "#BD5F0E",
               glow: .rgba(240, 138, 44, 0.6))
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(actions) { a in
                VStack(spacing: 6) {
                    Button(action: {}) {
                        SVGIcon(a.icon, size: 22, color: .white, lineWidth: 2.1)
                            .frame(width: 64, height: 52)
                            .background(alignment: .top) {
                                GlossEllipse(opacity: 0.5)
                                    .frame(height: 20)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 2)
                            }
                            .clipShape(RR(20))
                            .background(CSSBox(
                                shape: RR(20),
                                paint: .radialCircle(UnitPoint(x: 0.32, y: 0.2),
                                                     [stop(.hex(a.c1), 0), stop(.hex(a.c2), 0.55), stop(.hex(a.c3), 1)]),
                                shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.5)),
                                          .inner(0, -3, 8, 0, .rgba(0, 0, 0, 0.18)),
                                          .drop(0, 10, 20, -8, a.glow)]))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(a.id)

                    Text(a.id)
                        .font(AppFont.dm(12, 600))
                        .foregroundStyle(t.sub)
                        .lineLimit(1)
                        .fixedSize()           // white-space: nowrap – darf mittig über 76 pt hinausragen
                }
                .frame(width: 76)
            }
        }
        .frame(height: 94)
    }
}

// MARK: - Leer-Zustand

/// Korb ohne Streben (nur Henkel) – Pfade aus dem Leer-Zustand in Hybrid.dc.html.
private let DesignlistEmptyBasket: [SVGElement] = [
    .path("M3 10h18l-1.6 8.2a2 2 0 0 1-2 1.8H6.6a2 2 0 0 1-2-1.8L3 10z"),
    .path("M8 10l3-6M16 10l-3-6")
]

private struct DesignListEmptyState: View {
    let t: ListTheme

    var body: some View {
        VStack(spacing: 12) {
            // 72 × 72, Radius 24, Icon 30 / Strich 1.8
            SVGIcon(DesignlistEmptyBasket, size: 30, color: t.thumbIcon, lineWidth: 1.8)
                .frame(width: 72, height: 72)
                .background(CSSBox(shape: RR(24), paint: t.thumb, shadows: t.thumbShadow))
                .accessibilityHidden(true)

            Text("Die Liste ist leer")
                .font(AppFont.outfit(19, 600))
                .foregroundStyle(t.text)

            // max-width 250, 14 px, line-height 1.45 (= 20,3), zentriert
            Text("Füge Artikel über die Suche oder das Plus hinzu.")
                .font(AppFont.dm(14, 400))
                .foregroundStyle(t.sub)
                .multilineTextAlignment(.center)
                .cssLineHeight(20.3, font: AppFont.ui(.dmSans, 14, 400))
                .frame(maxWidth: 250)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
