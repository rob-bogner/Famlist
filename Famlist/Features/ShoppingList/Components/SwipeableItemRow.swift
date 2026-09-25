/*
 SwipeableItemRow.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikel-Zeile mit eigenen Wisch-Aktionen (Höhe 94):
   • offen:     Karte −256 → Löschen / Bearbeiten / Nicht verfügbar (64 × 52, Radius 20, Spalten 76, Abstand 8)
   • abgehakt:  Karte −86  → gelber „Zurück“-Knopf 56 in einer 76 breiten Spalte

 🔰 Notes for Beginners:
 - SwiftUI-`.swipeActions` lässt sich nicht im Design-Look gestalten, deshalb eine eigene Geste
   (`onHorizontalPan`, iOS 18+ ein UIKit-Pan, der nur waagerecht startet und das Scrollen nicht stört).
 - Physik (Gummiband, Schnell-Wisch, Schwelle) steckt testbar in SwipeRevealPhysics.
 - Die Aktionen blenden mit dem Wischweg stufenlos ein; beim Überschreiten der Schwelle gibt es Haptik.
 - Rechts-Wischen zweistufig: bis 96 pt und loslassen → Karte bleibt rechts offen, Button antippbar;
   weiter bis 180 pt → Button wächst, Haptik, beim Loslassen Abhaken bzw. Zurück auf die Liste.
 - Abgehakte Artikel: auch nach links zweistufig – „Zurück“ antippen oder bis 180 pt durchwischen.
 - Es ist immer höchstens eine Zeile offen (`openRow` gehört der Liste, inklusive Seite).
 - Tippen auf eine offene Karte schließt sie wieder.
 - VoiceOver erreicht dieselben Aktionen über Accessibility-Actions.

 📝 Last Change:
 - Glas-Aktionen nach GlassActionButton ausgelagert (gemeinsam mit den Listen-Karten).
 - LeadingCheckAction und UndoActionButton in eigene Dateien ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit
import QuartzCore

/// Item card with custom swipe-to-reveal actions.
struct SwipeableItemRow: View {
    let t: ListTheme
    let item: ItemModel
    @Binding var openRow: OpenSwipeRow?
    var onToggleChecked: () -> Void = {}
    var onDelete: () -> Void = {}
    var onEdit: () -> Void = {}
    var onToggleUnavailable: () -> Void = {}
    var onTapImage: () -> Void = {}
    var isRecentlySynced: Bool = false
    var onRetry: (() -> Void)? = nil

    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @State private var isPastThreshold = false
    /// Full swipe to the right reached (release performs check / undo).
    @State private var isArmed = false
    /// Full swipe to the left reached (checked items: release performs „Zurück“).
    @State private var isArmedTrailing = false
    /// Extremes of the card offset in the current drag and when they were reached (thumb snap-back vs. cancel).
    @State private var minOffset: CGFloat = 0
    @State private var maxOffset: CGFloat = 0
    @State private var minOffsetTime: CFTimeInterval = 0
    @State private var maxOffsetTime: CFTimeInterval = 0

    private var revealWidth: CGFloat { item.isChecked ? 86 : 256 }
    /// Rechts offen: 96 pt (Button sichtbar, antippbar). Durchwischen ab 180 pt löst aus.
    private static let leadingWidth: CGFloat = 96
    private var physics: SwipeRevealPhysics {
        SwipeRevealPhysics(revealWidth: revealWidth, leadingWidth: Self.leadingWidth, trailingFullSwipe: item.isChecked)
    }
    private var rest: SwipeRevealPhysics.Rest { openRow?.id == item.id ? (openRow?.rest ?? .closed) : .closed }
    private var cardOffset: CGFloat {
        isDragging ? physics.offset(rest: rest, translation: dragX) : physics.baseOffset(rest)
    }

    /// Einheitliche Feder für Öffnen, Schließen und Zurückschnappen.
    static let snap = Animation.spring(response: 0.34, dampingFraction: 0.84)

    var body: some View {
        let progress = physics.revealProgress(offset: cardOffset)
        let leading = physics.leadingProgress(offset: cardOffset)
        ZStack(alignment: .topTrailing) {
            LeadingCheckAction(t: t, isChecked: item.isChecked, progress: leading, isArmed: isArmed) {
                perform(onToggleChecked)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(Double(leading))
            .allowsHitTesting(rest == .leading && !isDragging)
            actions
                .opacity(Double(progress))
                .scaleEffect(0.86 + 0.14 * progress, anchor: .trailing)
                .allowsHitTesting(rest == .trailing && !isDragging)
            ItemCard(t: t, item: item, onToggleChecked: onToggleChecked, onTapImage: onTapImage,
                     isRecentlySynced: isRecentlySynced, onRetry: onRetry)
                .overlay {
                    if rest != .closed && !isDragging {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { close() }
                    }
                }
                .offset(x: cardOffset)
                .onHorizontalPan(onChanged: dragChanged, onEnded: dragEnded)
        }
        .frame(height: 94)
        .accessibilityElement(children: .contain)
        .accessibilityActions { accessibilityActionList }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if item.isChecked {
            UndoActionButton(t: t, isArmed: isArmedTrailing) { perform(onToggleChecked) }
        } else {
            HStack(spacing: 8) {
                GlassActionButton(style: .delete, title: "Löschen", icon: Icon.trashAction, labelColor: t.sub) { perform(onDelete) }
                GlassActionButton(style: .edit, title: "Bearbeiten", icon: Icon.pencil, labelColor: t.sub) { perform(onEdit) }
                GlassActionButton(style: .unavailable,
                                  title: item.isUnavailable ? "Verfügbar" : "Nicht verfügbar",
                                  icon: item.isUnavailable ? Icon.restore : Icon.unavailable,
                                  labelColor: t.sub) { perform(onToggleUnavailable) }
            }
        }
    }

    @ViewBuilder
    private var accessibilityActionList: some View {
        if item.isChecked {
            Button("Zurück auf die Liste", action: onToggleChecked)
        } else {
            Button("Bearbeiten", action: onEdit)
            Button(item.isUnavailable ? "Wieder verfügbar" : "Nicht verfügbar", action: onToggleUnavailable)
            Button("Löschen", action: onDelete)
        }
    }

    private func perform(_ action: @escaping () -> Void) {
        close()
        action()
    }

    private func close() {
        withAnimation(Self.snap) {
            if openRow?.id == item.id { openRow = nil }
        }
    }

    // MARK: - Gesture

    /// Karte folgt dem Finger 1:1 und ohne Animation. Eine andere offene Zeile schließt sich.
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
            isArmedTrailing = false
            if let other = openRow, other.id != item.id {
                withAnimation(Self.snap) { openRow = nil }
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

    /// Haptik beim Überschreiten der Öffnen-Schwelle links und der Durchwisch-Schwelle rechts.
    private func updateHaptics(offset: CGFloat) {
        let past = offset < -revealWidth / 2
        if past != isPastThreshold {
            isPastThreshold = past
            UISelectionFeedbackGenerator().selectionChanged()
        }
        let armed = rest != .trailing && offset >= physics.fullSwipeDistance
        if armed != isArmed {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { isArmed = armed }
            UIImpactFeedbackGenerator(style: armed ? .medium : .light).impactOccurred()
        }
        let armedTrailing = physics.trailingFullSwipe && rest != .leading && offset <= -physics.fullSwipeDistance
        if armedTrailing != isArmedTrailing {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { isArmedTrailing = armedTrailing }
            UIImpactFeedbackGenerator(style: armedTrailing ? .medium : .light).impactOccurred()
        }
    }

    /// Ruhelage nach weitestem Punkt, Rückzugsdauer und Geschwindigkeit, dann Federanimation.
    private func dragEnded(_ translation: CGFloat, _ velocity: CGFloat) {
        guard isDragging else { return }
        let now = CACurrentMediaTime()
        let drag = SwipeRevealPhysics.Drag(translation: translation, velocity: velocity,
                                           minOffset: minOffset, maxOffset: maxOffset,
                                           pullBackFromMin: now - minOffsetTime, pullBackFromMax: now - maxOffsetTime)
        let outcome = physics.release(from: rest, drag)
        withAnimation(Self.snap) {
            isDragging = false
            isArmed = false
            isArmedTrailing = false
            dragX = 0
            switch outcome {
            case .triggerLeading, .triggerTrailing, .rest(.closed):
                if openRow?.id == item.id { openRow = nil }
            case .rest(let newRest):
                openRow = OpenSwipeRow(id: item.id, rest: newRest)
            }
        }
        // Beide Durchwisch-Aktionen schalten den Abhak-Zustand um (Abhaken bzw. Zurück auf die Liste).
        if outcome == .triggerLeading || outcome == .triggerTrailing { onToggleChecked() }
    }
}

#Preview {
    @Previewable @State var open: OpenSwipeRow? = OpenSwipeRow(id: "b", rest: .trailing)
    VStack(spacing: 12) {
        SwipeableItemRow(t: ListTheme(.light), item: ItemModel(id: "b", name: "Butter", units: 1, measure: "pack"), openRow: $open)
        SwipeableItemRow(t: ListTheme(.light), item: ItemModel(id: "e", name: "Eier", units: 10, isChecked: true), openRow: $open)
    }
    .padding(20)
}

#Preview("Dark") {
    @Previewable @State var open: OpenSwipeRow? = OpenSwipeRow(id: "b", rest: .trailing)
    VStack(spacing: 12) {
        SwipeableItemRow(t: ListTheme(.dark), item: ItemModel(id: "b", name: "Butter", units: 1, measure: "pack"), openRow: $open)
        SwipeableItemRow(t: ListTheme(.dark), item: ItemModel(id: "e", name: "Eier", units: 10, isChecked: true), openRow: $open)
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
