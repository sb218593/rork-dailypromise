//
//  ReminderService.swift
//  DailyPromise
//

import Foundation
import UserNotifications

/// One quiet daily reminder to keep today's promise. Nothing else is ever scheduled.
enum ReminderService {
    private static let identifier = "dailypromise.daily-reminder"

    /// Asks for permission the first time the reminder is switched on.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            print("DailyPromise: notification permission request failed.")
            return false
        }
    }

    static func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    /// Replaces the pending reminder with a daily one at the given time.
    static func schedule(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Votre promesse du jour"
        content.body = "Un instant pour la tenir."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        do {
            try await center.add(request)
        } catch {
            print("DailyPromise: unable to schedule the daily reminder.")
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

/// Bundle information shown in Settings.
nonisolated enum AppInfo {
    static var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
