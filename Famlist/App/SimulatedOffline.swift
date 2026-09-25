/*
 SimulatedOffline.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nur DEBUG: Startargument `-simulateOffline` lässt jede HTTP-Anfrage der App so scheitern,
   als gäbe es kein Netz (URLError.notConnectedToInternet), und meldet „offline“.

 🔰 Notes for Beginners:
 - Der Simulator hat keinen Schalter für „Netz aus“. Damit lässt sich der Offline-Start im
   UI-Test prüfen (OfflineStartUITests).
 - Im Release-Build existiert dieser Code nicht.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Offline-Start prüfen).
 ------------------------------------------------------------------------
 */

import Foundation

enum SimulatedOffline {
    /// true nur in DEBUG und nur mit dem Startargument `-simulateOffline`.
    static var isActive: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-simulateOffline")
        #else
        false
        #endif
    }
}

#if DEBUG
/// Beantwortet jede Anfrage mit „keine Internetverbindung“.
final class SimulatedOfflineURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}
#endif
