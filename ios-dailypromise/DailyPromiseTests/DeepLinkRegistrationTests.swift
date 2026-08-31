//
//  DeepLinkRegistrationTests.swift
//  DailyPromiseTests
//
//  Guards the one thing that cannot be checked by reading source: whether the
//  URL scheme survives into the FINAL built app bundle. These tests are hosted
//  by DailyPromise.app, so `Bundle.main` here is the real product Info.plist
//  after Xcode merged the generated keys with DailyPromise-Info.plist.
//

import XCTest
@testable import DailyPromise

final class DeepLinkRegistrationTests: XCTestCase {

    /// Every URL scheme the built bundle actually claims.
    private var declaredSchemes: [String] {
        guard let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return []
        }
        return types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
    }

    func testBuiltBundleDeclaresCFBundleURLTypes() throws {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
        XCTAssertNotNil(
            types,
            "CFBundleURLTypes is absent from the built Info.plist. The custom plist did not merge into the product, so iOS will refuse dailypromise:// links."
        )
        XCTAssertFalse(declaredSchemes.isEmpty, "CFBundleURLTypes is present but declares no scheme.")
    }

    func testBuiltBundleClaimsDailyPromiseScheme() {
        XCTAssertTrue(
            declaredSchemes.contains("dailypromise"),
            "Built bundle claims \(declaredSchemes) — expected to contain exactly \"dailypromise\"."
        )
    }

    /// The scheme must match the callback URL character for character; iOS
    /// matching is by exact scheme, and it is lowercased by convention.
    func testSchemeMatchesTheCallbackURLTheEmailSendsUsersTo() throws {
        let callback = try XCTUnwrap(URL(string: "dailypromise://auth-callback"))
        let scheme = try XCTUnwrap(callback.scheme)

        XCTAssertEqual(scheme, "dailypromise")
        XCTAssertEqual(Backend.authCallbackURL.absoluteString, "dailypromise://auth-callback")
        XCTAssertTrue(
            declaredSchemes.contains(scheme),
            "The redirect target's scheme is not registered by the bundle."
        )
    }

    /// A realistic URL as Supabase hands it back, to be sure the guard that
    /// gates the session exchange does not reject the real thing.
    func testAuthCallbackRecognisesSupabaseReturnURLs() throws {
        let pkce = try XCTUnwrap(URL(string: "dailypromise://auth-callback?code=abc123"))
        let implicit = try XCTUnwrap(URL(string: "dailypromise://auth-callback#access_token=abc&refresh_token=def"))
        let bare = try XCTUnwrap(URL(string: "dailypromise://auth-callback"))
        let foreign = try XCTUnwrap(URL(string: "https://example.com"))

        XCTAssertTrue(Backend.isAuthCallback(pkce))
        XCTAssertTrue(Backend.isAuthCallback(implicit))
        XCTAssertTrue(Backend.isAuthCallback(bare))
        XCTAssertFalse(Backend.isAuthCallback(foreign))
    }

    func testBundleIdentifierIsTheExpectedOne() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "app.rork.ttexbyp0kww929p0x5t3t")
    }
}
