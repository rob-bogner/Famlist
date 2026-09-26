/*
 WatchSampleData.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Beispieldaten exakt wie in Watch*.dc.html – für #Preview und die Design-Screenshots.
 ------------------------------------------------------------------------
 */

import Foundation

enum WatchSampleData {
    static let sections: [WatchSectionDisplay] = [
        WatchSectionDisplay(title: "Obst & Gemüse", items: [
            WatchItemDisplay(id: "bananen", name: "Bananen", quantity: "6 Stück", isChecked: false),
            WatchItemDisplay(id: "tomaten", name: "Tomaten", quantity: "500 g", isChecked: false),
            WatchItemDisplay(id: "aepfel", name: "Äpfel", quantity: "1 kg", isChecked: true),
        ]),
    ]

    static let frequent: [WatchFrequentItem] = [
        WatchFrequentItem(name: "Milch", detail: "Milchprodukte"),
        WatchFrequentItem(name: "Brot", detail: "Backwaren"),
        WatchFrequentItem(name: "Eier", detail: "10 Stück"),
    ]

    static let lists: [WatchListSummary] = [
        WatchListSummary(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!, name: "My List",
                         status: "4 von 6 offen", fraction: 1.0 / 3.0, isFavorite: true),
        WatchListSummary(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!, name: "Drogerie",
                         status: "3 offen", fraction: 0),
        WatchListSummary(id: UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!, name: "Getränke",
                         status: "erledigt", fraction: 1),
    ]
}
