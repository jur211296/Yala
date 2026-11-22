//
//  RecurringChangesCards.swift
//  Yala
//
//  Lote S2 de pagos recurrentes: arriba de Pagos planificados, una tarjeta por pago que cambió de precio («Netflix subió
//  a S/ 49,90» · Actualizar / Dejar así) o que dejó de cobrarse («¿Dejaste de pagar Spotify?» · Pausar el pago / Sigue
//  activo). Cuelga del mismo interruptor que las propuestas de S1 («Proponer pagos que se repiten») y, como ellas, se
//  recalcula al aparecer y cuando cambian los datos con la página a la vista.
//

import SwiftData
import SwiftUI

@MainActor
@Observable
final class RecurringChangesModel {
    private(set) var items: [RecurringChangesSource.Item] = []
    private var isStale = true

    func refreshIfNeeded(context: ModelContext, isEnabled: Bool) {
        guard isStale, isEnabled else { return }
        refresh(context: context)
    }

    func markStale() { isStale = true }

    func refresh(context: ModelContext, now: Date = .now) {
        isStale = false
        do {
            items = try RecurringChangesSource.load(context: context, now: now)
        } catch {
            #if DEBUG
            print("RecurringChangesModel: Error: \(error)")
            #endif
            items = []
        }
    }

    func visibleItems(preferences: RecurringChangePreferences, isEnabled: Bool) -> [RecurringChangesSource.Item] {
        guard isEnabled else { return [] }
        return items.filter { $0.livePayment != nil && preferences.isVisible($0.change) }
    }
}

struct RecurringChangesCards: View {
    /// «Actualizar»: el pago pasa al precio nuevo.
    let onUpdateAmount: (ScheduledPayment, Double) -> Void
    /// «Pausar el pago»: deja de avisar y de reservar dinero, como pausarlo desde su detalle.
    let onPause: (ScheduledPayment) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.isRootPageShown) private var isRootPageShown
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    @State private var model = RecurringChangesModel()

    private var preferences: RecurringChangePreferences { .shared }
    private var isEnabled: Bool { RecurringProposalPreferences.shared.isEnabled }

    var body: some View {
        let visible = model.visibleItems(preferences: preferences, isEnabled: isEnabled)
        VStack(spacing: DS.Spacing.sm) {
            ForEach(visible) { item in
                if let payment = item.livePayment {
                    card(item.change, payment: payment)
                }
            }
        }
        // El margen va dentro: sin avisos, Pagos planificados queda exactamente como antes.
        .padding(.horizontal, visible.isEmpty ? 0 : DS.Spacing.lg)
        .padding(.top, visible.isEmpty ? 0 : DS.Spacing.md)
        .onAppear { if isRootPageShown { refreshIfNeeded() } }
        .onChange(of: sessionState.dataVersion) { _, _ in dataChanged() }
        .onChange(of: isRootPageShown) { _, shown in if shown { refreshIfNeeded() } }
        .onChange(of: isEnabled) { _, _ in if isRootPageShown { refreshIfNeeded() } }
    }

    private func card(_ change: RecurringPaymentChanges.Change, payment: ScheduledPayment) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                badge(for: payment)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title(change, payment: payment))
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(.thPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail(change, payment: payment))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                // El id va en el texto, no en la tarjeta: puesto en el contenedor, pisaría el de sus dos botones.
                .accessibilityIdentifier("recurring_change_card_\(change.kindKey)")
                Spacer(minLength: 0)
            }
            // Los dos botones siempre lado a lado (nunca uno debajo del otro); con texto grande, su texto pasa a dos líneas.
            HStack(alignment: .top, spacing: DS.Spacing.sm) { buttons(change, payment: payment) }
        }
        .panelCard(small: true)
    }

    @ViewBuilder
    private func buttons(_ change: RecurringPaymentChanges.Change, payment: ScheduledPayment) -> some View {
        switch change.kind {
        case .priceChanged(let newAmount, _):
            actionButton(L10n.CapturaAtajoParte2.Changes.update, prominent: true, id: "recurring_change_update") {
                onUpdateAmount(payment, newAmount)
            }
            actionButton(L10n.CapturaAtajoParte2.Changes.keep, prominent: false, id: "recurring_change_keep") {
                preferences.dismiss(change)
            }
        case .stopped:
            actionButton(L10n.CapturaAtajoParte2.Changes.pause, prominent: true, id: "recurring_change_pause") {
                onPause(payment)
            }
            actionButton(L10n.CapturaAtajoParte2.Changes.stillActive, prominent: false, id: "recurring_change_still_active") {
                preferences.dismiss(change)
            }
        }
    }

    private func actionButton(_ title: String, prominent: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DS.Typography.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.xs)
        }
        .buttonStyle(.plain)
        .foregroundStyle(prominent ? theme.onAccent : Color(uiColor: .label))
        .background(Capsule().fill(prominent ? theme.accent : Color(uiColor: .tertiarySystemFill)))
        .contentShape(Capsule())
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func badge(for payment: ScheduledPayment) -> some View {
        if let logo = PaymentLogoResolver.resolve(storedID: payment.brandLogoID, name: payment.name) {
            SubscriptionBrandBadge(logo: logo, isDecorative: true)
        } else {
            ZStack {
                Circle().fill(theme.accent)
                Image(systemName: PaymentCategory.recurring.iconName)
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.onAccent)
            }
            .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Textos

    private func title(_ change: RecurringPaymentChanges.Change, payment: ScheduledPayment) -> String {
        switch change.kind {
        case .priceChanged(let newAmount, let increased):
            let amount = money(newAmount, payment)
            return increased
                ? L10n.CapturaAtajoParte2.Changes.priceUp(payment.name, amount)
                : L10n.CapturaAtajoParte2.Changes.priceDown(payment.name, amount)
        case .stopped:
            return L10n.CapturaAtajoParte2.Changes.stoppedTitle(payment.name)
        }
    }

    private func detail(_ change: RecurringPaymentChanges.Change, payment: ScheduledPayment) -> String {
        switch change.kind {
        case .priceChanged(let newAmount, _):
            return L10n.CapturaAtajoParte2.Changes.priceDetail(money(newAmount, payment), money(payment.amount, payment))
        case .stopped(let lastSeen):
            let date = lastSeen.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLocale.current))
            return L10n.CapturaAtajoParte2.Changes.stoppedDetail(date)
        }
    }

    private func money(_ value: Double, _ payment: ScheduledPayment) -> String {
        appPreferences.currency(value, currencyCode: payment.currencyCode)
    }

    // MARK: - Refresco

    private func refreshIfNeeded() {
        model.refreshIfNeeded(context: modelContext, isEnabled: isEnabled)
    }

    private func dataChanged() {
        model.markStale()
        if isRootPageShown { refreshIfNeeded() }
    }
}

extension RecurringPaymentChanges.Change {
    /// Para los identificadores de accesibilidad: «price» o «stopped».
    var kindKey: String {
        switch kind {
        case .priceChanged: return "price"
        case .stopped: return "stopped"
        }
    }
}
