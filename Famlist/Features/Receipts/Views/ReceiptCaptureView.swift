/*
 ReceiptCaptureView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild „Kassenzettel“ (Kamera, immer dunkel): Sucher, Hinweis, Auslöser, Mediathek-Knopf und
   Seitenzähler. Lange Bons werden in mehreren Teilen aufgenommen.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptCaptureScreen in design-handoff/MyListUI/Screens/ReceiptScreens.swift (ReceiptCapture.dc.html).
 - Die Kameravorschau liegt unter dem Design; ohne Kamera (Simulator) bleibt der Design-Verlauf mit Hinweis.
 - Der Zähler rechts zeigt die Anzahl der Aufnahmen; Tippen darauf startet die Erkennung („Kassenzettel prüfen“).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
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

    var body: some View {
        let hintFont = AppFont.ui(.dmSans, 14, 400)

        ZStack(alignment: .top) {
            // Kamerabild-Platzhalter (in der App: Kamera-Vorschau)
            CSSRadialGradient(center: UnitPoint(x: 0.5, y: 0.4), extent: .ellipse(rx: 0.9, ry: 0.6),
                              stops: [stop(.hex("#2B3A3C"), 0), stop(.hex("#121A1B"), 0.7), stop(.hex("#0A0F10"), 1)])
            if cameraRunning {
                CameraPreviewView(session: camera.session)
                    .accessibilityHidden(true)
            }

            // Senkrecht fließend statt fester Abstände: Bei 844 pt ergeben sich die Designwerte (Leiste 62,
            // Sucher 140…610, Hinweis 630, Auslöser 48 über dem Rand). Auf dem iPhone SE wird nur der Sucher
            // niedriger – vorher lagen seine Ecken über den Knöpfen und der Hinweis wurde abgeschnitten.
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 62)
                viewfinder
                    .padding(.top, 30)
                    .layoutPriority(1)                                    // bekommt den Platz vor dem Abstand
                Text("Ganzen Bon ins Bild · bei langen Bons in mehreren Teilen")
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                    .multilineTextAlignment(.center)
                    .cssLineHeight(20.3, font: hintFont)                 // line-height 1.45
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                Spacer(minLength: 16)
                shutterRow
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
            Text("Kassenzettel")
                .font(AppFont.dm(14, 600))
                .foregroundStyle(Color.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(RR(18).fill(Color.rgba(0, 0, 0, 0.35)))
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

    /// Sucher 250 breit, höchstens 470 hoch, horizontal mittig (left 70 bei 390).
    private var viewfinder: some View {
        ZStack {
            RR(6)
                .fill(Color.rgba(255, 255, 255, 0.06))
                .overlay(RR(6).strokeBorder(Color.rgba(255, 255, 255, 0.3),
                                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                .padding(22)
            ViewfinderCorner().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            ViewfinderCorner().rotationEffect(.degrees(90))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            ViewfinderCorner().rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            ViewfinderCorner().rotationEffect(.degrees(270))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(width: 250)
        .frame(maxHeight: 470)
        .opacity(flash ? 0.3 : 1)
        .accessibilityHidden(true)
        .overlay(alignment: .top) {
            if !cameraRunning {
                Text("Kamera nicht verfügbar")
                    .font(AppFont.dm(12, 400))
                    .tracking(0.96)                                      // 0.08em × 12
                    .textCase(.uppercase)
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.25))
                    .fixedSize()
                    .padding(.top, 190)                                  // Design: y 330 = Sucher 140 + 190
                    .accessibilityHidden(true)
            }
        }
    }

    // Auslöser-Reihe: justify-content: space-around → 6 gleiche Halbabstände
    private var shutterRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            PhotosPicker(selection: $picked, maxSelectionCount: 6, matching: .images) {
                SVGIcon(EKKIcon.gallery, size: 22, color: .white, lineWidth: 1.9)
                    .frame(width: 48, height: 48)
                    .background(CSSBox(shape: Circle(), paint: .color(.rgba(255, 255, 255, 0.14)), border: 1,
                                       borderColor: .rgba(255, 255, 255, 0.28)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Aus Fotos wählen")
            Spacer(minLength: 0)
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
            Spacer(minLength: 0)
            glassButton(label: flow.pages.isEmpty ? "Noch keine Aufnahme" : "\(flow.pages.count) Aufnahmen prüfen",
                        action: onContinue) {
                Text("\(flow.pages.count)")
                    .font(AppFont.dm(14, 700))
                    .foregroundStyle(Color.white)
                    .contentTransition(.numericText())
            }
            .allowsHitTesting(!flow.pages.isEmpty)
            Spacer(minLength: 0)
        }
        .frame(height: 80)
        .padding(.horizontal, 40)
        .padding(.bottom, 48)
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
            onContinue()
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
