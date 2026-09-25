/*
 TestWaiting.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Wartet in Tests auf eine Bedingung statt eine feste Zeit zu schlafen. Feste Wartezeiten waren auf
   langsamen Rechnern zu kurz (Test rot) und auf schnellen unnötig lang (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

/// Prüft `condition` alle 10 ms, bis sie zutrifft oder `timeout` Sekunden vergangen sind.
/// Die anschließende Assertion im Test meldet den Fehler, falls die Bedingung nie eintrat.
@MainActor
func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
