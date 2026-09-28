/*
 ReceiptCaptureView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild „Kassenzettel“ (Kamera, immer dunkel): großer Sucher mit Hinweis, Mini-Ansicht der
   Aufnahmen, Mediathek-Knopf, Auslöser und „Prüfen“-Pille mit Anzahl. Lange Bons in mehreren Teilen.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCapture.dc.html (Canvas, Stand 26.09.2026). Werte 1 CSS-px = 1 pt bei 390 × 844.
 - Die Kameravorschau liegt unter dem Design; ohne Kamera (Simulator) bleibt der Verlauf mit Hinweis.
 - „Prüfen“ startet die Erkennung („Kassenzettel prüfen“); ohne Aufnahme ist die Pille gedimmt und inaktiv.
 - Jede Aufnahme erscheint als Vorschaubild (46 × 62); das ✕ löscht sie einzeln.

 📝 Last Change:
 - Live-Rahmen, Auto-Auslösung mit Ring und Schalter, Tippen aufs Vorschaubild öffnet das Vollbild
   (ReceiptCaptureLive.dc.html, freigegeben 28.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import PhotosUI

struct ReceiptCaptureView: View {
    @ObservedObject var flow: ReceiptFlowViewModel
    var onClose: () -> Void = {}
    var onContinue: () -> Void = {}

    @StateObject private var camera = ReceiptCamera()
    @StateObject private var scanner = ReceiptLiveScanner()
    /// Schalter „Auto“/„Manuell“; die Wahl bleibt gespeichert (Standard: Auto).
    @AppStorage("receiptAutoCapture") private var autoCapture = true
    @State private var showsPreview = false
    @State private var previewPage = 0
    /// Zählt Auto-Aufnahmen – Auslöser für die Haptik.
    @State private var autoShots = 0
    @State private var cameraRunning = false
    @State private var torchOn = false
    @State private var picked: [PhotosPickerItem] = []
    @State private var flash = false

    /// Kamera-Screen ist immer dunkel → Akzent aus dem dunklen Theme.
    private let k = SheetTheme(.dark)
    private var count: Int { flow.scans.count }
    private var detected: Bool { cameraRunning && scanner.quad != nil }
    private var hint: String {
        if detected { return autoCapture ? "Bon erkannt · ruhig halten" : "Bon erkannt · Auslöser tippen" }
        return count == 0 ? "Ganzen Bon ins Bild · bei langen Bons in mehreren Teilen"
                          : "Nächsten Teil aufnehmen oder „Prüfen“ tippen"
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Kamerabild-Platzhalter (in der App: Kamera-Vorschau)
            CSSRadialGradient(center: UnitPoint(x: 0.5, y: 0.4), extent: .ellipse(rx: 0.9, ry: 0.6),
                              stops: [stop(.hex("#2B3A3C"), 0), stop(.hex("#121A1B"), 0.7), stop(.hex("#0A0F10"), 1)])
            if cameraRunning {
                CameraPreviewView(session: camera.session, quad: scanner.quad,
                                  stroke: UIColor(k.a.light.color()), fill: UIColor(k.a.base.color(0.12)))
                    .accessibilityHidden(true)
            }

            // Bei 844 pt: Leiste 62, Sucher 126…630, Aufnahmen 646…708, Knöpfe 40 über dem Rand.
            // Der Sucher füllt die ganze freie Höhe: auf größeren iPhones wird er höher, auf kleineren
            // niedriger – alle anderen Abstände bleiben fest. (Vorher war er auf 504 begrenzt, der Rest
            // landete als leere Lücke über den Knöpfen.)
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 62)
                viewfinder
                    .padding(.top, 16)
                    .layoutPriority(1)
                thumbnailStrip
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                controlsRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .task { await startCamera() }
        .onDisappear {
            camera.setDocumentHandler(nil)
            camera.stop()
        }
        .onChange(of: picked) { _, items in importPicked(items) }
        .onChange(of: autoCapture) { _, on in scanner.isAutoEnabled = on }
        .onChange(of: showsPreview) { _, shown in scanner.isPaused = shown }
        .sensoryFeedback(.success, trigger: autoShots)
        .fullScreenCover(isPresented: $showsPreview) {
            ReceiptPagePreviewCover(flow: flow, page: $previewPage, onClose: { showsPreview = false })
        }
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            glassButton(label: "Schließen", action: close) {
                SVGIcon(Icon.close, size: 20, color: .white, lineWidth: 2.2)
            }
            Spacer(minLength: 0)
            Text(count == 0 ? "Kassenzettel" : "Kassenzettel · Teil \(count + 1)")
                .font(AppFont.dm(14, 600))
                .foregroundStyle(Color.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(RR(18).fill(Color.rgba(0, 0, 0, 0.35)))
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            glassButton(label: torchOn ? "Licht aus" : "Licht an", action: toggleTorch) {
                SVGIcon(EKKIcon.flash, size: 20, color: .white, lineWidth: 2)
            }
            .opacity(cameraRunning ? 1 : 0.4)
            .allowsHitTesting(cameraRunning)
        }
        .padding(.horizontal, 20)
    }

    /// Sucher 350 breit (left 20), füllt die freie Höhe (504 bei 844 pt); Ecken 36/Radius 20; Innenfläche 16 eingerückt.
    private var viewfinder: some View {
        ZStack {
            RR(8)
                .fill(Color.rgba(255, 255, 255, 0.05))
                .overlay(RR(8).strokeBorder(Color.rgba(255, 255, 255, 0.28),
                                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                .padding(16)
                .opacity(detected ? 0 : 1)                               // Bon erkannt: Innenfläche aus
            Group {
                ViewfinderCorner(size: 36, radius: 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                ViewfinderCorner(size: 36, radius: 20).rotationEffect(.degrees(90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                ViewfinderCorner(size: 36, radius: 20).rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                ViewfinderCorner(size: 36, radius: 20).rotationEffect(.degrees(270))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .opacity(detected ? 0.35 : 1)                                // Bon erkannt: Ecken treten zurück
        }
        .animation(.easeOut(duration: 0.2), value: detected)
        .opacity(flash ? 0.3 : 1)
        .overlay(alignment: .bottom) {
            ReceiptLiveHint(text: hint, detected: detected, accent: k.a.light.color())
        }
        .overlay {
            if !cameraRunning {
                Text("Kamera nicht verfügbar")
                    .font(AppFont.dm(12, 400))
                    .tracking(0.96)                                      // 0.08em × 12
                    .textCase(.uppercase)
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.25))
                    .fixedSize()
                    .frame(maxHeight: .infinity)                         // mittig im Sucher (Design: y 360 bei 844)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    /// Mini-Ansicht: Vorschaubilder 46 × 62, Abstand 10, links 20. Höhe bleibt auch ohne Aufnahme reserviert,
    /// damit der Sucher nach dem ersten Foto nicht springt.
    private var thumbnailStrip: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(flow.scans.enumerated()), id: \.element.id) { index, page in
                ReceiptPageThumbnail(image: page.image, number: index + 1, isLatest: index == count - 1,
                                     onDelete: {
                                         withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { flow.removePage(at: index) }
                                     },
                                     onOpen: {
                                         previewPage = index
                                         showsPreview = true
                                     })
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            Spacer(minLength: 0)
            // Schalter Auto/Manuell: rechts, unten bündig mit den Aufnahmen (ReceiptCaptureLive).
            ReceiptAutoToggle(isOn: $autoCapture, accent: k.a.light.color())
                .opacity(cameraRunning ? 1 : 0.4)
                .allowsHitTesting(cameraRunning)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 62, alignment: .bottom)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Aufnahmen")
    }

    /// Mediathek (48) · Auslöser (80) · „Prüfen“-Pille; die Seiten je 112 breit, damit der Auslöser mittig bleibt.
    private var controlsRow: some View {
        HStack(spacing: 0) {
            PhotosPicker(selection: $picked, maxSelectionCount: 6, matching: .images) {
                SVGIcon(EKKIcon.gallery, size: 22, color: .white, lineWidth: 1.9)
                    .frame(width: 48, height: 48)
                    .background(GlassCircleBackground(style: .neutralDark, appearance: .dark, accent: AccentScale(Appearance.dark.defaultAccent, .dark), size: 48))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Aus Fotos wählen")
            .frame(width: 112, alignment: .leading)

            Spacer(minLength: 0)
            ReceiptShutterButton(progress: detected && autoCapture ? scanner.progress : nil,
                                 ringColor: k.a.light.color(), action: { capture(automatic: false) })
                .opacity(cameraRunning ? 1 : 0.4)
                .allowsHitTesting(cameraRunning)
            Spacer(minLength: 0)

            ReceiptCheckButton(count: count, theme: k, action: onContinue)
                .frame(width: 112, alignment: .trailing)
        }
        .frame(height: 80)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    /// Glas-Knopf 48, neutral dunkel (Kamera, Canvas-Token gnd).
    private func glassButton<Label: View>(label: String, action: @escaping () -> Void,
                                          @ViewBuilder content: () -> Label) -> some View {
        Button(action: action) {
            content()
                .frame(width: 48, height: 48)
                .background(GlassCircleBackground(style: .neutralDark, appearance: .dark, accent: AccentScale(Appearance.dark.defaultAccent, .dark), size: 48))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    /// Kamera starten und die Live-Erkennung anschließen (Auto löst über `scanner.onAutoCapture` aus).
    private func startCamera() async {
        cameraRunning = await camera.start()
        guard cameraRunning else { return }
        scanner.isAutoEnabled = autoCapture
        scanner.onAutoCapture = { capture(automatic: true) }
        let scanner = scanner
        camera.setDocumentHandler { quad, time in
            Task { @MainActor in scanner.update(quad: quad, at: time) }
        }
    }

    private func capture(automatic: Bool) {
        if !automatic { scanner.didCaptureManually() }
        withAnimation(.easeOut(duration: 0.12)) { flash = true }
        Task {
            if let image = await camera.capture() {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { flow.addPage(image, automatic: automatic) }
                if automatic { autoShots += 1 }
            }
            withAnimation(.easeIn(duration: 0.2)) { flash = false }
        }
    }

    private func toggleTorch() {
        torchOn.toggle()
        camera.setTorch(torchOn)
    }

    private func importPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    flow.addPage(image)
                }
            }
            picked = []
        }
    }

    private func close() {
        camera.stop()
        onClose()
    }
}

#Preview("Kassenzettel", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptCaptureView(flow: ReceiptFlowViewModel(listItemNames: [], catalog: nil,
                                                  priceBook: PriceBook(repository: nil)))
}

#Preview("Kassenzettel – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptCaptureView(flow: ReceiptFlowViewModel(listItemNames: [], catalog: nil,
                                                  priceBook: PriceBook(repository: nil)))
        .preferredColorScheme(.dark)
}
