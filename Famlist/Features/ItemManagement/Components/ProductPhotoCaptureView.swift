/*
 ProductPhotoCaptureView.swift
 Famlist
 Created on: 01.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Per Foto hinzufügen“ – Kamera (Design: PhotoAddCapture): Live-Bild der Packung, Auslöser für das Foto.
   Nebenbei sucht die Kamera einen Barcode; wird einer gesehen, ist der Katalog-Treffer später sicher.

 🔰 Notes for Beginners:
 - VisionKit `DataScannerViewController` (ab iOS 16, echtes Gerät A12+): erkennt Barcodes live und nimmt mit
   `capturePhoto()` ein Standbild in voller Auflösung auf.
 - Ohne DataScanner (Simulator, ältere Geräte) öffnet ProductDetailSheet stattdessen die System-Kamera.
 - Keine Systemdialoge, keine SF Symbols: Glas-Knöpfe wie beim Barcode-Scanner.

 📝 Last Change:
 - Initial creation (zuverlässigere Erkennung, Wunsch Robert 01.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import VisionKit

struct ProductPhotoCaptureView: View {
    let appearance: Appearance
    /// Foto + (falls gesehen) Barcode.
    let onCapture: (UIImage, String?) -> Void
    let onLibrary: () -> Void
    let onClose: () -> Void

    @StateObject private var camera = PhotoCaptureCamera()
    @State private var torchOn = false
    @State private var isCapturing = false

    static var isAvailable: Bool { BarcodeCameraView.isAvailable }

    var body: some View {
        let k = SheetTheme(appearance)
        let t = ItemExtraTokens(appearance)

        ZStack(alignment: .top) {
            CSSRadialGradient(center: UnitPoint(x: 0.5, y: 0.4), extent: .ellipse(rx: 0.9, ry: 0.6),
                              stops: [stop(.hex("#2B3A3C"), 0), stop(.hex("#121A1B"), 0.7), stop(.hex("#0A0F10"), 1)])
            PhotoCaptureScannerView(camera: camera, torchOn: torchOn)
                .accessibilityHidden(true)

            // Top-Bar: Schließen · Titel · Licht
            HStack(spacing: 0) {
                glassButton(Icon.close, lineWidth: 2.2, label: "Schließen", action: onClose)
                Spacer(minLength: 0)
                Text("Per Foto hinzufügen")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(RR(18).fill(Color.rgba(0, 0, 0, 0.35)))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                glassButton(ItemExtraIcon.bolt, lineWidth: 2, label: torchOn ? "Licht aus" : "Licht an") {
                    torchOn.toggle()
                }
            }
            .padding(.top, 62)
            .padding(.horizontal, 20)

            PhotoCaptureFrame(color: camera.barcode != nil ? t.ok : .white)
                .frame(width: 300, height: 360)
                .padding(.top, 150)
                .animation(.easeOut(duration: 0.2), value: camera.barcode)
                .accessibilityHidden(true)

            status(k: k, t: t)
                .padding(.top, 530)
                .padding(.horizontal, 24)

            // Unten: Mediathek · Auslöser · (Platzhalter)
            HStack(spacing: 0) {
                glassButton(PhotoCaptureIcon.gallery, lineWidth: 1.9, label: "Aus Mediathek wählen", action: onLibrary)
                Spacer(minLength: 0)
                shutter
                Spacer(minLength: 0)
                Color.clear.frame(width: 48, height: 48)
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 44)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onChange(of: camera.barcode) { _, code in
            if code != nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
        .onDisappear { BarcodeCameraView.setTorch(false) }
    }

    @ViewBuilder
    private func status(k: SheetTheme, t: ItemExtraTokens) -> some View {
        if camera.barcode != nil {
            HStack(spacing: 8) {
                SVGIcon(Icon.check, size: 16, color: t.ok, lineWidth: 2.6)
                Text("Barcode erkannt – der Treffer ist sicher")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(RR(20).fill(Color.rgba(0, 0, 0, 0.45)))
            .frame(maxWidth: .infinity)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 6) {
                Text("Vorderseite ins Bild halten")
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.9))
                Text("Tipp: Barcode kurz zeigen – dann ist der Treffer sicher")
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.6))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
        }
    }

    /// Auslöser: Glas 78 mit weißem Kern 60.
    private var shutter: some View {
        Button {
            guard !isCapturing else { return }
            isCapturing = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task { @MainActor in
                if let photo = await camera.capture() {
                    onCapture(photo, camera.barcode)
                } else {
                    isCapturing = false
                }
            }
        } label: {
            Circle()
                .fill(Color.white)
                .frame(width: 60, height: 60)
                .scaleEffect(isCapturing ? 0.86 : 1)
                .frame(width: 78, height: 78)
                .background(GlassCircleBackground(style: .neutralDark, appearance: .dark,
                                                  accent: AccentScale(Appearance.dark.defaultAccent, .dark), size: 78))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isCapturing)
        .accessibilityLabel("Foto aufnehmen")
    }

    /// Glas-Knopf 48, neutral dunkel (wie BarcodeScanSheet).
    private func glassButton(_ icon: [SVGElement], lineWidth: CGFloat, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SVGIcon(icon, size: 20, color: .white, lineWidth: lineWidth)
                .frame(width: 48, height: 48)
                .background(GlassCircleBackground(style: .neutralDark, appearance: .dark,
                                                  accent: AccentScale(Appearance.dark.defaultAccent, .dark), size: 48))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Rahmen

/// Vier abgerundete Ecken (Länge 34, Strich 4); grün, sobald ein Barcode gesehen wurde.
struct PhotoCaptureFrame: View {
    let color: Color

    var body: some View {
        PhotoCaptureCorners()
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            .shadow(color: Color.black.opacity(0.35), radius: 6)
    }
}

private struct PhotoCaptureCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let l: CGFloat = 34, r: CGFloat = 22
        var p = Path()
        // oben links
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // oben rechts
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // unten rechts
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // unten links
        p.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return p
    }
}

enum PhotoCaptureIcon {
    /// Mediathek: Bildrahmen mit Bergen und Sonne.
    static let gallery: [SVGElement] = [
        .rect(3.5, 4.5, 17, 15, 3),
        .path("M3.5 16.5l4.6-4.6a1.6 1.6 0 0 1 2.3 0l5.1 5.1"),
        .path("M13.5 14.5l1.6-1.6a1.6 1.6 0 0 1 2.3 0l3.1 3.1"),
        .circle(15.5, 9, 1.6),
    ]
}

// MARK: - Kamera (VisionKit)

/// Hält den DataScanner für den Auslöser und meldet den zuletzt gesehenen Barcode.
@MainActor
final class PhotoCaptureCamera: ObservableObject {
    @Published var barcode: String?
    weak var scanner: DataScannerViewController?

    func capture() async -> UIImage? {
        guard let scanner else { return nil }
        return try? await scanner.capturePhoto()
    }
}

struct PhotoCaptureScannerView: UIViewControllerRepresentable {
    let camera: PhotoCaptureCamera
    var torchOn: Bool

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false)
        scanner.delegate = context.coordinator
        camera.scanner = scanner
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        BarcodeCameraView.setTorch(torchOn)
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
        BarcodeCameraView.setTorch(false)
    }

    func makeCoordinator() -> Coordinator { Coordinator(camera: camera) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let camera: PhotoCaptureCamera

        init(camera: PhotoCaptureCamera) { self.camera = camera }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let code = barcode.payloadStringValue, !code.isEmpty {
                    camera.barcode = code
                    return
                }
            }
        }
    }
}
