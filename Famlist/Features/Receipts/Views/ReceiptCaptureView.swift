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
 - Sucher füllt die freie Höhe (504 bei 844 pt, auf größeren iPhones höher) statt fest max. 504.
 ------------------------------------------------------------------------
 */

import SwiftUI
import PhotosUI

struct ReceiptCaptureView: View {
    @ObservedObject var flow: ReceiptFlowViewModel
    var onClose: () -> Void = {}
    var onContinue: () -> Void = {}

    @StateObject private var camera = ReceiptCamera()
    @State private var cameraRunning = false
    @State private var torchOn = false
    @State private var picked: [PhotosPickerItem] = []
    @State private var flash = false

    /// Kamera-Screen ist immer dunkel → Akzent aus dem dunklen Theme.
    private let k = SheetTheme(.dark)
    private var count: Int { flow.pages.count }

    var body: some View {
        ZStack(alignment: .top) {
            // Kamerabild-Platzhalter (in der App: Kamera-Vorschau)
            CSSRadialGradient(center: UnitPoint(x: 0.5, y: 0.4), extent: .ellipse(rx: 0.9, ry: 0.6),
                              stops: [stop(.hex("#2B3A3C"), 0), stop(.hex("#121A1B"), 0.7), stop(.hex("#0A0F10"), 1)])
            if cameraRunning {
                CameraPreviewView(session: camera.session)
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
        .task { cameraRunning = await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: picked) { _, items in importPicked(items) }
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
            ViewfinderCorner(size: 36, radius: 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            ViewfinderCorner(size: 36, radius: 20).rotationEffect(.degrees(90))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            ViewfinderCorner(size: 36, radius: 20).rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            ViewfinderCorner(size: 36, radius: 20).rotationEffect(.degrees(270))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .opacity(flash ? 0.3 : 1)
        .overlay(alignment: .bottom) {
            // Hinweis im Sucher: links/rechts 32, unten 30, DM Sans 13, Zeilenhöhe 1.4
            Text(count == 0 ? "Ganzen Bon ins Bild · bei langen Bons in mehreren Teilen"
                            : "Nächsten Teil aufnehmen oder „Prüfen“ tippen")
                .font(AppFont.dm(13, 400))
                .foregroundStyle(Color.rgba(255, 255, 255, 0.8))
                .multilineTextAlignment(.center)
                .cssLineHeight(18.2, font: AppFont.ui(.dmSans, 13, 400))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
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
            ForEach(Array(flow.pages.enumerated()), id: \.offset) { index, image in
                ReceiptPageThumbnail(image: image, number: index + 1, isLatest: index == count - 1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { flow.removePage(at: index) }
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
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
                    .background(CSSBox(shape: Circle(), paint: .color(.rgba(255, 255, 255, 0.14)), border: 1,
                                       borderColor: .rgba(255, 255, 255, 0.28)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Aus Fotos wählen")
            .frame(width: 112, alignment: .leading)

            Spacer(minLength: 0)
            Button(action: capture) {
                // 80 border-box, Rahmen 4 weiß .9, Padding 5 → Innenkreis 62
                Circle()
                    .fill(Color.white)
                    .padding(9)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().strokeBorder(Color.rgba(255, 255, 255, 0.9), lineWidth: 4))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(cameraRunning ? 1 : 0.4)
            .allowsHitTesting(cameraRunning)
            .accessibilityLabel("Foto aufnehmen")
            Spacer(minLength: 0)

            checkButton
                .frame(width: 112, alignment: .trailing)
        }
        .frame(height: 80)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    /// „Prüfen“ + Anzahl: Pille 52 hoch, Padding 16/12, Abstand 8, Glanz oben; ohne Aufnahme Glas, 45 %.
    private var checkButton: some View {
        let enabled = count > 0
        return Button(action: onContinue) {
            HStack(spacing: 8) {
                Text("Prüfen")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(enabled ? k.ctaText : Color.white)
                Text("\(count)")
                    .font(AppFont.dm(13, 700))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText())
                    .padding(.horizontal, 6)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Capsule().fill(enabled ? Color.rgba(4, 38, 42, 0.85) : Color.rgba(255, 255, 255, 0.2)))
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(height: 52)
            .background(alignment: .top) {
                if enabled {
                    GlossEllipse(opacity: 0.4)
                        .frame(height: 18)
                        .padding(.horizontal, 14)
                        .padding(.top, 2)
                }
            }
            .clipShape(Capsule())
            .background(CSSBox(shape: Capsule(),
                               paint: enabled ? k.ctaPaint : .color(.rgba(255, 255, 255, 0.14)),
                               shadows: enabled ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.5)),
                                                   .drop(0, 10, 22, -10, k.a.base.color(0.8))] : []))
            .contentShape(Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .animation(.easeOut(duration: 0.2), value: enabled)
        .accessibilityLabel(enabled ? (count == 1 ? "1 Aufnahme prüfen und Preise auslesen"
                                                  : "\(count) Aufnahmen prüfen und Preise auslesen")
                                    : "Prüfen – erst ein Foto aufnehmen")
    }

    /// Glas-Kreis 48 (border-box): weiß .14, Rahmen 1 weiß .28.
    private func glassButton<Label: View>(label: String, action: @escaping () -> Void,
                                          @ViewBuilder content: () -> Label) -> some View {
        Button(action: action) {
            content()
                .frame(width: 48, height: 48)
                .background(CSSBox(shape: Circle(), paint: .color(.rgba(255, 255, 255, 0.14)), border: 1,
                                   borderColor: .rgba(255, 255, 255, 0.28)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    private func capture() {
        withAnimation(.easeOut(duration: 0.12)) { flash = true }
        Task {
            if let image = await camera.capture() {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { flow.addPage(image) }
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
