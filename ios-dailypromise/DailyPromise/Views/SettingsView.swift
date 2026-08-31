//
//  SettingsView.swift
//  DailyPromise
//

import SwiftUI

/// A short, quiet settings screen: who you are, when to be reminded, and nothing more.
struct SettingsView: View {
    @Environment(PromiseStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(SyncEngine.self) private var sync
    @Environment(\.dismiss) private var dismiss

    @State private var isNameEditorPresented = false
    @State private var isLogoutConfirmationPresented = false
    @State private var isPermissionAlertPresented = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isNameEditorPresented = true
                    } label: {
                        HStack {
                            Text("Prénom")
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(store.userName)
                                .foregroundStyle(Theme.muted)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.muted.opacity(0.6))
                        }
                    }

                    if let email = auth.email {
                        LabeledContent("Compte", value: email)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } header: {
                    Text("Compte")
                } footer: {
                    if auth.isSignedIn {
                        Text(syncStatus)
                    } else {
                        Text("Vos promesses vivent sur cet appareil. Un compte les garde si vous changez de téléphone.")
                    }
                }

                Section {
                    Toggle("Rappel quotidien", isOn: reminderBinding)
                        .tint(Theme.terracotta)
                        .foregroundStyle(Theme.ink)

                    if store.isReminderEnabled {
                        DatePicker(
                            "Heure du rappel",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .foregroundStyle(Theme.ink)
                    }
                } header: {
                    Text("Rappel")
                } footer: {
                    Text("Un seul rappel par jour, pour penser à tenir votre promesse.")
                }

                Section("À propos") {
                    LabeledContent("Version", value: AppInfo.version)
                        .foregroundStyle(Theme.ink)
                }

                Section {
                    if auth.isSignedIn {
                        Button("Se déconnecter", role: .destructive) {
                            isLogoutConfirmationPresented = true
                        }
                    } else {
                        // A local user is invited, never pushed.
                        Button("Créer un compte") {
                            auth.requestAccount()
                            dismiss()
                        }
                        .foregroundStyle(Theme.terracotta)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.canvas.ignoresSafeArea())
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                        .foregroundStyle(Theme.terracotta)
                }
            }
            .sheet(isPresented: $isNameEditorPresented) {
                NameEditorView(initialName: store.userName) { name in
                    store.setUserName(name)
                }
            }
            .alert("Se déconnecter ?", isPresented: $isLogoutConfirmationPresented) {
                Button("Annuler", role: .cancel) {}
                Button("Se déconnecter", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Vos promesses restent sur cet appareil et sur votre compte.")
            }
            .alert("Notifications désactivées", isPresented: $isPermissionAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Autorisez les notifications dans les Réglages d'iOS pour recevoir le rappel.")
            }
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { store.isReminderEnabled },
            set: { enabled in
                Task { await setReminder(enabled: enabled) }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { store.reminderTime },
            set: { date in
                store.setReminderTime(date)
                Task {
                    await ReminderService.schedule(
                        hour: store.reminderHour,
                        minute: store.reminderMinute
                    )
                }
            }
        )
    }

    private func setReminder(enabled: Bool) async {
        guard enabled else {
            store.setReminderEnabled(false)
            ReminderService.cancel()
            return
        }

        var granted = await ReminderService.isAuthorized()
        if !granted {
            granted = await ReminderService.requestAuthorization()
        }

        guard granted else {
            store.setReminderEnabled(false)
            isPermissionAlertPresented = true
            return
        }

        store.setReminderEnabled(true)
        await ReminderService.schedule(hour: store.reminderHour, minute: store.reminderMinute)
    }

    /// Discreet, never an error banner: sync simply resumes later.
    private var syncStatus: String {
        if !sync.isOnline {
            return "Hors ligne. La synchronisation reprendra toute seule."
        }
        if sync.isSyncing {
            return "Synchronisation en cours…"
        }
        if let moment = sync.lastSyncedAt {
            return "Synchronisé à \(moment.formatted(date: .omitted, time: .shortened))"
        }
        return "Vos promesses sont sauvegardées sur votre compte."
    }

    /// Ends the session only. No promise, no history and no streak is ever removed,
    /// here or on the server.
    private func signOut() async {
        ReminderService.cancel()
        await auth.signOut()
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environment(PromiseStore(fileName: "preview-settings.json"))
        .environment(AuthManager())
        .environment(SyncEngine())
}
