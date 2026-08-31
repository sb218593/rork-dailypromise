//
//  Backend.swift
//  DailyPromise
//

import Foundation
import Supabase

/// The single Supabase client for the app.
///
/// Native Supabase Auth owns the session: it stores and refreshes the tokens in
/// the iOS Keychain, so the app never handles a raw token itself.
nonisolated enum Backend {
    /// Injected at build time. Empty in source control by design.
    private static let configuredURL: URL? = {
        let raw = Config.EXPO_PUBLIC_SUPABASE_URL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }()

    private static let anonKey: String = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY

    /// False when a build carries no Supabase configuration. The app then stays
    /// entirely local rather than crashing: offline behaviour is never sacrificed
    /// to the account layer.
    static var isConfigured: Bool { configuredURL != nil && !anonKey.isEmpty }

    /// Where Supabase sends the user back after they open a link from an email.
    ///
    /// The scheme is registered in `DailyPromise-Info.plist` and allow-listed in the
    /// project's Auth redirect URLs, so the confirmation link lands in the app
    /// instead of the default `SITE_URL`.
    static let authCallbackURL: URL = URL(string: "dailypromise://auth-callback")!

    /// True when a URL is one the auth layer should try to consume.
    static func isAuthCallback(_ url: URL) -> Bool {
        url.scheme?.lowercased() == authCallbackURL.scheme
    }

    static let client = SupabaseClient(
        supabaseURL: configuredURL ?? URL(string: "https://unconfigured.dailypromise.invalid")!,
        supabaseKey: anonKey
    )
}
