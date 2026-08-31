//
//  DailyPromiseApp.swift
//  DailyPromise
//

import SwiftUI
import UIKit

@main
struct DailyPromiseApp: App {
    @State private var store = PromiseStore()
    @State private var auth = AuthManager()
    @State private var migrator = AccountMigrator()
    @State private var sync = SyncEngine()

    init() {
        Self.applyWarmChrome()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(auth)
                .environment(migrator)
                .environment(sync)
                // The confirmation link from the Supabase email lands here.
                .onOpenURL { url in
                    auth.handleOpenURL(url)
                }
        }
    }

    /// Keeps the tab bar on the same warm paper as the app canvas.
    private static func applyWarmChrome() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(red: 0.969, green: 0.953, blue: 0.925, alpha: 1)
        appearance.shadowColor = UIColor(red: 0.859, green: 0.835, blue: 0.796, alpha: 0.8)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
