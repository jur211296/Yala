//
//  NotificationPrimerSheet.swift
//  Yala
//
//  Contextual notification permission primer shown after 3rd transaction.
//

import SwiftUI
import SwiftData

extension View {
    /// La hoja del permiso de notificaciones en un momento dado (UX 2.2 · L5-14). Un solo modificador para no alargar
    /// la cadena del `body` de los editores (límite del type-checker del CI, `.claude/rules/swiftui-ds.md`).
    func notificationPrimerSheet(
        isPresented: Binding<Bool>,
        context: NotificationPrimerContext,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            NotificationPrimerSheet(context: context)
        }
    }
}

/// Encender la alerta de un presupuesto es el momento de pedir las notificaciones (UX 2.2 · L5-14): sin permiso, la
/// alerta no llega nunca. Solo al encenderla con el editor ya cargado (no al abrir uno que ya la tenía).
struct BudgetAlertNotificationPrimer: ViewModifier {
    let alertEnabled: Bool
    let isLoaded: Bool

    @State private var showPrimer = false

    func body(content: Content) -> some View {
        content
            .onChange(of: alertEnabled) { _, enabled in offerIfNeeded(enabled) }
            .notificationPrimerSheet(isPresented: $showPrimer, context: .budgetAlert)
    }

    private func offerIfNeeded(_ enabled: Bool) {
        guard enabled, isLoaded else { return }
        Task { @MainActor in
            if await NotificationPrimerMoments.claim(.budgetAlert) { showPrimer = true }
        }
    }
}

struct NotificationPrimerSheet: View {

    /// Desde dónde se pide (UX 2.2 · L5-14): en contexto, la hoja dice solo el beneficio de ese momento.
    var context: NotificationPrimerContext = .records

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 48 // A11Y-DT: primer icon
    @State private var isRequesting = false

    /// El texto va en un scroll que solo se mueve si hace falta, y los botones fuera de él: la hoja es de media
    /// altura y, sin esto, el tercer beneficio salía cortado («…al límite de un…») en un iPhone 17 Pro en español
    /// a tamaño normal (medido el 2026-10-14). Molde: `.claude/rules/swiftui-ds.md`, pantallas con `Spacer`s.
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Icon
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: iconSize))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)

                        // Title
                        Text(title)
                            .font(DS.Typography.title)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        // Benefits: en contexto, solo el de ese momento (no promete avisos de lo que no tienes).
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            switch context {
                            case .records:
                                benefitRow(icon: "chart.bar.fill", text: L10n.NotificationPrimer.benefit1)
                                benefitRow(icon: "calendar.badge.clock", text: L10n.NotificationPrimer.benefit2)
                                benefitRow(icon: "bell.fill", text: L10n.NotificationPrimer.benefit3)
                            case .scheduledPayment:
                                benefitRow(icon: "calendar.badge.clock", text: L10n.NotificationPrimer.scheduledBenefit)
                            case .budgetAlert:
                                benefitRow(icon: "bell.fill", text: L10n.NotificationPrimer.budgetBenefit)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                    }
                    .padding(.top, DS.Spacing.xl)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            // CTA
            VStack(spacing: DS.Spacing.md) {
                YalaPrimaryButton(
                    L10n.NotificationPrimer.accept,
                    isLoading: isRequesting
                ) {
                    acceptNotifications()
                }

                Button {
                    dismiss()
                } label: {
                    Text(L10n.NotificationPrimer.reject)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Text(L10n.NotificationPrimer.hint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .yalaScreenBackground(.partialSheet)
        .yalaSheetDetents([.medium])
    }

    // MARK: - Components

    private var title: String {
        switch context {
        case .records: L10n.NotificationPrimer.title
        case .scheduledPayment: L10n.NotificationPrimer.scheduledTitle
        case .budgetAlert: L10n.NotificationPrimer.budgetTitle
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(.tint)
                .frame(width: DS.Spacing.xxl)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func acceptNotifications() {
        isRequesting = true
        Task { @MainActor in
            let granted = await NotificationService.shared.requestPermission()
            if granted {
                // Activate all existing notifications (seeded as inactive during onboarding)
                let descriptor = FetchDescriptor<NotificationItem>()
                do {
                    let items = try modelContext.fetch(descriptor)
                    for item in items {
                        item.isActive = true
                    }
                    try modelContext.save()
                    await NotificationService.shared.rescheduleAllNotifications(items: items)
                    // Enable budget alerts global toggle so BudgetAlertService activates.
                    // Va por `PreferenceSyncService` y no por `UserDefaults.standard.set`: la key es
                    // `synced: true` y esto es un punto de INTENCIÓN del usuario, así que tiene que
                    // llegar a sus otros devices. Escribir en crudo llegaba a iCloud de rebote —
                    // `AppPreferences.loadFromDefaults` re-persistía lo que releía— y ese puente
                    // accidental se cerró (ver el docblock de `loadFromDefaults`). El service hace
                    // el `local.set` por dentro, así que `BudgetAlertService` lee lo mismo que antes.
                    PreferenceSyncService.shared.set(
                        bool: true, forKey: AppPreferences.Keys.budgetAlertsEnabled)
                    // Y el recordatorio de deudas de Grupos, por la MISMA vía y por el mismo motivo.
                    //
                    // Decisión de Jürgen (2026-09-08), ticket
                    // `groups-settlement-reminder-discoverability`: nació con el default `false`
                    // copiado de `budgetAlertsEnabled` —correcto: es el único aviso que habla del
                    // dinero que le debes a otra persona, y encenderlo sin pedirlo convertiría una
                    // actualización en un cobro sorpresa— pero **se copió el default sin copiar el
                    // encendido**, y ese encendido es justo lo que hace inocuo al default. Resultado:
                    // un feature construido, correcto y pinneado que no recibía prácticamente nadie.
                    //
                    // Aquí el usuario está diciendo «sí, avísame»; el consentimiento sigue siendo
                    // real porque el toggle queda visible y apagable en Ajustes.
                    PreferenceSyncService.shared.set(
                        bool: true, forKey: AppPreferences.Keys.groupSettlementRemindersEnabled)
                } catch {
                    #if DEBUG
                    print("NotificationPrimerSheet: Error activating notifications: \(error)")
                    #endif
                }
            }
            isRequesting = false
            dismiss()
        }
    }
}
