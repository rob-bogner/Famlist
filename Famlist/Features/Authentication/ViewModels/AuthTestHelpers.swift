/*
 AuthTestHelpers.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Helper for providing pre-configured test accounts in simulator.

 🛠 Includes:
 - TestAccount enum with pre-configured credentials
 - Helper to retrieve credentials for quick testing

 🔰 Notes for Beginners:
 - Only compiled in DEBUG mode for simulators.
 - Provides quick access to test accounts without typing credentials.
 - Never ship these credentials in production builds.

 📝 Last Change:
 - Passwörter nicht mehr im Quelltext, sondern aus der lokalen Secrets.plist (Audit 25.09.2026;
   alte Passwörter waren im öffentlichen Repo und wurden live ersetzt).
 ------------------------------------------------------------------------
 */

#if DEBUG && targetEnvironment(simulator)

import Foundation // Foundation provides string types.

/// Helper for providing pre-configured test accounts in simulator.
enum SimulatorAuthHelper {
    
    enum TestAccount: String, CaseIterable {
        case developer = "developer@grocerygenius.app"
        case tester = "tester@grocerygenius.app"
        case demo = "demo@grocerygenius.app"
        
        /// Passwort aus der lokalen, nicht versionierten `Secrets.plist` im Projektordner
        /// (Schlüssel TEST_PASSWORD_DEVELOPER / _TESTER / _DEMO). Leer, wenn die Datei fehlt.
        /// Der Simulator darf Dateien des Macs lesen; der Pfad wird aus `#filePath` abgeleitet.
        var password: String {
            SimulatorAuthHelper.localSecrets["TEST_PASSWORD_\(description.uppercased())"] ?? ""
        }
        
        var description: String {
            switch self {
            case .developer: return "Developer"
            case .tester: return "Tester"
            case .demo: return "Demo"
            }
        }
    }
    
    /// Projektordner/Secrets.plist, fünf Ebenen über dieser Datei.
    /// Nur Textwerte (`[String: String]` ist Sendable); gelesen werden ohnehin nur Strings.
    static let localSecrets: [String: String] = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent("Secrets.plist")
        return ((NSDictionary(contentsOf: file) as? [String: Any]) ?? [:]).compactMapValues { $0 as? String }
    }()

    static func getCredentials(for account: TestAccount) -> (email: String, password: String) {
        return (email: account.rawValue, password: account.password)
    }
}

#endif

