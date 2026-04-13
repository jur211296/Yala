//
//  PanelSheetsModifier.swift
//  Yala
//
//  Sheet presentations extracted from PanelView.
//

import SwiftData
import SwiftUI
import UIKit

/// Wrapper to enable `.sheet(item:)` pattern for both new and edit account forms.
struct AccountFormSheet: Identifiable {
    let id = UUID()
    let account: Account?
}

/// Encapsulates sheet presentations to reduce body complexity and avoid type-checker limits
struct PanelSheetsModifier: ViewModifier {
    @Binding var accountFormSheet: AccountFormSheet?
    @Binding var isPresentingSettings: Bool
    @Binding var showWidgetPreferences: Bool
    @Binding var showNewTransaction: Bool
    @Binding var showVoiceRecording: Bool
    @Binding var showImageSelection: Bool
    @Binding var showCustomPeriodPicker: Bool
    @Binding var showBudgetFavoritesSettings: Bool
    @Binding var showInbox: Bool
    @Binding var showUpgradeForVoice: Bool
    @Binding var showUpgradeForImage: Bool
    @Binding var showUpgradeForAccounts: Bool
    @Binding var navigateToInboxAfterVoice: Bool
    @Binding var switchToImageAfterVoice: Bool
    @Binding var navigateToInboxAfterImage: Bool
    @Binding var showAIConsentAlert: Bool
    @Binding var pendingAIInput: PendingAIInput
    @Binding var practiceCleanupItem: PracticeCleanupItem?
    @Binding var isVoiceSetupTrial: Bool
    @Binding var isImageSetupTrial: Bool
    @Binding var setupTrialExampleImages: [UIImage]?
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
    let deletePracticeItem: (PracticeCleanupItem) -> Void

    let prefillAccountID: PersistentIdentifier?
    let prefillCategoryID: PersistentIdentifier?
    let customDateRange: DateInterval?
    let viewModel: PanelViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $accountFormSheet) { sheet in
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
            .sheet(isPresented: $isPresentingSettings, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                ProfileView(initialDestination: SessionState.shared.pendingProfileDestination)
            }
            .sheet(isPresented: $showWidgetPreferences, onDismiss: {
                viewModel.endWidgetPreferencesEditing()
                viewModel.reloadAndRecalculate()
            }) {
                WidgetPreferencesView(viewModel: viewModel)
                    .presentationDragIndicator(.visible)
                    .onAppear {
                        viewModel.beginWidgetPreferencesEditing()
                    }
            }
            .sheet(isPresented: $showNewTransaction, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                let subcategoryName = viewModel.selectedSubcategoryIDs.first.flatMap { id in
                    viewModel.allSubcategories.first { $0.persistentModelID == id }?.name
                }
                NewTransactionView(
                    prefillAccountID: prefillAccountID,
                    prefillCategoryID: prefillCategoryID,
                    prefillSubcategoryName: subcategoryName
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showVoiceRecording, onDismiss: {
                handleVoiceRecordingDismiss()
            }) {
                VoiceRecordingView(
                    onSavedToInbox: {
                        navigateToInboxAfterVoice = true
                    },
                    onSwitchToImage: {
                        switchToImageAfterVoice = true
                    },
                    onSetupTrialCompleted: isVoiceSetupTrial ? { itemID, itemName, kind in
                        deferredVoicePractice = DeferredPractice(
                            id: itemID, name: itemName, kind: kind, additionalIDs: []
                        )
                    } : nil,
                    onSetupTrialSkipped: isVoiceSetupTrial ? {
                        SetupChecklistManager.shared.markCompleted(.tryVoiceInput)
                    } : nil
                )
            }
            .sheet(isPresented: $showImageSelection, onDismiss: {
                handleImageSelectionDismiss()
            }) {
                ImageSelectionView(
                    onSavedToInbox: {
                        navigateToInboxAfterImage = true
                    },
                    exampleImages: setupTrialExampleImages,
                    onSetupTrialCompleted: isImageSetupTrial ? { itemID, itemName, kind, additionalIDs in
                        deferredImagePractice = DeferredPractice(
                            id: itemID, name: itemName, kind: kind, additionalIDs: additionalIDs
                        )
                    } : nil,
                    onSetupTrialSkipped: isImageSetupTrial ? {
                        SetupChecklistManager.shared.markCompleted(.tryImageInput)
                    } : nil
                )
            }
            .sheet(isPresented: $showCustomPeriodPicker) {
                CustomPeriodPickerSheet(
                    minDate: viewModel.transactionDateRange.start,
                    maxDate: viewModel.transactionDateRange.end,
                    currentRange: customDateRange
                )
            }
            .sheet(isPresented: $showBudgetFavoritesSettings, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                NavigationStack {
                    BudgetsFavoritesSettingsView()
                }
            }
            .sheet(isPresented: $showInbox, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                InboxView(onNavigateToRecords: {
                    viewModel.navigateToStatistics(.records)
                })
            }
            .sheet(isPresented: $showUpgradeForVoice) {
                UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
            }
            .sheet(isPresented: $showUpgradeForImage) {
                UpgradePromptSheet(feature: .imageInput, context: .proFeature)
            }
            .sheet(isPresented: $showUpgradeForAccounts) {
                UpgradePromptSheet(feature: .accounts, context: .limitReached)
            }
            .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { input in
                switch input {
                case .voice: showVoiceRecording = true
                case .image: showImageSelection = true
                }
            }
            .onChange(of: practiceCleanupItem?.id) { _, newValue in
                showPracticeAlert = newValue != nil
            }
            .alert(
                L10n.SetupChecklist.practiceTitle(practiceCleanupItem?.localizedItemType ?? ""),
                isPresented: $showPracticeAlert
            ) {
                Button(L10n.SetupChecklist.practiceKeep, role: .cancel) {
                    practiceCleanupItem = nil
                }
                Button(L10n.SetupChecklist.practiceDelete, role: .destructive) {
                    if let item = practiceCleanupItem {
                        deletePracticeItem(item)
                    }
                    practiceCleanupItem = nil
                    viewModel.reloadAndRecalculate()
                }
            } message: {
                Text(L10n.SetupChecklist.practiceMessage)
            }
    }

    private func handleVoiceRecordingDismiss() {
        if isVoiceSetupTrial {
            isVoiceSetupTrial = false
            FeatureGateService.shared.disableSetupTrial(for: .voiceInput)
        }
        if navigateToInboxAfterVoice {
            navigateToInboxAfterVoice = false
            showInbox = true
        }
        if switchToImageAfterVoice {
            switchToImageAfterVoice = false
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                showImageSelection = true
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
        if isImageSetupTrial {
            isImageSetupTrial = false
            setupTrialExampleImages = nil
            FeatureGateService.shared.disableSetupTrial(for: .imageInput)
        }
        if navigateToInboxAfterImage {
            navigateToInboxAfterImage = false
            showInbox = true
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
