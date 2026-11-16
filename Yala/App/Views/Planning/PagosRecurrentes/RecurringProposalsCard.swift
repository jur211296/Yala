//
//  RecurringProposalsCard.swift
//  Yala
//
//  Tarjeta «Pagos que se repiten» arriba de Pagos planificados (lote S1, opción P1 de la definición del 12-nov):
//  lo que Yala encontró en el historial y todavía no tiene respuesta. Tocar una fila abre la propuesta; la tarjeta
//  desaparece cuando no queda nada por responder.
//

import SwiftData
import SwiftUI

/// Lo que la tarjeta sabe del historial. Se recalcula al aparecer y cuando cambian los datos con la página a la vista;
/// con la página oculta solo se apunta y se recalcula al volver (las seis páginas siguen montadas).
@MainActor
@Observable
final class RecurringProposalsModel {
    private(set) var items: [RecurringProposalsSource.Item] = []
    private var isStale = true

    /// Con la función apagada no se lee nada: queda pendiente para cuando se encienda.
    func refreshIfNeeded(context: ModelContext, isEnabled: Bool) {
        guard isStale, isEnabled else { return }
        refresh(context: context)
    }

    func markStale() { isStale = true }

    func refresh(context: ModelContext, now: Date = .now) {
        isStale = false
        do {
            items = try RecurringProposalsSource.load(context: context, now: now)
        } catch {
            #if DEBUG
            print("RecurringProposalsModel: Error: \(error)")
            #endif
            items = []
        }
    }

    /// Lo que se enseña según lo que la persona ya contestó.
    func visibleItems(preferences: RecurringProposalPreferences) -> [RecurringProposalsSource.Item] {
        let visibleKeys = Set(preferences.visible(items.map(\.proposal)).map(\.key))
        return items.filter { visibleKeys.contains($0.proposal.key) }
    }
}

struct RecurringProposalsCard: View {
    /// Lleva la lista al mes del primer cobro del pago recién creado («Ver» del aviso).
    let onShowMonth: (Date) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.isRootPageShown) private var isRootPageShown
    @Environment(\.yalaTheme) private var theme

    @State private var model = RecurringProposalsModel()
    @State private var openedItem: RecurringProposalsSource.Item?
    @State private var showsSettings = false

    private var preferences: RecurringProposalPreferences { .shared }

    var body: some View {
        let items = model.visibleItems(preferences: preferences)
        VStack(spacing: DS.Spacing.none) {
            // El margen va dentro del `if`: sin propuestas, Pagos planificados queda exactamente como antes.
            if !items.isEmpty {
                card(items)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)
            }
        }
        // Las páginas de pestaña están montadas desde el arranque: con la página oculta no se lee el historial.
        .onAppear { if isRootPageShown { refreshIfNeeded() } }
        .onChange(of: sessionState.dataVersion) { _, _ in dataChanged() }
        .onChange(of: isRootPageShown) { _, shown in pageShownChanged(shown) }
        .onChange(of: preferences.isEnabled) { _, _ in if isRootPageShown { refreshIfNeeded() } }
        .sheet(item: $openedItem) { item in
            RecurringProposalSheet(item: item) { created in
                proposalCreated(created)
            }
        }
        .sheet(isPresented: $showsSettings) {
            RecurringProposalsSettingsView()
        }
    }

    private func card(_ items: [RecurringProposalsSource.Item]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(PagosRecurrentesText.cardTitle)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    Text(PagosRecurrentesText.cardSubtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.sm)
                Menu {
                    Button {
                        showsSettings = true
                    } label: {
                        Label(PagosRecurrentesText.cardManage, systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("recurring_proposals_manage")
                } label: {
                    Image(systemName: "ellipsis")
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: DS.Icon.badgeLarge, minHeight: DS.Icon.badgeLarge)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(PagosRecurrentesText.cardManageA11y)
                .accessibilityIdentifier("recurring_proposals_menu")
            }

            VStack(spacing: DS.Spacing.sm) {
                ForEach(items) { item in
                    RecurringProposalRow(item: item) { openedItem = item }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recurring_proposals_card")
    }

    // MARK: - Refresco

    private func refreshIfNeeded() {
        model.refreshIfNeeded(context: modelContext, isEnabled: preferences.isEnabled)
    }

    private func dataChanged() {
        model.markStale()
        if isRootPageShown { refreshIfNeeded() }
    }

    private func pageShownChanged(_ shown: Bool) {
        if shown { refreshIfNeeded() }
    }

    // MARK: - Pago creado

    /// La lista se recarga sola: el guardado sube `dataVersion`.
    private func proposalCreated(_ created: RecurringProposalSheet.Created) {
        let message: String
        if let reminder = created.firstReminder {
            message = PagosRecurrentesText.createdNotice(
                name: created.name, reminderDate: ScheduledPaymentDateText.dayMonthLong(reminder)
            )
        } else {
            message = PagosRecurrentesText.createdNoticeNoReminder(name: created.name)
        }
        let firstDue = created.firstDueDate
        DraftDiscardUndoNotice.show(
            message: message,
            systemImage: "checkmark.circle",
            undoTitle: PagosRecurrentesText.createdView,
            noticeIdentifier: "recurring_created_notice",
            undoIdentifier: "recurring_created_view"
        ) {
            onShowMonth(firstDue)
        }
    }
}

// MARK: - Fila

/// Una propuesta: el logo del servicio (o el icono de pago recurrente), nombre, cada cuánto y con qué cuenta, y el monto.
struct RecurringProposalRow: View {
    let item: RecurringProposalsSource.Item
    let action: () -> Void

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: action) {
            content
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recurring_proposal_row_\(item.proposal.key)")
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.md) {
                    badge
                    nameAndDetail
                }
                amountLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DS.Spacing.md) {
                badge
                nameAndDetail
                Spacer(minLength: DS.Spacing.sm)
                amountLabel
                Image(systemName: "chevron.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let brandID = item.proposal.brandID, let brand = SubscriptionBrandCatalog.brand(id: brandID) {
            SubscriptionBrandBadge(brand: brand, isDecorative: true)
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

    private var nameAndDetail: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(item.proposal.displayName)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            Text(RecurringProposalFormatting.detailLine(item))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        }
    }

    private var amountLabel: some View {
        Text(RecurringProposalFormatting.amount(item.proposal, appPreferences: appPreferences))
            .font(DS.Typography.headline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Formato

@MainActor
enum RecurringProposalFormatting {
    /// «Cada mes, el 14 · Visa BCP».
    static func detailLine(_ item: RecurringProposalsSource.Item) -> String {
        let cadence = cadenceText(item.proposal.cadence)
        guard let account = item.liveAccount?.name, !account.isEmpty else { return cadence }
        return "\(cadence) · \(account)"
    }

    static func cadenceText(_ cadence: RecurringPaymentDetector.Cadence, locale: Locale? = nil) -> String {
        let locale = locale ?? AppLocale.current
        switch cadence {
        case .monthly(let day, let isApproximate):
            let dayText = String(day)
            return isApproximate
                ? PagosRecurrentesText.cadenceMonthlyApprox(day: dayText)
                : PagosRecurrentesText.cadenceMonthly(day: dayText)
        case .weekly(let weekday):
            return PagosRecurrentesText.cadenceWeekly(weekday: weekdayName(weekday, locale: locale))
        }
    }

    /// «lunes» (en el idioma de la app; `Calendar` cuenta 1 = domingo).
    static func weekdayName(_ weekday: Int, locale: Locale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.standaloneWeekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "" }
        let name = symbols[weekday - 1]
        // En español y portugués el día va en minúscula dentro de la frase.
        let lowercaseLanguages: Set<String> = ["es", "pt", "fr", "it", "nl", "pl"]
        if let language = locale.language.languageCode?.identifier, lowercaseLanguages.contains(language) {
            return name.lowercased(with: locale)
        }
        return name
    }

    /// El monto del último cobro con su divisa. Sin «≈» aunque varíe: «≈» solo marca una tasa de cambio aproximada
    /// (decisión 31 de 2.3); que el monto cambia lo dice la hoja.
    static func amount(_ proposal: RecurringPaymentDetector.Proposal, appPreferences: AppPreferences) -> String {
        appPreferences.currency(proposal.amount, currencyCode: proposal.currencyCode, forceFullPrecision: true)
    }
}
