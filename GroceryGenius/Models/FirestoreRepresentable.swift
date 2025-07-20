/*
 FirestoreRepresentable.swift
 GroceryGenius
 Created on: 20.07.2025
 ------------------------------------------------------------------------
 📄 File Overview:
 This protocol defines a contract for models that can be represented in Firestore.
 It provides methods for converting to and from Firestore-compatible dictionaries.
 ------------------------------------------------------------------------
*/

import Foundation

/// Protocol for Firestore-compatible models.
protocol FirestoreRepresentable {
    /// Converts the model to a Firestore dictionary.
    func toFirestoreDict() -> [String: Any]
    /// Initializes the model from a Firestore dictionary.
    init?(from dict: [String: Any])
}
