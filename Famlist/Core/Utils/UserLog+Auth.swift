/*
 UserLog+Auth.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nutzer-Logs der Kategorie UserLog.Auth: Anmeldung, Abmeldung, Profil und Sitzung.

 📝 Last Change:
 - Aus UserLogger.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension UserLog {
    /// Authentifizierungs- und Profil-Events
    struct Auth {
        static func loginStarted(email: String? = nil) {
            if let email = email {
                log("🔑 Anmeldung gestartet für \(email)")
            } else {
                log("🔑 Anmeldung gestartet")
            }
        }

        static func loginSuccess(username: String? = nil) {
            if let username = username {
                log("✅ Erfolgreich angemeldet als \(username)")
            } else {
                log("✅ Erfolgreich angemeldet")
            }
        }

        static func loginFailed(reason: String? = nil) {
            if let reason = reason {
                log("❌ Anmeldung fehlgeschlagen: \(reason)")
            } else {
                log("❌ Anmeldung fehlgeschlagen")
            }
        }

        static func loggedOut() {
            log("👋 Benutzer abgemeldet")
        }

        static func restoringSession() {
            log("🔄 Sitzung wird wiederhergestellt...")
        }

        static func sessionRestored() {
            log("✅ Sitzung wiederhergestellt")
        }

        static func loadingProfile() {
            log("👤 Benutzerprofil wird geladen...")
        }

        /// Profil gespeichert (Benutzername / Name)
        static func profileUpdated(username: String) {
            log("👤 Profil gespeichert: @\(username)")
        }

        /// Profilfoto geändert
        static func avatarUpdated() {
            log("👤 Profilfoto aktualisiert")
        }

        /// Konto gelöscht (alle Daten entfernt)
        static func accountDeleted() {
            log("🗑️ Konto und alle Daten gelöscht")
        }

        /// Anmeldelink per E-Mail verschickt
        static func magicLinkSent(email: String) {
            log("✉️ Anmeldelink an \(email) gesendet")
        }

        /// Mit Apple angemeldet
        static func appleSignIn() {
            log("🍎 Mit Apple angemeldet")
        }

        static func profileLoaded(publicId: String? = nil) {
            if let publicId = publicId {
                log("✅ Benutzerprofil geladen (ID: \(publicId))")
            } else {
                log("✅ Benutzerprofil geladen")
            }
        }

        static func authSessionReady() {
            log("🔐 Authentifizierung bereit")
        }

        static func authStateChanged(event: String) {
            log("🔄 Auth-Status: \(event)")
        }

        static func authBootstrapCompleted() {
            log("✅ Initialisierung abgeschlossen")
        }
    }
}
