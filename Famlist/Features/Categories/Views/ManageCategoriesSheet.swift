/*
 ManageCategoriesSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Kategorien verwalten“ (Höhe 790): Hinweis zum Ladenweg, „Neue Kategorie“, nummerierte Kategorien
   mit Griff. Kopf, Hinweis, Knopf und Anzahl stehen fest, nur die Kategorien scrollen. Umsortieren per Ziehen; Tippen öffnet „Kategorie bearbeiten“.

 🔰 Notes for Beginners:
 - Vorlage: ManageCategoriesScreen in design-handoff/MyListUI/Screens/CategoryScreens.swift
   (ManageCategories.dc.html). Werte 1:1; Beispieldaten durch CategoryStore ersetzt.
 - Ziehen: langer Druck auf eine Zeile hebt sie an, Ablegen auf einer anderen Zeile verschiebt sie.
 - Wischen nach links zeigt „Löschen“ (wie in „Artikel verwalten“); „Sonstiges“ lässt sich nicht wischen.
   VoiceOver: Aktionen „Nach oben“ / „Nach unten“ am Griff.
 - Die Liste blendet oben (12) und unten (44) weich aus.

 📝 Last Change:
 - „Neue Kategorie“ über der Liste; Kopf fest, nur die Kategorien scrollen (30.09.2026).
 - Kachel in der Kategorie-Farbe mit weißem Icon, Untertitel „Tippen: Name, Farbe, Icon“ (30.09.2026).
 - Wischen zum Löschen; Name ist kein Button mehr (Wischen wurde sonst blockiert).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UniformTypeIdentifiers

struct ManageCategoriesSheet: View {
    @ObservedObject var store: CategoryStore
    let appearance: Appearance
    var onClose: () -> Void = {}
    var onEdit: (CategoryDefinition) -> Void = { _ in }
    var onAdd: () -> Void = {}
    /// Wischen nach links → „Löschen“ (nicht für die Standardkategorie).
    var onDelete: (CategoryDefinition) -> Void = { _ in }

    @State private var draggingId: UUID?

    var body: some View {
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)
        let hintFont = AppFont.ui(.dmSans, 13, 400)

        EKKSheetStage(k: k, background: {
            DesignListScreen(appearance: appearance, state: .normal)
        }) {
            SheetSurface(k: k, height: 790) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Kategorien verwalten", k: k, onClose: onClose)
                        .padding(.horizontal, 20)

                    // Fest: Hinweis, „Neue Kategorie“ und Anzahl – nur die Kategorien darunter scrollen.
                    VStack(alignment: .leading, spacing: 0) {
                        // Hinweis: Rahmen 1 (content-box) → Einzug 13 / 15
                        HStack(alignment: .top, spacing: 10) {
                            SVGIcon(EKKIcon.map, size: 20, color: k.accentText, lineWidth: 1.9)
                                .padding(.top, 1)
                                .accessibilityHidden(true)
                            Text("Sortiere die Kategorien so, wie du durch deinen Laden gehst. Die Liste zeigt die Artikel dann in dieser Reihenfolge.")
                                .font(AppFont.dm(13, 400))
                                .foregroundStyle(k.sub)
                                .cssLineHeight(18.85, font: hintFont)          // line-height 1.45
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 13)
                        .padding(.horizontal, 15)
                        .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                        .padding(.top, 16)

                        Button(action: onAdd) {
                            HStack(spacing: 8) {
                                SVGIcon(Icon.plus, size: 18, color: k.accentText, lineWidth: 2.4)
                                Text("Neue Kategorie")
                                    .font(AppFont.dm(15, 600))
                                    .foregroundStyle(k.accentText)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(CSSBox(shape: RR(20), border: 1.5, borderColor: k.dashed, dash: [4.5, 4.5]))
                            .contentShape(RR(20))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)

                        EKKSectionLabel(text: store.categories.count == 1 ? "1 Kategorie" : "\(store.categories.count) Kategorien", k: k)
                            .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(Array(store.categories.enumerated()), id: \.element.id) { index, c in
                                swipeableRow(index: index, c, k: k, t: t)
                                    .onDrag {
                                        draggingId = c.id
                                        return NSItemProvider(object: c.id.uuidString as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: CategoryDropDelegate(
                                        targetId: c.id, draggingId: $draggingId,
                                        onMove: { store.move($0, to: $1) }))
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.categories)
                        .padding(.horizontal, 20)
                        .padding(.top, 6)                                // Platz für Schatten oben
                        .padding(.bottom, 40)                            // 34 unten + Luft für den Ausblend-Rand
                    }
                    .scrollIndicators(.hidden)
                    // Oben 12 / unten 44 weich ausblenden: zeigt, dass es weitergeht.
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 12)
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 44)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// „Sonstiges“ bleibt immer erhalten → keine Wischgeste.
    @ViewBuilder
    private func swipeableRow(index: Int, _ c: CategoryDefinition, k: SheetTheme, t: EKKTokens) -> some View {
        if c.isFallback {
            categoryRow(index: index, c, k: k, t: t)
        } else {
            SwipeToDeleteRow(labelColor: k.sub, columnHeight: 68, onDelete: { onDelete(c) }) {
                categoryRow(index: index, c, k: k, t: t)
            }
        }
    }

    /// Zeile 68 (border-box): Nummer 22 · Kachel 44 · Name/Untertitel (grow) · Griff 44, Abstand 12.
    private func categoryRow(index: Int, _ c: CategoryDefinition, k: SheetTheme, t: EKKTokens) -> some View {
        EKKFlexRow(spacing: 12, grow: [0, 0, 1, 0], shrink: [1, 0, 1, 1]) {
            Text("\(index + 1)")
                .font(AppFont.outfit(15, 600))
                .foregroundStyle(k.sub)
                .frame(minWidth: 0, idealWidth: 22, maxWidth: 22)
                .accessibilityHidden(true)

            SVGIcon(c.svgIcon, size: 22, color: .white, lineWidth: 1.9)
                .frame(width: 44, height: 44)
                .background(CSSBox(shape: RR(14), paint: CategoryColor.tilePaint(CategoryColor.rgb(for: c)),
                                   shadows: CategoryColor.tileShadow(CategoryColor.rgb(for: c))))
                .accessibilityHidden(true)

            // Kein Button: Er hielte die Berührung fest und blockierte das Wischen (View+SwipeFriendlyTap).
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name)
                    .font(AppFont.outfit(16, 600))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(c.isFallback ? "Standard · kann nicht gelöscht werden" : "Tippen: Name, Farbe, Icon")
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .swipeFriendlyTap("\(index + 1). \(c.name) bearbeiten") { onEdit(c) }

            SVGIcon(EKKIcon.grip, size: 20, color: k.sub, lineWidth: 3)
                .frame(minWidth: 0, idealWidth: 44, maxWidth: 44)
                .frame(height: 44)
                .contentShape(Rectangle())
                .accessibilityElement()
                .accessibilityLabel("\(c.name) verschieben")
                .accessibilityAction(named: "Nach oben") { store.move(c.id, by: -1) }
                .accessibilityAction(named: "Nach unten") { store.move(c.id, by: 1) }
        }
        .padding(.leading, 13)                                   // 1 Rahmen + 12 Padding
        .padding(.trailing, 11)                                  // 1 Rahmen + 10 Padding
        .frame(height: 68)
        .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
    }
}

/// Ablegen auf einer Zeile verschiebt die gezogene Kategorie an diese Stelle.
private struct CategoryDropDelegate: DropDelegate {
    let targetId: UUID
    @Binding var draggingId: UUID?
    let onMove: (UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingId, draggingId != targetId else { return }
        onMove(draggingId, targetId)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }
}

#Preview("Kategorien verwalten", traits: .fixedLayout(width: 390, height: 844)) {
    ManageCategoriesSheet(store: CategoryStore(repository: nil), appearance: .light)
}

#Preview("Kategorien verwalten – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ManageCategoriesSheet(store: CategoryStore(repository: nil), appearance: .dark)
}
