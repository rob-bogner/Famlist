/*
 LiveTestCleanup.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Räumt nach Live-UI-Tests auf: löscht alle Artikel und Artikelstamm-Einträge mit dem Namensanfang
   „Livetest“ oder „Offlineprobe“ in den drei Testkonten (vorher blieben sie nach jedem Lauf liegen).

 🔰 Notes for Beginners:
 - Zugang wie in AuthTestHelpers: lokale, nicht versionierte Secrets.plist im Projektordner
   (SUPABASE_URL, SUPABASE_ANON_KEY, TEST_PASSWORD_*). Fehlt sie, wird nichts gelöscht.
 - Die Datenbank-Regeln (RLS) erlauben jedem Konto nur das Löschen in eigenen bzw. geteilten Listen.
 ------------------------------------------------------------------------
 */

import Foundation

enum LiveTestCleanup {
    private static let accounts = [("developer", "DEVELOPER"), ("tester", "TESTER"), ("demo", "DEMO")]

    /// Projektordner/Secrets.plist, eine Ebene über FamlistUITests.
    /// Nur Textwerte (`[String: String]` ist Sendable); gelesen werden ohnehin nur Strings.
    private static let secrets: [String: String] = {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<2 { url.deleteLastPathComponent() }
        return ((NSDictionary(contentsOf: url.appendingPathComponent("Secrets.plist")) as? [String: Any]) ?? [:])
            .compactMapValues { $0 as? String }
    }()

    /// Löscht „Livetest…“-Artikel und -Stammeinträge in allen Testkonten. Gibt die Anzahl gelöschter Zeilen zurück.
    @discardableResult
    static func removeLiveTestData() async -> Int {
        guard let base = secrets["SUPABASE_URL"], let key = secrets["SUPABASE_ANON_KEY"] else { return 0 }
        var removed = 0
        for (name, suffix) in accounts {
            guard let password = secrets["TEST_PASSWORD_\(suffix)"],
                  let token = await signIn(base: base, key: key, email: "\(name)@grocerygenius.app", password: password)
            else { continue }
            for prefix in ["Livetest", "Offlineprobe"] {
                removed += await delete(base: base, key: key, token: token, path: "items?name=like.\(prefix)*")
                removed += await delete(base: base, key: key, token: token,
                                        path: "item_catalog?name_lower=like.\(prefix.lowercased())*")
            }
        }
        return removed
    }

    private static func signIn(base: String, key: String, email: String, password: String) async -> String? {
        guard let url = URL(string: "\(base)/auth/v1/token?grant_type=password") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["access_token"] as? String
    }

    private static func delete(base: String, key: String, token: String, path: String) async -> Int {
        guard let url = URL(string: "\(base)/rest/v1/\(path)") else { return 0 }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return 0 }
        return rows.count
    }
}
