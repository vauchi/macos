// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// ImportContactsSheet.swift
// File picker for importing contacts from vCard (.vcf) files

import SwiftUI
import UniformTypeIdentifiers

#if canImport(VauchiPlatform)
    import VauchiPlatform

    struct ImportContactsSheet: View {
        @EnvironmentObject var viewModel: AppViewModel
        @Environment(\.dismiss) var dismiss
        @Environment(\.designTokens) private var tokens
        @ObservedObject private var localizationService = LocalizationService.shared
        @State private var showFilePicker = false
        @State private var isImporting = false
        @State private var importResult: ContactImportResult?
        @State private var errorMessage: String?

        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.rectangle.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.cyan)
                    .accessibilityHidden(true)

                Text(localizationService.t("import_contacts.title"))
                    .font(.title2.bold())

                if let result = importResult {
                    resultView(result)
                } else if isImporting {
                    ProgressView(localizationService.t("import_contacts.importing"))
                } else {
                    promptView
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 360, minHeight: 300)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationService.t("action.cancel")) { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [
                    UTType(filenameExtension: "vcf") ?? .data,
                    .vCard,
                    .data,
                ],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }

        // MARK: - Subviews

        private var promptView: some View {
            VStack(spacing: 16) {
                Text(localizationService.t("import_contacts.description"))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showFilePicker = true
                } label: {
                    Label(localizationService.t("import_contacts.choose_file"), systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(CGFloat(tokens.spacing.sm))
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .padding(.horizontal)
                .accessibilityIdentifier("import.chooseFile")

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }

        private func resultView(_ result: ContactImportResult) -> some View {
            VStack(spacing: 16) {
                Image(systemName: result.imported > 0 ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(result.imported > 0 ? .green : .orange)
                    .accessibilityHidden(true)

                Text(localizationService.t("import_contacts.result_imported", args: ["count": String(result.imported)]))
                    .font(.headline)

                if result.skipped > 0 {
                    Text(localizationService.t(
                        "import_contacts.result_skipped",
                        args: ["count": String(result.skipped)]
                    ))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                if !result.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.warnings.prefix(5), id: \.self) { warning in
                            Text("- \(warning)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if result.warnings.count > 5 {
                            Text(localizationService.t(
                                "import_contacts.result_more",
                                args: ["count": String(result.warnings.count - 5)]
                            ))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button {
                        importResult = nil
                        errorMessage = nil
                    } label: {
                        Label(localizationService.t("import_contacts.import_more"), systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    Button(localizationService.t("action.done")) { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                }
            }
        }

        // MARK: - Logic

        private func handleFileSelection(_ result: Result<[URL], Error>) {
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }

                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = localizationService.t("import_contacts.error_access_file")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let data = try Data(contentsOf: url)
                    importVcf(data)
                } catch {
                    errorMessage = localizationService.t(
                        "import_contacts.error_read_file",
                        args: ["error": error.localizedDescription]
                    )
                }

            case let .failure(error):
                errorMessage = localizationService.t(
                    "import_contacts.error_file_selection",
                    args: ["error": error.localizedDescription]
                )
            }
        }

        private func importVcf(_ data: Data) {
            guard let vauchi = viewModel.vauchi else { return }

            isImporting = true
            errorMessage = nil

            Task {
                do {
                    let result = try vauchi.importContactsFromVcf(data: data)
                    await MainActor.run {
                        // 0.20.2: result.warnings is now [MobileImportWarning] —
                        // a struct of (key, args, legacyText). Map to the English
                        // legacyText here (this branch only bumps the binding —
                        // the localization routing lives in feature/macos-
                        // localization-adoption and will replace legacyText with
                        // LocalizationService.t(warning.key, args: warning.args)
                        // once that MR lands).
                        importResult = ContactImportResult(
                            imported: Int(result.imported),
                            skipped: Int(result.skipped),
                            warnings: result.warnings.map { $0.legacyText }
                        )
                        isImporting = false
                        viewModel.invalidateAll()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = localizationService.t(
                            "import_contacts.error_import_failed",
                            args: ["error": error.localizedDescription]
                        )
                        isImporting = false
                    }
                }
            }
        }
    }

    struct ContactImportResult {
        let imported: Int
        let skipped: Int
        let warnings: [String]
    }
#endif
