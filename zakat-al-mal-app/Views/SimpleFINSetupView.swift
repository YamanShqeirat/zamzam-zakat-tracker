import SwiftData
import SwiftUI

struct SimpleFINSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingAssets: [Asset]

    @State private var token: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let assetVM = AssetViewModel()

    var body: some View {
        Form {
            Section("Connect Your Accounts") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Visit beta-bridge.simplefin.org", systemImage: "1.circle.fill")
                    Label("Connect your banks and brokerages there", systemImage: "2.circle.fill")
                    Label("Create a Setup Token and paste it below", systemImage: "3.circle.fill")
                }
                .font(.footnote)
            }

            Section("Setup Token") {
                TextField("Paste setup token", text: $token, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(3, reservesSpace: true)
                    .font(.system(.body, design: .monospaced))
            }

            Section {
                Button {
                    Task { await connect() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().controlSize(.small)
                        }
                        Text(isLoading ? "Connecting…" : "Connect")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }

            if let err = errorMessage {
                Section { Text(err).foregroundStyle(.red) }
            }
            if let success = successMessage {
                Section { Text(success).foregroundStyle(.green) }
            }

            Section {
                Text("Your credentials are stored securely in the iOS Keychain. SimpleFIN provides read-only access to your balances.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Connect SimpleFIN")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func connect() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let accessURL = try await SimpleFINSetup.claimAccessURL(setupToken: trimmed)
            try KeychainService.save(key: KeychainKey.simplefinAccessURL, value: accessURL)

            // Fetch accounts and create Asset records for newly linked accounts.
            let service = SimpleFINService(accessURL: accessURL)
            let accounts = try await service.fetchAccounts()
            assetVM.linkSimpleFINAccounts(accounts, existingAssets: existingAssets, context: modelContext)

            successMessage = "Connected — \(accounts.count) account\(accounts.count == 1 ? "" : "s") linked."
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { SimpleFINSetupView() }
        .modelContainer(for: [Asset.self], inMemory: true)
}
