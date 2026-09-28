/*
 ReceiptCropCanvas.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fotofläche von „Ecken anpassen“: Originalfoto eingepasst, außerhalb des Vierecks abgedunkelt,
   vier ziehbare Griffe und die Lupe beim Ziehen.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCropEdit.dc.html. Foto eingepasst in die Fläche (links/rechts 20), mittig.
   Abdunkeln Schwarz 55 %, Kante Akzent hell 2,5, Griff Kreis 28 (Weiß, Ring Akzent hell 3), gezogen 34
   (Weiß 15 %, Ring Weiß 3), Tippfläche 44. Lupe 104 bei (28 | 36) bzw. gespiegelt rechts, wenn der Finger links ist.
 - Die Ecken bleiben relativ zum Foto gespeichert (0…1). Ein Griff kann nicht aus dem Foto gezogen werden.
 - Gezogen wird relativ: Die Ecke wandert um den Fingerweg und springt beim Anfassen nicht zur Fingerspitze.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptCropCanvas: View {
    let image: UIImage
    @Binding var quad: ReceiptQuad
    let accent: Color

    @State private var dragging: Int?
    @State private var dragStart: CGPoint?

    private static let cornerNames = ["oben links", "oben rechts", "unten rechts", "unten links"]

    var body: some View {
        GeometryReader { geo in
            let rect = Self.fitRect(imageSize: image.size, in: geo.size, inset: 20)
            let points = (0..<4).map { point(quad[corner: $0], in: rect) }
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .accessibilityLabel("Foto des Kassenzettels")
                scrim(rect: rect, points: points)
                Path { $0.addLines(points); $0.closeSubpath() }
                    .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                    .allowsHitTesting(false)
                ForEach(0..<4, id: \.self) { index in
                    handle(index, at: points[index], rect: rect)
                }
                if let dragging {
                    ReceiptCropLoupe(image: image, imageRect: rect, corners: points, focus: points[dragging], accent: accent)
                        .offset(x: points[dragging].x < geo.size.width / 2 ? geo.size.width - 28 - ReceiptCropLoupe.size : 28,
                                y: 36)
                }
            }
        }
    }

    /// Außerhalb des Vierecks abdunkeln (gerade/ungerade-Regel: Foto minus Viereck).
    private func scrim(rect: CGRect, points: [CGPoint]) -> some View {
        Path { path in
            path.addRect(rect)
            path.addLines(points)
            path.closeSubpath()
        }
        .fill(Color.rgba(0, 0, 0, 0.55), style: FillStyle(eoFill: true))
        .allowsHitTesting(false)
    }

    private func handle(_ index: Int, at position: CGPoint, rect: CGRect) -> some View {
        let active = dragging == index
        let diameter: CGFloat = active ? 34 : 28
        return Circle()
            .fill(active ? Color.rgba(255, 255, 255, 0.15) : Color.white)
            .overlay(Circle().stroke(active ? Color.white : accent, lineWidth: 3))
            .frame(width: diameter, height: diameter)
            .shadow(color: .rgba(0, 0, 0, 0.5), radius: 2, y: 2)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .position(position)
            .gesture(drag(index, rect: rect))
            .accessibilityLabel("Ecke \(Self.cornerNames[index])")
            .accessibilityHint("Zum Verschieben ziehen")
    }

    private func drag(_ index: Int, rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragging != index {
                    dragging = index
                    dragStart = point(quad[corner: index], in: rect)
                }
                guard let start = dragStart else { return }
                let moved = CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height)
                quad[corner: index] = normalized(moved, in: rect)
            }
            .onEnded { _ in
                dragging = nil
                dragStart = nil
            }
    }

    /// Relative Ecke (0…1) → Punkt in der Fläche.
    private func point(_ corner: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + corner.x * rect.width, y: rect.minY + corner.y * rect.height)
    }

    /// Punkt in der Fläche → relative Ecke, auf das Foto begrenzt.
    private func normalized(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: min(max((point.x - rect.minX) / rect.width, 0), 1),
                y: min(max((point.y - rect.minY) / rect.height, 0), 1))
    }

    /// Foto seitenverhältnistreu einpassen, links/rechts `inset` Abstand, mittig.
    static func fitRect(imageSize: CGSize, in size: CGSize, inset: CGFloat) -> CGRect {
        let box = CGSize(width: max(size.width - inset * 2, 1), height: max(size.height, 1))
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: box) }
        let scale = min(box.width / imageSize.width, box.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }
}

#Preview("Fotofläche", traits: .fixedLayout(width: 390, height: 515)) {
    @Previewable @State var quad = ReceiptQuad.inset(by: 0.12)
    ReceiptCropCanvas(image: ReceiptSampleBon.image(), quad: $quad,
                      accent: AccentScale(Appearance.light.defaultAccent, .light).light.color())
        .background(Color.hex("#0A0F10"))
}

#Preview("Fotofläche – Dark", traits: .fixedLayout(width: 390, height: 515)) {
    @Previewable @State var quad = ReceiptQuad.inset(by: 0.12)
    ReceiptCropCanvas(image: ReceiptSampleBon.image(), quad: $quad,
                      accent: AccentScale(Appearance.dark.defaultAccent, .dark).light.color())
        .background(Color.hex("#0A0F10"))
        .preferredColorScheme(.dark)
}
