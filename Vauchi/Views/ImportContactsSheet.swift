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

                Text("Import Contacts")
                    .font(.title2.bold())

                if let result = importResult {
                    resultView(result)
                } else if isImporting {
                    ProgressView("Importing...")
                } else {
                    promptView
                }

                Spacer()
            }
            .padding()
            .frame(minWidth: 360, minHeight: 300)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                Text("Import contacts from a vCard (.vcf) file.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Choose File", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(8)
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

                Text("\(result.imported) contact(s) imported")
                    .font(.headline)

                if result.skipped > 0 {
                    Text("\(result.skipped) skipped (duplicates or invalid)")
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
                            Text("... and \(result.warnings.count - 5) more")
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
                        Label("Import More", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    Button("Done") { dismiss() }
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
                    errorMessage = "Could not access file"
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                do {
                    let data = try Data(contentsOf: url)
                    importVcf(data)
                } catch {
                    errorMessage = "Could not read file: \(error.localizedDescription)"
                }

            case let .failure(error):
                errorMessage = "File selection failed: \(error.localizedDescription)"
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
                        importResult = ContactImportResult(
                            imported: Int(result.imported),
                            skipped: Int(result.skipped),
                            warnings: result.warnings
                        )
                        isImporting = false
                        viewModel.invalidateAll()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = "Import failed: \(error.localizedDescription)"
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
