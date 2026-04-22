// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ImportBackupSheet.swift
// File picker and password entry for restoring an encrypted backup

import CoreUIModels
import SwiftUI
import UniformTypeIdentifiers

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// Classify a backup-import failure.
    ///
    /// TODO(ADR-044): Once the UniFFI bindings ship the new `MobileError`
    /// variants (`wrongPassword`, `decryptFailed`, `invalidInput`, `other`,
    /// etc.), replace this substring match with a `switch` on the variant.
    /// See `_private/docs/decisions/2026-04-20-adr-044-mobile-error-typing.md`.
    private func classifyImportError(_ error: Error) -> String {
        let description = error.localizedDescription
        if description.contains("decrypt") || description.contains("password") {
            return LocalizationService.shared.t("backup.error_incorrect_password")
        }
        return description
    }

    struct ImportBackupSheet: View {
        @EnvironmentObject var viewModel: AppViewModel
        @Environment(\.dismiss) var dismiss
        @Environment(\.designTokens) private var tokens
        @ObservedObject private var localizationService = LocalizationService.shared
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

                Text(localizationService.t("backup.import_title"))
                    .font(.title2.bold())

                if hasExistingIdentity {
                    Text(localizationService.t("backup.import_warning_inline"))
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
                            Text(localizationService.t("backup.file_loaded"))
                        }

                        SecureField(
                            localizationService.t("backup.enter_backup_password"),
                            text: $password
                        )
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
                                    Text(localizationService.t("backup.restore_identity"))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(CGFloat(tokens.spacing.sm))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .disabled(password.isEmpty || isImporting)
                        .padding(.horizontal)
                    }
                } else {
                    Text(localizationService.t("backup.select_file_instruction"))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showFilePicker = true
                    } label: {
                        Label(
                            localizationService.t("backup.choose_file"),
                            systemImage: "folder"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(CGFloat(tokens.spacing.sm))
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
                    Button(localizationService.t("action.cancel")) { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert(
                localizationService.t("backup.replace_confirm"),
                isPresented: $showConfirmation
            ) {
                Button(localizationService.t("action.cancel"), role: .cancel) {}
                Button(localizationService.t("backup.replace_button"), role: .destructive) {
                    importBackup()
                }
            } message: {
                Text(localizationService.t("backup.replace_warning"))
            }
        }

        private func handleFileSelection(_ result: Result<[URL], Error>) {
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }

                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        errorMessage = localizationService.t("backup.error_access_file")
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let data = try String(contentsOf: url, encoding: .utf8)
                    backupData = data.trimmingCharacters(in: .whitespacesAndNewlines)
                    errorMessage = nil
                } catch {
                    errorMessage = localizationService.t(
                        "backup.error_read_file",
                        args: ["error": error.localizedDescription]
                    )
                }
            case let .failure(error):
                errorMessage = localizationService.t(
                    "backup.error_file_selection",
                    args: ["error": error.localizedDescription]
                )
            }
        }

        private func importBackup() {
            guard let data = backupData, let vauchi = viewModel.vauchi else { return }

            isImporting = true
            errorMessage = nil

            Task {
                do {
                    try vauchi.importFullBackup(backupData: data, password: password)
                    await MainActor.run {
                        viewModel.invalidateAll()
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = classifyImportError(error)
                    }
                }
                await MainActor.run {
                    isImporting = false
                }
            }
        }
    }
#endif
