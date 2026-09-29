/*
 ListViewModel+ListUndo.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Liste löschen / verlassen mit 5 s „Rückgängig“ (Wisch-Aktion und Kontextmenü in „Meine Listen“).

 🔰 Notes for Beginners:
 - `stageListRemoval`: Liste sofort ausblenden (ggf. zur nächsten Liste wechseln), Zeitraum starten.
 - `undoListRemoval`: Liste wieder einblenden; war sie geöffnet, wieder zu ihr wechseln. Nichts wurde gesendet.
 - `commitPendingListRemoval`: Auftrag an den Server (wie deleteList / leaveList). Schlägt er fehl, kommt
   die Liste zurück und eine Fehlermeldung erscheint.
 - Eine neue Löschung schreibt eine noch offene zuerst fest (immer nur ein Hinweis gleichzeitig).
 - Die letzte Liste kann nicht gelöscht werden (Hinweis wie LastListError).

 📝 Last Change:
 - Initial creation (Wisch-Aktionen „Meine Listen“ + Rückgängig, Wunsch Robert 29.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension ListViewModel {
    /// Blendet die Liste sofort aus und startet den Rückgängig-Zeitraum.
    func stageListRemoval(_ list: ListModel, kind: PendingListRemoval.Kind) {
        if kind == .delete, allLists.count <= 1 {
            errorMessage = "Die letzte Liste kann nicht gelöscht werden."
            return
        }
        commitPendingListRemoval()
        logVoid(params: (action: "stageListRemoval", listId: list.id, leave: kind != .delete))

        let wasActive = listId == list.id
        withAnimation(.easeInOut(duration: 0.3)) {
            allLists.removeAll { $0.id == list.id }
            pendingListRemoval = PendingListRemoval(list: list, kind: kind, wasActive: wasActive,
                                                    deadline: Date().addingTimeInterval(PendingListRemoval.undoDuration))
        }
        if wasActive, let next = allLists.first(where: { $0.isDefault }) ?? allLists.first {
            switchToList(next)
        }
        let removalId = pendingListRemoval?.id
        pendingListRemovalTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(PendingListRemoval.undoDuration * 1_000_000_000))
            guard !Task.isCancelled, let self, self.pendingListRemoval?.id == removalId else { return }
            self.commitPendingListRemoval()
        }
    }

    /// „Rückgängig“: Liste wieder anzeigen, nichts wurde gesendet.
    func undoListRemoval() {
        guard let pending = pendingListRemoval else { return }
        pendingListRemovalTask?.cancel()
        pendingListRemovalTask = nil
        logVoid(params: (action: "undoListRemoval", listId: pending.list.id))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            pendingListRemoval = nil
            if !allLists.contains(where: { $0.id == pending.list.id }) {
                allLists.append(pending.list)
                allLists.sort { $0.createdAt < $1.createdAt }
            }
        }
        if pending.wasActive { switchToList(pending.list) }
    }

    /// Sendet eine offene Löschung bzw. das Verlassen an den Server.
    func commitPendingListRemoval() {
        guard let pending = pendingListRemoval else { return }
        pendingListRemovalTask?.cancel()
        pendingListRemovalTask = nil
        withAnimation(.easeInOut(duration: 0.25)) { pendingListRemoval = nil }
        listItemCounts.removeValue(forKey: pending.list.id)
        switch pending.kind {
        case .delete: sendListDeletion(pending.list)
        case .leave(let profileId): sendListLeave(pending.list, profileId: profileId)
        }
    }

    // MARK: - Server

    private func sendListDeletion(_ list: ListModel) {
        guard let repo = listsRepository else { return }
        logVoid(params: (action: "deleteList", listId: list.id, title: list.title))
        UserLog.Data.listDeleted(name: list.title)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await repo.deleteList(listId: list.id)
                self.forgetLocalData(of: list.id)
                logVoid(params: (action: "deleteList.accepted", listId: list.id))
            } catch {
                self.restore(list, after: error)
                logVoid(params: (action: "deleteList.error", error: (error as NSError).localizedDescription))
            }
        }
    }

    private func sendListLeave(_ list: ListModel, profileId: UUID) {
        guard let repo = listsRepository else { return }
        logVoid(params: (action: "leaveList", listId: list.id))
        UserLog.Data.listLeft(name: list.title)
        Task { [weak self] in
            guard let self else { return }
            do {
                try await repo.leaveList(listId: list.id, profileId: profileId)
                self.forgetLocalData(of: list.id)
            } catch {
                self.restore(list, after: error)
            }
        }
    }

    /// Auftrag abgelehnt (z. B. offline): Liste wieder anzeigen, Fehler melden.
    private func restore(_ list: ListModel, after error: Error) {
        if !allLists.contains(where: { $0.id == list.id }) {
            allLists.append(list)
            allLists.sort { $0.createdAt < $1.createdAt }
        }
        setError(error)
    }
}
