//
//  CashFlowOthersSheet.swift
//  Yala
//
//  Sheet showing breakdown of "other expenses" categories not assigned to any line.
//  Desde el 19-nov-2026 dice también qué se proyecta como fijo y qué se dejó fuera por aislado
//  (`FlujoProyeccionInteligente`), con los textos en su propia tabla (`L10n.FlujoProyeccion`).
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
    @State private var selectedDetent: PresentationDetent = .medium

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
                    descriptionText
                    if let other = otherResult {
                        if !other.categoryBreakdown.isEmpty {
                            categoryList(other)
                        }
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
        Text(isIncome ? L10n.CashFlowPlan.othersIncomeDesc : L10n.CashFlowPlan.othersDesc)
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Category List

    private func categoryList(_ other: CashFlowOtherResult) -> some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(other.categoryBreakdown, id: \.categoryName) { item in
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: item.iconName)
                        .font(DS.Typography.body)
                        .foregroundStyle(Color(hex: item.colorHex))
                        .frame(width: DS.Icon.badgeSmall)

                    Text(item.categoryName)
                        .font(DS.Typography.body)

                    Spacer()

                    AmountText(
                        value: item.amount,
                        currencyCode: currencyCode,
                        font: DS.Typography.amountSmall.monospacedDigit()
                    )
                    .accessibilityIdentifier("cashflow_others_item_amount")

                    Button {
                        promoteCategory(named: item.categoryName)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(theme.accentText)
                            .font(DS.Typography.headline)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)

                if item.categoryName != other.categoryBreakdown.last?.categoryName {
                    Divider()
                        .padding(.leading, DS.Spacing.xxl + 24)
                }
            }
        }
        .solidCard()
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
            if !other.fixedItems.isEmpty {
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
            } else if other.variableEstimate > 0 {
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

    private func promoteCategory(named name: String) {
        guard let ctx = viewModel.plan?.modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Category>()
            let categories = try ctx.fetch(descriptor)
            if let category = categories.first(where: { $0.name == name && $0.isIncome == isIncome }) {
                viewModel.promoteFromOthers(category)
                dismiss()
            }
        } catch {
            #if DEBUG
            print("CashFlowOthersSheet: Error fetching category: \(error)")
            #endif
        }
    }
}
