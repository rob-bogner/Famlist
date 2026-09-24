/*
 SwipeableListCard.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Listen-Karte („Meine Listen“) mit eigener Wischgeste und Kontextmenü (Höhe 76):
   • links wischen:  Umbenennen (+ Löschen, nur Besitzer) als Glas-Aktionen
   • rechts wischen: „Standard“ (nur eigene Liste, die noch nicht Standard ist);
                     bis 96 pt offen lassen, ab 180 pt durchwischen → sofort als Standard setzen
   • lange drücken:  Kontextmenü mit denselben Aktionen

 🔰 Notes for Beginners:
 - Gleiche Physik wie die Artikel-Zeilen (SwipeRevealPhysics, onHorizontalPan).
 - Links-Durchwischen löst nichts aus – Löschen nur per Tipp auf den Button und mit Rückfrage.
 - Tippen auf die geschlossene Karte wählt die Liste, auf eine offene Karte schließt sie.

 📝 Last Change:
 - Initial creation („Meine Listen“ im Hybrid-Design).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit
import QuartzCore

/// List card with swipe actions and context menu.
struct SwipeableListCard: View {
    let k: SheetTheme
    let list: ListModel
    let itemCount: Int
    let isSelected: Bool
    let isOwner: Bool
    let isShared: Bool
    @Binding var openRow: OpenSwipeRow?
    var onSelect: () -> Void = {}
    var onRename: () -> Void = {}
    var onDelete: () -> Void = {}
    var onSetDefault: () -> Void = {}

    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @State private var isPastThreshold = false
    @State private var isArmed = false
    @State private var minOffset: CGFloat = 0
    @State private var maxOffset: CGFloat = 0
    @State private var minOffsetTime: CFTimeInterval = 0
    @State private var maxOffsetTime: CFTimeInterval = 0

    private var rowId: String { list.id.uuidString }
    private var canSetDefault: Bool { isOwner && !list.isDefault }
    /// Spalten 76, Abstand 8, 12 Luft zur Karte (wie bei den Artikel-Zeilen).
    private var revealWidth: CGFloat { isOwner ? 76 * 2 + 8 + 12 : 76 + 12 }
    private var physics: SwipeRevealPhysics {
        SwipeRevealPhysics(revealWidth: revealWidth, leadingWidth: canSetDefault ? 96 : 0)
    }
    private var rest: SwipeRevealPhysics.Rest { openRow?.id == rowId ? (openRow?.rest ?? .closed) : .closed }
    private var cardOffset: CGFloat {
        isDragging ? physics.offset(rest: rest, translation: dragX) : physics.baseOffset(rest)
    }

    var body: some View {
        let progress = physics.revealProgress(offset: cardOffset)
        let leading = physics.leadingProgress(offset: cardOffset)
        ZStack(alignment: .topTrailing) {
            if canSetDefault {
                GlassActionButton(style: .favorite, title: "Standard", icon: Icon.star,
                                  labelColor: k.sub, columnHeight: 76) { perform(onSetDefault) }
                    .scaleEffect(isArmed ? 1.12 : 0.7 + 0.3 * leading)
                    .padding(.leading, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(Double(leading))
                    .allowsHitTesting(rest == .leading && !isDragging)
            }
            trailingActions
                .opacity(Double(progress))
                .scaleEffect(0.86 + 0.14 * progress, anchor: .trailing)
                .allowsHitTesting(rest == .trailing && !isDragging)
            card
        }
        .frame(height: 76)
        .accessibilityElement(children: .contain)
        .accessibilityActions { menuActions }
    }

    // MARK: - Parts

    private var card: some View {
        ListSummaryCard(k: k, list: list, itemCount: itemCount, isSelected: isSelected, isShared: isShared)
            .swipeFriendlyTap(isSelected ? "\(list.title), aktive Liste" : "\(list.title) öffnen") {
                if rest == .closed { onSelect() } else { close() }
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .contextMenu { menuActions }
            .offset(x: cardOffset)
            .onHorizontalPan(onChanged: dragChanged, onEnded: dragEnded)
    }

    private var trailingActions: some View {
        HStack(spacing: 8) {
            if isOwner {
                GlassActionButton(style: .delete, title: "Löschen", icon: Icon.trashAction,
                                  labelColor: k.sub, columnHeight: 76) { perform(onDelete) }
            }
            GlassActionButton(style: .edit, title: "Umbenennen", icon: Icon.pencil,
                              labelColor: k.sub, columnHeight: 76) { perform(onRename) }
        }
    }

    /// Kontextmenü und VoiceOver-Aktionen (gleicher Inhalt).
    @ViewBuilder
    private var menuActions: some View {
        Button { onRename() } label: { Label("Umbenennen", systemImage: "pencil") }
        if canSetDefault {
            Button { onSetDefault() } label: { Label("Als Standard setzen", systemImage: "star") }
        }
        if isOwner {
            Button(role: .destructive) { onDelete() } label: { Label("Löschen", systemImage: "trash") }
        }
    }

    private func perform(_ action: @escaping () -> Void) {
        close()
        action()
    }

    private func close() {
        withAnimation(SwipeableItemRow.snap) {
            if openRow?.id == rowId { openRow = nil }
        }
    }

    // MARK: - Gesture

    /// Karte folgt dem Finger 1:1. Eine andere offene Karte schließt sich.
    private func dragChanged(_ translation: CGFloat) {
        let now = CACurrentMediaTime()
        if !isDragging {
            let base = physics.baseOffset(rest)
            minOffset = base
            maxOffset = base
            minOffsetTime = now
            maxOffsetTime = now
            isPastThreshold = rest == .trailing
            isArmed = false
            if let other = openRow, other.id != rowId {
                withAnimation(SwipeableItemRow.snap) { openRow = nil }
            }
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isDragging = true
            dragX = translation
        }
        let offset = physics.offset(rest: rest, translation: translation)
        if offset < minOffset { minOffset = offset; minOffsetTime = now }
        if offset > maxOffset { maxOffset = offset; maxOffsetTime = now }
        updateHaptics(offset: offset)
    }

    private func updateHaptics(offset: CGFloat) {
        let past = offset < -revealWidth / 2
        if past != isPastThreshold {
            isPastThreshold = past
            UISelectionFeedbackGenerator().selectionChanged()
        }
        let armed = canSetDefault && rest != .trailing && offset >= physics.fullSwipeDistance
        if armed != isArmed {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { isArmed = armed }
            UIImpactFeedbackGenerator(style: armed ? .medium : .light).impactOccurred()
        }
    }

    private func dragEnded(_ translation: CGFloat, _ velocity: CGFloat) {
        guard isDragging else { return }
        let now = CACurrentMediaTime()
        let drag = SwipeRevealPhysics.Drag(translation: translation, velocity: velocity,
                                           minOffset: minOffset, maxOffset: maxOffset,
                                           pullBackFromMin: now - minOffsetTime, pullBackFromMax: now - maxOffsetTime)
        let outcome = physics.release(from: rest, drag)
        withAnimation(SwipeableItemRow.snap) {
            isDragging = false
            isArmed = false
            dragX = 0
            switch outcome {
            case .triggerLeading, .triggerTrailing, .rest(.closed):
                if openRow?.id == rowId { openRow = nil }
            case .rest(let newRest):
                openRow = OpenSwipeRow(id: rowId, rest: newRest)
            }
        }
        if outcome == .triggerLeading { onSetDefault() }
    }
}

#Preview {
    @Previewable @State var open: OpenSwipeRow?
    let owner = UUID()
    VStack(spacing: 10) {
        SwipeableListCard(k: SheetTheme(.light),
                          list: ListModel(id: UUID(), ownerId: owner, title: "My List", isDefault: true,
                                          createdAt: Date(), updatedAt: Date()),
                          itemCount: 3, isSelected: true, isOwner: true, isShared: false, openRow: $open)
        SwipeableListCard(k: SheetTheme(.light),
                          list: ListModel(id: UUID(), ownerId: owner, title: "Drogerie", isDefault: false,
                                          createdAt: Date(), updatedAt: Date()),
                          itemCount: 1, isSelected: false, isOwner: true, isShared: false, openRow: $open)
    }
    .padding(20)
}
