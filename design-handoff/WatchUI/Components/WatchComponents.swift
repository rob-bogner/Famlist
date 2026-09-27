/*
 WatchComponents.swift
 Famlist Watch – Design-Referenz

 Wiederkehrende Bausteine aus Watch*.dc.html. Bei der Übernahme: eine Type je Datei (Projektregel).
 */

import SwiftUI

/// Bildschirm-Hintergrund: Schwarz + Akzent-Schein von unten.
struct WatchBackground: View {
    let w: WatchTheme
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [w.glow, .clear], center: UnitPoint(x: 0.5, y: 1.1), startRadius: 0, endRadius: 150)
                .scaleEffect(x: 1.2 / 0.7, y: 1, anchor: UnitPoint(x: 0.5, y: 1.1))   // Ellipse 120 % × 70 %
        }
        .ignoresSafeArea()
    }
}

/// Karten-Fläche (Radius 18, bzw. 20/24 je Screen).
struct WatchCardBackground: View {
    let w: WatchTheme
    var radius: CGFloat = 18
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(LinearGradient(colors: [w.cardTop, w.cardBottom], startPoint: .top, endPoint: .bottom))
            .overlay(shape.strokeBorder(w.cardBorder, lineWidth: 1))
            .overlay(alignment: .top) {                                   // inset 0 1 0 weiß .12
                shape.stroke(w.cardInnerHighlight, lineWidth: 1).mask(Rectangle().frame(height: 2)).padding(.horizontal, radius / 2)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
    }
}

/// Fortschrittsbalken: 5 hoch, Radius 3, Spur weiß .14, Füllung light → accent.
struct WatchProgressBar: View {
    let w: WatchTheme
    let fraction: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(w.track)
                Capsule().fill(w.fill).frame(width: g.size.width * max(0, min(fraction, 1)))
            }
        }
        .frame(height: 5)
    }
}

/// Ring-Anzeige (Listen: 30 pt / Strich 3,5; Komplikation: 38 pt / Strich 4). Start oben, im Uhrzeigersinn.
struct WatchRing: View {
    let w: WatchTheme
    let fraction: Double
    var size: CGFloat = 30
    var lineWidth: CGFloat = 3.5
    var label: String? = nil
    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.16), lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(w.accentText, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let label {
                Text(label).font(WatchFont.dm(11, .semibold)).foregroundStyle(.white)
            }
        }
        .padding(lineWidth / 2)
        .frame(width: size, height: size)
    }
}

/// Abschnittstitel: DM 11/600, Sperrung 0.06em, Großbuchstaben, weiß .6, Innenabstand oben 4 / seitlich 4.
struct WatchSectionLabel: View {
    let w: WatchTheme
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(WatchFont.dm(11, .semibold))
            .tracking(0.66)
            .foregroundStyle(w.sub)
            .padding(.horizontal, 4)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Artikelzeile: 46 hoch, Innenabstand 12, Radius 18, Kreis 26 (offen: Rand 2 ring; erledigt: Orb + Haken 14/3),
/// Name DM 15/500, Menge DM 12 weiß .6, Abstand 10. Erledigt: ganze Zeile 55 %, Name durchgestrichen.
struct WatchItemRow: View {
    let w: WatchTheme
    let name: String
    let quantity: String
    var isChecked = false
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if isChecked {
                    Circle().fill(w.orb(accentStop: 0.55))
                        .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1).mask(Rectangle().frame(height: 2).frame(maxHeight: .infinity, alignment: .top)))
                    Image(systemName: "checkmark")                     // Referenz: SVG-Pfad M5 12.5l4.5 4.5L19 7.5, Strich 3
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                } else {
                    Circle().strokeBorder(w.ring, lineWidth: 2)
                }
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(WatchFont.dm(15, .medium)).strikethrough(isChecked).lineLimit(1)
                Text(quantity).font(WatchFont.dm(12)).foregroundStyle(w.sub).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(WatchCardBackground(w: w))
        .opacity(isChecked ? 0.55 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

/// Runder Glas-Knopf 42 (Rand 1 glassBorder), Icon 20 weiß.
struct WatchGlassButton: View {
    let w: WatchTheme
    let systemImage: String
    let label: String
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Circle().fill(LinearGradient(colors: [w.glassTop, w.glassBottom], startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(w.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// FAB 42: Orb-Verlauf, Glanz oben (left/right 8, top 3, h 15), Plus 20 / Strich 2,8, Schein rgba(accent,.35).
struct WatchFab: View {
    let w: WatchTheme
    var label = "Artikel hinzufügen"
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(w.orb())
                Ellipse().fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 26, height: 15).offset(y: -10.5)
                Image(systemName: "plus").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .shadow(color: w.fabGlow, radius: 7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
