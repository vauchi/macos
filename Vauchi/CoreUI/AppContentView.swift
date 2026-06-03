// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// AppContentView.swift
// Core-driven content views: ContentView (auth/error/loading dispatch),
// AppContentView (NavigationSplitView with sidebar + ScreenRendererView
// detail + toast/alert/sheet hosts), and SidebarView.

import CoreUIModels
import SwiftUI

#if canImport(VauchiPlatform)
    import VauchiPlatform

    struct ContentView: View {
        @EnvironmentObject var appState: AppState

        var body: some View {
            Group {
                if appState.isAuthenticationRequired {
                    LockScreenView(onUnlock: { appState.authenticateAndRetry() })
                } else if let error = appState.error {
                    ErrorView(message: error)
                } else if let viewModel = appState.viewModel {
                    AppContentView(viewModel: viewModel)
                } else {
                    ProgressView(LocalizationService.shared.t("app.initializing"))
                }
            }
        }
    }

    struct AppContentView: View {
        @ObservedObject var viewModel: AppViewModel

        var body: some View {
            ZStack(alignment: .top) {
                NavigationSplitView {
                    SidebarView(viewModel: viewModel)
                } detail: {
                    if let screen = viewModel.currentScreen {
                        ScreenRendererView(
                            screen: screen,
                            onAction: { action in
                                viewModel.handleAction(action)
                            },
                            onQrScanned: { data in
                                viewModel.handleQrScanned(data: data)
                            }
                        )
                    } else {
                        LoadingView()
                    }
                }

                // Toast overlay for ActionResult.showToast (positioned above content)
                if let message = viewModel.toastMessage {
                    ToastOverlayView(
                        message: message,
                        undoActionId: viewModel.toastUndoActionId,
                        onAction: { action in viewModel.handleAction(action) },
                        onDismiss: {
                            withAnimation {
                                viewModel.toastMessage = nil
                                viewModel.toastUndoActionId = nil
                            }
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
                    .zIndex(100)
                }
            }
            .alert(item: $viewModel.alertMessage) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(LocalizationService.shared.t("action.ok")))
                )
            }
            .onChange(of: viewModel.currentScreen?.screenId) { newId in
                syncQrFrameTimer(for: newId)
            }
            .onAppear {
                syncQrFrameTimer(for: viewModel.currentScreen?.screenId)
            }
            .onDisappear {
                viewModel.stopQrFrameTimer()
                viewModel.stopMultiStagePollTimer()
            }
            .sheet(isPresented: $viewModel.showDeviceLinkSheet) {
                CoreSheetView(
                    actionId: "device_linking",
                    viewModel: viewModel,
                    onComplete: { viewModel.showDeviceLinkSheet = false },
                    cancelIfScreenMatches: { $0.hasPrefix("link_") }
                )
                .padding(20)
                .frame(width: 400)
                .frame(minHeight: 450)
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuExchange)) { _ in
                viewModel.navigateToTab(actionId: "exchange")
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuContacts)) { _ in
                viewModel.navigateToTab(actionId: "contacts")
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuGroups)) { _ in
                viewModel.navigateToTab(actionId: "groups")
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuMyCard)) { _ in
                viewModel.navigateToTab(actionId: "my_info")
            }
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuMore)) { _ in
                viewModel.navigateToTab(actionId: "more")
            }
            // Phase 3 retirement of `2026-05-02-macos-humble-ui-retirement` G1:
            // emit core's `import_contacts` action instead of opening
            // the bespoke ImportContactsSheet. Sequence:
            //   1. navigate the engine to AppScreen::More so MoreEngine
            //      is the active engine
            //   2. emit `import_contacts` action_id, which MoreEngine
            //      maps to ExchangeCommand::FilePickFromUser
            //   3. AppViewModel.dispatchExchangeCommands triggers the
            //      Phase 3 NSOpenPanel via presentFilePickFromUser
            //   4. picker resolves → FilePickedFromUser routes via
            //      AppScreen::More → Vauchi::import_contacts_from_vcf
            //      → toast with imported / skipped counts
            // Engine state moves; the user's currently-rendered scene
            // stays put (CoreSceneView only opens on Settings nav).
            .onReceive(NotificationCenter.default.publisher(for: .vauchiMenuImportContacts)) { _ in
                viewModel.navigateToTab(actionId: "more")
                viewModel.handleAction(.actionPressed(actionId: "import_contacts"))
            }
        }

        /// Start the animated-QR timer while the ShowQr screen is visible; stop
        /// it everywhere else. Cheap to call unconditionally — both methods are
        /// idempotent.
        private func syncQrFrameTimer(for screenId: String?) {
            if screenId == "exchange_show_qr" {
                viewModel.startQrFrameTimer()
            } else {
                viewModel.stopQrFrameTimer()
            }
            // Multi-stage (Glance) exchange advances via a separate
            // poll-driven tick — its machine replaced the legacy
            // `exchange_show_qr` engine and is driven by `pollNotifications`,
            // not `advanceQrFrameJson` (Bug 5,
            // `2026-05-30-exchange-screen-nav-visual-bugs`).
            if screenId == "multi_stage_exchange" {
                viewModel.startMultiStagePollTimer()
            } else {
                viewModel.stopMultiStagePollTimer()
            }
        }
    }

    /// Sidebar listing available navigation screens from core.
    struct SidebarView: View {
        @ObservedObject var viewModel: AppViewModel
        @State private var sidebarSelection: String?

        var body: some View {
            List(selection: $sidebarSelection) {
                ForEach(viewModel.sidebarItems, id: \.id) { tab in
                    Label(
                        tab.label,
                        systemImage: sidebarIcon(forScreenId: tab.id)
                    )
                    // Tag with the opaque snake_case screen_id (== the
                    // selection id surfaced by `currentTabId`); the tap
                    // forwards `tab.actionId` via `navigateToTab`.
                    .tag(tab.id)
                }
            }
            .navigationTitle(LocalizationService.shared.t("app.name"))
            .onChange(of: sidebarSelection) { newValue in
                guard let selectedId = newValue,
                      selectedId != viewModel.selectedScreen,
                      let tab = viewModel.sidebarItems.first(where: { $0.id == selectedId })
                else { return }
                // Forward the opaque `actionId` — core resolves it to the
                // canonical screen (zero-domain-vocab, ADR-043 Am4).
                viewModel.navigateToTab(actionId: tab.actionId)
            }
            .onChange(of: viewModel.selectedScreen) { newValue in
                sidebarSelection = newValue
            }
            .onAppear {
                sidebarSelection = viewModel.selectedScreen
            }
        }

        /// macOS contributes the preferred SF Symbol (prefer filled
        /// variants) for each top-level sidebar entry. Labels + the
        /// entry set itself are core-owned via
        /// `AppEngine::sidebar_items(locale)`; see §6 of the
        /// pure-renderer audit for rationale.
        private func sidebarIcon(forScreenId id: String) -> String {
            switch id {
            case "my_info": "person.crop.rectangle.fill"
            case "contacts": "person.2.fill"
            case "exchange": "qrcode"
            case "groups": "rectangle.3.group.fill"
            case "settings": "gearshape.fill"
            case "recovery": "key.horizontal.fill"
            case "device_management": "laptopcomputer"
            case "backup": "externaldrive.fill"
            case "privacy": "hand.raised.fill"
            case "support": "bubble.left.and.bubble.right.fill"
            case "help": "questionmark.circle.fill"
            case "activity_log": "list.bullet.rectangle.fill"
            case "sync": "arrow.triangle.2.circlepath"
            case "more": "ellipsis.circle.fill"
            case "onboarding": "wand.and.stars"
            default: "square"
            }
        }
    }
#endif
