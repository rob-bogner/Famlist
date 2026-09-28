/*
 CameraPreviewView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zeigt die Kameravorschau einer AVCaptureSession bildschirmfüllend (AVCaptureVideoPreviewLayer)
   und darüber den Live-Rahmen um den erkannten Bon.

 🔰 Notes for Beginners:
 - Die Live-Erkennung liefert die Ecken in Sensor-Koordinaten (quer, 0…1). Die Vorschau ist hochkant und
   bildschirmfüllend beschnitten; `layerPointConverted(fromCaptureDevicePoint:)` rechnet das exakt um.
   Deshalb zeichnet diese Ansicht den Rahmen selbst (Core Animation) statt SwiftUI.
 - Rahmen laut ReceiptCaptureLive.dc.html: Linie 3 in Akzent hell, Fläche Akzent 12 %, Ecken-Punkte 10
   (Akzent hell, Rand Weiß 2). Bewegung weich über 0,1 s, damit der Rahmen nicht zappelt.

 📝 Last Change:
 - Live-Rahmen um den erkannten Bon (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Erkannte Ecken in Sensor-Koordinaten; nil = kein Rahmen.
    var quad: ReceiptQuad? = nil
    var stroke: UIColor = .white
    var fill: UIColor = .clear

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        private let frameLayer = CAShapeLayer()
        private let dotsLayer = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            frameLayer.lineWidth = 3
            frameLayer.lineJoin = .round
            dotsLayer.lineWidth = 2
            dotsLayer.strokeColor = UIColor.white.cgColor
            [frameLayer, dotsLayer].forEach {
                $0.opacity = 0
                layer.addSublayer($0)
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        func show(_ quad: ReceiptQuad?, stroke: UIColor, fill: UIColor) {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.1)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .linear))
            frameLayer.strokeColor = stroke.cgColor
            frameLayer.fillColor = fill.cgColor
            dotsLayer.fillColor = stroke.cgColor
            if let quad {
                let points = quad.corners.map { previewLayer.layerPointConverted(fromCaptureDevicePoint: $0) }
                let outline = UIBezierPath()
                outline.move(to: points[0])
                points.dropFirst().forEach { outline.addLine(to: $0) }
                outline.close()
                let dots = UIBezierPath()
                points.forEach { dots.append(UIBezierPath(arcCenter: $0, radius: 5, startAngle: 0, endAngle: .pi * 2, clockwise: true)) }
                frameLayer.path = outline.cgPath
                dotsLayer.path = dots.cgPath
            }
            frameLayer.opacity = quad == nil ? 0 : 1
            dotsLayer.opacity = quad == nil ? 0 : 1
            CATransaction.commit()
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.show(quad, stroke: stroke, fill: fill)
    }
}
