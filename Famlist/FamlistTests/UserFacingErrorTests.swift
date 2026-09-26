/*
 UserFacingErrorTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit-Tests für UserFacingError.message(for:): technische Fehler → deutsche Sätze.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
*/

import XCTest
import Supabase
@testable import Famlist

final class UserFacingErrorTests: XCTestCase {

    private func http(_ status: Int) -> HTTPError {
        let response = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return HTTPError(data: Data("{\"message\":\"raw\"}".utf8), response: response)
    }

    // MARK: - Netzwerk

    func test_urlError_offline() {
        XCTAssertEqual(UserFacingError.message(for: URLError(.notConnectedToInternet)), UserFacingError.offline)
        XCTAssertEqual(UserFacingError.message(for: URLError(.networkConnectionLost)), UserFacingError.offline)
    }

    func test_nsErrorInURLDomain_offline() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
        XCTAssertEqual(UserFacingError.message(for: error), UserFacingError.offline)
    }

    func test_urlError_timeout() {
        XCTAssertEqual(UserFacingError.message(for: URLError(.timedOut)), UserFacingError.timeout)
    }

    // MARK: - HTTP

    func test_httpStatus() {
        XCTAssertEqual(UserFacingError.message(for: http(401)), UserFacingError.sessionExpired)
        XCTAssertEqual(UserFacingError.message(for: http(403)), UserFacingError.forbidden)
        XCTAssertEqual(UserFacingError.message(for: http(429)), UserFacingError.rateLimited)
        XCTAssertEqual(UserFacingError.message(for: http(500)), UserFacingError.fallback)
    }

    // MARK: - PostgREST

    func test_postgrestCodes() {
        XCTAssertEqual(UserFacingError.message(for: PostgrestError(code: "42501", message: "rls")), UserFacingError.forbidden)
        XCTAssertEqual(UserFacingError.message(for: PostgrestError(code: "PGRST116", message: "none")), UserFacingError.notFound)
        XCTAssertEqual(UserFacingError.message(for: PostgrestError(code: "23505", message: "dup")), UserFacingError.duplicate)
        XCTAssertEqual(UserFacingError.message(for: PostgrestError(code: "XX000", message: "boom")), UserFacingError.fallback)
    }

    // MARK: - Auth

    func test_authErrors() {
        let response = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        let wrong = Auth.AuthError.api(message: "Invalid login credentials", errorCode: .invalidCredentials,
                                  underlyingData: Data(), underlyingResponse: response)
        XCTAssertEqual(UserFacingError.message(for: wrong), UserFacingError.invalidCredentials)
        XCTAssertEqual(UserFacingError.message(for: Auth.AuthError.sessionMissing), UserFacingError.sessionExpired)
        XCTAssertEqual(UserFacingError.message(for: Famlist.AuthError.unauthenticated), UserFacingError.sessionExpired)

        let limited = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 429, httpVersion: nil, headerFields: nil)!
        let unknown = Auth.AuthError.api(message: "slow down", errorCode: .unknown, underlyingData: Data(), underlyingResponse: limited)
        XCTAssertEqual(UserFacingError.message(for: unknown), UserFacingError.rateLimited)
    }

    // MARK: - Eigene und unbekannte Fehler

    func test_inviteError_keepsOwnText() {
        XCTAssertEqual(UserFacingError.message(for: InviteError.invalidOrExpired), InviteError.invalidOrExpired.errorDescription)
    }

    func test_unknownError_fallback_neverRawText() {
        let raw = NSError(domain: "Something", code: 42, userInfo: [NSLocalizedDescriptionKey: "The operation couldn’t be completed."])
        XCTAssertEqual(UserFacingError.message(for: raw), "Das hat nicht geklappt. Bitte versuche es noch einmal.")
    }
}
