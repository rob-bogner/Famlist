/*
 EditCategorySheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Kategorie bearbeiten“ (Höhe 594): Name, Icon (5 × 2), „Speichern“, „Kategorie löschen“
   mit Hinweis „Artikel dieser Kategorie wandern nach „Sonstiges““. Auch für „Neue Kategorie“.

 🔰 Notes for Beginners:
 - Vorlage: EditCategoryScreen in design-handoff/MyListUI/Screens/CategoryScreens.swift (EditCategory.dc.html).
 - „Neue Kategorie“ nutzt dasselbe Sheet mit eigenem Titel und ohne Löschen (eigener Zustand, nicht gestaltet).
 - „Sonstiges“: Name nicht änderbar, Löschen gedimmt.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct EditCategorySheet: View {
    let appearance: Appearance
    /// nil = neue Kategorie
    let category: CategoryDefinition?
    var keyboardHeight: CGFloat = 0
    var isNameAvailable: (String) -> Bool = { _ in true }
    var onClose: () -> Void = {}
    var onSave: (_ name: String, _ icon: String) -> Void = { _, _ in }
    var onDelete: () -> Void = {}

    @State private var name = ""
    @State private var icon = "drop"
    /// true, sobald der Nutzer selbst ein Icon gewählt hat → kein automatischer Vorschlag mehr.
    @State private var iconTouched = false
    @FocusState private var nameFocused: Bool

    private var isFallback: Bool { category?.isFallback ?? false }
    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { isFallback || (!trimmed.isEmpty && isNameAvailable(trimmed)) }

    var body: some View {
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)

        EKKSheetStage(k: k, background: {
            DesignListScreen(appearance: appearance)
        }) {
            SheetSurface(k: k, height: 704) {                // +110 für das gruppierte Icon-Raster
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: category == nil ? "Neue Kategorie" : "Kategorie bearbeiten", k: k, onClose: onClose)

                    HStack(spacing: 14) {
                        SVGIcon(CategoryIconCatalog.icon(for: icon), size: 30, color: .white, lineWidth: 1.9)
                            .frame(width: 64, height: 64)
                            .background(CSSBox(shape: RR(20), paint: t.avatarBg,
                                               shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.4))]))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Name", k: k)
                            TextField("", text: $name, prompt: Text("z. B. Drogerie").foregroundStyle(k.sub.opacity(0.75)))
                                .font(AppFont.dm(16, 500))
                                .foregroundStyle(isFallback ? k.sub : k.text)
                                .tint(k.accent)
                                .disabled(isFallback)
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .padding(.horizontal, 17.5)                 // 1,5 Rahmen + 16 Padding
                                .frame(height: 52)
                                .background(CSSBox(shape: RR(16), paint: .color(k.fieldFocus), border: 1.5,
                                                   borderColor: k.ring, shadows: [.drop(0, 0, 0, 4, k.ringSoft)]))
                                .accessibilityLabel("Name der Kategorie")
                        }
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Icon", k: k)
                        iconGrid(k: k)
                    }
                    .padding(.top, 20)

                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        CTAButton(title: "Speichern", k: k, isEnabled: canSave) { onSave(trimmed, icon) }
                        if category != nil {
                            EKKTextButton(title: "Kategorie löschen", color: t.danger, action: onDelete)
                                .opacity(isFallback ? 0.45 : 1)
                                .allowsHitTesting(!isFallback)
                            Text(isFallback ? "„Sonstiges“ ist die Standardkategorie und bleibt immer erhalten."
                                            : "Artikel dieser Kategorie wandern nach „Sonstiges“.")
                                .font(AppFont.dm(12, 400))
                                .foregroundStyle(k.sub)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.top, -4)                              // margin-top: −4
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(.bottom, keyboardHeight > 0 ? max(0, keyboardHeight - 180) : 0)
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        .onAppear {
            name = category?.name ?? ""
            icon = category.map { CategoryIconCatalog.displayKey(name: $0.name, icon: $0.icon) } ?? "tag"
            if category == nil { nameFocused = true }
        }
    }

    /// Gruppiertes Icon-Raster (60 Icons, 8 Gruppen), scrollt innerhalb von 284 pt.
    /// Oben/unten 14 pt weich ausgeblendet, damit sichtbar ist, dass es weitergeht.
    private func iconGrid(k: SheetTheme) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                    ForEach(CategoryIconCatalog.groups, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title.uppercased())
                                .font(AppFont.dm(11, 600))
                                .tracking(0.66)                              // 0.06em
                                .foregroundStyle(k.sub)
                                .padding(.leading, 4)
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(group.choices, id: \.key) { choice in
                                    iconCell(choice, k: k).id(choice.key)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 14)
            }
            .frame(height: 284)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.05),
                                         .init(color: .black, location: 0.95), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .padding(.top, -14)
            .onAppear { proxy.scrollTo(icon, anchor: .center) }
        }
        .onChange(of: name) { _, newName in
            // Neue Kategorie: passendes Icon vorschlagen, bis der Nutzer selbst wählt.
            guard category == nil, !iconTouched, let suggestion = CategoryIconCatalog.suggestedKey(for: newName) else { return }
            withAnimation(.easeOut(duration: 0.2)) { icon = suggestion }
        }
    }

    /// Icon-Taste: Höhe 52, Radius 16; normal Rahmen 1 fieldBorder auf field, gewählt Rahmen 2 ring auf ringSoft.
    private func iconCell(_ choice: CategoryIconCatalog.Choice, k: SheetTheme) -> some View {
        let key = choice.key
        let isOn = key == icon
        return Button(action: { icon = key; iconTouched = true }) {
            SVGIcon(CategoryIconCatalog.icon(for: key), size: 24, color: k.accentText, lineWidth: 1.9)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(CSSBox(shape: RR(16), paint: .color(isOn ? k.ringSoft : k.field),
                                   border: isOn ? 2 : 1, borderColor: isOn ? k.ring : k.fieldBorder))
                .contentShape(RR(16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview("Kategorie bearbeiten", traits: .fixedLayout(width: 390, height: 844)) {
    EditCategorySheet(appearance: .light, category: CategoryDefinition.defaults[1])
}

#Preview("Kategorie bearbeiten – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    EditCategorySheet(appearance: .dark, category: CategoryDefinition.defaults[1])
}
