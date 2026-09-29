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
 - Ohne Foto: beim Bearbeiten/Neu die gestrichelte Kachel „Foto hinzufügen“ (200, Radius 50),
   beim Ansehen dieselbe Kachel ohne Strichlinie mit durchgestrichener Kamera.
 - Unten rechts am Bild (16 vom Rand, 48 rund): beim Ansehen der Glas-Stift „Bearbeiten“,
   beim Bearbeiten mit Foto der Akzent-Knopf „Bild ändern“. Produktbild 300 oben 16, Kachel 200 oben 65.

 📝 Last Change:
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
        if let image {
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
        } else if mode.isEditing {
            Button(action: onPhoto) {
                VStack(spacing: 8) {
                    SVGIcon(Icon.camera, size: 34, color: k.accentText, lineWidth: 1.7)
                    Text("Foto hinzufügen")
                        .font(AppFont.dm(14, 600))
                        .foregroundStyle(k.sub)
                }
                .frame(width: 200, height: 200)
                .background(CSSBox(shape: RR(50), paint: .color(photoFill), border: 1.5, borderColor: k.dashed,
                                   dash: [4.5, 4.5]))
                .contentShape(RR(50))
            }
            .buttonStyle(.plain)
            .padding(.top, 65)
            .accessibilityLabel("Foto hinzufügen")
        } else {
            SVGIcon(Icon.cameraOff, size: 56, color: k.isDark ? k.a.light.color() : .hex("#8AA0A4"), lineWidth: 1.4)
                .frame(width: 200, height: 200)
                .background(CSSBox(shape: RR(50), paint: .color(photoFill)))
                .padding(.top, 65)
                .accessibilityLabel("Kein Produktbild vorhanden")
        }
    }

    private var photoFill: Color { k.isDark ? .rgba(255, 255, 255, 0.04) : .rgba(255, 255, 255, 0.6) }

    /// linear-gradient(170deg, …) wie im Design.
    private var paint: Paint {
        k.isDark
            ? .linear(170, [stop(k.a.base.color(0.2), 0), stop(.hex("#0E1D1F"), 0.6), stop(.hex("#0A1618"), 1)])
            : .linear(170, [stop(k.a.base.color(0.14), 0), stop(.hex("#F2F7F7"), 0.55), stop(.hex("#FBF3E6"), 1)])
    }
}
