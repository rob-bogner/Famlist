/*
 DockView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Untere Leiste (Dock): dunkle Glas-Leiste 276 × 64 mit vier Aktionen + Plus-Knopf 64. Genau ein Knopf ist als Pille gewählt; die Pille wandert animiert (matchedGeometryEffect).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/Dock.swift (Dock.dc.html / DockStates.png; ergänzt um Aktionen und Pillen-Animation).
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 - Plus gedrückt halten: Leiste wird „Barcode | Foto“ (DockMorphMenu, 13.10.2026).
 - Halten: Ausrollen startet sofort, rastet nach 0,4 s ein (vorher Start 0,1 s, Einrasten 0,7 s; Wunsch Robert 14.10.2026).
 - Plus: `onPress` (UIKit-Erkenner) statt DragGesture, weil iOS 27 das Aufsetzen verzögert meldet (14.10.2026).
 - Nach der Auswahl bleibt „Barcode | Foto erkennen“ stehen, bis × oder daneben getippt wird (Wunsch Robert 14.10.2026).
 - DockGeometry, DockItemModel, DockActionButton und DockFAB in eigene Dateien ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

struct DockView: View {
    let appearance: Appearance
    var accentHex: String? = nil
    var active: DockActive = .none
    var pill: DockPill = .open
    /// Optional: echter `backdrop-filter` (blur 24) über `.ultraThinMaterial`. Im Standbild aus.
    var liveBlur: Bool = false
    /// Aktionen der vier Knöpfe und des Plus-Knopfs (Vorschau: leer).
    var onCheck: () -> Void = {}
    var onSort: () -> Void = {}
    var onCopy: () -> Void = {}
    var onDelete: () -> Void = {}
    var onAdd: () -> Void = {}
    /// Plus gedrückt halten → Leiste wird „Barcode | Foto“ (DockMorphMenu). nil = nur Tippen.
    var onScan: (() -> Void)? = nil
    var onPhoto: (() -> Void)? = nil
    /// Eingerastet offen (die Liste legt dann eine Abdunkelung darunter; false von außen schließt).
    var morphOpen: Binding<Bool> = .constant(false)

    @State private var morph: CGFloat = 0
    @State private var locked = false
    @State private var pressing = false
    @State private var pressStart = Date.distantPast
    @State private var moved = false
    @State private var tapToClose = false
    @State private var hover: DockMorphOption?
    @State private var pressTask: Task<Void, Never>?
    /// Rahmen der Leiste im globalen Koordinatensystem (für das Hinziehen auf eine Pille).
    @State private var navFrame: CGRect = .zero

    /// Gemeinsamer Namensraum, damit die gewählte Pille zum angetippten Knopf wandert.
    @Namespace private var pillSpace

    init(appearance: Appearance, accentHex: String? = nil, active: DockActive = .none,
         pill: DockPill = .open, liveBlur: Bool = false,
         onCheck: @escaping () -> Void = {}, onSort: @escaping () -> Void = {},
         onCopy: @escaping () -> Void = {}, onDelete: @escaping () -> Void = {},
         onAdd: @escaping () -> Void = {},
         onScan: (() -> Void)? = nil, onPhoto: (() -> Void)? = nil,
         morphOpen: Binding<Bool> = .constant(false)) {
        self.appearance = appearance
        self.accentHex = accentHex
        self.active = active
        self.pill = pill
        self.liveBlur = liveBlur
        self.onCheck = onCheck
        self.onSort = onSort
        self.onCopy = onCopy
        self.onDelete = onDelete
        self.onAdd = onAdd
        self.onScan = onScan
        self.onPhoto = onPhoto
        self.morphOpen = morphOpen
    }

    private var holdEnabled: Bool { onScan != nil && onPhoto != nil }

    private func action(for key: DockKey) -> () -> Void {
        switch key {
        case .check: onCheck
        case .sort: onSort
        case .copy: onCopy
        case .delete: onDelete
        }
    }

    var body: some View {
        let t = ListTheme(appearance, accentHex: accentHex)
        let k = DockTokens(appearance)
        let items = DockItemModel.items(t: t, active: active, pill: pill)

        HStack(spacing: 10) {
            // Leiste
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Spacer(minLength: 0) }
                    DockActionButton(item: item, pillSpace: pillSpace, action: action(for: item.key))
                }
            }
            .padding(4)
            .modifier(DockItemsRollMask(progress: morph))
            .allowsHitTesting(morph < 0.05 && !locked)
            .overlay {
                if holdEnabled {
                    DockMorphLayer(t: t, progress: morph, hover: hover, onSelect: select)
                }
            }
            .frame(maxWidth: .infinity)            // Leiste wächst mit der Bildschirmbreite (Design 390 → 276)
            .frame(height: 62)
            .background { glassReflections }       // Spiegelungen liegen unter den Knöpfen (Dock.dc.html)
            .clipShape(Pill)                       // overflow: hidden (Padding-Box, Radius 31)
            .padding(1)                            // border 1
            .frame(height: 64)
            .background(CSSBox(shape: Pill, paint: .color(k.nav), border: 1, borderColor: k.navBorder, shadows: k.navShadow))
            .background {
                if liveBlur { Pill.fill(.ultraThinMaterial) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(locked ? "Hinzufügen per" : "Listen-Aktionen")
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { navFrame = geo.frame(in: .global) }
                        .onChange(of: geo.frame(in: .global)) { _, frame in navFrame = frame }
                }
            }

            if holdEnabled { holdFAB(t: t) } else { DockFAB(t: t, action: onAdd) }
        }
        .frame(height: 64)                         // Breite = Bildschirm − 2 × 20 (Design 390 → 350)
        .onChange(of: morphOpen.wrappedValue) { _, open in if !open && (locked || morph > 0) { collapse() } }
        .onDisappear { pressTask?.cancel() }
    }
}

// MARK: - Plus gedrückt halten

extension DockView {
    /// Plus mit eigener Geste: Tippen (unter 0,1 s) = Hinzufügen; beim Drücken rollt „Barcode | Foto“ sofort aus,
    /// bei 0,4 s rastet es ein; während des Haltens auf eine Pille ziehen und loslassen wählt sie.
    /// `onPress` statt DragGesture: Die erkennt das Aufsetzen seit iOS 27 verzögert (siehe PressGestureRecognizer).
    fileprivate func holdFAB(t: ListTheme) -> some View {
        DockFAB(t: t, action: onAdd, rotation: 45 * Double(morph), glow: morph, isButton: false)
            .scaleEffect(pressing ? 0.93 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: pressing)
            .onPress(onChanged: pressChanged, onEnded: pressEnded)
            .accessibilityElement()
            .accessibilityLabel(locked ? "Schließen" : "Artikel hinzufügen")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Gedrückt halten für Barcode oder Foto")
            .accessibilityAction { if locked { collapse() } else { onAdd() } }
            .accessibilityAction(named: "Barcode scannen") { onScan?() }
            .accessibilityAction(named: "Per Foto erkennen") { onPhoto?() }
    }

    /// `location` im globalen Koordinatensystem, `translation` seit dem Aufsetzen.
    fileprivate func pressChanged(location: CGPoint, translation: CGSize) {
        if !pressing {
            pressing = true
            moved = false
            pressStart = Date()
            // Eingerastet: erneutes Antippen des Plus schließt.
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
                morphOpen.wrappedValue = true
            }
        }
        guard !tapToClose else { return }
        if abs(translation.width) > 10 || abs(translation.height) > 10 { moved = true }
        // Hinziehen: über welcher Hälfte der Leiste liegt der Finger? (44 pt Spielraum über und unter der Leiste)
        let held = Date().timeIntervalSince(pressStart) > 0.2 || locked
        var target: DockMorphOption?
        if held, location.x >= navFrame.minX, location.x < navFrame.maxX,
           location.y > navFrame.minY - 44, location.y < navFrame.minY + 108 {
            target = location.x < navFrame.midX ? .scan : .photo
        }
        if target != hover {
            if target != nil { UISelectionFeedbackGenerator().selectionChanged() }
            hover = target
        }
    }

    fileprivate func pressEnded() {
        pressing = false
        pressTask?.cancel()
        if tapToClose { tapToClose = false; collapse(); return }
        if let hover { select(hover); return }
        let short = Date().timeIntervalSince(pressStart) < 0.1 && !moved
        if locked { return }                                  // eingerastet: bleibt offen
        collapse()
        if short { onAdd() }
    }

    /// Auswahl: Die Leiste bleibt als „Barcode | Foto erkennen“ eingerastet stehen. Nach dem Scanner oder der
    /// Foto-Erkennung ist so gleich die nächste Auswahl möglich. Schließen: Plus (×) oder daneben tippen.
    fileprivate func select(_ option: DockMorphOption) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        pressTask?.cancel()
        hover = nil
        if !locked {                                          // beim Hinziehen vor dem Einrasten gewählt
            locked = true
            morphOpen.wrappedValue = true
        }
        if option == .scan { onScan?() } else { onPhoto?() }
    }

    fileprivate func collapse() {
        pressTask?.cancel()
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            morph = 0
            hover = nil
        }
        locked = false
        if morphOpen.wrappedValue { morphOpen.wrappedValue = false }
    }
}

// MARK: - Glas

extension DockView {
    /// Wie beim Plus-Knopf (Dock.dc.html): Glanz oben als Pille mit runden Enden – links/rechts 14, top 3, Höhe 26,
    /// Radius 13, weiß .32 → 0, blur 1; Lichtschein unten – links/rechts 36, unten 3, Höhe 8, Radius 4, weiß .14, blur 3.
    /// Werte ab Rahmen, hier −1.
    var glassReflections: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(stops: [stop(.rgba(255, 255, 255, 0.32), 0), stop(.rgba(255, 255, 255, 0), 1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 26)
                .blur(radius: 1)
                .padding(.horizontal, 13)
                .padding(.top, 2)
                .frame(maxHeight: .infinity, alignment: .top)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.rgba(255, 255, 255, 0.14))
                .frame(height: 8)
                .blur(radius: 3)
                .padding(.horizontal, 35)
                .padding(.bottom, 2)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Tokens

/// Leisten-Tokens aus Dock.dc.html (in beiden Modi dunkles Glas).
private struct DockTokens {
    let nav: Color
    let navBorder: Color
    let navShadow: [BoxShadow]

    init(_ appearance: Appearance) {
        if appearance == .dark {
            nav = .rgba(8, 17, 19, 0.88)
            navBorder = .rgba(255, 255, 255, 0.1)
            navShadow = [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.1)),
                         .drop(0, 24, 44, -12, .rgba(0, 0, 0, 0.85))]
        } else {
            nav = .rgba(6, 14, 16, 0.9)
            navBorder = .rgba(255, 255, 255, 0.1)
            navShadow = [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.12)),
                         .drop(0, 20, 36, -12, .rgba(12, 30, 33, 0.5))]
        }
    }
}

#Preview("DockView") {
    DockView(appearance: .light)
        .padding(20)
        .background(Color.hex("#F4F7F7"))
}

#Preview("DockView – Dark") {
    DockView(appearance: .dark)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
