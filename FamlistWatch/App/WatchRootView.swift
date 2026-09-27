/*
 WatchRootView.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Wurzel der Uhr-App: ohne Listen ein Statusbildschirm (Anmeldung über das iPhone), sonst die Navigation
   „Listen“ → aktive Liste (bzw. „Alles erledigt“) → Artikel / Hinzufügen. Haptik beim Abhaken.

 🔰 Notes for Beginners:
 - Offline-First: Liegen Listen lokal vor, zeigt die Uhr sie immer – auch ohne Sitzung oder Netz.
 - Deep Links (Komplikationen) setzen den Navigationsstapel (WatchRoute.path(for:)).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchRootView: View {
    @ObservedObject var session: WatchSessionManager
    @ObservedObject var model: WatchListViewModel
    @Binding var path: [WatchRoute]

    var body: some View {
        if model.hasLists {
            navigation
        } else {
            status
        }
    }

    private var navigation: some View {
        NavigationStack(path: $path) {
            WatchListsScreen(lists: model.lists) { list in
                model.select(list.id)
                path = [.list]
            }
            .navigationDestination(for: WatchRoute.self) { route in
                destination(route)
            }
        }
        .sensoryFeedback(.success, trigger: model.checkFeedback)
    }

    @ViewBuilder private func destination(_ route: WatchRoute) -> some View {
        switch route {
        case .list:
            if model.isAllDone {
                WatchDoneScreen(count: model.totalCount, listName: model.title, onReset: model.resetAll,
                                onTitle: { path = [] })
            } else {
                WatchListScreen(title: model.title, checked: model.checkedCount, total: model.totalCount,
                                sections: model.sections, onToggle: model.toggle,
                                onOpen: { path.append(.item($0)) }, onCheckAll: model.checkAll,
                                onAdd: { path.append(.add) }, onTitle: { path = [] }, note: pendingNote)
            }
        case .item(let id):
            if let detail = model.detail(for: id) {
                WatchItemScreen(backTitle: model.title, name: detail.name, category: detail.category,
                                unitName: detail.unitName, units: detail.units, step: detail.step,
                                onUnitsChanged: { model.setUnits(id, to: $0) },
                                onCheck: { model.check(id); pop() }, onBack: pop)
            }
        case .add:
            WatchAddScreen(frequent: model.frequent) { name in
                model.add(name: name)
                pop()
            }
        }
    }

    /// Ohne Sitzung wird nichts gesendet – Änderungen warten (nicht gestaltet, PLAN.md §9).
    private var pendingNote: String? {
        guard session.userId == nil, model.pendingChanges > 0 else { return nil }
        return model.pendingChanges == 1 ? "1 Änderung wartet auf das iPhone" : "\(model.pendingChanges) Änderungen warten auf das iPhone"
    }

    @ViewBuilder private var status: some View {
        switch session.state {
        case .checking, .pairing:
            WatchStatusScreen(message: "Verbinde mit dem iPhone …", showsProgress: true)
        case .needsPhone:
            WatchStatusScreen(message: "Öffne Famlist auf dem iPhone, um die Uhr anzumelden.") {
                Task { await session.requestFromPhone() }
            }
        case .signedIn:
            WatchStatusScreen(message: "Listen werden geladen …", showsProgress: true)
        }
    }

    private func pop() {
        if !path.isEmpty { path.removeLast() }
    }
}

#if DEBUG
#Preview("Uhr mit Beispieldaten") {
    let preview = WatchPreviewFactory.make()
    return WatchRootView(session: preview.session, model: preview.model, path: .constant([.list]))
}
#endif
