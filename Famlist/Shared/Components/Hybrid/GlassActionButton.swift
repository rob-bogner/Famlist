/*
 GlassActionButton.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Glas-Aktion hinter wischbaren Karten, darunter Beschriftung 12/600,
   in einer 76 breiten Spalte (Artikel-Karten 94 hoch, Listen-Karten 76 hoch).
 - Artikel-Karten: runder Knopf 56 × 56 (wie „Zurück“), Listen-Karten: 64 × 52, Radius 20.

 🔰 Notes for Beginners:
 - Radialer Verlauf in drei Tönen + Glanz-Ellipse + farbiger Schein; Farben je Stil.
 - Der Knopf selbst ist für VoiceOver versteckt – die Karten bieten dieselben Aktionen als Accessibility-Actions.

 📝 Last Change:
 - `isRound`: runde Knöpfe für die Wisch-Aktionen der Artikel-Karten (Canvas „Wisch-Aktionen“).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Glass action shown behind a swiped card.
struct GlassActionButton: View {
    enum Style {
        case delete, edit, unavailable, favorite, duplicate, members

        var colors: (String, String, String, Color) {
            switch self {
            case .delete:      return ("#FF8A80", "#E5484D", "#B4232A", .rgba(229, 72, 77, 0.6))
            case .edit:        return ("#8DB8FF", "#3B7BF6", "#1F4FC0", .rgba(59, 123, 246, 0.6))
            case .unavailable: return ("#FFC08A", "#F08A2C", "#BD5F0E", .rgba(240, 138, 44, 0.6))
            case .favorite:    return ("#FFE38A", "#F5B521", "#C98A06", .rgba(201, 138, 6, 0.7))
            case .duplicate:   return ("#7FE3D9", "#14B8A6", "#0F766E", .rgba(20, 184, 166, 0.6))
            case .members:     return ("#C9B8FF", "#8B6CFF", "#5B3FD6", .rgba(139, 108, 255, 0.6))
            }
        }
    }

    let style: Style
    let title: String
    let icon: [SVGElement]
    let labelColor: Color
    var columnHeight: CGFloat = 94
    /// Rund 56 × 56 wie der „Zurück“-Knopf (Artikel-Karten); sonst 64 × 52, Radius 20.
    var isRound = false
    /// Durchmesser im runden Stil (Meine Listen: 48).
    var roundSize: CGFloat = 56
    /// Spaltenbreite und Schriftgröße der Beschriftung (Meine Listen: 70 / 11).
    var columnWidth: CGFloat = 76
    var labelSize: CGFloat = 12
    let action: () -> Void

    /// Radius 28 bei 56 × 56 = Kreis; CSSBox braucht eine InsettableShape.
    private var shape: RoundedRectangle { RR(isRound ? roundSize / 2 : 20) }

    var body: some View {
        let (c1, c2, c3, glow) = style.colors
        VStack(spacing: 6) {
            Button(action: action) {
                SVGIcon(icon, size: isRound && roundSize < 56 ? 20 : 22, color: .white, lineWidth: 2.1)
                    .frame(width: isRound ? roundSize : 64, height: isRound ? roundSize : 52)
                    .background(alignment: .top) {
                        GlossEllipse(opacity: isRound ? 0.65 : 0.5)
                            .frame(height: 20)
                            .padding(.horizontal, isRound ? 10 : 8)
                            .padding(.top, isRound ? 3 : 2)
                    }
                    .clipShape(shape)
                    .background(CSSBox(
                        shape: shape,
                        paint: .radialCircle(UnitPoint(x: 0.32, y: 0.2),
                                             [stop(.hex(c1), 0), stop(.hex(c2), 0.55), stop(.hex(c3), 1)]),
                        shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.5)),
                                  .inner(0, -3, 8, 0, .rgba(0, 0, 0, 0.18)),
                                  .drop(0, 10, 20, -8, glow)]))
                    .contentShape(shape)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            Text(title)
                .font(AppFont.dm(labelSize, 600))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize()           // white-space: nowrap – darf mittig über 76 pt hinausragen
        }
        .frame(width: columnWidth, height: columnHeight)
    }
}

#Preview {
    HStack(spacing: 8) {
        GlassActionButton(style: .delete, title: "Löschen", icon: Icon.trashAction, labelColor: .gray, isRound: true) {}
        GlassActionButton(style: .edit, title: "Umbenennen", icon: Icon.pencil, labelColor: .gray, columnHeight: 76) {}
        GlassActionButton(style: .favorite, title: "Standard", icon: Icon.star, labelColor: .gray, columnHeight: 76) {}
    }
    .padding()
}

#Preview("Dark") {
    HStack(spacing: 8) {
        GlassActionButton(style: .delete, title: "Löschen", icon: Icon.trashAction, labelColor: SheetTheme(.dark).sub, isRound: true) {}
        GlassActionButton(style: .edit, title: "Umbenennen", icon: Icon.pencil, labelColor: SheetTheme(.dark).sub, columnHeight: 76) {}
        GlassActionButton(style: .favorite, title: "Standard", icon: Icon.star, labelColor: SheetTheme(.dark).sub, columnHeight: 76) {}
    }
    .padding()
    .background(Color.hex("#0A1416"))
}
