/*
 WatchDesignGallery.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nur DEBUG: zeigt einen Screen mit den Beispieldaten aus Watch*.dc.html für den Pixelvergleich.
   Start: xcrun simctl launch <uhr> com.roxo.famlist.watchkitapp -watchDesignScreen list|item|add|done|lists|face
 ------------------------------------------------------------------------
 */

#if DEBUG
import SwiftUI

struct WatchDesignGallery: View {
    let screen: String

    /// Wert des Startarguments `-watchDesignScreen`, sonst nil.
    static var requestedScreen: String? {
        UserDefaults.standard.string(forKey: "watchDesignScreen")
    }

    var body: some View {
        NavigationStack {
            switch screen {
            case "item":
                WatchItemScreen(backTitle: "My List", name: "Butter", category: "Milchprodukte",
                                unitName: "Packung", units: 1)
            case "add":
                WatchAddScreen(frequent: WatchSampleData.frequent)
            case "done":
                WatchDoneScreen(count: 6, listName: "My List")
            case "lists":
                WatchListsScreen(lists: WatchSampleData.lists)
            case "face":
                WatchFaceGallery()
            default:
                WatchListScreen(title: "My List", checked: 2, total: 6, sections: WatchSampleData.sections)
            }
        }
    }
}

#Preview {
    WatchDesignGallery(screen: "list")
}
#endif
