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
    @Environment(SceneNavigation.self) private var navigation

    @Environment(AppPreferences.self) private var appPreferences

    @State private var showPracticeAlert = false

    /// La hoja de filtros escribe en `SessionState` a través de este puente; el Panel recalcula solo al cambiar.
    @State private var panelFilters = PanelSessionFilters()

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
            .sheet(item: $sheets.accountDetail) { presentation in
                AccountDetailSheet(
                    account: presentation.account,
                    viewModel: viewModel,
                    isExpensesOnlyMode: sessionState.isExpensesOnlyMode,
                    onAccountChanged: { viewModel.reloadAndRecalculate() }
                )
            }
            .sheet(isPresented: $sheets.showOrphanedRecords, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                OrphanedRecordsSheet(onMoved: { viewModel.reloadAndRecalculate() })
            }
            .sheet(isPresented: $sheets.showFilters) {
                RecordsFiltersView(recordsViewModel: panelFilters)
            }
            .sheet(isPresented: $sheets.isPresentingSettings, onDismiss: {
                sheets.settingsInitialDestination = nil
                // Card vbf9: una petición del aviso que no llegó a la tarjeta (la pantalla cambió entretanto) no se queda
                // armada para la próxima vez que la persona abra «Dónde viven tus datos» por su cuenta.
                CloudAdoptOfferRequest.pending = false
                viewModel.reloadAndRecalculate()
            }) {
                ProfileView(initialDestination: sheets.settingsInitialDestination)
            }
            .sheet(isPresented: $sheets.showSectionsConfig) {
                PanelSectionsConfigView()
            }
            .sheet(item: $sheets.sectionPrefsPresentation) { kind in
                // Detents + drag indicator are declared inside the sheet so it
                // can observe the current detent and adapt its background
                // (glass material for medium, themed for large).
                PanelSectionPreferencesSheet(kind: kind, viewModel: viewModel)
            }
            .sheet(isPresented: $sheets.showNewTransaction, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                let subcategoryName = viewModel.selectedSubcategoryIDs.first.flatMap { id in
                    viewModel.allSubcategories.first { $0.persistentModelID == id }?.name
                }
                // La cuenta la pone la regla del formulario con el filtro entero (UX 2.2 · L2-1): `selectedAccountID` era
                // una cuenta al azar con dos filtradas y la excluida en modo excluir.
                NewTransactionView(
                    prefillCategoryID: viewModel.selectedCategoryID,
                    prefillSubcategoryName: subcategoryName
                )
                .presentationDetents([.large])
            }
            .sheet(
                isPresented: Binding(
                    get: { navigation.showNewTransactionFromChat },
                    set: { newValue in
                        navigation.showNewTransactionFromChat = newValue
                        if !newValue { navigation.pendingChatDraftPrefill = nil }
                    }
                ),
                onDismiss: { viewModel.reloadAndRecalculate() }
            ) {
                if let prefill = navigation.pendingChatDraftPrefill {
                    NewTransactionView(prefillFromChatDraft: prefill)
                        .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $sheets.showVoiceRecording, onDismiss: {
                handleVoiceRecordingDismiss()
            }) {
                VoiceRecordingView(
                    onSwitchToImage: {
                        sheets.switchToImageAfterVoice = true
                    },
                    onSetupTrialCompleted: sheets.isVoiceSetupTrial ? { itemID, itemName, kind in
                        deferredVoicePractice = DeferredPractice(
                            id: itemID, name: itemName, kind: kind, additionalIDs: []
                        )
                    } : nil,
                    onSetupTrialSkipped: sheets.isVoiceSetupTrial ? {
                        SetupChecklistManager.shared.markSkipped(.tryVoiceInput)
                    } : nil
                )
            }
            .sheet(isPresented: $sheets.showImageSelection, onDismiss: {
                handleImageSelectionDismiss()
            }) {
                ImageSelectionView(
                    exampleImages: sheets.setupTrialExampleImages,
                    onSetupTrialCompleted: sheets.isImageSetupTrial ? { itemID, itemName, kind, additionalIDs in
                        deferredImagePractice = DeferredPractice(
                            id: itemID, name: itemName, kind: kind, additionalIDs: additionalIDs
                        )
                    } : nil,
                    onSetupTrialSkipped: sheets.isImageSetupTrial ? {
                        SetupChecklistManager.shared.markSkipped(.tryImageInput)
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
                navigation.isInboxSheetVisible = false
                viewModel.reloadAndRecalculate()
            }) {
                InboxView(onNavigateToRecords: {
                    viewModel.navigateToStatistics(.records, in: navigation)
                })
                .onAppear { navigation.isInboxSheetVisible = true }
                // Si quien la presenta se desmonta (una ventana que pasa a esperar o asciende a líder), `onDismiss` no
                // está garantizado: el flag no debe quedarse puesto (tiraría los avisos de bandeja de TODAS las ventanas).
                .onDisappear { navigation.isInboxSheetVisible = false }
            }
            // Si se compra Pro en la hoja, al cerrarse se abre lo que se quería (UX 2.2 · L17-9).
            .proUpgradeSheet(isPresented: $sheets.showUpgradeForVoice, feature: .voiceInput, context: .proFeature) {
                openAIEntryAfterUnlock(.voice)
            }
            .proUpgradeSheet(isPresented: $sheets.showUpgradeForImage, feature: .imageInput, context: .proFeature) {
                openAIEntryAfterUnlock(.image)
            }
            .proUpgradeSheet(isPresented: $sheets.showUpgradeForAccounts, feature: .accounts, context: .limitReached) {
                sheets.accountFormSheet = AccountFormSheet(account: nil)
            }
            // Yala IA: columna al lado en ventana ancha, la hoja de siempre en compacta.
            .yalaAIChat(isPresented: $sheets.showChatSheet)
            .yalaAIOnboardingSheet(
                isPresented: $sheets.showYalaAIOnboarding,
                pendingOpenChat: $sheets.pendingOpenChatAfterOnboarding,
                showChatSheet: $sheets.showChatSheet,
                launcher: .panel,
                onPersistFlag: { appPreferences.hasShownYalaAIOnboarding = true }
            )
            .proUpgradeSheet(isPresented: $sheets.showUpgradeForChat, feature: .chatAssistant, context: .proFeature) {
                openChatAfterUnlock()
            }
            .chatConsentAlert(isPresented: $sheets.showChatConsentAlert) {
                // Consent recién aceptado por el alert. Decidimos siguiente paso vía pure-logic.
                switch YalaAIOnboardingLogic.nextScreen(
                    consentAccepted: true,
                    onboardingShown: appPreferences.hasShownYalaAIOnboarding
                ) {
                case .onboarding: sheets.showYalaAIOnboarding = true
                case .chat:       sheets.showChatSheet = true
                case .consent:    break  // imposible: consent acaba de aceptarse
                }
            }
            .aiConsentAlert(isPresented: $sheets.showAIConsentAlert, pendingInput: $sheets.pendingAIInput) { input in
                switch input {
                case .voice: sheets.showVoiceRecording = true
                case .image: sheets.showImageSelection = true
                }
            }
            .onChange(of: sheets.showAIConsentAlert) { _, showing in
                // Sin aceptar (Cancelar o la política de privacidad), el fallo de un soltar no espera a la próxima vez
                // que se abra el registro por imagen: ahí ya no explicaría nada. Y la práctica de «Primeros pasos» que
                // esperaba a este aviso se apaga: su hoja no se va a abrir (`endSetupTrialsThatNeverOpened`).
                if !showing, !UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
                    navigation.pendingImageEntryFailure = nil
                    for feature in sheets.endSetupTrialsThatNeverOpened() {
                        FeatureGateService.shared.disableSetupTrial(for: feature)
                    }
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
                    TrialOfferMoments.notePracticeAnswered(sheets.practiceCleanupItem)
                    sheets.practiceCleanupItem = nil
                }
                Button(L10n.SetupChecklist.practiceDelete, role: .destructive) {
                    if let item = sheets.practiceCleanupItem {
                        viewModel.deletePracticeItem(item)
                    }
                    TrialOfferMoments.notePracticeAnswered(sheets.practiceCleanupItem)
                    sheets.practiceCleanupItem = nil
                    viewModel.reloadAndRecalculate()
                }
            } message: {
                Text(L10n.SetupChecklist.practiceMessage)
            }
    }

    /// Tras comprar Pro desde «Función Pro» (UX 2.2 · L17-9): el mismo camino que tocar Voz o Foto siendo Pro, con su
    /// consentimiento de datos si aún no se dio.
    private func openAIEntryAfterUnlock(_ input: PendingAIInput) {
        guard appPreferences.aiDataConsentAccepted else {
            sheets.pendingAIInput = input
            sheets.showAIConsentAlert = true
            return
        }
        switch input {
        case .voice: sheets.showVoiceRecording = true
        case .image: sheets.showImageSelection = true
        }
    }

    /// Tras comprar Pro desde «Función Pro»: el mismo camino que tocar Yala IA siendo Pro.
    private func openChatAfterUnlock() {
        switch YalaAIOnboardingLogic.nextScreen(
            consentAccepted: appPreferences.aiChatConsentAccepted,
            onboardingShown: appPreferences.hasShownYalaAIOnboarding
        ) {
        case .onboarding: sheets.showYalaAIOnboarding = true
        case .chat: sheets.showChatSheet = true
        case .consent: sheets.showChatConsentAlert = true
        }
    }

    private func handleVoiceRecordingDismiss() {
        if sheets.isVoiceSetupTrial {
            sheets.isVoiceSetupTrial = false
            FeatureGateService.shared.disableSetupTrial(for: .voiceInput)
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
    }
}
