/*
 AuthTestHelpers.swift

 GroceryGenius
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
 - Extracted from AuthView.swift to improve file organization.
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
        
        var password: String {
            switch self {
            case .developer: return "DevTest123!"
            case .tester: return "TestUser456!"
            case .demo: return "DemoPass789!"
            }
        }
        
        var description: String {
            switch self {
            case .developer: return "Developer"
            case .tester: return "Tester"
            case .demo: return "Demo"
            }
        }
    }
    
    static func getCredentials(for account: TestAccount) -> (email: String, password: String) {
        return (email: account.rawValue, password: account.password)
    }
}

#endif

