//
//  PanelSheetsModifier.swift
//  Yala
//
//  Sheet presentations extracted from PanelView.
//  Applied at PanelShell level to keep UISheetPresentationController
//  out of PanelView's body evaluation cycle.
//

import SwiftData
import SwiftUI
import UIKit

/// Encapsulates sheet presentations to reduce body complexity and avoid type-checker limits.
/// Applied at PanelShell (not PanelView) so UISheetPresentationController.layoutBelowIfNeeded
/// forces re-evaluation of PanelShell (trivial) instead of PanelView (expensive).
struct PanelSheetsModifier: ViewModifier {
    @Binding var sheets: PanelSheetState
    let viewModel: PanelViewModel

    /// Read lazily inside sheet closures — NOT during body evaluation.
    @Environment(SessionState.self) private var sessionState

    @Environment(AppPreferences.self) private var appPreferences

    @State private var showPracticeAlert = false

    /// Deferred practice data — stored during callback, consumed in onDismiss.
    private struct DeferredPractice {
        let id: PersistentIdentifier
        let name: String
        let kind: PracticeItemKind
        let additionalIDs: [PersistentIdentifier]
    }
    @State private var deferredVoicePractice: DeferredPractice?
    @State private var deferredImagePractice: DeferredPractice?

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheets.accountFormSheet) { sheet in
                let names: [String] = {
                    guard let editing = sheet.account else {
                        return viewModel.accounts.map(\.name)
                    }
                    return viewModel.accounts
                        .filter { $0.persistentModelID != editing.persistentModelID }
                        .map(\.name)
                }()
                AccountFormView(
                    existingNames: names,
                    accountToEdit: sheet.account
                )
                .onDisappear {
                    viewModel.reloadAndRecalculate()
                }
            }
            .sheet(isPresented: $sheets.isPresentingSettings, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                ProfileView(initialDestination: SessionState.shared.pendingProfileDestination)
            }
            .sheet(isPresented: $sheets.showSectionsConfig) {
                PanelSectionsConfigView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $sheets.showWidgetPreferences, onDismiss: {
                viewModel.endWidgetPreferencesEditing()
                viewModel.reloadAndRecalculate()
            }) {
                WidgetPreferencesView(viewModel: viewModel)
                    .presentationDragIndicator(.visible)
                    // Deferred: mutating @Observable in .onAppear during sheet transition
                    // causes an infinite layoutBelowIfNeeded loop (watchdog 0x8BADF00D).
                    // The delay lets the transition finish; .task auto-cancels on dismiss.
                    .task {
                        do {
                            try await Task.sleep(for: .milliseconds(500))
                            viewModel.beginWidgetPreferencesEditing()
                        } catch {}
                    }
            }
            .sheet(isPresented: $sheets.showNewTransaction, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                let subcategoryName = viewModel.selectedSubcategoryIDs.first.flatMap { id in
                    viewModel.allSubcategories.first { $0.persistentModelID == id }?.name
                }
                NewTransactionView(
                    prefillAccountID: viewModel.selectedAccountID,
                    prefillCategoryID: viewModel.selectedCategoryID,
                    prefillSubcategoryName: subcategoryName
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $sheets.showVoiceRecording, onDismiss: {
                handleVoiceRecordingDismiss()
            }) {
                VoiceRecordingView(
                    onSavedToInbox: {
                        sheets.navigateToInboxAfterVoice = true
                    },
                    onSwitchToImage: {
                        sheets.switchToImageAfterVoice = true
                    },
                    onSetupTrialCompleted: sheets.isVoiceSetupTrial ? { itemID, itemName, kind in
                        deferredVoicePractice = DeferredPractice(
                            id: itemID, name: itemName, kind: kind, additionalIDs: []
                        )
                    } : nil,
                    onSetupTrialSkipped: sheets.isVoiceSetupTrial ? {
                        SetupChecklistManager.shared.markCompleted(.tryVoiceInput)
                    } : nil
                )
            }
            .sheet(isPresented: $sheets.showImageSelection, onDismiss: {
                handleImageSelectionDismiss()
            }) {
                ImageSelectionView(
                    onSavedToInbox: {
                        sheets.navigateToInboxAfterImage = true
                    },
                    exampleImages: sheets.setupTrialExampleImages,
                    onSetupTrialCompleted: sheets.isImageSetupTrial ? { itemID, itemName, kind, additionalIDs in
                        deferredImagePractice = DeferredPractice(
                            id: itemID, name: itemName, kind: kind, additionalIDs: additionalIDs
                        )
                    } : nil,
                    onSetupTrialSkipped: sheets.isImageSetupTrial ? {
                        SetupChecklistManager.shared.markCompleted(.tryImageInput)
                    } : nil
                )
            }
            .sheet(isPresented: $sheets.showCustomPeriodPicker) {
                CustomPeriodPickerSheet(
                    minDate: viewModel.transactionDateRange.start,
                    maxDate: viewModel.transactionDateRange.end,
                    currentRange: sessionState.customDateRange
                )
            }
            .sheet(isPresented: $sheets.showBudgetFavoritesSettings, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                NavigationStack {
                    BudgetsFavoritesSettingsView()
                }
            }
            .sheet(isPresented: $sheets.showInbox, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                InboxView(onNavigateToRecords: {
                    viewModel.navigateToStatistics(.records)
                })
            }
            .sheet(isPresented: $sheets.showUpgradeForVoice) {
                UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
            }
            .sheet(isPresented: $sheets.showUpgradeForImage) {
                UpgradePromptSheet(feature: .imageInput, context: .proFeature)
            }
            .sheet(isPresented: $sheets.showUpgradeForAccounts) {
                UpgradePromptSheet(feature: .accounts, context: .limitReached)
            }
            .sheet(isPresented: $sheets.showChatSheet) {
                ChatSheetView()
            }
            .sheet(isPresented: $sheets.showUpgradeForChat) {
                UpgradePromptSheet(feature: .chatAssistant, context: .proFeature)
            }
            .alert(L10n.AIConsent.chatTitle, isPresented: $sheets.showChatConsentAlert) {
                Button(L10n.AIConsent.accept) {
                    appPreferences.aiChatConsentAccepted = true
                    appPreferences.chatAssistantEnabled = true
                    sheets.showChatSheet = true
                }
                Button(L10n.AIConsent.privacyPolicy) {
                    UIApplication.shared.open(AppConstants.privacyURL)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.chatMessage)
            }
            .aiConsentAlert(isPresented: $sheets.showAIConsentAlert, pendingInput: $sheets.pendingAIInput) { input in
                switch input {
                case .voice: sheets.showVoiceRecording = true
                case .image: sheets.showImageSelection = true
                }
            }
            .onChange(of: sheets.practiceCleanupItem?.id) { _, newValue in
                showPracticeAlert = newValue != nil
            }
            .alert(
                L10n.SetupChecklist.practiceTitle(sheets.practiceCleanupItem?.localizedItemType ?? ""),
                isPresented: $showPracticeAlert
            ) {
                Button(L10n.SetupChecklist.practiceKeep, role: .cancel) {
                    sheets.practiceCleanupItem = nil
                }
                Button(L10n.SetupChecklist.practiceDelete, role: .destructive) {
                    if let item = sheets.practiceCleanupItem {
                        viewModel.deletePracticeItem(item)
                    }
                    sheets.practiceCleanupItem = nil
                    viewModel.reloadAndRecalculate()
                }
            } message: {
                Text(L10n.SetupChecklist.practiceMessage)
            }
    }

    private func handleVoiceRecordingDismiss() {
        if sheets.isVoiceSetupTrial {
            sheets.isVoiceSetupTrial = false
            FeatureGateService.shared.disableSetupTrial(for: .voiceInput)
        }
        if sheets.navigateToInboxAfterVoice {
            sheets.navigateToInboxAfterVoice = false
            sheets.showInbox = true
        }
        if sheets.switchToImageAfterVoice {
            sheets.switchToImageAfterVoice = false
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                sheets.showImageSelection = true
            }
        }

        if let deferred = deferredVoicePractice {
            deferredVoicePractice = nil
            SetupChecklistManager.shared.markCompleted(
                .tryVoiceInput,
                practiceItem: PracticeCleanupItem(
                    stepID: .tryVoiceInput,
                    itemName: deferred.name,
                    persistentID: deferred.id,
                    kind: deferred.kind
                )
            )
        }

        viewModel.reloadAndRecalculate()
    }

    private func handleImageSelectionDismiss() {
        if sheets.isImageSetupTrial {
            sheets.isImageSetupTrial = false
            sheets.setupTrialExampleImages = nil
            FeatureGateService.shared.disableSetupTrial(for: .imageInput)
        }
        if sheets.navigateToInboxAfterImage {
            sheets.navigateToInboxAfterImage = false
            sheets.showInbox = true
        }

        if let deferred = deferredImagePractice {
            deferredImagePractice = nil
            SetupChecklistManager.shared.markCompleted(
                .tryImageInput,
                practiceItem: PracticeCleanupItem(
                    stepID: .tryImageInput,
                    itemName: deferred.name,
                    persistentID: deferred.id,
                    kind: deferred.kind,
                    additionalIDs: deferred.additionalIDs
                )
            )
        }

        viewModel.reloadAndRecalculate()

        AppBootstrapper.shared.showDeferredActionsIfNeeded()
    }
}
