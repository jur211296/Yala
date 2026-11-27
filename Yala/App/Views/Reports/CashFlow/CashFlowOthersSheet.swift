//
//  CashFlowOthersSheet.swift
//  Yala
//
//  Sheet showing breakdown of "other expenses" categories not assigned to any line.
//  Desde el 19-nov-2026 dice también qué se proyecta como fijo y qué se dejó fuera por aislado
//  (`FlujoProyeccionInteligente`), con los textos en su propia tabla (`L10n.FlujoProyeccion`).
//
//  Desde el 19-nov-2026 por la tarde (Jürgen: «siempre lleguemos a nivel de subcategoría» y «poder verlos y elegirlos
//  para meses futuros»): cada fila es una subcategoría, agrupada bajo su categoría (que se pliega y dice su suma); lo
//  anotado en la madre sin subcategoría va en su propia fila; el + agrega esa subcategoría al plan. En un mes que viene,
//  con plan, solo hay partidas fijas, cada una con «Considerar a futuro». El total de arriba y la lista salen de la
//  misma fuente (`CashFlowOtherResult.items`): la hoja ya no puede abrirse vacía con un total distinto de cero.
//

import SwiftData
import SwiftUI

struct CashFlowOthersSheet: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    var isIncome: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDetent: PresentationDetent = .medium
    /// Las categorías plegadas.
    @State private var plegadas: Set<String> = []

    private var isLargeDetent: Bool { selectedDetent == .large }

    private var otherResult: CashFlowOtherResult? {
        Self.otherResult(
            in: viewModel.projection?.months ?? [],
            selectedMonthKey: viewModel.selectedMonthKey,
            isIncome: isIncome
        )
    }

    /// Lo no considerado del mes elegido en la tira, que es desde donde se abre la hoja. Antes leía siempre el mes en
    /// curso y, abierta desde otro mes, enseñaba lo de este (lote 08 de las necesarias 2.3). Un mes elegido sin nada
    /// no cae al mes en curso; solo si la clave ya no está en la proyección (cambió el horizonte) se enseña el actual.
    static func otherResult(in months: [CashFlowMonth], selectedMonthKey: String, isIncome: Bool) -> CashFlowOtherResult? {
        let month = months.first { $0.monthKey == selectedMonthKey }
            ?? months.first(where: \.isCurrent)
            ?? months.first
        return isIncome ? month?.otherIncome : month?.otherExpenses
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    if let other = otherResult {
                        totalHeader(other)
                    }
                    descriptionText
                    if let other = otherResult {
                        subcategoryGroups(other)
                        projectionSections(other)
                    }
                    hintText
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .yalaSafeBottomPadding()
            }
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(isIncome ? L10n.CashFlowPlan.othersIncomeTitle : L10n.CashFlowPlan.othersTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
    }

    // MARK: - Description

    private var descriptionText: some View {
        let futureFixed = otherResult?.isFixedOnly ?? false
        return Text(futureFixed
            ? L10n.FlujoDetalleLinea.otrosNotaFutura(esIngreso: isIncome)
            : (isIncome ? L10n.CashFlowPlan.othersIncomeDesc : L10n.CashFlowPlan.othersDesc))
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Total

    /// «Total en diciembre  S/ 1,200»: la misma cifra que la fila del mes, y la suma de la lista de abajo.
    private func totalHeader(_ other: CashFlowOtherResult) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.FlujoDetalleLinea.otrosTotal(monthName))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: DS.Spacing.sm)
            AmountText(
                value: other.plannedAmount,
                currencyCode: currencyCode,
                font: DS.Typography.title.weight(.bold).monospacedDigit()
            )
            .accessibilityIdentifier("cashflow_others_total")
        }
        .accessibilityElement(children: .combine)
    }

    private var monthName: String {
        selectedMonth.map { CashFlowMonthSummaryLogic.monthInSentence($0.date) } ?? ""
    }

    // MARK: - Por subcategoría, agrupado por categoría

    private struct Grupo: Identifiable {
        let id: String
        let nombre: String
        let iconName: String
        let colorHex: String
        let items: [OtherSubcategoryItem]
        var total: Double { items.reduce(0) { $0 + $1.total } }
    }

    private func grupos(_ other: CashFlowOtherResult) -> [Grupo] {
        var orden: [String] = []
        var porCategoria: [String: [OtherSubcategoryItem]] = [:]
        for item in other.items {
            if porCategoria[item.categoryName] == nil { orden.append(item.categoryName) }
            porCategoria[item.categoryName, default: []].append(item)
        }
        return orden.map { nombre in
            let items = porCategoria[nombre] ?? []
            let muestra = items.first
            // La categoría de la proyección puede haberse borrado (otra pestaña, otro teléfono) sin recalcular aún: no se
            // lee borrada (card 1w89).
            let categoria = muestra?.category.flatMap { $0.isDeleted || $0.modelContext == nil ? nil : $0 }
            return Grupo(
                id: nombre, nombre: nombre,
                iconName: categoria?.iconName ?? muestra?.iconName ?? AppConstants.uncategorizedIconName,
                colorHex: categoria?.colorHex ?? muestra?.colorHex ?? AppConstants.uncategorizedColorHex,
                items: items
            )
        }.sorted { $0.total > $1.total }
    }

    @ViewBuilder
    private func subcategoryGroups(_ other: CashFlowOtherResult) -> some View {
        let lista = grupos(other)
        if lista.isEmpty {
            if other.isFixedOnly {
                Text(L10n.FlujoDetalleLinea.otrosFuturoVacio(esIngreso: isIncome))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("cashflow_others_future_empty")
            }
        } else {
            VStack(spacing: DS.Spacing.md) {
                ForEach(lista) { grupo in
                    groupCard(grupo, other: other)
                }
                if other.variableLeft > 0.005 {
                    variableRow(other.variableLeft)
                }
            }
        }
    }

    private func groupCard(_ grupo: Grupo, other: CashFlowOtherResult) -> some View {
        let plegada = plegadas.contains(grupo.id)
        return VStack(spacing: DS.Spacing.none) {
            Button {
                dsWithAnimation(reduceMotion, DS.Animation.appear) {
                    if plegada { plegadas.remove(grupo.id) } else { plegadas.insert(grupo.id) }
                }
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    categoryIcon(grupo.iconName, colorHex: grupo.colorHex)
                    Text(grupo.nombre)
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: DS.Spacing.sm)
                    AmountText(
                        value: grupo.total,
                        currencyCode: currencyCode,
                        font: DS.Typography.amountSmall.monospacedDigit()
                    )
                    Image(systemName: "chevron.down")
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(plegada ? -90 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("cashflow_others_group")

            if !plegada {
                ForEach(grupo.items) { item in
                    Divider().padding(.leading, DS.Spacing.xxl + 24)
                    itemRow(item, other: other)
                }
            }
        }
        .solidCard()
    }

    private func itemRow(_ item: OtherSubcategoryItem, other: CashFlowOtherResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                AdaptiveRowStack(spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(item.name)
                            .font(DS.Typography.body)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detalle = detalle(item, other: other) {
                            Text(detalle)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } trailing: {
                    AmountText(
                        value: item.total,
                        currencyCode: currencyCode,
                        font: DS.Typography.amountSmall.monospacedDigit()
                    )
                    .accessibilityIdentifier("cashflow_others_item_amount")
                }
                if item.canBecomeLine {
                    Button {
                        promote(item)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(theme.accentText)
                            .font(DS.Typography.headline)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.FlujoDetalleLinea.otrosAgregar(item.name))
                    .accessibilityIdentifier("cashflow_others_add")
                }
            }
            // En un mes que viene, cada partida fija se puede dejar de contar en los meses futuros.
            if other.isFixedOnly {
                ForEach(Array(item.fixedItems.enumerated()), id: \.offset) { _, fixed in
                    OthersConsiderToggle(
                        title: item.fixedItems.count == 1
                            ? L10n.FlujoDetalleLinea.otrosConsiderar
                            : "\(L10n.FlujoDetalleLinea.otrosConsiderar) · \(fixed.name)",
                        isOn: fixed.isConsideredInFuture,
                        onChange: { considerar(fixed, $0) }
                    )
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    /// Debajo del nombre: por qué es fijo, si es aislado, lo programado o lo anotado en la madre.
    private func detalle(_ item: OtherSubcategoryItem, other: CashFlowOtherResult) -> String? {
        var partes: [String] = []
        if item.kind == .parentWithoutSubcategory {
            partes.append(L10n.FlujoDetalleLinea.otrosMadre(item.categoryName))
        }
        if let fixed = item.fixedItems.first {
            if other.isFixedOnly && !fixed.isConsideredInFuture {
                partes.append(L10n.FlujoDetalleLinea.otrosNoConsiderado)
            } else {
                partes.append(L10n.FlujoDetalleLinea.otrosRazon(
                    dia: fixed.day, vistos: fixed.monthsSeen, de: fixed.monthsWindow
                ))
            }
        }
        if item.isolatedAmount > 0.005 {
            partes.append(L10n.FlujoDetalleLinea.otrosAislado)
        }
        if item.scheduledAmount > 0.005 {
            partes.append(L10n.FlujoDetalleLinea.otrosProgramado(
                appPreferences.currency(item.scheduledAmount, currencyCode: currencyCode)
            ))
        }
        return partes.isEmpty ? nil : partes.joined(separator: " · ")
    }

    /// «Lo variable que falta este mes»: la mediana menos lo que el mes ya tiene (solo el mes en curso, o sin plan).
    private func variableRow(_ amount: Double) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(L10n.FlujoDetalleLinea.otrosVariable)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: DS.Spacing.sm)
            AmountText(value: amount, currencyCode: currencyCode, font: DS.Typography.amountSmall.monospacedDigit())
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .solidCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cashflow_others_variable_row")
    }

    private func considerar(_ fixed: OtherFixedItem, _ on: Bool) {
        DS.Haptic.selection()
        FlujoFijosAFuturo.considerar(fixed.stableKey, on)
        // El flujo de caja recalcula con la revisión del plan (la hoja abierta enseña el total nuevo); el Panel, los
        // widgets y Tendencias, con `dataVersion`.
        viewModel.marcarPlanCambiado()
        if let ctx = viewModel.plan?.modelContext {
            CashFlowPlanViewModel.announcePlanChange(ctx)
        } else {
            SessionState.shared.incrementDataVersion()
        }
    }

    // MARK: - Lo proyectado sin línea

    /// Qué se proyecta como fijo, qué quedó fuera por aislado y cómo va el resto. En un mes cerrado no hay nada que
    /// explicar (no se proyecta), y sin historia suficiente se dice por qué aún no se detecta nada.
    @ViewBuilder
    private func projectionSections(_ other: CashFlowOtherResult) -> some View {
        let isPastMonth = selectedMonth?.isPast ?? false
        if !isPastMonth {
            if !other.detects, other.historyMonths > 0 {
                explanation(L10n.FlujoProyeccion.historiaCorta(meses: FlujoProyeccionInteligente.Umbrales.mesesMinimos))
                    .accessibilityIdentifier("cashflow_others_short_history")
            }
            if !other.fixedItems.isEmpty, other.items.isEmpty {
                section(
                    title: L10n.FlujoProyeccion.fijosTitulo,
                    description: L10n.FlujoProyeccion.fijosDescripcion(esIngreso: isIncome)
                ) {
                    ForEach(Array(other.fixedItems.enumerated()), id: \.offset) { index, item in
                        fixedRow(item)
                        if index < other.fixedItems.count - 1 { rowDivider }
                    }
                }
                .accessibilityIdentifier("cashflow_others_fixed_section")
            }
            if !other.isolatedItems.isEmpty {
                section(
                    title: L10n.FlujoProyeccion.aisladosTitulo,
                    description: L10n.FlujoProyeccion.aisladosDescripcion
                ) {
                    ForEach(Array(other.isolatedItems.enumerated()), id: \.offset) { index, item in
                        isolatedRow(item)
                        if index < other.isolatedItems.count - 1 { rowDivider }
                    }
                }
                .accessibilityIdentifier("cashflow_others_isolated_section")
            }
            if isIncome {
                explanation(L10n.FlujoProyeccion.variableIngresos)
            } else if other.variableEstimate > 0, !other.isFixedOnly {
                explanation(L10n.FlujoProyeccion.variableGastos(
                    appPreferences.currency(other.variableEstimate, currencyCode: currencyCode)
                ))
                .accessibilityIdentifier("cashflow_others_variable")
            }
        }
    }

    /// El mes elegido en la tira (el mismo que lee `otherResult`).
    private var selectedMonth: CashFlowMonth? {
        let months = viewModel.projection?.months ?? []
        return months.first { $0.monthKey == viewModel.selectedMonthKey }
            ?? months.first(where: \.isCurrent)
            ?? months.first
    }

    private func section<Content: View>(
        title: String, description: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.headline)
                .accessibilityAddTraits(.isHeader)
            Text(description)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: DS.Spacing.none) {
                content()
            }
            .solidCard()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, DS.Spacing.xxl + 24)
    }

    private func explanation(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fixedRow(_ item: OtherFixedItem) -> some View {
        let amount = appPreferences.currency(item.monthlyAmount, currencyCode: currencyCode)
        let cadence = item.day.map { L10n.FlujoProyeccion.fijoConDia(amount, dia: $0) }
            ?? L10n.FlujoProyeccion.fijoAlMes(amount)
        // «Ya llegó» solo con el dinero dentro: un pago planificado pendiente o un fechado también dejan la falta en 0.
        let isDone = (selectedMonth?.isCurrent ?? false) && FlujoProyeccionInteligente.yaLlego(
            item.receivedAmount, de: item.monthlyAmount
        )
        let estado = isDone
            ? L10n.FlujoProyeccion.fijoYaEsta(esIngreso: isIncome)
            : L10n.FlujoProyeccion.fijoVisto(item.monthsSeen, de: item.monthsWindow)
        let detail = item.groupName.map { "\($0) · \(estado)" } ?? estado
        return AdaptiveRowStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                categoryIcon(item.iconName, colorHex: item.colorHex)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(item.name)
                        .font(DS.Typography.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } trailing: {
            Text(cadence)
                .font(DS.Typography.amountSmall.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier("cashflow_others_fixed_amount")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .accessibilityElement(children: .combine)
    }

    private func isolatedRow(_ item: OtherIsolatedItem) -> some View {
        AdaptiveRowStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                categoryIcon(item.iconName, colorHex: item.colorHex)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(item.name)
                        .font(DS.Typography.body)
                        .fixedSize(horizontal: false, vertical: true)
                    let mes = item.month.formatted(Date.FormatStyle().month(.wide).year().locale(AppLocale.current))
                    Text(item.groupName.map { "\($0) · \(mes)" } ?? mes)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } trailing: {
            AmountText(
                value: item.amount,
                currencyCode: currencyCode,
                font: DS.Typography.amountSmall.monospacedDigit()
            )
            .accessibilityIdentifier("cashflow_others_isolated_amount")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .accessibilityElement(children: .combine)
    }

    private func categoryIcon(_ name: String, colorHex: String) -> some View {
        Image(systemName: name)
            .font(DS.Typography.body)
            .foregroundStyle(Color(hex: colorHex))
            .frame(width: DS.Icon.badgeSmall)
            .accessibilityHidden(true)
    }

    // MARK: - Hint

    private var hintText: some View {
        Text(isIncome ? L10n.CashFlowPlan.othersIncomeHint : L10n.CashFlowPlan.othersHint)
            .font(DS.Typography.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Promote

    /// El + de una fila: la subcategoría entra al plan (o la categoría, si no tiene subcategorías). Nunca la categoría
    /// entera cuando tiene subcategorías: perdería el detalle (regla del replanteo).
    private func promote(_ item: OtherSubcategoryItem) {
        switch item.kind {
        case .subcategory:
            guard let sub = item.subcategory, !sub.isDeleted, sub.modelContext != nil else { return }
            viewModel.promoteSubcategory(sub, isIncome: isIncome)
        case .categoryWithoutSubcategories:
            guard let category = item.category, !category.isDeleted, category.modelContext != nil else { return }
            viewModel.promoteFromOthers(category)
        case .parentWithoutSubcategory, .uncategorized:
            return
        }
        viewModel.marcarPlanCambiado()
        DS.Haptic.success()
        dismiss()
    }
}

extension CashFlowPlanViewModel {

    /// Agrega una subcategoría al plan desde «no considerados», con su promedio de 6 meses (que se mueve solo). Si ya
    /// tiene línea (criterio del motor, `FlujoLineasSinDuplicar`), no hace nada.
    func promoteSubcategory(_ sub: Subcategory, isIncome: Bool) {
        guard let plan, let ctx = plan.modelContext, !sub.isDeleted else { return }
        let lines = plan.lines ?? []
        let esIngreso = sub.category?.isIncome ?? isIncome
        guard !FlujoLineasSinDuplicar.yaEnElPlan(
            categoria: sub.category, subcategoria: sub, esIngreso: esIngreso, lineas: lines
        ) else { return }
        let line = CashFlowLine(
            name: sub.name, isIncome: esIngreso,
            sortOrder: (lines.map(\.sortOrder).max() ?? 0) + 1, estimationMethod: .average6m,
            category: sub.category, subcategory: sub
        )
        ctx.insert(line)
        line.plan = plan
        do {
            try ctx.save()
            Self.announcePlanChange(ctx)
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error agregando la subcategoría: \(error)")
            #endif
        }
    }
}

/// «Considerar a futuro» de una partida fija. Lleva su propio estado (sin `Binding(get:set:)` en el `body`,
/// `swiftui-ds.md`) y avisa del cambio; el cálculo vuelve a leer lo guardado.
private struct OthersConsiderToggle: View {
    let title: String
    let onChange: (Bool) -> Void
    @State private var isOn: Bool
    @Environment(\.yalaTheme) private var theme

    init(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.title = title
        self.onChange = onChange
        _isOn = State(initialValue: isOn)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .tint(theme.accent)
        .onChange(of: isOn) { _, nuevo in onChange(nuevo) }
        .accessibilityIdentifier("cashflow_others_consider")
    }
}
