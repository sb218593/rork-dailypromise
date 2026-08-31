//
//  PromiseComposerView.swift
//  DailyPromise
//

import SwiftUI

/// The quiet moment of choosing today's single promise.
struct PromiseComposerView: View {
    let initialText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("PROMESSE DU JOUR")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)

                TextField(
                    "Appeler maman avant 20h",
                    text: $text,
                    axis: .vertical
                )
                .font(.journal(28))
                .foregroundStyle(Theme.ink)
                .lineSpacing(5)
                .lineLimit(1...4)
                .focused($isFocused)
                .submitLabel(.done)
                .onChange(of: text) { _, newValue in
                    if newValue.count > 90 {
                        text = String(newValue.prefix(90))
                    }
                    if newValue.contains("\n") {
                        text = newValue.replacingOccurrences(of: "\n", with: " ")
                        isFocused = false
                    }
                }

                Text("Une seule promesse, pour aujourd'hui.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)

                Spacer(minLength: 0)

                Button {
                    onSave(trimmed)
                    dismiss()
                } label: {
                    Text("Enregistrer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(
                    trimmed.isEmpty ? Theme.terracotta.opacity(0.35) : Theme.terracotta,
                    in: .rect(cornerRadius: 16)
                )
                .disabled(trimmed.isEmpty)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WarmBackground(intensity: 0.06))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Theme.muted)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .onAppear {
            text = initialText
            isFocused = true
        }
    }
}

/// Lets the user set or correct the first name shown in the greeting.
struct NameEditorView: View {
    let initialName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("VOTRE PRÉNOM")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.muted)

                TextField("Camille", text: $name)
                    .font(.journal(28))
                    .foregroundStyle(Theme.ink)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(save)

                Spacer(minLength: 0)

                Button(action: save) {
                    Text("Enregistrer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(
                    trimmed.isEmpty ? Theme.terracotta.opacity(0.35) : Theme.terracotta,
                    in: .rect(cornerRadius: 16)
                )
                .disabled(trimmed.isEmpty)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WarmBackground(intensity: 0.06))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(Theme.muted)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .onAppear {
            name = initialName
            isFocused = true
        }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }
}

#Preview {
    PromiseComposerView(initialText: "") { _ in }
}
