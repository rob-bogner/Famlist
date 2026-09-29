/*
 SwipeableListRow.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Listenkarte in „Meine Listen“ mit Wisch-Aktionen wie bei Artikeln (Design: MyListsSwipeLeft/-Right).

 🔰 Notes for Beginners:
 - Nach rechts: gelber „Favorit“ (Karte +86); durchwischen ab 180 pt schaltet direkt um.
 - Nach links: Löschen (rot) · Umbenennen (blau) · Duplizieren (türkis) · Mitglieder (violett),
   Kreise 48, Spalten 70, Abstand 4 → Karte −300. Geteilte Listen: „Verlassen“ statt „Löschen“.
 - Physik (Einrasten, Gummiband, Geschwindigkeit) aus SwipeRevealPhysics – wie SwipeableItemRow.
 - Tippen öffnet die Liste, langer Druck die Listen-Optionen (unverändert).

 📝 Last Change:
 - Initial creation (Wunsch Robert 29.09.2026: gleiche Wisch-Funktion wie bei Artikeln).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit
import QuartzCore

/// List card with swipe-to-reveal actions (favourite / delete, rename, duplicate, members).
struct SwipeableListRow<Card: View>: View {
    let k: SheetTheme
    let id: String
    let isFavorite: Bool
    /// Eigene Liste → „Löschen“, geteilte Liste → „Verlassen“.
    let isOwner: Bool
    @Binding var openRow: OpenSwipeRow?
    var onTap: () -> Void = {}
    var onLongPress: () -> Void = {}
    var onToggleFavorite: () -> Void = {}
    var onDelete: () -> Void = {}
    var onRename: () -> Void = {}
    var onDuplicate: () -> Void = {}
    var onMembers: () -> Void = {}
    @ViewBuilder let card: () -> Card

    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @State private var isPastThreshold = false
    @State private var isArmed = false
    @State private var minOffset: CGFloat = 0
    @State private var maxOffset: CGFloat = 0
    @State private var minOffsetTime: CFTimeInterval = 0
    @State private var maxOffsetTime: CFTimeInterval = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 4 × 70 + 3 × 4 = 292, dazu 8 Abstand zur Karte.
    private static var revealWidth: CGFloat { 300 }
    private static var leadingWidth: CGFloat { 86 }
    private static var rowHeight: CGFloat { 76 }

    private var physics: SwipeRevealPhysics {
        SwipeRevealPhysics(revealWidth: Self.revealWidth, leadingWidth: Self.leadingWidth)
    }
    private var rest: SwipeRevealPhysics.Rest { openRow?.id == id ? (openRow?.rest ?? .closed) : .closed }
    private var cardOffset: CGFloat {
        isDragging ? physics.offset(rest: rest, translation: dragX) : physics.baseOffset(rest)
    }
    private var snapAnimation: Animation { SwipeableItemRow.snap(reduceMotion: reduceMotion) }

    var body: some View {
        let progress = physics.revealProgress(offset: cardOffset)
        let leading = physics.leadingProgress(offset: cardOffset)
        ZStack(alignment: .topTrailing) {
            LeadingFavoriteAction(labelColor: k.sub, isFavorite: isFavorite, progress: leading, isArmed: isArmed) {
                perform(onToggleFavorite)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .opacity(Double(leading))
            .allowsHitTesting(rest == .leading && !isDragging)

            actions
                .frame(maxHeight: .infinity)
                .opacity(Double(progress))
                .scaleEffect(0.86 + 0.14 * progress, anchor: .trailing)
                .allowsHitTesting(rest == .trailing && !isDragging)

            card()
                .contentShape(Rectangle())
                .onTapGesture { rest == .closed ? onTap() : close() }
                .onLongPressGesture(minimumDuration: 0.45) {
                    guard rest == .closed else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onLongPress()
                }
                .offset(x: cardOffset)
                .onHorizontalPan(onChanged: dragChanged, onEnded: dragEnded)
        }
        .frame(height: Self.rowHeight)
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            Button(isFavorite ? "Kein Favorit" : "Als Favorit markieren", action: onToggleFavorite)
            Button("Umbenennen", action: onRename)
            Button("Duplizieren", action: onDuplicate)
            Button("Mitglieder verwalten", action: onMembers)
            Button(isOwner ? "Löschen" : "Verlassen", action: onDelete)
        }
    }

    private var actions: some View {
        HStack(spacing: 4) {
            action(.delete, isOwner ? "Löschen" : "Verlassen", isOwner ? Icon.trashAction : Icon.logout, onDelete)
            action(.edit, "Umbenennen", Icon.pencil, onRename)
            action(.duplicate, "Duplizieren", Icon.duplicate, onDuplicate)
            action(.members, "Mitglieder", ListAccountIcon.members, onMembers)
        }
    }

    private func action(_ style: GlassActionButton.Style, _ title: String, _ icon: [SVGElement],
                        _ run: @escaping () -> Void) -> some View {
        GlassActionButton(style: style, title: title, icon: icon, labelColor: k.sub, columnHeight: Self.rowHeight,
                          isRound: true, roundSize: 48, columnWidth: 70, labelSize: 11) { perform(run) }
    }

    private func perform(_ action: @escaping () -> Void) {
        close()
        action()
    }

    private func close() {
        withAnimation(snapAnimation) {
            if openRow?.id == id { openRow = nil }
        }
    }

    // MARK: - Gesture

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
            if let other = openRow, other.id != id {
                withAnimation(snapAnimation) { openRow = nil }
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
        let past = offset < -Self.revealWidth / 2
        if past != isPastThreshold {
            isPastThreshold = past
            UISelectionFeedbackGenerator().selectionChanged()
        }
        let armed = rest != .trailing && offset >= physics.fullSwipeDistance
        if armed != isArmed {
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.25, dampingFraction: 0.6)) { isArmed = armed }
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
        withAnimation(snapAnimation) {
            isDragging = false
            isArmed = false
            dragX = 0
            switch outcome {
            case .triggerLeading, .triggerTrailing, .rest(.closed):
                if openRow?.id == id { openRow = nil }
            case .rest(let newRest):
                openRow = OpenSwipeRow(id: id, rest: newRest)
            }
        }
        // Nach rechts durchgewischt: Favorit umschalten.
        if outcome == .triggerLeading { onToggleFavorite() }
    }
}

#Preview {
    @Previewable @State var open: OpenSwipeRow? = OpenSwipeRow(id: "a", rest: .trailing)
    let k = SheetTheme(.light)
    SwipeableListRow(k: k, id: "a", isFavorite: false, isOwner: true, openRow: $open) {
        Text("Drogerie").frame(maxWidth: .infinity, minHeight: 76).background(RR(22).fill(.white))
    }
    .padding(20)
    .background(Color.hex("#F4F8F8"))
}
