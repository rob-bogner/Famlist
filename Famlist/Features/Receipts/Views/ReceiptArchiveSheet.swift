/*
 ReceiptArchiveSheet.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Kassenzettel“ (Höhe 790, ReceiptArchive.dc.html): gespeicherte Bons nach Monat gruppiert,
   Filterchips nach Laden, Zurück → Einstellungen, ✕ schließt, Tippen → Detail.

 🔰 Notes for Beginners:
 - Unterzeile 13 sub (Abstand 6), Chips ab 14: Höhe 34, Padding 0 14, Radius 17, Abstand 6, Text 13/600;
   aktiv CTA-Verlauf/ctaText, sonst Akzent mit 10 % (dunkel 16 %) und accentText.
 - Monat: Abschnittstitel (Abstand 18 bzw. 22), Karte ab 10: Radius 20, card, Rahmen 1 cardBorder, Schatten.
 - Beim Öffnen wird die Warteschlange gesendet und der Server-Stand geladen (offline bleibt der letzte Stand).
 - Leeres Archiv: nicht gestaltet → schlichter Hinweis in sub (PLAN §9).

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptArchiveSheet: View {
    /// Einmal je geöffnetem Archiv (Filter bleibt beim Neuzeichnen der Liste erhalten).
    @StateObject private var viewModel: ReceiptArchiveViewModel
    @ObservedObject var archive: ReceiptArchive
    let appearance: Appearance
    var onBack: () -> Void
    var onClose: () -> Void
    var onOpen: (ArchivedReceipt) -> Void

    init(archive: ReceiptArchive, appearance: Appearance, currentUserId: UUID? = nil, ownedListIds: Set<UUID> = [],
         onBack: @escaping () -> Void = {}, onClose: @escaping () -> Void = {},
         onOpen: @escaping (ArchivedReceipt) -> Void = { _ in }) {
        _viewModel = StateObject(wrappedValue: ReceiptArchiveViewModel(archive: archive, currentUserId: currentUserId,
                                                                       ownedListIds: ownedListIds))
        self.archive = archive
        self.appearance = appearance
        self.onBack = onBack
        self.onClose = onClose
        self.onOpen = onOpen
    }

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k
        ListAccountBackdrop(scrim: t.scrimSheet) {
            DesignListScreen(appearance: appearance)
        } content: {
            SheetSurface(k: k, height: 790) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Kassenzettel", k: k, onClose: onClose, onBack: onBack)
                    Text(viewModel.subtitle)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                        .padding(.horizontal, 4)
                        .padding(.top, 6)
                    filterChips(k: k)
                        .padding(.top, 14)
                    content(t: t)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .task { await archive.refresh() }
        .onChange(of: archive.receipts) { _, _ in viewModel.validateFilter() }
    }

    private func filterChips(k: SheetTheme) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.filters, id: \.self) { store in
                    chip(store, on: store == viewModel.selectedStore, k: k)
                }
            }
        }
        .frame(height: 34)
    }

    private func chip(_ store: String, on: Bool, k: SheetTheme) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { viewModel.selectedStore = store } }) {
            Text(store)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(on ? k.ctaText : k.accentText)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(CSSBox(shape: Pill, paint: on ? k.ctaPaint : .color(k.a.base.color(k.isDark ? 0.16 : 0.1))))
                .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder
    private func content(t: ListAccountTokens) -> some View {
        let groups = viewModel.groups
        if groups.isEmpty {
            Text(archive.isLoading ? "Wird geladen …" : "Noch keine Kassenzettel gespeichert.")
                .font(AppFont.dm(13, 400))
                .foregroundStyle(t.k.sub)
                .padding(.horizontal, 4)
                .padding(.top, 18)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        monthSection(group, t: t)
                            .padding(.top, index == 0 ? 18 : 22)
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func monthSection(_ group: ReceiptArchiveViewModel.MonthGroup, t: ListAccountTokens) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ListAccountSectionLabel(text: group.title, t: t)
            VStack(spacing: 0) {
                ForEach(Array(group.receipts.enumerated()), id: \.element.id) { index, receipt in
                    ReceiptArchiveRow(receipt: receipt, t: t, archive: archive, hasTopLine: index > 0,
                                      onOpen: { onOpen(receipt) })
                }
            }
            .padding(1)                                   // Rahmen
            .clipShape(RR(20))
            .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder,
                               shadows: t.cardShadow))
        }
    }
}

#Preview("Kassenzettel", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptArchiveSheet(archive: .preview(), appearance: .light)
}

#Preview("Kassenzettel – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptArchiveSheet(archive: .preview(), appearance: .dark)
}
