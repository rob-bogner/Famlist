/*
 ScanQuantityRoll.swift
 Famlist
 Created on: 14.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Barcode-Scanner, Karte „Artikel erkannt“: Mengen-Kreis gedrückt halten → rechts rollen die Mengen 2× … 6×
   über „Zur Liste hinzufügen“ aus. Gleicher Stil und gleiche Animation wie Plus gedrückt halten im Dock
   (DockView + DockMorphMenu), nur gespiegelt: Die Vorderkante läuft vom Kreis nach rechts.

 🔰 Notes for Beginners:
 - Alles hängt an EINEM Wert `morph` (0…1). Die Ebenen sind `Animatable`, deshalb wandert die Vorderkante
   gleichmäßig über den Knopf.
 - Ablauf wie im Dock: Tippen (unter 0,1 s) = Menge weiterzählen. Beim Drücken rollt es sofort aus (0,4 s) und
   rastet dann ein. Vorher loslassen → rollt zurück. Während des Haltens auf eine Zahl ziehen und loslassen wählt
   sie; eingerastet genügt Antippen. Der Kreis wird dabei zum ×: Antippen schließt.
 - Nach der Wahl rollt die Fläche zurück und der Kreis zeigt die neue Menge.
 - `.onPress` statt DragGesture (Verzögerung seit iOS 27, siehe PressGestureRecognizer).

 📝 Last Change:
 - Initial creation (Wunsch Robert 14.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Mengen, die rechts neben dem Kreis ausrollen.
enum ScanQuantityRoll {
    static let values = [2, 3, 4, 5, 6]
}

// MARK: - Knopf wird überrollt

/// „Zur Liste hinzufügen“: sichtbar bleibt nur der Teil rechts der Vorderkante (Spiegel von DockItemsRollMask).
struct ScanQuantityRollMask: ViewModifier, Animatable {
    var progress: CGFloat
    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask(alignment: .trailing) {
            GeometryReader { geo in
                Rectangle()
                    .frame(width: geo.size.width * (1 - DockMorphRoll.clamp(progress)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - Ausgerollte Fläche

/// Spiegel von DockMorphLayer: dunkle Fläche mit Zahlen-Pillen, Rolle an der Vorderkante (läuft nach rechts).
struct ScanQuantityRollLayer: View, Animatable {
    let accent: AccentScale
    var progress: CGFloat
    var hover: Int?
    var onSelect: (Int) -> Void

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { geo in
            let p = DockMorphRoll.clamp(progress)
            let front = geo.size.width * p                        // Vorderkante: läuft vom Kreis nach rechts
            ZStack(alignment: .leading) {
                surface
                    .mask(alignment: .leading) { Rectangle().frame(width: front) }
                DockMorphRollEdge(accent: accent, progress: p, height: geo.size.height, shadowX: -4)
                    .offset(x: front - DockMorphRoll.thickness(p) / 2)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .clipShape(Pill)
        .allowsHitTesting(progress > 0.6)
    }

    /// Fläche wie im Dock (rgba(6,14,16,.97)), Pillen ab Rand 3 (Knopf 56 statt Leiste 62), Abstand 2.
    private var surface: some View {
        HStack(spacing: 2) {
            ForEach(ScanQuantityRoll.values, id: \.self) { n in segment(n) }
        }
        .padding(3)
        .background(Color.rgba(6, 14, 16, 0.97))
    }

    private func segment(_ n: Int) -> some View {
        let on = hover == n
        return Button { onSelect(n) } label: {
            Text("\(n)×")
                .font(AppFont.dm(15, 600, scaled: false))
                .tracking(-0.075)                              // -0.005em × 15
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DockMorphPillBackground(accent: accent, on: on))
                .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: on)
        .accessibilityLabel("Menge \(n)")
    }
}

// MARK: - Kreis + Knopf mit Halten-Geste

/// Mengen-Kreis 56 links, rechts daneben der Knopf (`trailing`), über den die Mengen ausrollen.
struct ScanQuantityControl<Trailing: View>: View {
    let k: SheetTheme
    let quantity: Int
    let onCycle: () -> Void
    let onPick: (Int) -> Void
    /// Eingerastet offen (der Scanner legt dann eine Tipp-Fläche darunter; false von außen schließt).
    @Binding var isOpen: Bool
    let trailing: Trailing

    @State private var morph: CGFloat = 0
    @State private var locked = false
    @State private var pressing = false
    @State private var pressStart = Date.distantPast
    @State private var moved = false
    @State private var tapToClose = false
    @State private var hover: Int?
    @State private var pressTask: Task<Void, Never>?
    /// Rahmen des Knopfs im globalen Koordinatensystem (für das Hinziehen auf eine Zahl).
    @State private var rowFrame: CGRect = .zero

    init(k: SheetTheme, quantity: Int, isOpen: Binding<Bool>, onCycle: @escaping () -> Void,
         onPick: @escaping (Int) -> Void, @ViewBuilder trailing: () -> Trailing) {
        self.k = k
        self.quantity = quantity
        self._isOpen = isOpen
        self.onCycle = onCycle
        self.onPick = onPick
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            circle
            trailing
                .modifier(ScanQuantityRollMask(progress: morph))
                .allowsHitTesting(morph < 0.05 && !locked)
                .overlay {
                    ScanQuantityRollLayer(accent: k.a, progress: morph, hover: hover, onSelect: select)
                }
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { rowFrame = geo.frame(in: .global) }
                            .onChange(of: geo.frame(in: .global)) { _, frame in rowFrame = frame }
                    }
                }
        }
        .onChange(of: isOpen) { _, open in if !open && (locked || morph > 0) { collapse() } }
        .onDisappear { pressTask?.cancel() }
    }

    /// Kreis: Menge, beim Ausrollen dreht sich ein × herein (wie das Plus im Dock), Akzent-Schein wächst mit.
    private var circle: some View {
        let quantityText = "\(quantity)×"
        return ZStack {
            Text(quantityText)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(k.accentText)
                .opacity(Double(1 - morph))
                .scaleEffect(1 - 0.4 * morph)
            SVGIcon(Icon.close, size: 18, color: k.accentText, lineWidth: 2.4)
                .rotationEffect(.degrees(-90 * Double(1 - morph)))
                .opacity(Double(morph))
        }
        .frame(width: 56, height: 56)
        .background(GlassCircleBackground(style: .neutral, appearance: k.appearance, accent: k.a, size: 56))
        .shadow(color: k.a.base.color(0.5 * Double(morph)), radius: 14 * morph)
        .contentShape(Circle())
        .scaleEffect(pressing ? 0.93 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: pressing)
        .onPress(onChanged: pressChanged, onEnded: pressEnded)
        .accessibilityElement()
        .accessibilityLabel(locked ? "Schließen" : "Menge: \(quantityText)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tippen erhöht die Menge, gedrückt halten zeigt weitere Mengen")
        .accessibilityAction { if locked { collapse() } else { onCycle() } }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onPick(min(9, quantity + 1))
            case .decrement: onPick(max(1, quantity - 1))
            @unknown default: break
            }
        }
    }

    // MARK: Geste (wie DockView.holdFAB, gespiegelt)

    private func pressChanged(location: CGPoint, translation: CGSize) {
        if !pressing {
            pressing = true
            moved = false
            pressStart = Date()
            // Eingerastet: erneutes Antippen des Kreises (×) schließt.
            if locked { tapToClose = true; return }
            tapToClose = false
            pressTask?.cancel()
            // Ausrollen startet sofort und dauert 0,4 s; die erste Haptik kommt erst, wenn es kein Tippen mehr ist.
            withAnimation(.timingCurve(0.2, 0, 0.2, 1, duration: 0.4)) { morph = 1 }
            pressTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, pressing else { return }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, pressing else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                locked = true
                isOpen = true
            }
        }
        guard !tapToClose else { return }
        if abs(translation.width) > 10 || abs(translation.height) > 10 { moved = true }
        // Hinziehen: über welcher Zahl liegt der Finger? (44 pt Spielraum über und unter dem Knopf)
        let held = Date().timeIntervalSince(pressStart) > 0.2 || locked
        var target: Int?
        let values = ScanQuantityRoll.values
        if held, rowFrame.width > 0, location.x >= rowFrame.minX, location.x < rowFrame.maxX,
           location.y > rowFrame.minY - 44, location.y < rowFrame.maxY + 44 {
            let slot = (rowFrame.width - 6) / CGFloat(values.count)
            let index = Int((location.x - rowFrame.minX - 3) / slot)
            target = values[min(values.count - 1, max(0, index))]
        }
        if target != hover {
            if target != nil { UISelectionFeedbackGenerator().selectionChanged() }
            hover = target
        }
    }

    private func pressEnded() {
        pressing = false
        pressTask?.cancel()
        if tapToClose { tapToClose = false; collapse(); return }
        if let hover { select(hover); return }
        let short = Date().timeIntervalSince(pressStart) < 0.1 && !moved
        if locked { return }                                  // eingerastet: bleibt offen
        collapse()
        if short { onCycle() }
    }

    /// Auswahl: Menge übernehmen, Fläche rollt zurück, der Kreis zeigt die neue Zahl.
    private func select(_ n: Int) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onPick(n)
        collapse()
    }

    private func collapse() {
        pressTask?.cancel()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            morph = 0
            hover = nil
        }
        locked = false
        if isOpen { isOpen = false }
    }
}

// MARK: - Vorschau

private struct ScanQuantityRollPreview: View {
    let appearance: Appearance
    let progress: CGFloat
    var hover: Int? = nil

    var body: some View {
        let k = SheetTheme(appearance)
        HStack(spacing: 10) {
            Circle().fill(Color.rgba(255, 255, 255, 0.2)).frame(width: 56, height: 56)
            CTAButton(title: "Zur Liste hinzufügen", k: k)
                .modifier(ScanQuantityRollMask(progress: progress))
                .overlay { ScanQuantityRollLayer(accent: k.a, progress: progress, hover: hover, onSelect: { _ in }) }
        }
        .padding(20)
        .background(appearance == .dark ? Color.hex("#0A1416") : Color.hex("#F4F7F7"))
    }
}

#Preview("ScanQuantityRoll") {
    VStack(spacing: 0) {
        ScanQuantityRollPreview(appearance: .light, progress: 0.5)
        ScanQuantityRollPreview(appearance: .light, progress: 1, hover: 3)
    }
}

#Preview("ScanQuantityRoll – Dark") {
    VStack(spacing: 0) {
        ScanQuantityRollPreview(appearance: .dark, progress: 0.5)
        ScanQuantityRollPreview(appearance: .dark, progress: 1, hover: 4)
    }
}
