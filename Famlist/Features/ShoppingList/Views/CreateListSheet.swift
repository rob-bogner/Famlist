/*
 CreateListSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Neue Liste“ (Höhe 392): Name der Liste + Schalter „Als Favorit – Öffnet sich beim App-Start“
   + „Liste erstellen“.

 🔰 Notes for Beginners:
 - Vorlage: CreateListScreen in design-handoff/MyListUI/Screens/ListManagementScreens.swift
   (CreateList.dc.html). Werte 1:1; statt des Design-Cursors zeichnet iOS den Cursor (.tint).
 - Mit Tastatur wandert das Sheet um die Tastaturhöhe nach oben (Design zeigt keine Tastatur).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CreateListSheet: View {
    let appearance: Appearance
    var keyboardHeight: CGFloat = 0
    var onClose: () -> Void = {}
    var onCreate: (_ name: String, _ isFavorite: Bool) -> Void = { _, _ in }

    @State private var name = ""
    @State private var isFavorite = false

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k

        ListAccountBackdrop(scrim: t.scrimSheet) {
            DesignListScreen(appearance: appearance)
        } content: {
            ListAccountSheet(k: k, height: 392, title: "Neue Liste", onClose: onClose) {
                ListAccountFieldGroup(label: "Name der Liste", t: t) {
                    ListAccountFocusedField(t: t, text: $name, placeholder: "z. B. Edeka oder Wochenmarkt",
                                            a11yLabel: "Name der Liste", autoFocus: true, onSubmit: create) {
                        EmptyView()
                    }
                }
                .padding(.top, 20)

                // Favoriten-Zeile: padding 12 14 (+1 Rahmen, content-box), Radius 18, gap 12
                HStack(spacing: 12) {
                    SVGFilledIcon(Icon.star, size: 20, color: .hex("#F5B521"), lineWidth: 1.5)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Als Favorit")
                            .font(AppFont.dm(15, 500))
                            .foregroundStyle(k.text)
                        Text("Öffnet sich beim App-Start")
                            .font(AppFont.dm(12, 400))
                            .foregroundStyle(k.sub)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ListAccountToggle(t: t, isOn: $isFavorite, label: "Als Favorit")
                }
                .padding(.vertical, 13)
                .padding(.horizontal, 15)
                .background(CSSBox(shape: RR(18), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                .padding(.top, 16)

                Spacer(minLength: 0)                               // margin-top: auto
                CTAButton(title: "Liste erstellen", k: k, isEnabled: !trimmed.isEmpty, action: create)
                    .padding(.top, 20)
            }
        }
        .padding(.bottom, keyboardHeight)
        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }

    private func create() {
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed, isFavorite)
    }
}

#Preview("Neue Liste", traits: .fixedLayout(width: 390, height: 844)) { CreateListSheet(appearance: .light) }
#Preview("Neue Liste – Dark", traits: .fixedLayout(width: 390, height: 844)) { CreateListSheet(appearance: .dark) }
