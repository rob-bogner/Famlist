//  OnboardingCategoryReceiptPreviews.swift
//  MyListUI
//
//  Gruppe „Einstieg, Kategorien, Kassenzettel“ auf der Referenzgröße 390 × 844 pt.
//  „Kassenzettel“ (Kamera) gibt es nur als ein Artboard – die Kamera ist immer dunkel.

import SwiftUI

// MARK: Anmelden
#Preview("Anmelden", traits: .fixedLayout(width: 390, height: 844)) { SignInScreen(appearance: .light) }
#Preview("Anmelden – Dark", traits: .fixedLayout(width: 390, height: 844)) { SignInScreen(appearance: .dark) }

// MARK: Profil anlegen
#Preview("Profil anlegen", traits: .fixedLayout(width: 390, height: 844)) { ProfileSetupScreen(appearance: .light) }
#Preview("Profil anlegen – Dark", traits: .fixedLayout(width: 390, height: 844)) { ProfileSetupScreen(appearance: .dark) }

// MARK: Einladung annehmen
#Preview("Einladung annehmen", traits: .fixedLayout(width: 390, height: 844)) { AcceptInviteScreen(appearance: .light) }
#Preview("Einladung annehmen – Dark", traits: .fixedLayout(width: 390, height: 844)) { AcceptInviteScreen(appearance: .dark) }

// MARK: Kategorien verwalten
#Preview("Kategorien verwalten", traits: .fixedLayout(width: 390, height: 844)) { ManageCategoriesScreen(appearance: .light) }
#Preview("Kategorien verwalten – Dark", traits: .fixedLayout(width: 390, height: 844)) { ManageCategoriesScreen(appearance: .dark) }

// MARK: Kategorie bearbeiten
#Preview("Kategorie bearbeiten", traits: .fixedLayout(width: 390, height: 844)) { EditCategoryScreen(appearance: .light) }
#Preview("Kategorie bearbeiten – Dark", traits: .fixedLayout(width: 390, height: 844)) { EditCategoryScreen(appearance: .dark) }

// MARK: Kassenzettel (Kamera, nur ein Artboard)
#Preview("Kassenzettel fotografieren (Kamera, immer dunkel)", traits: .fixedLayout(width: 390, height: 844)) { ReceiptCaptureScreen(appearance: .light) }

// MARK: Kassenzettel prüfen
#Preview("Kassenzettel prüfen", traits: .fixedLayout(width: 390, height: 844)) { ReceiptReviewScreen(appearance: .light) }
#Preview("Kassenzettel prüfen – Dark", traits: .fixedLayout(width: 390, height: 844)) { ReceiptReviewScreen(appearance: .dark) }

// MARK: Einkauf erledigt
#Preview("Einkauf erledigt", traits: .fixedLayout(width: 390, height: 844)) { ShoppingDoneScreen(appearance: .light) }
#Preview("Einkauf erledigt – Dark", traits: .fixedLayout(width: 390, height: 844)) { ShoppingDoneScreen(appearance: .dark) }
