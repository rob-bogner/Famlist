/*
 DesignItemRow.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikel-Zeile der statischen Design-Liste: Karte, Zurück-Knopf und Wisch-Aktionen für DesignListScreen.

 📝 Last Change:
 - Aus DesignListScreen.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Artikel-Zeile (Karte + Wisch-Aktionen)

struct DesignItemRow: View {
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

#Preview("Artikelzeile") {
    DesignItemRow(t: ListTheme(.light), state: .normal)
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Artikelzeile – Dark") {
    DesignItemRow(t: ListTheme(.dark), state: .swipe)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
