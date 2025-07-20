/*
 FirestoreRepresentable.swift
 GroceryGenius
 Created on: 20.07.2025
 ------------------------------------------------------------------------
 📄 File Overview:
 Dieses Protokoll definiert die Anforderungen für Models, die mit Firestore gespeichert und geladen werden können.
 ------------------------------------------------------------------------
*/

import Foundation

/// Protokoll für Models, die mit Firestore gespeichert und geladen werden können.
protocol FirestoreRepresentable: Identifiable, Codable {
    var id: String { get }
}
