/*
 ReceiptDetailSheet.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Kassenzettel – Laden“ (Höhe 790, ReceiptDetail.dc.html): Fotos zum Blättern, Summenkarte,
   „Teilen“ (Share Sheet mit den Fotos) und „Löschen“.

 🔰 Notes for Beginners:
 - Unterzeile 13 sub (Abstand 6); Foto-Fläche ab 14 (ReceiptPhotoPager); Summenkarte ab 14:
   Padding 14/16, Radius 20, Hero-Verlauf, links 13 weiß .85 + 15/600, rechts Outfit 26/600, Abstand 14.
 - Knöpfe unten (Abstand oben mind. 16, untereinander 10): 52 hoch, Radius 26, Text 15/600, Icon 18.
 - „Löschen“ fragt per System-Dialog nach (nicht gestaltet, PLAN §9) und fehlt, wenn man den Bon nicht
   löschen darf (nur Ersteller und Listenbesitzer).
 - Teilen: Die Fotos werden als JPEG-Dateien „Kassenzettel Edeka 24.09.2026 (1).jpg“ geteilt.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptDetailSheet: View {
    let receipt: ArchivedReceipt
    @ObservedObject var archive: ReceiptArchive
    let appearance: Appearance
    var canDelete = true
    var onBack: () -> Void = {}
    var onClose: () -> Void = {}
    var onDelete: () -> Void = {}

    @State private var images: [UIImage?] = []
    @State private var shareFiles: [URL] = []
    @State private var page = 0
    @State private var fullscreen = false
    @State private var confirmDelete = false

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k
        ListAccountBackdrop(scrim: t.scrimSheet) {
            DesignListScreen(appearance: appearance)
        } content: {
            SheetSurface(k: k, height: 790) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: receipt.storeName, k: k, onClose: onClose, onBack: onBack)
                    Text(ReceiptArchiveViewModel.detailSubtitle(receipt))
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                    ReceiptPhotoPager(k: k, images: pagerImages, page: $page, onFullscreen: { fullscreen = true })
                        .padding(.top, 14)
                    summaryCard(appearance: appearance)
                        .padding(.top, 14)
                    Spacer(minLength: 16)
                    buttons(t: t)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .task(id: receipt.id) { await loadPhotos() }
        .fullScreenCover(isPresented: $fullscreen) {
            ReceiptFullscreenViewer(images: pagerImages, page: $page, onClose: { fullscreen = false })
        }
        .confirmationDialog("Kassenzettel löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive, action: onDelete)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Fotos werden für alle in der Liste gelöscht. Die Preise im Preisverlauf bleiben.")
        }
    }

    /// Bis zum Laden je Foto ein Platzhalter (Fläche zeigt Ladeanzeige).
    private var pagerImages: [UIImage?] {
        images.isEmpty ? Array(repeating: nil, count: max(receipt.photoPaths.count, 1)) : images
    }

    private func summaryCard(appearance: Appearance) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ReceiptArchiveViewModel.detailCounts(receipt))
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                Text("Summe laut Bon")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(ReceiptArchiveViewModel.euro(receipt.total))
                .font(AppFont.outfit(26, 600))
                .foregroundStyle(Color.white)
                .fixedSize()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(CSSBox(shape: RR(20), paint: ListTheme(appearance).heroBg))
        .accessibilityElement(children: .combine)
    }

    private func buttons(t: ListAccountTokens) -> some View {
        let k = t.k
        return HStack(spacing: 10) {
            ShareLink(items: shareFiles) {
                buttonLabel("Teilen", icon: Icon.shareUp, color: k.text)
                    .background(CSSBox(shape: Pill, paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            }
            .buttonStyle(.plain)
            .disabled(shareFiles.isEmpty)
            if canDelete {
                Button(action: { confirmDelete = true }) {
                    buttonLabel("Löschen", icon: Icon.trash, color: t.danger)
                        .background(Capsule().fill(t.dangerSoft))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func buttonLabel(_ title: String, icon: [SVGElement], color: Color) -> some View {
        HStack(spacing: 8) {
            SVGIcon(icon, size: 18, color: color, lineWidth: 2)
            Text(title)
                .font(AppFont.dm(15, 600))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .contentShape(Capsule())
    }

    /// Fotos in voller Größe laden und für „Teilen“ als Dateien bereitlegen.
    private func loadPhotos() async {
        var loaded: [UIImage?] = []
        var files: [URL] = []
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ReceiptShare", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let base = "Kassenzettel \(receipt.storeName) \(ReceiptArchiveViewModel.day(receipt.purchasedAt))"
            .replacingOccurrences(of: "/", with: "-")
        for (index, path) in receipt.photoPaths.enumerated() {
            loaded.append(await archive.image(path: path))
            images = loaded + Array(repeating: nil, count: receipt.photoPaths.count - loaded.count)
            guard let data = await archive.photoData(path: path) else { continue }
            let name = receipt.photoPaths.count > 1 ? "\(base) (\(index + 1)).jpg" : "\(base).jpg"
            let url = folder.appendingPathComponent(name)
            if (try? data.write(to: url, options: .atomic)) != nil { files.append(url) }
        }
        shareFiles = files
    }
}

#Preview("Kassenzettel – Edeka", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptDetailSheet(receipt: ArchivedReceipt.designSamples[0], archive: .preview(), appearance: .light)
}

#Preview("Kassenzettel – Edeka – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptDetailSheet(receipt: ArchivedReceipt.designSamples[0], archive: .preview(), appearance: .dark)
}
