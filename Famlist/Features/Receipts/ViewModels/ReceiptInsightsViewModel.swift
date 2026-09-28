/*
 ReceiptInsightsViewModel.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand der Auswertung: gewählter Reiter, Monat und Suchtext; berechnet „Ausgaben“ (ReceiptInsights).

 🔰 Notes for Beginners:
 - Offline-First: rechnet nur mit den übergebenen Bons (Archiv inkl. ausstehender), kein Netz.
 - Startmonat: übergeben (Rückweg aus dem Preisverlauf), sonst aktueller Monat bzw. letzter Monat mit Bons.
 - „weiter“ nur bis zum aktuellen Monat, „zurück“ nur bis zum Monat des ersten Bons.
 - UserLog nur hier (ViewModel): „📊 Auswertung geöffnet (<Monat>)“, „📊 Monat gewechselt“.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ReceiptInsightsViewModel: ObservableObject {
    @Published var tab: InsightTab
    @Published private(set) var month: Date
    @Published var search = ""

    let receipts: [ArchivedReceipt]
    let context: ReceiptLineContext
    private let now: Date

    init(receipts: [ArchivedReceipt], context: ReceiptLineContext, tab: InsightTab = .spend, month: Date? = nil,
         now: Date = Date()) {
        self.receipts = receipts
        self.context = context
        self.tab = tab
        self.now = now
        self.month = ReceiptInsights.monthStart(month ?? ReceiptInsights.defaultMonth(receipts, now: now) ?? now)
    }

    var spend: SpendInsights { ReceiptInsights.spend(receipts, month: month, context: context) }

    /// „September 2026“
    var monthTitle: String { InsightFormat.month(month, withYear: true) }

    var canGoBack: Bool {
        guard let first = ReceiptInsights.firstMonth(receipts) else { return false }
        return month > first
    }

    var canGoForward: Bool { month < ReceiptInsights.monthStart(now) }

    func showPreviousMonth() {
        guard canGoBack else { return }
        change(by: -1)
    }

    func showNextMonth() {
        guard canGoForward else { return }
        change(by: 1)
    }

    /// Beim Erscheinen des Sheets.
    func noteOpened() {
        logVoid(params: (action: "receiptInsights.open", month: monthTitle, receipts: receipts.count))
        UserLog.UI.insightsOpened(month: monthTitle)
    }

    private func change(by months: Int) {
        month = ReceiptInsights.adding(months: months, to: month)
        logVoid(params: (action: "receiptInsights.month", month: monthTitle))
        UserLog.UI.insightsMonthChanged(to: monthTitle)
    }
}
