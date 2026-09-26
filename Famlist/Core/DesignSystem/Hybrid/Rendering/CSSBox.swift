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
 - Äußere Schatten zeichnet Core Animation (CALayer.shadowPath), nicht SwiftUI-`.blur`: Ändert sich eine Box
   in jedem Frame (z. B. der Listenkopf beim Scrollen), musste SwiftUI jede Unschärfe neu rechnen – die Liste
   stotterte (auf dem Gerät nachgewiesen, 26.09.2026). Ein Schatten mit festem Umriss kostet dagegen fast nichts.

 📝 Last Change:
 - Äußere Schatten über Core Animation statt `.blur` (flüssiges Scrollen mit mitklappendem Listenkopf).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

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
                if outer[i].blur == 0 {
                    HardShadowShape(shape: shape, s: outer[i]).fill(outer[i].color)   // z. B. Fokus-Ring, 1-pt-Kante
                } else {
                    DropShadowLayer(shape: shape, s: outer[i])
                }
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

/// Schatten ohne Unschärfe als reine Fläche: Schattenform minus Box (ausgestanzt wie in CSS), ohne Filter.
private struct HardShadowShape<S: InsettableShape>: Shape {
    let shape: S
    let s: BoxShadow

    func path(in rect: CGRect) -> Path {
        shape.inset(by: -s.spread).path(in: rect)
            .offsetBy(dx: s.x, dy: s.y)
            .subtracting(shape.path(in: rect))
    }
}

/// Äußerer Schatten als CALayer-Schatten mit festem Umriss (`shadowPath`), unter der Box ausgestanzt.
/// Gauß-Radius wie bisher B / 2 (README: `box-shadow` blur B).
private struct DropShadowLayer<S: InsettableShape>: UIViewRepresentable {
    let shape: S
    let s: BoxShadow

    func makeUIView(context: Context) -> ShadowHostView { ShadowHostView() }

    func updateUIView(_ view: ShadowHostView, context: Context) {
        let shape = shape, spread = s.spread
        view.apply(s, shadowPath: { shape.inset(by: -spread).path(in: $0).cgPath },
                   boxPath: { shape.path(in: $0).cgPath })
    }
}

/// Trägt den Schatten auf ihrem eigenen Layer; die Maske (großer Rahmen minus Box, even-odd) stanzt
/// den Schatten unter der Box aus – wie in CSS, damit er durch halbtransparente Flächen nicht durchscheint.
private final class ShadowHostView: UIView {
    private var shadow = BoxShadow(color: .clear)
    private var shadowPathIn: (CGRect) -> CGPath = { CGPath(rect: $0, transform: nil) }
    private var boxPathIn: (CGRect) -> CGPath = { CGPath(rect: $0, transform: nil) }
    private let knockout = CAShapeLayer()

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        knockout.fillRule = .evenOdd
        layer.mask = knockout
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func apply(_ s: BoxShadow, shadowPath: @escaping (CGRect) -> CGPath, boxPath: @escaping (CGRect) -> CGPath) {
        shadow = s
        shadowPathIn = shadowPath
        boxPathIn = boxPath
        layer.shadowColor = UIColor(s.color).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = s.blur / 2
        layer.shadowOffset = CGSize(width: s.x, height: s.y)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)          // Pfade folgen der Box ohne eigene Animation
        layer.shadowPath = shadowPathIn(bounds)
        let pad = shadow.blur * 2 + abs(shadow.x) + abs(shadow.y) + abs(shadow.spread) + 4
        let mask = CGMutablePath()
        mask.addRect(bounds.insetBy(dx: -pad, dy: -pad))
        mask.addPath(boxPathIn(bounds))
        knockout.path = mask
        CATransaction.commit()
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
