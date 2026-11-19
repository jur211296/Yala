//
//  RecurringFromRecordSheet.swift
//  Yala
//
//  «Hacer recurrente» a partir de un registro (encargo del 15-nov). Una sola presentación con fases: si ya hay un
//  recurrente parecido, primero se ofrece vincular el registro a él; si no, o si la persona prefiere otro, el editor de
//  recurrentes de siempre, prellenado con el registro. En los dos caminos el registro queda como un pago del
//  recurrente y no se crea ningún gasto más (`RecurringFromRecordService`).
//
//  Fases en vez de una alerta seguida de una hoja: una alerta no admite el nombre del recurrente en el botón, y dos
//  presentaciones encadenadas desde el mismo ancla son el molde que deja flags pegados (`swiftui-ds.md`).
//

import SwiftData
import SwiftUI

struct RecurringFromRecordSheet: View {
    let record: TransactionItem
    /// Termina el flujo: se creó o se vinculó. Se llama antes de que la hoja se cierre.
    var onFinished: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme

    private enum Phase {
        case deciding
        case choice(ScheduledPayment)
        case editor(ScheduledPaymentPrefill)
    }

    @State private var phase: Phase = .deciding

    var body: some View {
        // Un registro borrado mientras la hoja está abierta no se lee (`swiftui-ds.md`, filas con modelo borrado).
        if record.isDeleted || record.modelContext == nil {
            Color.clear
        } else {
            switch phase {
            case .deciding:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .yalaScreenBackground(.subtle)
                    .onAppear(perform: decide)
            case .choice(let payment):
                choiceView(payment)
            case .editor(let prefill):
                ScheduledPaymentEditorView(
                    payment: nil,
                    prefill: prefill,
                    onSaved: { paymentID in
                        if RecurringFromRecordService.linkAsFirstPayment(
                            record, paymentID: paymentID, context: modelContext) != nil {
                            SavedRecordNotice.showInfo(message: L10n.RecurringFromRecord.noticeCreated)
                        }
                        onFinished?()
                    }
                )
            }
        }
    }

    private func decide() {
        if let similar = RecurringFromRecordService.similarPayment(for: record, in: modelContext) {
            phase = .choice(similar)
        } else {
            phase = .editor(RecurringFromRecordService.prefill(from: record))
        }
    }

    // MARK: - Ya hay uno parecido

    private func choiceView(_ payment: ScheduledPayment) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.RecurringFromRecord.choiceHeadline)
                            .font(DS.Typography.title3)
                            .accessibilityAddTraits(.isHeader)
                        Text(L10n.RecurringFromRecord.choiceBody)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    paymentCard(payment)

                    VStack(spacing: DS.Spacing.md) {
                        YalaPrimaryButton(L10n.RecurringFromRecord.choiceLink(payment.name)) {
                            link(to: payment)
                        }
                        .accessibilityIdentifier("recurring_from_record_link")

                        Button {
                            phase = .editor(RecurringFromRecordService.prefill(from: record))
                        } label: {
                            Text(L10n.RecurringFromRecord.choiceCreateNew)
                                .font(DS.Typography.headline)
                                .foregroundStyle(theme.accentText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.lg)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recurring_from_record_create_new")
                    }
                }
                .padding(DS.Spacing.xl)
                .frame(maxWidth: DS.Adaptive.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(L10n.RecurringFromRecord.makeRecurring)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .yalaScreenBackground(.subtle)
        }
        .accessibilityIdentifier("recurring_from_record_choice")
    }

    private func paymentCard(_ payment: ScheduledPayment) -> some View {
        let dateStyle = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(AppLocale.current)
        return HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(payment.name)
                    .font(DS.Typography.headline)
                Text(L10n.RecurringFromRecord.choiceNextDue(payment.nextDueDate.formatted(dateStyle)))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(appPreferences.currency(payment.amount, currencyCode: payment.currencyCode))
                .font(DS.Typography.headline)
                .monospacedDigit()
        }
        .padding(DS.Spacing.lg)
        .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .combine)
    }

    private func link(to payment: ScheduledPayment) {
        let name = payment.name
        guard RecurringFromRecordService.link(record, to: payment, context: modelContext) else {
            DS.Haptic.error()
            return
        }
        DS.Haptic.success()
        onFinished?()
        dismiss()
        SavedRecordNotice.showInfo(message: L10n.RecurringFromRecord.noticeLinked(name))
    }
}

// MARK: - Selector de registros (Planificación › Pagos › «Reusar»)

/// Los registros recientes que se pueden hacer recurrentes, como en Registros (encargo del 17-nov): el buscador, los
/// filtros rápidos (Cuenta · Categoría · Más filtros) y las mismas filas agrupadas por día. Al elegir uno sigue el mismo
/// flujo que el menú de un registro, en la misma hoja.
///
/// Los filtros son de la hoja (`ReusarRegistroFilters`), no de la sesión: elegir una cuenta para encontrar el registro no
/// deja filtrados Registros, el Panel ni Estadísticas.
struct RecurringRecordPickerSheet: View {
    var onFinished: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    @State private var records: [TransactionItem] = []
    @State private var accounts: [Account] = []
    @State private var categories: [Category] = []
    @State private var subcategories: [Subcategory] = []
    @State private var tags: [Tag] = []
    @State private var filters = ReusarRegistroFilters()
    @State private var query = ""
    @State private var chosen: TransactionItem?
    @State private var hasLoaded = false
    /// El monto de la sesión al abrir «Más filtros»: esa hoja lo escribe en la sesión (`SessionState.applyAmountFilter`)
    /// y aquí se pasa a los filtros propios y se devuelve el de la sesión al cerrarla.
    @State private var sessionAmountBeforeMoreFilters: ReusarRegistroLogic.SessionAmount?

    /// Hasta dónde mira atrás: seis meses cubren cualquier cobro mensual o trimestral reciente.
    private static let lookbackMonths = 6
    private static let fetchLimit = 600

    var body: some View {
        if let chosen {
            RecurringFromRecordSheet(record: chosen, onFinished: onFinished)
        } else {
            NavigationStack {
                content
                    .navigationTitle(L10n.RecurringFromRecord.pickerTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                                dismiss()
                            }
                        }
                    }
                    .yalaScreenBackground(.subtle)
            }
            .providesGroupNames()
            .onAppear(perform: load)
            .sheet(isPresented: $filters.showFiltersSheet, onDismiss: takeAmountFromMoreFilters) {
                RecordsFiltersView(recordsViewModel: filters)
                    .onAppear(perform: rememberSessionAmount)
            }
        }
    }

    private var content: some View {
        let groups = ReusarRegistroLogic.groups(
            records, criteria: filters.filterCriteria(withTagCatalog: tags), query: query, tags: tags)
        return ScrollView {
            VStack(spacing: DS.Spacing.md) {
                RecordsListSearchField(text: $query, onClear: { query = "" })
                RecordsQuickFilterBar(
                    viewModel: filters,
                    accounts: accounts,
                    categories: categories,
                    subcategories: subcategories,
                    onFilterChange: {}
                ) {
                    if filters.hasActiveFilters {
                        clearFiltersButton
                    }
                }
                list(groups)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xl)
            .frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("recurring_record_picker_list")
    }

    /// Solo con algún filtro puesto, al final de la fila de chips. Sin texto: con «Limpiar filtros» escrito, en el iPhone
    /// SE los chips bajaban a tres líneas.
    private var clearFiltersButton: some View {
        Button {
            DS.Haptic.selection()
            filters.clearFilters()
        } label: {
            Image(systemName: "xmark")
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.thAccentText)
                .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ReusarRegistroText.clearFilters)
        .accessibilityIdentifier("recurring_record_picker_clear_filters")
    }

    @ViewBuilder
    private func list(_ groups: [(date: Date, records: [TransactionItem])]) -> some View {
        if hasLoaded && records.isEmpty {
            ContentUnavailableView(L10n.RecurringFromRecord.pickerEmpty, systemImage: "repeat")
        } else if groups.isEmpty && hasLoaded {
            if !RecordsListSearchLogic.query(query).isEmpty {
                ContentUnavailableView(L10n.RecurringFromRecord.pickerNoResults(query), systemImage: "magnifyingglass")
            } else {
                ContentUnavailableView(
                    ReusarRegistroText.noMatches,
                    systemImage: "line.3.horizontal.decrease",
                    description: Text(ReusarRegistroText.noMatchesHint))
            }
        } else {
            LazyVStack(spacing: DS.Spacing.sm) {
                ForEach(groups, id: \.date) { day in
                    RecordDateSectionView(
                        date: day.date,
                        includesYear: RecordsMonthSectionsLogic.dayHeaderIncludesYear(day.date),
                        showsWeekday: true
                    )
                    ForEach(day.records, id: \.persistentModelID) { record in
                        RecordRowView(
                            record: record,
                            currencyCode: appPreferences.defaultCurrencyCode.rawValue,
                            isSelectionMode: false,
                            isSelected: false,
                            onTap: { choose(record) },
                            onToggleSelection: {}
                        )
                    }
                }
                Text(L10n.RecurringFromRecord.pickerFooter)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DS.Spacing.md)
            }
        }
    }

    private func choose(_ record: TransactionItem) {
        DS.Haptic.selection()
        chosen = record
    }

    // MARK: - «Más filtros» y el monto de la sesión

    private func rememberSessionAmount() {
        guard sessionAmountBeforeMoreFilters == nil else { return }
        sessionAmountBeforeMoreFilters = .init(
            condition: SessionState.shared.amountCondition, currency: SessionState.shared.amountCurrency)
    }

    private func takeAmountFromMoreFilters() {
        guard let before = sessionAmountBeforeMoreFilters else { return }
        sessionAmountBeforeMoreFilters = nil
        let after = ReusarRegistroLogic.SessionAmount(
            condition: SessionState.shared.amountCondition, currency: SessionState.shared.amountCurrency)
        guard after != before else { return }
        filters.amountCondition = after.condition
        SessionState.shared.applyAmountFilter(before.condition, in: before.currency)
    }

    // MARK: - Carga

    private func load() {
        guard !hasLoaded else { return }
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .month, value: -Self.lookbackMonths, to: calendar.startOfDay(for: .now))
            ?? .distantPast
        var descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= cutoff && $0.scheduledPaymentID == nil && $0.balanceAdjustmentType == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = Self.fetchLimit
        do {
            records = try modelContext.fetch(descriptor).filter(RecurringFromRecordService.offersMakeRecurring)
            accounts = try modelContext.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
            categories = try modelContext.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
            subcategories = try modelContext.fetch(FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\.name)]))
            tags = try modelContext.fetch(FetchDescriptor<Tag>())
        } catch {
            #if DEBUG
            print("RecurringRecordPickerSheet: Error fetching records: \(error)")
            #endif
            records = []
        }
        hasLoaded = true
    }
}

// MARK: - Filtros de la hoja

/// Los filtros del selector: los mismos que Registros (la barra rápida y «Más filtros» los escriben igual), pero
/// propios de la hoja. Nacen vacíos y mueren con ella.
@MainActor
@Observable
final class ReusarRegistroFilters: Filterable, RecordsQuickFilterModel {
    var selectedAccounts: Set<PersistentIdentifier> = []
    var selectedCategories: Set<PersistentIdentifier> = []
    var selectedSubcategories: Set<PersistentIdentifier> = []
    var selectedNeeds: Set<SubcategoryNeed> = []
    var selectedTags: Set<PersistentIdentifier> = []
    var selectedCurrencies: Set<CurrencyCode> = []
    var amountCondition: AmountFilterCondition = .any
    var searchText: String = ""
    var excludedAccounts: Set<PersistentIdentifier> = []
    var excludedCategories: Set<PersistentIdentifier> = []
    var excludedSubcategories: Set<PersistentIdentifier> = []
    var excludedNeeds: Set<SubcategoryNeed> = []
    var excludedTags: Set<PersistentIdentifier> = []
    var excludedCurrencies: Set<CurrencyCode> = []
    var selectedTransactionNatures: Set<TransactionNature> = []
    var sharedExpenseFilter: SharedExpenseFilter = .all
    /// «Más filtros» abierto: lo enciende la barra rápida.
    var showFiltersSheet = false

    var hasActiveFilters: Bool { hasActiveFiltersDefault }
    var activeFilterCount: Int { activeFilterCountDefault }
    func clearFilters() { clearFiltersDefault() }
}

// MARK: - Lógica

enum ReusarRegistroLogic {
    /// El monto que la sesión tenía puesto, con su moneda.
    struct SessionAmount: Equatable {
        let condition: AmountFilterCondition
        let currency: CurrencyCode?
    }

    /// Lo que se ve: los registros que pasan los filtros de la hoja, por día (el más reciente arriba) y, dentro de cada
    /// día, en el orden en que llegaron; después, el buscador de Registros (descripción, categoría, cuenta, etiqueta o
    /// importe).
    static func groups(
        _ records: [TransactionItem],
        criteria: FilterCriteria,
        query: String,
        tags: [Tag],
        calendar: Calendar = .current
    ) -> [(date: Date, records: [TransactionItem])] {
        var byDay: [Date: [TransactionItem]] = [:]
        var order: [Date] = []
        for record in records where !record.isDeleted && FilterService.matchesCriteria(record, criteria: criteria) {
            let day = calendar.startOfDay(for: record.date)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(record)
        }
        let grouped = order.sorted(by: >).map { (date: $0, records: byDay[$0] ?? []) }
        return RecordsViewModel.applyingListSearch(query, to: grouped, tags: tags)
    }
}

// MARK: - Textos

/// Los textos de «Reusar», en su tabla propia (`ReusarRegistro.strings`). Se leen con la misma cadena que `ls()` de
/// `L10n.swift`: el idioma elegido dentro de Yala, su variante y su idioma padre.
enum ReusarRegistroText {
    static let table = "ReusarRegistro"

    /// La clave en la tabla, con la cadena de idiomas de la app (variante → padre → main → la clave).
    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "reusarRegistro.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// «Reusar», junto a «Nuevo pago planificado».
    static var button: String { string("button") }
    /// Lo que hace el botón, para VoiceOver.
    static var buttonHint: String { string("buttonHint") }
    static var clearFilters: String { string("clearFilters") }
    static var noMatches: String { string("noMatches") }
    static var noMatchesHint: String { string("noMatchesHint") }
}
