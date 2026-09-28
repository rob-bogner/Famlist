/*
 ReceiptDetailSheet.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Kassenzettel – Laden“ (Höhe 790, Board ReceiptDetailMeta): Einkaufsdaten in sechs Kacheln,
   Segment „Artikel“ · „Bon-Foto“, Artikel mit Kategorie und Betrag, „Teilen“ und „Löschen“.

 🔰 Notes for Beginners:
 - Unterzeile 13 sub (Abstand 6); Kacheln ab 14 (ReceiptMetaGrid); Segment ab 14 (SheetSegmentControl);
   darunter scrollt der Inhalt bis zum unteren Rand, Artikel-Karte ab 12, Knöpfe ab 16, weicher Auslauf 70.
 - Ohne gespeicherte Zeilen (Bons vor Migration 029) oder ohne Fotos gibt es kein Segment; gezeigt wird,
   was da ist.
 - Tipp auf eine zugeordnete Zeile öffnet den Preisverlauf (`onOpenHistory`); „Zurück“ dort führt hierher.
 - Knöpfe: 52 hoch, Radius 26, Text 15/600, Icon 18, Abstand 10. „Löschen“ fragt per System-Dialog nach
   (nicht gestaltet, PLAN §9) und fehlt, wenn man den Bon nicht löschen darf (nur Ersteller und Listenbesitzer).
 - Teilen: Die Fotos werden als JPEG-Dateien „Kassenzettel Edeka 24.09.2026 (1).jpg“ geteilt.

 📝 Last Change:
 - Einkaufsdaten und Artikel statt Foto-Fläche und Summenkarte (Einkaufsdaten & Auswertung).
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
    /// Kategorien, Farben und Nachschlagen für ältere Bons.
    var context: ReceiptLineContext = .empty
    /// Tipp auf einen zugeordneten Artikel → Preisverlauf.
    var onOpenHistory: ((String) -> Void)? = nil

    @State private var tab = 0
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
                    Text(ReceiptDetailFormat.subtitle(receipt))
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                    ReceiptMetaGrid(tiles: ReceiptDetailFormat.tiles(receipt, lines: receipt.lines), t: t)
                        .padding(.top, 14)
                    if showsSegment {
                        SheetSegmentControl(titles: ["Artikel", "Bon-Foto"], selection: $tab, t: t,
                                            accessibilityLabel: "Ansicht")
                            .padding(.top, 14)
                    }
                    scrollArea(t: t)
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

    private var hasLines: Bool { !(receipt.lines ?? []).isEmpty }
    private var hasPhotos: Bool { !receipt.photoPaths.isEmpty }
    private var showsSegment: Bool { hasLines && hasPhotos }
    private var showsLines: Bool { hasLines && (!hasPhotos || tab == 0) }

    /// Scrollt bis zum unteren Sheet-Rand, unten weicher Auslauf (SheetFadeScrollArea).
    private func scrollArea(t: ListAccountTokens) -> some View {
        SheetFadeScrollArea(t: t) {
            VStack(spacing: 0) {
                if showsLines {
                    ReceiptLinesCard(rows: ReceiptDetailFormat.rows(context.lines(of: receipt), context: context),
                                     t: t, onOpen: onOpenHistory)
                } else {
                    ReceiptPhotoPager(k: t.k, images: pagerImages, page: $page, onFullscreen: { fullscreen = true })
                }
                buttons(t: t)
                    .padding(.top, 16)
            }
            .padding(.top, 12)
        }
    }

    /// Bis zum Laden je Foto ein Platzhalter (Fläche zeigt Ladeanzeige).
    private var pagerImages: [UIImage?] {
        images.isEmpty ? Array(repeating: nil, count: max(receipt.photoPaths.count, 1)) : images
    }

    private func buttons(t: ListAccountTokens) -> some View {
        let k = t.k
        return HStack(spacing: 10) {
            ShareLink(items: shareFiles) {
                buttonLabel("Teilen", icon: Icon.shareUp, color: k.text)
                    .background(GlassPillBackground(style: .neutral, appearance: k.appearance, accent: k.a, height: 52))
            }
            .buttonStyle(.plain)
            .disabled(shareFiles.isEmpty)
            if canDelete {
                Button(action: { confirmDelete = true }) {
                    buttonLabel("Löschen", icon: Icon.trash, color: t.danger)
                        .background(GlassPillBackground(style: .neutral, appearance: k.appearance, accent: k.a, height: 52))
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
    ReceiptDetailSheet(receipt: ArchivedReceipt.designSamples[0], archive: .preview(), appearance: .light,
                       context: .designSample)
}

#Preview("Kassenzettel – Edeka – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptDetailSheet(receipt: ArchivedReceipt.designSamples[0], archive: .preview(), appearance: .dark,
                       context: .designSample)
}
