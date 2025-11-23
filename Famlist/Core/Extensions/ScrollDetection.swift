/*
 ScrollDetection.swift
 
 GroceryGenius
 Created on: 22.11.2025
 
 ------------------------------------------------------------------------
 📄 File Overview:
 - ViewModifier und Helper für Scroll-Detection in SwiftUI Lists
 
 🛠 Includes:
 - Scroll-Erkennung mittels DragGesture
 - Debounce-Logik für "Scroll beendet"-Events
 
 🔰 Notes for Beginners:
 - Nutzt simultaneousGesture mit DragGesture für zuverlässiges Tracking
 - Task-basierte Debounce-Logik erkennt Scroll-Ende
 - Funktioniert mit SwiftUI List und ScrollView
 
 📝 Last Change:
 - Umgestellt auf DragGesture für maximale Kompatibilität
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - View Extension

extension View {
    /// Fügt Scroll-Detection hinzu und benachrichtigt über Scroll-Status
    /// - Parameters:
    ///   - isScrolling: Binding das true ist während gescrollt wird
    ///   - debounceDelay: Verzögerung in Sekunden bevor Scrollen als "beendet" gilt (Standard: 0.2)
    func onScrollChange(
        isScrolling: Binding<Bool>,
        debounceDelay: Double = 0.2
    ) -> some View {
        self.modifier(ScrollDetectionModifier(isScrolling: isScrolling, debounceDelay: debounceDelay))
    }
}

// MARK: - Scroll Detection Modifier

/// ViewModifier der Scroll-Aktivität über DragGesture erkennt
struct ScrollDetectionModifier: ViewModifier {
    @Binding var isScrolling: Bool
    let debounceDelay: Double
    
    @State private var debounceTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        handleScrollStart()
                    }
                    .onEnded { _ in
                        handleScrollEnd()
                    }
            )
    }
    
    private func handleScrollStart() {
        // Cancele vorherige Debounce-Task
        debounceTask?.cancel()
        
        // Setze sofort auf "scrolling"
        if !isScrolling {
            isScrolling = true
        }
    }
    
    private func handleScrollEnd() {
        // Starte Debounce-Task
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    isScrolling = false
                }
            }
        }
    }
}

