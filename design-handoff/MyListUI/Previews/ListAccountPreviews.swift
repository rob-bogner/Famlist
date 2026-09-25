//  ListAccountPreviews.swift
//  MyListUI
//
//  Gruppe „Listen & Konto“: alle Artboards in Light und Dark auf 390 × 844 pt.

import SwiftUI

// MARK: Meine Listen
#Preview("Meine Listen", traits: .fixedLayout(width: 390, height: 844)) { MyListsScreen(appearance: .light) }
#Preview("Meine Listen – Dark", traits: .fixedLayout(width: 390, height: 844)) { MyListsScreen(appearance: .dark) }

// MARK: Neue Liste
#Preview("Neue Liste", traits: .fixedLayout(width: 390, height: 844)) { CreateListScreen(appearance: .light) }
#Preview("Neue Liste – Dark", traits: .fixedLayout(width: 390, height: 844)) { CreateListScreen(appearance: .dark) }

// MARK: Listen-Optionen
#Preview("Listen-Optionen", traits: .fixedLayout(width: 390, height: 844)) { ListOptionsScreen(appearance: .light) }
#Preview("Listen-Optionen – Dark", traits: .fixedLayout(width: 390, height: 844)) { ListOptionsScreen(appearance: .dark) }

// MARK: Mitglieder & Teilen
#Preview("Mitglieder & Teilen", traits: .fixedLayout(width: 390, height: 844)) { ShareMembersScreen(appearance: .light) }
#Preview("Mitglieder & Teilen – Dark", traits: .fixedLayout(width: 390, height: 844)) { ShareMembersScreen(appearance: .dark) }

// MARK: Profil bearbeiten
#Preview("Profil bearbeiten", traits: .fixedLayout(width: 390, height: 844)) { EditProfileScreen(appearance: .light) }
#Preview("Profil bearbeiten – Dark", traits: .fixedLayout(width: 390, height: 844)) { EditProfileScreen(appearance: .dark) }

// MARK: Einstellungen
#Preview("Einstellungen", traits: .fixedLayout(width: 390, height: 844)) { SettingsScreen(appearance: .light) }
#Preview("Einstellungen – Dark", traits: .fixedLayout(width: 390, height: 844)) { SettingsScreen(appearance: .dark) }

// MARK: Konto löschen
#Preview("Konto löschen", traits: .fixedLayout(width: 390, height: 844)) { DeleteAccountScreen(appearance: .light) }
#Preview("Konto löschen – Dark", traits: .fixedLayout(width: 390, height: 844)) { DeleteAccountScreen(appearance: .dark) }
