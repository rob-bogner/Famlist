//  AllScreensPreviews.swift
//  MyListUI
//
//  Übersicht: Die Vorschauen liegen je Gruppe in eigenen Dateien (alle 390 × 844 pt, Light + Dark):
//  - CorePreviews.swift                       Liste (Hybrid), Abgehakt, Wisch-Aktionen, Leere Liste, Dock-Zustände
//  - OverlayPreviews.swift                    Kontext-Menü, Sortieren, Kopieren, Kopiert, Artikel löschen, Rückgängig
//  - ItemPreviews.swift                       Suchen, Neuer Artikel, Bearbeiten, Produktbild, Artikel verwalten, Barcode, Preisverlauf
//  - ListAccountPreviews.swift                Meine Listen, Neue Liste, Listen-Optionen, Mitglieder & Teilen, Profil, Einstellungen, Konto löschen
//  - OnboardingCategoryReceiptPreviews.swift  Anmelden, Profil anlegen, Einladung, Kategorien, Kassenzettel, Einkauf erledigt
//
//  Zum Pixel-Abgleich: Vorschau auf 100 % stellen und gegen Design/png/<Artboard>.png (@2x) legen.

import SwiftUI

// MARK: - System-Erscheinungsbild

/// Wählt Light/Dark automatisch nach dem System-Erscheinungsbild.
struct AdaptiveListScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    var state: ListRowState = .normal

    var body: some View {
        ListScreen(appearance: colorScheme == .dark ? .dark : .light, state: state)
    }
}
