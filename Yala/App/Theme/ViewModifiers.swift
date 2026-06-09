//
//  ViewModifiers.swift
//  Yala
//
//  Reusable view modifiers for consistent styling across the app.
//  Usage: .yalaCard(), .yalaFormRow(), .yalaSection()
//

import SwiftUI

// MARK: - Card Modifier

/// Aplica estilo de card estándar: background, radius, shadow, border
struct YalaCardModifier: ViewModifier {
    @Environment(\.yalaTheme) private var theme
    let padding: CGFloat
    let radius: CGFloat
    let hasShadow: Bool

    init(
        padding: CGFloat = DS.Card.padding,
        radius: CGFloat = DS.Card.radius,
        hasShadow: Bool = true
    ) {
        self.padding = padding
        self.radius = radius
        self.hasShadow = hasShadow
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                if theme.usesMaterial {
                    // ultraThinMaterial preserva el blur/vibrancy (Liquid Glass del sistema).
                    // El overlay neutralizador encima drena el tinte de color que el material
                    // vibrante hereda del fondo (gradient violeta/rosa/teal del PanelBackground),
                    // logrando que el widget se sienta "cristal real" sin teñirse del tema.
                    RoundedRectangle(cornerRadius: radius)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: radius)
                                .fill(Color.white.opacity(0.02))
                        )
                } else {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(theme.card)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
            .modifier(ConditionalShadow(hasShadow: hasShadow, shadowOpacity: theme.shadowOpacity))
    }
}

private struct ConditionalShadow: ViewModifier {
    let hasShadow: Bool
    var shadowOpacity: Double = DS.Opacity.faint

    func body(content: Content) -> some View {
        if hasShadow {
            content.shadow(color: .black.opacity(shadowOpacity), radius: 10, x: 0, y: 5)
        } else {
            content
        }
    }
}

extension View {
    /// Aplica estilo de card estándar (widget, panel card)
    func yalaCard(
        padding: CGFloat = DS.Card.padding,
        radius: CGFloat = DS.Card.radius,
        shadow: Bool = true
    ) -> some View {
        modifier(YalaCardModifier(padding: padding, radius: radius, hasShadow: shadow))
    }

    /// Aplica estilo de card compacto
    func yalaCardCompact(shadow: Bool = true) -> some View {
        modifier(YalaCardModifier(
            padding: DS.Card.paddingCompact,
            radius: DS.Card.radius,
            hasShadow: shadow
        ))
    }

    /// Aplica estilo de list row (RecordRowView style)
    func yalaListRow(shadow: Bool = true) -> some View {
        modifier(YalaCardModifier(
            padding: 0,
            radius: DS.ListRow.radius,
            hasShadow: shadow
        ))
        .padding(.vertical, DS.ListRow.paddingV)
        .padding(.horizontal, DS.ListRow.paddingH)
    }
    /// Aplica estilo de card sólido (mismo fondo que widgets del Panel, sin material)
    func solidCard(padding: CGFloat = 0, radius: CGFloat = DS.Card.radius) -> some View {
        modifier(SolidCardModifier(padding: padding, radius: radius))
    }

    /// Aplica el estilo canónico de widget del Panel (padding+radius reducidos
    /// respecto a `solidCard` para mantener el home más calmo).
    func panelCard(small: Bool = false) -> some View {
        solidCard(
            padding: small ? DS.Panel.smallWidgetPadding : DS.Card.paddingCompact,
            radius: small ? DS.Panel.smallWidgetRadius : DS.Panel.widgetRadius
        )
    }

    /// Card seleccionable: mismo fondo `.thCard` + esquinas `.continuous` que `solidCard`,
    /// con stroke condicional 2pt cuando `isSelected`, 1pt cuando no. Inyectar
    /// `activeColor`/`inactiveColor` cuando el contexto requiera strokes no temáticos
    /// (ej. fondos hero sobre dark donde `theme.accent` no contrasta).
    func selectableCard(
        isSelected: Bool,
        radius: CGFloat = DS.Card.radius,
        activeColor: Color? = nil,
        inactiveColor: Color? = nil
    ) -> some View {
        modifier(SelectableCardModifier(
            isSelected: isSelected,
            radius: radius,
            activeColor: activeColor,
            inactiveColor: inactiveColor
        ))
    }

}

// MARK: - Solid Card Modifier (matches PanelView widget styling)

struct SolidCardModifier: ViewModifier {
    @Environment(\.yalaTheme) private var theme
    var padding: CGFloat = 0
    var radius: CGFloat = DS.Card.radius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Selectable Card Modifier

struct SelectableCardModifier: ViewModifier {
    @Environment(\.yalaTheme) private var theme
    let isSelected: Bool
    let radius: CGFloat
    let activeColor: Color?
    let inactiveColor: Color?

    func body(content: Content) -> some View {
        content
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        isSelected ? (activeColor ?? theme.accent) : (inactiveColor ?? theme.cardBorder),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
}

// MARK: - Form Row Modifier

/// Aplica estilo de fila de formulario: padding, background, contenido alineado
struct YalaFormRowModifier: ViewModifier {
    @Environment(\.yalaTheme) private var theme
    let showChevron: Bool
    let hasBackground: Bool

    func body(content: Content) -> some View {
        HStack(spacing: DS.FormRow.iconSpacing) {
            content

            if showChevron {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        .frame(minHeight: DS.FormRow.minHeight)
        .background {
            if hasBackground && theme.usesMaterial {
                Rectangle().fill(.ultraThinMaterial)
            } else if hasBackground {
                Rectangle().fill(theme.card)
            } else {
                Color.clear
            }
        }
    }
}

extension View {
    /// Aplica estilo de fila de formulario
    func yalaFormRow(showChevron: Bool = false, hasBackground: Bool = true) -> some View {
        modifier(YalaFormRowModifier(showChevron: showChevron, hasBackground: hasBackground))
    }
}

// MARK: - Section Modifier

/// Aplica estilo de sección con spacing y header opcional
struct YalaSectionModifier: ViewModifier {
    let spacing: CGFloat

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
    }
}

extension View {
    /// Agrupa contenido en una sección con spacing estándar
    func yalaSection(spacing: CGFloat = DS.Spacing.md) -> some View {
        modifier(YalaSectionModifier(spacing: spacing))
    }
}

// MARK: - Safe Area Bottom Padding

extension View {
    /// Añade padding inferior seguro para scroll views
    func yalaSafeBottomPadding() -> some View {
        self.padding(.bottom, DS.Spacing.safeBottom)
    }
}

// MARK: - Skeleton Placeholder

/// Modifier para mostrar placeholder skeleton mientras carga
struct YalaSkeletonModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        if isLoading {
            content
                .redacted(reason: .placeholder)
                .shimmer()
        } else {
            content
        }
    }
}

extension View {
    /// Muestra skeleton loading mientras isLoading es true
    func yalaSkeleton(_ isLoading: Bool) -> some View {
        modifier(YalaSkeletonModifier(isLoading: isLoading))
    }
}

// MARK: - AI Consent Alert

/// Which AI input feature the user was trying to activate when consent was requested
enum PendingAIInput: String, Codable, Equatable, Hashable {
    case voice
    case image
}

/// Shared consent alert for voice/image processing.
/// Reused across PanelView, DetailContainerView, RecordsStandaloneView, ProfileView.
struct AIConsentAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var pendingInput: PendingAIInput
    @AppStorage(AppPreferences.Keys.aiDataConsentAccepted) private var aiDataConsentAccepted: Bool = false
    @Environment(\.openURL) private var openURL

    /// Called after consent is accepted and alert dismisses, to show the appropriate sheet
    var onAccepted: (PendingAIInput) -> Void

    func body(content: Content) -> some View {
        content
            .alert(L10n.AIConsent.processingTitle, isPresented: $isPresented) {
                Button(L10n.AIConsent.accept) {
                    aiDataConsentAccepted = true
                    let input = pendingInput
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(500))
                        onAccepted(input)
                    }
                }
                Button(L10n.AIConsent.privacyPolicy) {
                    openURL(AppConstants.privacyURL)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.processingMessage)
            }
    }
}

extension View {
    /// Adds the AI consent alert for voice/image input features
    func aiConsentAlert(
        isPresented: Binding<Bool>,
        pendingInput: Binding<PendingAIInput>,
        onAccepted: @escaping (PendingAIInput) -> Void
    ) -> some View {
        modifier(AIConsentAlertModifier(
            isPresented: isPresented,
            pendingInput: pendingInput,
            onAccepted: onAccepted
        ))
    }
}

// MARK: - Chat Consent Alert

/// Shared consent alert for the Chat Assistant feature.
/// Reused across PanelSheetsModifier, RecordsStandaloneView, and AIPrivacySettingsView.
struct ChatConsentAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @AppStorage(AppPreferences.Keys.aiChatConsentAccepted) private var aiChatConsentAccepted: Bool = false
    @Environment(\.openURL) private var openURL

    /// Called after consent is accepted (e.g. to present the chat sheet).
    var onAccepted: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(L10n.AIConsent.chatTitle, isPresented: $isPresented) {
                Button(L10n.AIConsent.accept) {
                    aiChatConsentAccepted = true
                    onAccepted()
                }
                Button(L10n.AIConsent.privacyPolicy) {
                    openURL(AppConstants.privacyURL)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.chatMessage)
            }
    }
}

extension View {
    /// Adds the chat assistant consent alert.
    func chatConsentAlert(
        isPresented: Binding<Bool>,
        onAccepted: @escaping () -> Void = {}
    ) -> some View {
        modifier(ChatConsentAlertModifier(isPresented: isPresented, onAccepted: onAccepted))
    }
}

// MARK: - Insights Consent Alert

/// Shared consent alert for AI-powered insights generation.
/// Reused across InsightsTabView, CashFlowChartsSheet, PanelHeroSection, and AIPrivacySettingsView.
struct InsightsConsentAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    @AppStorage(AppPreferences.Keys.aiInsightsConsentAccepted) private var aiInsightsConsentAccepted: Bool = false
    @Environment(\.openURL) private var openURL

    /// Called after consent is accepted (e.g. to trigger AI generation).
    var onAccepted: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(L10n.AIConsent.insightsTitle, isPresented: $isPresented) {
                Button(L10n.AIConsent.accept) {
                    aiInsightsConsentAccepted = true
                    onAccepted()
                }
                Button(L10n.AIConsent.privacyPolicy) {
                    openURL(AppConstants.privacyURL)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.insightsMessage)
            }
    }
}

extension View {
    /// Adds the insights consent alert.
    func insightsConsentAlert(
        isPresented: Binding<Bool>,
        onAccepted: @escaping () -> Void = {}
    ) -> some View {
        modifier(InsightsConsentAlertModifier(isPresented: isPresented, onAccepted: onAccepted))
    }
}

// MARK: - Yala AI Onboarding Sheet

/// Compartido entre los 3 launchers del chat (Panel, Records, Statistics) — encapsula
/// el sheet con encadenamiento `onDismiss:` callback nativo iOS para abrir el chat
/// tras completar el onboarding (sin Task.sleep frágil).
///
/// Pattern:
/// 1. CTA Step 4 → setea `pendingOpenChat=true` y cierra el sheet del onboarding.
/// 2. `onDismiss:` se dispara post-animación nativa de iOS, abre el chat.
/// 3. Skip / Close cierran sin pendingOpenChat → no abren chat.
struct YalaAIOnboardingSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var pendingOpenChat: Bool
    @Binding var showChatSheet: Bool
    let launcher: YalaAIOnboardingLauncher
    let onPersistFlag: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(
                isPresented: $isPresented,
                onDismiss: {
                    if pendingOpenChat {
                        pendingOpenChat = false
                        showChatSheet = true
                    }
                }
            ) {
                YalaAIOnboardingView(launcher: launcher) { result in
                    switch result {
                    case .complete:
                        onPersistFlag()
                        pendingOpenChat = true
                    case .close:
                        TelemetryService.track(
                            .yalaAIOnboardingDismissed,
                            parameters: ["launcher": launcher.rawValue]
                        )
                    }
                    isPresented = false
                }
            }
    }
}

extension View {
    func yalaAIOnboardingSheet(
        isPresented: Binding<Bool>,
        pendingOpenChat: Binding<Bool>,
        showChatSheet: Binding<Bool>,
        launcher: YalaAIOnboardingLauncher,
        onPersistFlag: @escaping () -> Void
    ) -> some View {
        modifier(YalaAIOnboardingSheetModifier(
            isPresented: isPresented,
            pendingOpenChat: pendingOpenChat,
            showChatSheet: showChatSheet,
            launcher: launcher,
            onPersistFlag: onPersistFlag
        ))
    }
}

// MARK: - Groups Onboarding Sheet

/// Modifier simplificado para el onboarding informativo del tab Grupos.
/// A diferencia de YalaAI, NO encadena sheets — el CTA Step 3 ("Ir a Grupos")
/// solo cierra el sheet; el user queda en `GroupsContainerView` con empty state.
///
/// `onPersistFlag` se invoca en `.complete` (CTA Step 3 "Ir a Grupos") — persiste
/// flag y dispara seed lazy de categorías sistema. En `.close` (X topLeft) no se
/// invoca, lo que hace que el onboarding reaparezca al próximo tap del tab.
struct GroupsOnboardingSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onPersistFlag: () -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            GroupsOnboardingView { result in
                switch result {
                case .complete:
                    onPersistFlag()
                case .close:
                    break
                }
                isPresented = false
            }
        }
    }
}

extension View {
    func groupsOnboardingSheet(
        isPresented: Binding<Bool>,
        onPersistFlag: @escaping () -> Void
    ) -> some View {
        modifier(GroupsOnboardingSheetModifier(
            isPresented: isPresented,
            onPersistFlag: onPersistFlag
        ))
    }
}

// MARK: - Dismiss Keyboard on Tap

/// Global function to dismiss keyboard from anywhere
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}

/// Cierra el teclado al tocar áreas vacías del view.
/// Aplicar al contenido del ScrollView (después de .padding), NO al background —
/// el ScrollView absorbe taps al fondo del ZStack.
struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
    }
}

extension View {
    /// Dismisses keyboard when tapping anywhere on this view
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }

    /// Hides the keyboard programmatically
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Screen Background Modifier

/// Variantes de background para vistas root, sheets, fullScreenCovers.
/// SSOT para evitar inconsistencias (PanelBackgroundView vs theme.background plano).
enum YalaBackgroundVariant {
    /// `PanelBackgroundView()` con hero gradient theme-aware en los themes
    /// translucent (accent→negro, replicando WelcomeHero/Onboarding). SOLO para
    /// vistas completas: tab roots, vistas navegadas (push) y fullScreenCover.
    /// En light/finance themes mantiene el LinearGradient existing.
    case panel

    /// `theme.background` plano. Para CUALQUIER sheet desde el bottom (sin
    /// detents o con `[.large]`) y para success/celebración donde el contenido
    /// debe brillar sin distraer.
    case subtle

    /// Sin fondo aplicado (desnudo): el sheet muestra su fondo de sistema. Para
    /// sheets con detent parcial (`.medium`/`.height`/`.fraction`). En iPad el
    /// detent se fuerza a `.large`, así que esos sheets usan `.subtle` vía
    /// `DS.Adaptive.usesLargeSheets ? .subtle : .transparent`.
    case transparent
}

/// Aplica background temático consistente a la vista.
///
/// Reemplaza patrones manuales:
///   `ZStack { PanelBackgroundView(); content }` → `content.yalaScreenBackground()`
///   `ZStack { theme.background.ignoresSafeArea(); content }` → `content.yalaScreenBackground(.subtle)`
///
/// NOTA: Form/List dentro de la vista deben aplicar `.scrollContentBackground(.hidden)`
/// manualmente — el modifier NO lo hace automático para preservar predictibilidad.
struct YalaScreenBackgroundModifier: ViewModifier {
    @Environment(\.yalaTheme) private var theme
    let variant: YalaBackgroundVariant
    let ignoredEdges: Edge.Set?

    private var effectiveEdges: Edge.Set {
        ignoredEdges ?? .all
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch variant {
        case .panel:
            ZStack {
                PanelBackgroundView(ignoredEdges: effectiveEdges)
                content
            }
        case .subtle:
            ZStack {
                theme.background
                    .ignoresSafeArea(edges: effectiveEdges)
                content
            }
        case .transparent:
            content
        }
    }
}

extension View {
    /// Aplica background temático según `variant`.
    ///
    /// - Parameter variant: `.panel` (gradient, vistas completas), `.subtle`
    ///   (plano, sheets normales/success), `.transparent` (desnudo, sheets con
    ///   detent parcial).
    /// - Parameter ignoredEdges: Si `nil`, usa `.all`. Pasar valor explícito
    ///   (`[.top]`, `[.bottom]`) para coexistir con `safeAreaInset`.
    func yalaScreenBackground(
        _ variant: YalaBackgroundVariant = .panel,
        ignoredEdges: Edge.Set? = nil
    ) -> some View {
        modifier(YalaScreenBackgroundModifier(variant: variant, ignoredEdges: ignoredEdges))
    }
}

// MARK: - Previews

#Preview("Card Modifiers") {
    ScrollView {
        VStack(spacing: DS.Spacing.xl) {
            // Standard card
            Text("Card estándar")
                .frame(maxWidth: .infinity)
                .yalaCard()

            // Compact card
            Text("Card compacto")
                .frame(maxWidth: .infinity)
                .yalaCardCompact()

            // List row style
            HStack {
                Image(systemName: "cart.fill")
                    .foregroundStyle(.white)
                    .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                    .background(.blue, in: Circle())
                VStack(alignment: .leading) {
                    Text("Supermercado")
                    Text("Alimentación")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("-S/ 150.00")
                    .foregroundStyle(DS.Semantic.errorForeground)
            }
            .yalaListRow()

            // No shadow
            Text("Sin sombra")
                .frame(maxWidth: .infinity)
                .yalaCard(shadow: false)
        }
        .padding()
    }
    .background(.thBackground)
}

#Preview("Form Row Modifiers") {
    VStack(spacing: 1) {
        HStack {
            Image(systemName: "creditcard")
                .frame(width: DS.FormRow.iconWidth)
            Text("Cuenta")
            Spacer()
            Text("Banco Principal")
                .foregroundStyle(.secondary)
        }
        .yalaFormRow(showChevron: true)

        HStack {
            Image(systemName: "calendar")
                .frame(width: DS.FormRow.iconWidth)
            Text("Fecha")
            Spacer()
            Text("15 Ene 2026")
                .foregroundStyle(.secondary)
        }
        .yalaFormRow(showChevron: true)

        HStack {
            Image(systemName: "tag")
                .frame(width: DS.FormRow.iconWidth)
            Text("Etiquetas")
            Spacer()
        }
        .yalaFormRow(showChevron: true)
    }
    .background(.thBackground)
}
