/*
 DockMorphMenu.swift
 Famlist
 Created on: 13.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Plus gedrückt halten → die Dock-Leiste verwandelt sich in „Barcode | Foto“ (Design: Prototyp G „Dock wird
   Auswahlmenü“, FabHoldDock.dc.html). Hier liegen die Ebenen IN der Leiste: die ausgerollte Fläche mit den
   zwei Auswahl-Pillen und die Rolle an ihrer Vorderkante. Die Steuerung (Halten, Einrasten, Wählen) macht DockView.

 🔰 Notes for Beginners:
 - Alles hängt an EINEM Wert `progress` (0…1). Die Views sind `Animatable`: SwiftUI rechnet jeden Frame mit
   dem Zwischenwert, deshalb wandert die Vorderkante gleichmäßig (ein normales withAnimation würde nur
   Anfangs- und Endwert überblenden).
 - Ablauf: Beim Drücken rollt die neue Fläche vom Plus nach links über die Dock-Knöpfe (0,4 s), dann rastet
   sie ein. Vorher loslassen → rollt zurück.
 - Die Pillen stehen von Anfang an an ihrem Platz. Sichtbar ist nur der Teil rechts der Vorderkante; die
   Dock-Knöpfe sind nur links davon sichtbar. Nichts schiebt sich herein.

 📝 Last Change:
 - Initial creation (Wunsch Robert 13.10.2026).
 - Aufrollen statt Hereinschieben, Pillen bündig nach Design (5 pt Rand, 2 pt Abstand), 0,4 s (Wunsch Robert 14.10.2026).
 - Pillen sehen aus wie die gewählte Dock-Pille „Alle abhaken“ (Wunsch Robert 14.10.2026).
 - Rolle und Pillen-Hintergrund als geteilte Bausteine (Mengen-Ausrollen im Barcode-Scanner, 14.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

enum DockMorphOption: Equatable {
    case scan
    case photo

    /// „Foto erkennen“ misst mit Icon 112,7 pt und passt bis 375 pt Bildschirmbreite in die Pille (124,5 pt).
    var title: String { self == .scan ? "Barcode" : "Foto erkennen" }
    var accessibilityTitle: String { self == .scan ? "Barcode scannen" : "Per Foto erkennen" }
    var icon: [SVGElement] { self == .scan ? Icon.scan : DockMorphIcon.photo }
}

enum DockMorphIcon {
    /// Kamera (wie „Per Foto hinzufügen“).
    static let photo: [SVGElement] = [
        .path("M4 8.5A1.5 1.5 0 0 1 5.5 7h2.3l1.4-2h5.6l1.4 2h2.3A1.5 1.5 0 0 1 20 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5z"),
        .circle(12, 12.8, 3.2),
    ]
}

/// Maße der Rolle an der Vorderkante.
enum DockMorphRoll {
    static func clamp(_ v: CGFloat) -> CGFloat { min(1, max(0, v)) }
    /// Die Rolle wird beim Ausrollen dünner: 18 → 6.
    static func thickness(_ p: CGFloat) -> CGFloat { 18 - 12 * clamp(p) }
    /// Blendet am Anfang ein und kurz vor dem Ende aus.
    static func opacity(_ p: CGFloat) -> Double { Double(clamp(p * 12) * clamp((1 - p) * 8)) }
}

// MARK: - Dock-Knöpfe werden überrollt

/// Dock-Knöpfe: sichtbar bleibt nur der Teil links der Vorderkante.
struct DockItemsRollMask: ViewModifier, Animatable {
    var progress: CGFloat
    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle().frame(width: geo.size.width * (1 - DockMorphRoll.clamp(progress)))
            }
        }
    }
}

// MARK: - Ebene in der Leiste

struct DockMorphLayer: View, Animatable {
    let t: ListTheme
    var progress: CGFloat
    var hover: DockMorphOption?
    var onSelect: (DockMorphOption) -> Void

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { geo in
            let p = DockMorphRoll.clamp(progress)
            let front = geo.size.width * (1 - p)                  // Vorderkante: läuft vom Plus nach links
            ZStack(alignment: .leading) {
                surface
                    .mask(alignment: .trailing) { Rectangle().frame(width: geo.size.width - front) }
                roll(p, height: geo.size.height)
                    .offset(x: front - DockMorphRoll.thickness(p) / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .allowsHitTesting(progress > 0.6)
    }

    /// Ausgerollte Fläche (FabHold.dc.html, Variante „dock“): dunkle Leiste rgba(6,14,16,.97), darauf die Pillen
    /// ab Rahmen 5 (hier 4, der Rahmen der Leiste liegt außen), Abstand 2, Höhe 54. Aussehen der Pillen: siehe `segment`.
    private var surface: some View {
        HStack(spacing: 2) {
            segment(.scan)
            segment(.photo)
        }
        .padding(4)
        .background(Color.rgba(6, 14, 16, 0.97))
    }

    /// Die Rolle an der Vorderkante (geteilt mit dem Mengen-Ausrollen im Barcode-Scanner).
    private func roll(_ p: CGFloat, height: CGFloat) -> some View {
        DockMorphRollEdge(accent: t.a, progress: p, height: height)
    }

    /// Pille wie die gewählte Dock-Pille „Alle abhaken“ (DockActionButton + hiAccent in DockItemModel):
    /// Icon 18 / 2.2, Text 13 / 600, Verlauf Akzent .55 → .22, Rahmen weiß .22, inset 0 -1 0 schwarz .2,
    /// Schein 0 0 16 Akzent .3. Finger darüber: Verlauf .75 → .35, Schein .45.
    private func segment(_ option: DockMorphOption) -> some View {
        let on = hover == option
        return Button { onSelect(option) } label: {
            HStack(spacing: 6) {
                SVGIcon(option.icon, size: 18, color: .white, lineWidth: 2.2)
                Text(option.title)
                    .font(AppFont.dm(13, 600, scaled: false))
                    .tracking(-0.065)                  // -0.005em × 13
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(DockMorphPillBackground(accent: t.a, on: on))
            .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: on)
        .accessibilityLabel(option.accessibilityTitle)
    }
}

// MARK: - Geteilte Bausteine (Dock · Mengen-Ausrollen im Barcode-Scanner)

/// Die Rolle an der Vorderkante: ein Zylinder über die ganze Höhe, mit Schlagschatten auf die ausgerollte Fläche.
/// `shadowX` zeigt zur ausgerollten Fläche: +4 im Dock (Fläche rechts der Kante), −4 beim Ausrollen nach rechts.
struct DockMorphRollEdge: View {
    let accent: AccentScale
    let progress: CGFloat
    let height: CGFloat
    var shadowX: CGFloat = 4

    var body: some View {
        Rectangle()
            .fill(LinearGradient(stops: [stop(.rgba(0, 0, 0, 0.45), 0),
                                         stop(accent.base.color(), 0.3),
                                         stop(.rgba(255, 255, 255, 0.85), 0.5),
                                         stop(accent.base.color(), 0.72),
                                         stop(.rgba(0, 0, 0, 0.5), 1)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: DockMorphRoll.thickness(progress), height: height)
            .shadow(color: .rgba(0, 0, 0, 0.45), radius: 5, x: shadowX, y: 0)
            .opacity(DockMorphRoll.opacity(progress))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Pillen-Hintergrund wie die gewählte Dock-Pille „Alle abhaken“: Verlauf Akzent .55 → .22, Rahmen weiß .22,
/// inset 0 -1 0 schwarz .2, Schein 0 0 16 Akzent .3. Finger darüber (`on`): Verlauf .75 → .35, Schein .45.
struct DockMorphPillBackground: View {
    let accent: AccentScale
    let on: Bool

    var body: some View {
        CSSBox(shape: Pill,
               paint: .linear(180, [stop(accent.base.color(on ? 0.75 : 0.55), 0),
                                    stop(accent.base.color(on ? 0.35 : 0.22), 1)]),
               border: 1, borderColor: .rgba(255, 255, 255, 0.22),
               shadows: [.inner(0, -1, 0, 0, .rgba(0, 0, 0, 0.2)),
                         .drop(0, 0, 16, 0, accent.base.color(on ? 0.45 : 0.3))])
    }
}

/// Vorschau-Hülle: Leiste 276 × 62 mit der Ebene bei einem festen Fortschritt.
private struct DockMorphLayerPreview: View {
    let appearance: Appearance
    let progress: CGFloat
    var hover: DockMorphOption? = nil

    var body: some View {
        DockMorphLayer(t: ListTheme(appearance), progress: progress, hover: hover, onSelect: { _ in })
            .frame(width: 274, height: 62)
            .background(Color.rgba(6, 14, 16, 0.9))
            .clipShape(Pill)
            .padding(20)
            .background(appearance == .dark ? Color.hex("#0A1416") : Color.hex("#F4F7F7"))
    }
}

#Preview("DockMorphLayer") {
    VStack(spacing: 0) {
        DockMorphLayerPreview(appearance: .light, progress: 0.5)
        DockMorphLayerPreview(appearance: .light, progress: 1, hover: .photo)
    }
}

#Preview("DockMorphLayer – Dark") {
    VStack(spacing: 0) {
        DockMorphLayerPreview(appearance: .dark, progress: 0.5)
        DockMorphLayerPreview(appearance: .dark, progress: 1, hover: .scan)
    }
}
