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
 - Wischgeste neu: UIKit-Pan statt DragGesture, Gummiband, Geschwindigkeits-Entscheidung, stufenlose Aktionen.
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
            ItemCard(t: t, item: item, onToggleChecked: onToggleChecked, onTapImage: onTapImage)
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
                SwipeActionButton(t: t, style: .delete, title: "Löschen", icon: Icon.trashAction) { perform(onDelete) }
                SwipeActionButton(t: t, style: .edit, title: "Bearbeiten", icon: Icon.pencil) { perform(onEdit) }
                SwipeActionButton(t: t, style: .unavailable,
                                  title: item.isUnavailable ? "Verfügbar" : "Nicht verfügbar",
                                  icon: item.isUnavailable ? Icon.restore : Icon.unavailable) { perform(onToggleUnavailable) }
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

// MARK: - Leading Check Action

/// Grüne Abhak-Aktion links hinter der Karte (Rechts-Wischen). Abgehakt: gelbes „Zurück“.
/// Nicht im Design gezeichnet – Stil der Glas-Aktionen, Farben Grün #6EE7A8 → #22C55E → #15803D.
private struct LeadingCheckAction: View {
    let t: ListTheme
    let isChecked: Bool
    let progress: CGFloat
    let isArmed: Bool
    let action: () -> Void

    var body: some View {
        let colors = isChecked
            ? ("#FFE38A", "#F5B521", "#C98A06", Color.rgba(201, 138, 6, 0.7))
            : ("#6EE7A8", "#22C55E", "#15803D", Color.rgba(34, 197, 94, 0.6))
        VStack(spacing: 6) {
            Button(action: action) { circle(colors) }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            Text(isChecked ? "Zurück" : "Abhaken")
                .font(AppFont.dm(12, 600))
                .foregroundStyle(t.sub)
                .fixedSize()
        }
        .frame(width: 76, height: 94)
        .padding(.leading, 10)
        .accessibilityHidden(true)
    }

    private func circle(_ colors: (String, String, String, Color)) -> some View {
            SVGIcon(isChecked ? Icon.undo : Icon.check, size: 22,
                    color: isChecked ? .hex("#4A3300") : .white, lineWidth: 2.4)
                .frame(width: 56, height: 56)
                .background(alignment: .top) {
                    GlossEllipse(opacity: 0.6)
                        .frame(height: 20)
                        .padding(.horizontal, 10)
                        .padding(.top, 3)
                }
                .clipShape(Circle())
                .background(CSSBox(
                    shape: Circle(),
                    paint: .radialCircle(UnitPoint(x: 0.32, y: 0.24),
                                         [stop(.hex(colors.0), 0), stop(.hex(colors.1), 0.55), stop(.hex(colors.2), 1)]),
                    shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.55)),
                              .inner(0, -3, 8, 0, .rgba(0, 0, 0, 0.18)),
                              .drop(0, 10, 20, -8, colors.3)]))
                .scaleEffect(isArmed ? 1.12 : 0.7 + 0.3 * progress)
                .contentShape(Circle())
    }
}

// MARK: - Swipe Action Button

/// Glas-Aktion 64 × 52, Radius 20, darunter Beschriftung 12/600 (Spalte 76 breit).
private struct SwipeActionButton: View {
    enum Style {
        case delete, edit, unavailable

        var colors: (String, String, String, Color) {
            switch self {
            case .delete:      return ("#FF8A80", "#E5484D", "#B4232A", .rgba(229, 72, 77, 0.6))
            case .edit:        return ("#8DB8FF", "#3B7BF6", "#1F4FC0", .rgba(59, 123, 246, 0.6))
            case .unavailable: return ("#FFC08A", "#F08A2C", "#BD5F0E", .rgba(240, 138, 44, 0.6))
            }
        }
    }

    let t: ListTheme
    let style: Style
    let title: String
    let icon: [SVGElement]
    let action: () -> Void

    var body: some View {
        let (c1, c2, c3, glow) = style.colors
        VStack(spacing: 6) {
            Button(action: action) {
                SVGIcon(icon, size: 22, color: .white, lineWidth: 2.1)
                    .frame(width: 64, height: 52)
                    .background(alignment: .top) {
                        GlossEllipse(opacity: 0.5)
                            .frame(height: 20)
                            .padding(.horizontal, 8)
                            .padding(.top, 2)
                    }
                    .clipShape(RR(20))
                    .background(CSSBox(
                        shape: RR(20),
                        paint: .radialCircle(UnitPoint(x: 0.32, y: 0.2),
                                             [stop(.hex(c1), 0), stop(.hex(c2), 0.55), stop(.hex(c3), 1)]),
                        shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.5)),
                                  .inner(0, -3, 8, 0, .rgba(0, 0, 0, 0.18)),
                                  .drop(0, 10, 20, -8, glow)]))
                    .contentShape(RR(20))
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            Text(title)
                .font(AppFont.dm(12, 600))
                .foregroundStyle(t.sub)
                .lineLimit(1)
                .fixedSize()           // white-space: nowrap – darf mittig über 76 pt hinausragen
        }
        .frame(width: 76, height: 94)
    }
}

// MARK: - Undo Action

/// Gelber „Zurück“-Knopf 56 in einer 76 breiten Spalte.
private struct UndoActionButton: View {
    let t: ListTheme
    var isArmed = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                SVGIcon(Icon.undo, size: 22, color: .hex("#4A3300"), lineWidth: 2.2)
                    .frame(width: 56, height: 56)
                    .background(alignment: .top) {
                        GlossEllipse(opacity: 0.65)
                            .frame(height: 20)
                            .padding(.horizontal, 10)
                            .padding(.top, 3)
                    }
                    .clipShape(Circle())
                    .background(CSSBox(
                        shape: Circle(),
                        paint: .radialCircle(UnitPoint(x: 0.32, y: 0.24),
                                             [stop(.hex("#FFE38A"), 0), stop(.hex("#F5B521"), 0.55), stop(.hex("#C98A06"), 1)]),
                        shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.6)),
                                  .inner(0, -3, 8, 0, .rgba(120, 70, 0, 0.25)),
                                  .drop(0, 10, 20, -8, .rgba(201, 138, 6, 0.7))]))
                    .scaleEffect(isArmed ? 1.12 : 1)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            Text("Zurück")
                .font(AppFont.dm(12, 600))
                .foregroundStyle(t.sub)
        }
        .frame(width: 76, height: 94)
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
