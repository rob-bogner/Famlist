/*
 ListNameSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hybrid-Sheet für den Namen einer Liste: „Neue Liste“ oder „Liste umbenennen“.
   Titelzeile → 20 → Feldbezeichnung „Name“ → Textfeld 52 → Button (unten 34 bzw. 14 über der Tastatur).

 🔰 Notes for Beginners:
 - Nicht im Design-Paket gezeichnet; gebaut aus denselben Bausteinen wie „Neuer Artikel“.
 - Die Sheet-Höhe wächst mit der Tastatur, damit Feld und Button sichtbar bleiben.
 - Neue Listen gehören immer dem angemeldeten Nutzer (Fallback: Besitzer der aktiven Liste).

 📝 Last Change:
 - Initial creation (ersetzt ListNameInputSheet aus ListsOverviewView).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hybrid sheet to create or rename a list.
struct ListNameSheet: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var session: AppSessionViewModel

    let mode: ListNameMode
    let k: SheetTheme
    let maxHeight: CGFloat
    let keyboardHeight: CGFloat
    let onDone: () -> Void

    @State private var name: String

    init(mode: ListNameMode, k: SheetTheme, maxHeight: CGFloat, keyboardHeight: CGFloat, onDone: @escaping () -> Void) {
        self.mode = mode
        self.k = k
        self.maxHeight = maxHeight
        self.keyboardHeight = keyboardHeight
        self.onDone = onDone
        _name = State(initialValue: mode.initialName)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var bottomInset: CGFloat { keyboardHeight > 0 ? keyboardHeight + 14 : 34 }
    /// Kopf 72 (Rand 1 + 10 + Griff 5 + 12 + Titelzeile 44) + 20 + Label 22 + Feld 52 + 24 + Button 56 + unten.
    private var designHeight: CGFloat { 72 + 20 + 22 + 52 + 24 + 56 + bottomInset }

    var body: some View {
        HybridSheetLayer(k: k, title: mode.title, designHeight: designHeight, maxHeight: maxHeight, onClose: onDone) {
            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Name", k: k)
                    SheetTextField(k: k, text: $name, placeholder: "Listenname", height: 52, autoFocus: true)
                        .onSubmit(submit)
                }
                .padding(.top, 20)
                .frame(maxHeight: .infinity, alignment: .top)
                CTAButton(title: mode.confirmLabel, k: k, isEnabled: !trimmed.isEmpty, action: submit)
                    .padding(.bottom, bottomInset)   // Button unten angeheftet (wie „Neuer Artikel“)
            }
            .padding(.horizontal, 20)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
        }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        switch mode {
        case .create:
            guard let ownerId = session.currentProfile?.id ?? listViewModel.defaultList?.ownerId else { return }
            listViewModel.createNewList(title: trimmed, ownerId: ownerId)
        case .rename(let list):
            if trimmed != list.title { listViewModel.renameList(list, to: trimmed) }
        }
        onDone()
    }
}

#Preview {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        ListNameSheet(mode: .create, k: SheetTheme(.light), maxHeight: 790, keyboardHeight: 0, onDone: {})
    }
    .ignoresSafeArea()
    .environmentObject(listVM)
    .environmentObject(AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                           lists: PreviewListsRepository(), listViewModel: listVM))
}
