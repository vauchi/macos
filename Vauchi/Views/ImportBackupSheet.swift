// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ImportBackupSheet.swift
// File picker and password entry for restoring an encrypted backup

import SwiftUI
import UniformTypeIdentifiers

#if canImport(VauchiPlatform)
    import VauchiPlatform

    struct ImportBackupSheet: View {
        @EnvironmentObject var viewModel: AppViewModel
        @Environment(\.dismiss) var dismiss
        @State private var showFilePicker = false
        @State private var backupData: String?
        @State private var password = ""
        @State private var isImporting = false
        @State private var errorMessage: String?
        @State private var showConfirmation = false

        /// True when the current screen is not an onboarding flow (identity likely exists).
        private var hasExistingIdentity: Bool {
            guard let screenId = viewModel.currentScreen?.screenId else { return false }
            return !screenId.lowercased().contains("onboarding")
                && !screenId.lowercased().contains("welcome")
                && !screenId.lowercased().contains("create_identity")
        }

        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(.cyan)

                Text("Import Backup")
                    .font(.title2.bold())

                if hasExistingIdentity {
                    Text("Warning: Importing a backup will replace your current identity!")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if backupData != nil {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Backup file loaded")
                        }

                        SecureField("Enter backup password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)

                        Button {
                            if hasExistingIdentity {
                                showConfirmation = true
                            } else {
                                importBackup()
                            }
                        } label: {
                            HStack {
                                if isImporting {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Restore Identity")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(password.isEmpty || isImporting)
                        .padding(.horizontal)
                    }
                } else {
                    Text("Select a backup file to restore your identity")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Choose File", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                            .padding(8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 360, minHeight: 340)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Replace Identity?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Replace", role: .destructive) {
                    importBackup()
                }
            } message: {
                Text(
                    "This will permanently replace your current identity. "
                        + "Make sure you have a backup of your current identity first."
                )
            }
        }

        private func handleFileSelection(_ result: Result<[URL], Error>) {
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }

                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        errorMessage = "Could not access file"
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let data = try String(contentsOf: url, encoding: .utf8)
                    backupData = data.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = nil
                } catch {
                    errorMessage = "Could not read file: \(error.localizedDescription)"
                }
            case let .failure(error):
                errorMessage = "File selection failed: \(error.localizedDescription)"
            }
        }

        private func importBackup() {
            guard let data = backupData, let vauchi = viewModel.vauchi else { return }

            isImporting = true
            errorMessage = nil

            Task {
                do {
                    try vauchi.importBackup(backupData: data, password: password)
                    await MainActor.run {
                        viewModel.invalidateAll()
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        if error.localizedDescription.contains("decrypt")
                            || error.localizedDescription.contains("password")
                        {
                            errorMessage = "Incorrect password"
                        } else {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                await MainActor.run {
                    isImporting = false
                }
            }
        }
    }
#endif
