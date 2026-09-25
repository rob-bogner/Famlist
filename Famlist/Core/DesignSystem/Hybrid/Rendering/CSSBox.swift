/*
 CSSBox.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - CSS-Box mit CSS-Malreihenfolge: äußere Schatten, Hintergrund, innere Schatten, Rahmen.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Eine vollständige CSS-Box (border-box) mit der CSS-Malreihenfolge:
/// äußere Schatten → Hintergrund → innere Schatten → Rahmen.
/// Der Inhalt liegt immer darüber (per `.background(CSSBox(...))` anhängen).
///
/// • Äußere Schatten werden – wie in CSS – unter der Box selbst ausgestanzt,
///   damit sie durch halbtransparente Flächen nicht durchscheinen.
/// • Innere Schatten werden auf die Padding-Box (innerhalb des Rahmens) begrenzt.
/// • Der Rahmen liegt innerhalb des Frames (box-sizing: border-box).
struct CSSBox<S: InsettableShape>: View {
    let shape: S
    var paint: Paint = .color(.clear)
    var border: CGFloat = 0
    var borderColor: Color = .clear
    var dash: [CGFloat] = []
    var shadows: [BoxShadow] = []

    var body: some View {
        let outer = shadows.filter { !$0.isInset }
        let inner = shadows.filter { $0.isInset }
        ZStack {
            // In CSS liegt der zuerst genannte Schatten oben → rückwärts zeichnen.
            ForEach(Array(outer.indices.reversed()), id: \.self) { i in
                DropShadowLayer(shape: shape, s: outer[i])
            }
            paint.view.clipShape(shape)
            ForEach(Array(inner.indices.reversed()), id: \.self) { i in
                InnerShadowLayer(shape: shape.inset(by: border), s: inner[i])
            }
            if border > 0 {
                shape.strokeBorder(borderColor, style: StrokeStyle(lineWidth: border, dash: dash))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct DropShadowLayer<S: InsettableShape>: View {
    let shape: S
    let s: BoxShadow

    var body: some View {
        ZStack {
            shape.inset(by: -s.spread)
                .fill(s.color)
                .offset(x: s.x, y: s.y)
                .blur(radius: s.blur / 2)
            shape.fill(Color.black).blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

private struct InnerShadowLayer<S: InsettableShape>: View {
    let shape: S
    let s: BoxShadow

    var body: some View {
        let pad = s.blur + abs(s.x) + abs(s.y) + abs(s.spread) + 2
        ZStack {
            Rectangle().fill(s.color).padding(-pad)
            shape.inset(by: s.spread)
                .fill(Color.black)
                .offset(x: s.x, y: s.y)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .blur(radius: s.blur / 2)
        .clipShape(shape)
    }
}

#Preview("CSSBox") {
    CSSBox(shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
           paint: .linear(160, [stop(.hex("#FFFFFF"), 0), stop(.hex("#E8F4F5"), 1)]),
           border: 1, borderColor: .hex("#0FA3AE", 0.3),
           shadows: [.drop(0, 8, 24, 0, .rgba(0, 0, 0, 0.12)), .inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.8))])
        .frame(width: 200, height: 120)
        .padding(40)
}

#Preview("CSSBox – Dark") {
    CSSBox(shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
           paint: .linear(160, [stop(.hex("#1A2A2D"), 0), stop(.hex("#0F1C1E"), 1)]),
           border: 1, borderColor: .hex("#1FC2CC", 0.3),
           shadows: [.drop(0, 8, 24, 0, .rgba(0, 0, 0, 0.5)), .inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08))])
        .frame(width: 200, height: 120)
        .padding(40)
        .background(Color.hex("#0A1416"))
}
