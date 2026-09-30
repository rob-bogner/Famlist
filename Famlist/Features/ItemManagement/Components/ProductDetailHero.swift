/*
 ProductDetailHero.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kopf von „Produktdetails“ (ProductDetail.dc.html, oben im Sheet): Fläche 390 × 330, unten Radius 40,
   Verlauf 170° (Akzent → Grau → Creme bzw. dunkel), Lichtfleck oben links, Produktbild 300 × 300.

 🔰 Notes for Beginners:
 - Eigene Fotos füllen den ganzen Kopf (390 × 330, unten Radius 40), oben Verlauf Schwarz 28 % → 0 auf 140.
 - Ohne Foto füllt in allen Modi (Ansehen, Bearbeiten, Neu) der gestrichelte Platzhalter „Foto hinzufügen“
   den ganzen Kopf.
 - Unten rechts am Bild (16 vom Rand, 48 rund): beim Ansehen der Glas-Stift „Bearbeiten“,
   beim Bearbeiten mit Foto der Akzent-Knopf „Bild ändern“. Produktbild 300 oben 16, Kachel 200 oben 65.

 📝 Last Change:
 - Freigestellte Fotos auf dem Verlauf, „Artikel wird freigestellt …“, Umschalter „Freigestellt · Original“, Nachbessern (30.09.2026).
 - Platzhalter „Foto hinzufügen“ auch beim Ansehen statt der durchgestrichenen Kamera (Wunsch Robert 30.09.2026).
 - Platzhalter „Foto hinzufügen“ füllt den ganzen Kopf (Kamera-Glaskugel, „Kamera oder Mediathek“) (30.09.2026).
 - Im Sheet: Höhe 330, Stift „Bearbeiten“ unten rechts am Bild.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Header area with the product image of the product detail screen.
struct ProductDetailHero: View {
    let k: SheetTheme
    let image: UIImage?
    let mode: ProductDetailMode
    let onPhoto: () -> Void
    var onEdit: () -> Void = {}
    /// Freistellen läuft: Foto abgedunkelt, unten „Artikel wird freigestellt …“ (PhotoCutoutScan).
    var isProcessing = false
    /// Direkt nach der Aufnahme: Umschalter „Freigestellt · Original“ (true = freigestellt). nil = kein Umschalter.
    var cutoutChoice: Binding<Bool>? = nil
    /// „Nachbessern“ (Glas-Knopf neben dem Umschalter, langer Druck auf das freigestellte Bild).
    var onFix: (() -> Void)? = nil

    static let height: CGFloat = 330

    var body: some View {
        ZStack(alignment: .top) {
            // left -60, top -110, 320 × 240: radial-gradient(closest-side, glow, transparent)
            CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                              stops: [stop(k.isDark ? .rgba(255, 255, 255, 0.08) : .rgba(255, 255, 255, 0.9), 0),
                                      stop(.rgba(255, 255, 255, 0), 1)])
                .frame(width: 320, height: 240)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: -60, y: -110)
                .allowsHitTesting(false)
            content
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(CSSBox(shape: UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40), paint: paint))
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40))
        .overlay { if isProcessing { processingOverlay } }
        .overlay(alignment: .bottomLeading) {
            if let cutoutChoice, mode.isEditing, !isProcessing {
                HStack(spacing: 8) {
                    cutoutSegment(cutoutChoice)
                    if cutoutChoice.wrappedValue, let onFix {
                        GlassCircleButton(style: .neutral, appearance: k.appearance, accent: k.a, icon: ProductDetailIcon.wand,
                                          label: "Nachbessern", size: 40, iconSize: 18, lineWidth: 2, action: onFix)
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 20)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // left 326 / top 266 im 390 × 330-Kopf → 16 vom rechten und unteren Rand
            Group {
                if mode == .view {
                    GlassCircleButton(style: .neutral, appearance: k.appearance, accent: k.a, icon: Icon.pencil,
                                      label: "Bearbeiten", size: 48, iconSize: 20, lineWidth: 2, action: onEdit)
                } else if image != nil {
                    GlassCircleButton(style: .accent, appearance: k.appearance, accent: k.a, icon: Icon.camera,
                                      label: "Bild ändern", size: 48, iconSize: 20, iconColor: .white, lineWidth: 2,
                                      action: onPhoto)
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let image, !isProcessing, ProductCutout.isCutout(image) {
            // Freigestellt: auf dem neutralen Verlauf wie die Produktbilder (264 × 256, oben 34, weicher Schatten).
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 264, height: 256)
                .shadow(color: .rgba(40, 30, 20, k.isDark ? 0.45 : 0.22), radius: 9, x: 0, y: 18)
                .padding(.top, 34)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.45) {
                    guard mode.isEditing, let onFix else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onFix()
                }
                .accessibilityLabel("Produktbild, freigestellt")
        } else if let image {
            // Eigenes Foto füllt den ganzen Kopf (Wunsch Robert 28.09.2026); oben ein leichter Schatten,
            // damit Statusleiste und Glas-Knöpfe auf hellen Fotos lesbar bleiben.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Self.height)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 140)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("Produktbild")
        } else {
            // Platzhalter füllt den ganzen Kopf wie ein Foto (Wunsch Robert 30.09.2026) – in allen Modi, auch beim
            // Ansehen (dort speichert das Sheet das gewählte Foto sofort): gestrichelt, 12 Rand,
            // oben 24 (unter dem Griff), Radius 22 oben / 30 unten; Kamera-Glaskugel 72, Titel + Untertitel.
            let shape = UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 30,
                                               bottomTrailingRadius: 30, topTrailingRadius: 22)
            Button(action: onPhoto) {
                VStack(spacing: 10) {
                    ZStack {
                        GlassCircleBackground(style: .accent, appearance: k.appearance, accent: k.a, size: 72)
                        SVGIcon(Icon.camera, size: 30, color: .white, lineWidth: 1.9)
                    }
                    .frame(width: 72, height: 72)
                    VStack(spacing: 4) {
                        Text("Foto hinzufügen")
                            .font(AppFont.dm(16, 600))
                            .foregroundStyle(k.text)
                        Text("Kamera oder Mediathek")
                            .font(AppFont.dm(13, 400))
                            .foregroundStyle(k.sub)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CSSBox(shape: shape, paint: .color(photoFill), border: 1.5, borderColor: k.dashed,
                                   dash: [4.5, 4.5]))
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .frame(height: Self.height)
            .accessibilityLabel("Foto hinzufügen")
            .accessibilityHint("Kamera oder Mediathek")
        }
    }

    /// Abdunkelung + Glas-Pille „Artikel wird freigestellt …“ mit drehendem Ring.
    private var processingOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
            HStack(spacing: 10) {
                CutoutSpinner()
                Text("Artikel wird freigestellt …")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(GlassPillBackground(style: .neutralDark, appearance: k.appearance, accent: k.a, height: 40))
            .padding(.bottom, 18)
        }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 40, bottomTrailingRadius: 40))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    /// „Freigestellt · Original“: Glas-Hülle 40 (Innenabstand 3), Knöpfe 34, aktiv hell mit Schatten.
    private func cutoutSegment(_ choice: Binding<Bool>) -> some View {
        HStack(spacing: 2) {
            segmentButton("Freigestellt", icon: ProductDetailIcon.sparkle, isOn: choice.wrappedValue) { choice.wrappedValue = true }
            segmentButton("Original", icon: nil, isOn: !choice.wrappedValue) { choice.wrappedValue = false }
        }
        .padding(3)
        .background(Capsule().fill(k.isDark ? Color.rgba(10, 20, 22, 0.55) : Color.rgba(255, 255, 255, 0.72)))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bild")
    }

    private func segmentButton(_ title: String, icon: [SVGElement]?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 6) {
                if let icon { SVGIcon(icon, size: 13, color: k.accentText, lineWidth: 2) }
                Text(title)
                    .font(AppFont.dm(13, isOn ? 600 : 500))
                    .foregroundStyle(isOn ? k.text : k.sub)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background {
                if isOn { Capsule().fill(k.isDark ? Color.rgba(255, 255, 255, 0.14) : .white).shadow(color: .black.opacity(0.12), radius: 1.5, y: 1) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var photoFill: Color { k.isDark ? .rgba(255, 255, 255, 0.04) : .rgba(255, 255, 255, 0.6) }

    /// linear-gradient(170deg, …) wie im Design.
    private var paint: Paint {
        k.isDark
            ? .linear(170, [stop(k.a.base.color(0.2), 0), stop(.hex("#0E1D1F"), 0.6), stop(.hex("#0A1618"), 1)])
            : .linear(170, [stop(k.a.base.color(0.14), 0), stop(.hex("#F2F7F7"), 0.55), stop(.hex("#FBF3E6"), 1)])
    }
}

/// Drehender Ring 16 (Rand 2,5, Viertel weiß) statt System-Spinner.
private struct CutoutSpinner: View {
    @State private var spinning = false

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.25), lineWidth: 2.5)
            .overlay(Circle().trim(from: 0, to: 0.25).stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)))
            .frame(width: 16, height: 16)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}
