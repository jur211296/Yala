//
//  UpgradePromptSheet.swift
//  Yala
//
//  La hoja que sale al tocar algo de Yala Pro siendo gratis (auditoría UX 2.2 · L17-3 variante 2, L16-11, L17-9).
//  El título dice lo que pasa, una línea dice que lo que ya se tiene no cambia y los dos planes van DENTRO: se empieza
//  la prueba sin abrir otra hoja encima. Al comprar, «Comenzar» cierra todo y quien abrió la hoja abre la función que
//  se quería usar (`proUpgradeSheet(…, onUnlocked:)`).
//

import StoreKit
import SwiftUI

// MARK: - Upgrade Context

/// Context in which the upgrade prompt is shown
enum UpgradeContext {
    /// User reached free tier limit (accounts/budgets)
    case limitReached
    /// User tried to use a Pro-only feature (voice, image, icons)
    case proFeature
    /// User's trial has expired
    case trialExpired

    /// Si la hoja destaca la función que la abrió. `.trialExpired` no la abre ninguna función (lote 17 · B6).
    var showsFeatureHighlight: Bool {
        switch self {
        case .limitReached, .proFeature: return true
        case .trialExpired: return false
        }
    }
}

/// Lo que la hoja enseña en lugar del icono de la función cuando se tocó un tema o un icono (L16-11): cómo se vería.
enum ProGatePreview: Equatable {
    case theme(AppTheme, variant: TranslucentVariant)
    case icon(AppIconOption)
}

// MARK: - Upgrade Prompt Sheet

struct UpgradePromptSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    // MARK: - Properties

    let feature: ProFeature
    let context: UpgradeContext
    var source: String = "featureGate"
    var preview: ProGatePreview?
    /// La compra salió bien dentro de esta hoja. Lo usa `proUpgradeSheet` para abrir la función al cerrarse.
    var onPurchased: () -> Void = {}

    // MARK: - State

    private let store = StoreKitManager.shared
    @State private var selectedPlan: String = StoreKitManager.proYearlyID
    @State private var pricesFailed = false
    @State private var showError = false
    @State private var showSuccess = false

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Spacer(minLength: DS.Spacing.lg)

                    visual

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(title)
                            .font(DS.Typography.title)
                            .foregroundStyle(.thPrimaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("upgrade_prompt_title")

                        Text(message)
                            .font(DS.Typography.body)
                            .foregroundStyle(.thSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("upgrade_prompt_message")

                        // Un ejemplo de qué hace la función (UX 2.2 · L4-12): se queda en voz y foto.
                        if context == .proFeature, let example = featureExample {
                            Text(example)
                                .font(DS.Typography.subheadline.italic())
                                .foregroundStyle(.thPrimaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("upgrade_prompt_example")
                        }
                    }

                    plans

                    Spacer(minLength: DS.Spacing.md)

                    VStack(spacing: DS.Spacing.md) {
                        YalaPrimaryButton(ctaTitle, isDisabled: store.isPurchasing || store.planOffers.isEmpty) {
                            Task { await purchaseSelected() }
                        }
                        .accessibilityIdentifier("upgrade_prompt_cta")

                        Button(L10n.Action.notNow) {
                            dismiss()
                        }
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        // Mientras Apple procesa la compra no se sale: cerrar ahí dejaba Pro activo sin bienvenida ni
                        // la función que se quería (review del lote decidido 06).
                        .disabled(store.isPurchasing)
                        .accessibilityIdentifier("upgrade_prompt_not_now")

                        ProLegalFooter()
                    }
                    .padding(.bottom, DS.Spacing.lg)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .yalaScreenBackground(.subtle)
        .interactiveDismissDisabled(store.isPurchasing)
        .task { await loadPrices() }
        .alert(store.alertTitle ?? L10n.Subscription.errorTitle, isPresented: $showError) {
            // Vaciar el aviso al cerrarlo: con el mismo error otra vez, el `onChange` no volvía a saltar.
            Button(L10n.Common.ok, role: .cancel) { clearStoreAlert() }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.errorMessage) { _, newValue in
            if newValue != nil { showError = true }
        }
        // «Comenzar» cierra la bienvenida y esta hoja; quien la abrió abre la función (UX 2.2 · L17-9).
        .fullScreenCover(isPresented: $showSuccess, onDismiss: { dismiss() }) {
            SubscriptionSuccessView(feature: context == .trialExpired ? nil : feature)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var visual: some View {
        switch preview {
        case .theme(let appTheme, let variant):
            previewBlock {
                ThemePreviewTile(appTheme: appTheme, translucentVariant: variant)
                    .frame(width: 200, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
        case .icon(let icon):
            previewBlock {
                AppIconPreviewImage(icon: icon, size: 96)
            }
        case nil:
            if context == .proFeature, feature == .chatAssistant {
                // UX 2.2 · L14-13 (opción C): la demo animada del paso 1 de la presentación de Yala IA —registrar,
                // preguntar y una sugerencia— en vez del icono: enseña qué hace en lugar de describirlo. Va en el
                // sitio del icono, como la vista previa de temas e iconos (L16-11).
                YalaAIChatPreview()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(feature.localizedName)
                    .accessibilityIdentifier("upgrade_prompt_chat_demo")
            } else if context.showsFeatureHighlight {
                // Con su nombre para VoiceOver, y visible en el árbol: oculto, se perdía también su identificador
                // (lo cazó `ProConversionUpsellsUITests` B6).
                tile(systemName: feature.icon, hidden: false)
                    .accessibilityLabel(feature.localizedName)
                    .accessibilityIdentifier("upgrade_prompt_feature_row")
            } else {
                tile(systemName: "hourglass", circular: true)
            }
        }
    }

    private func tile(systemName: String, circular: Bool = false, hidden: Bool = true) -> some View {
        Image(systemName: systemName)
            .font(DS.Typography.title)
            .foregroundStyle(.thOnAccent)
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: circular ? 28 : DS.Radius.md, style: .continuous)
                    .fill(theme.accent)
            )
            .accessibilityHidden(hidden)
    }

    /// La vista previa del tema o del icono tocado, con «Así se vería Yala» (L16-11).
    private func previewBlock<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            content()
            Text(L10n.UXPro.gatePreviewCaption)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("upgrade_prompt_preview")
    }

    @ViewBuilder
    private var plans: some View {
        if !store.planOffers.isEmpty {
            ProPlanPicker(offers: store.planOffers, selectedID: $selectedPlan, showsMonthlyEquivalent: false)
        } else if pricesFailed {
            ProPricesUnavailable {
                pricesFailed = false
                Task { await loadPrices() }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    // MARK: - Texts

    private var title: String {
        switch context {
        case .trialExpired:
            // Quien pagó y canceló también ve este aviso: no le habla de una prueba (L17-6).
            return ProPresentation.endedWasTrial ? L10n.UXPro.endedTrialTitle : L10n.Subscription.Downgrade.title
        case .limitReached:
            switch feature {
            case .budgets: return L10n.UXPro.limitTitleBudgets(feature.freeLimit ?? 0)
            case .accounts: return L10n.UXPro.limitTitleAccounts(feature.freeLimit ?? 0)
            default: return L10n.FeatureGate.limitReachedTitle
            }
        case .proFeature:
            switch feature {
            case .voiceInput: return L10n.UXPro.gateTitleVoice
            case .imageInput: return L10n.UXPro.gateTitlePhoto
            case .smartInsightsAI: return L10n.UXPro.gateTitleInsights
            case .chatAssistant: return L10n.UXPro.gateTitleChat
            case .cashFlowAdvanced: return L10n.UXPro.gateTitleCashFlow
            case .proThemes:
                if case .theme(let appTheme, _) = preview { return L10n.UXPro.gateTitleTheme(appTheme.label) }
                return L10n.UXPro.gateTitleThemeGeneric
            case .premiumIcons:
                if case .icon(let icon) = preview { return L10n.UXPro.gateTitleIcon(icon.displayName) }
                return L10n.UXPro.gateTitleIconGeneric
            case .accounts, .budgets: return L10n.FeatureGate.proFeatureTitle
            }
        }
    }

    /// La línea de tranquilidad: qué pasa con lo que ya se tiene (L17-3).
    private var message: String {
        switch context {
        case .trialExpired:
            return L10n.UXPro.gateTrialBody(ProFeature.accounts.freeLimit ?? 0, ProFeature.budgets.freeLimit ?? 0)
        case .limitReached, .proFeature:
            switch feature {
            case .budgets: return L10n.UXPro.limitBodyBudgets(feature.freeLimit ?? 0)
            case .accounts: return L10n.UXPro.limitBodyAccounts(feature.freeLimit ?? 0)
            case .voiceInput, .imageInput: return L10n.UXPro.gateBodyManualStaysFree
            case .smartInsightsAI, .chatAssistant: return L10n.UXPro.gateBodyDataStaysFree
            case .proThemes: return L10n.UXPro.gateBodyThemeStays
            case .premiumIcons: return L10n.UXPro.gateBodyIconStays
            case .cashFlowAdvanced: return L10n.UXPro.gateBodyCashFlowStays
            }
        }
    }

    /// Solo voz y foto llevan ejemplo: son las que el lote 4 auditó.
    private var featureExample: String? {
        switch feature {
        case .voiceInput: return L10n.FeatureGate.voiceExample
        case .imageInput: return L10n.FeatureGate.imageExample
        default: return nil
        }
    }

    /// «Probar Pro gratis 30 días» con la prueba; «Pasarme a Pro» si ya la usó (L17-4).
    private var ctaTitle: String {
        if store.isPurchasing { return L10n.Subscription.processing }
        let selected = store.planOffers.first { $0.id == selectedPlan } ?? store.planOffers.first
        if selected?.trialDays != nil, selected?.trialIsOneMonth == true { return L10n.UXL15.gateStartTrialOneMonth }
        if let days = selected?.trialDays { return L10n.UXPro.gateStartTrialDays(days) }
        return L10n.UXPro.switchToPro
    }

    // MARK: - Actions

    private func clearStoreAlert() {
        store.errorMessage = nil
        store.alertTitle = nil
    }

    private func loadPrices() async {
        if store.planOffers.isEmpty { await store.loadProducts() }
        pricesFailed = store.planOffers.isEmpty
    }

    private func purchaseSelected() async {
        let offerID = store.planOffers.first { $0.id == selectedPlan }?.id ?? store.planOffers.first?.id
        guard let offerID else { return }
        let purchased = await store.purchase(offerID: offerID)
        guard purchased, store.didJustSubscribe else { return }
        // Esta hoja enseña su propia bienvenida: nadie más tiene que reaccionar a la compra.
        store.didJustSubscribe = false
        onPurchased()
        showSuccess = true
    }
}

// MARK: - Presentación con «abrir lo que se quería» (L17-9)

extension View {
    /// Presenta «Función Pro». Si la persona compra ahí, al cerrarse todo corre `onUnlocked`: lo que quería hacer
    /// (grabar por voz, el presupuesto nuevo, aplicar el tema…). Sin compra, no corre nada.
    func proUpgradeSheet(
        isPresented: Binding<Bool>,
        feature: ProFeature,
        context: UpgradeContext,
        preview: ProGatePreview? = nil,
        source: String = "featureGate",
        onUnlocked: (() -> Void)? = nil
    ) -> some View {
        modifier(ProUpgradeSheetModifier(
            isPresented: isPresented, feature: feature, context: context,
            preview: preview, source: source, onClosedWithoutUnlock: nil, onUnlocked: onUnlocked))
    }

    /// La misma hoja, con lo que hacer si se cierra sin comprar (la foto compartida retenida, card fazw). Sobrecarga
    /// aparte, con las dos salidas etiquetadas: un parámetro nuevo delante de `onUnlocked` cambiaba a qué cierre se
    /// enganchaba el `{ … }` final de los demás llamadores.
    func proUpgradeSheet(
        isPresented: Binding<Bool>,
        feature: ProFeature,
        context: UpgradeContext,
        onClosedWithoutUnlock: @escaping () -> Void,
        onUnlocked: @escaping () -> Void
    ) -> some View {
        modifier(ProUpgradeSheetModifier(
            isPresented: isPresented, feature: feature, context: context,
            preview: nil, source: "featureGate", onClosedWithoutUnlock: onClosedWithoutUnlock, onUnlocked: onUnlocked))
    }
}

private struct ProUpgradeSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let feature: ProFeature
    let context: UpgradeContext
    let preview: ProGatePreview?
    let source: String
    /// Se cerró sin comprar (o sin que la compra dejara Pro activo). Lo usa la foto compartida retenida (card fazw).
    let onClosedWithoutUnlock: (() -> Void)?
    let onUnlocked: (() -> Void)?

    @State private var purchased = false

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented, onDismiss: handleDismiss) {
            UpgradePromptSheet(feature: feature, context: context, source: source, preview: preview) {
                purchased = true
            }
        }
    }

    private func handleDismiss() {
        let opens = purchased && FeatureGateService.shared.isProUser
        purchased = false
        if opens { onUnlocked?() } else { onClosedWithoutUnlock?() }
    }
}

// MARK: - Preview

#Preview {
    UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
}
