//
//  WidgetInfoSheet.swift
//  Yala
//
//  Sheet pedagógica para widgets del Panel. Solo explica (UX 2.2 · L3-7, opción B): el selector de tamaño y su
//  botón de guardar salieron de aquí —quien venía a entender acababa cambiando el widget— y el tamaño se cambia en
//  el menú de cuadrícula de la sección (`PanelSectionPreferencesSheet`). Arriba, una línea con los números de la
//  persona cuando el widget tiene un dato que contar.
//

import SwiftUI

struct WidgetInfoSheet<Preview: View>: View {
    let kind: WidgetInfoKind
    /// `nil` cuando se invoca fuera del Panel — el sheet omite el segmented
    /// de tamaño, la preview interactiva y el botón Save; muestra solo
    /// chips + Q&A. En el Panel el VM se usa para leer/persistir el tamaño.
    var viewModel: PanelViewModel? = nil
    @ViewBuilder let previewContent: (WidgetSize) -> Preview

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    /// El tamaño con el que el widget está hoy en el Panel: la vista previa lo enseña así.
    @State private var shownSize: WidgetSize = .small
    @State private var contentWidth: CGFloat = 0

    private var content: WidgetInfoContent { .content(for: kind) }
    private var widgetType: WidgetType? { kind.widgetType }
    /// La vista previa y la línea con sus números solo aplican cuando el kind mapea a un WidgetType del Panel y se
    /// pasó un viewModel.
    private var isInPanel: Bool { viewModel != nil && widgetType != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    if isInPanel {
                        previewBox
                    }
                    if let personalLine {
                        yourDataBlock(personalLine)
                    }
                    chipsRow
                    sectionsBlock
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
                    contentWidth = width
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Fuera del Panel iOS pinta su glass nativo del sheet (sin gradient
            // propio); en el Panel se mantiene el `PanelBackgroundView`.
            .yalaScreenBackground(isInPanel ? .subtle : .transparent)
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(
                        systemName: "xmark",
                        label: L10n.Accessibility.close
                    ) {
                        dismiss()
                    }
                    .accessibilityIdentifier("widget_info_close")
                }
            }
        }
        // Panel necesita `.large` (preview). Fuera (chips + Q&A) entra en `.medium`.
        .presentationDetents(isInPanel ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
        .task(id: kind) {
            // La vista previa enseña el widget con el tamaño que tiene hoy en el Panel. Fuera del Panel
            // (viewModel == nil o kind sin widgetType), no hay tamaño que cargar.
            guard let viewModel, let widgetType else { return }
            shownSize = viewModel.widgetSize(widgetType)
        }
        // Sin nada que guardar, la hoja siempre está «limpia»: una foto compartida puede cerrarla.
        .modifier(PanelWidgetInfoSharedPhotoClose(
            isInPanelWindow: viewModel != nil,
            isClean: true,
            dismiss: { dismiss() }
        ))
    }

    /// Small se renderiza al ~50% del ancho disponible para emular la
    /// apariencia half-pair del grid del Panel; medium/large ocupan ancho
    /// completo. `.allowsHitTesting(false)` centraliza el invariante "preview
    /// no acepta gestos" — sin esto, taps filtrarían el Panel real por debajo.
    @ViewBuilder
    private var previewBox: some View {
        let isSmall = shownSize == .small
        let smallWidth = max(0, contentWidth * 0.5)
        ZStack {
            previewContent(shownSize)
                .environment(\.isWidgetPreviewMode, true)
                .environment(appPreferences)
                .frame(width: isSmall && smallWidth > 0 ? smallWidth : nil)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: kind.previewBoxHeight)
    }

    @ViewBuilder
    private var chipsRow: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            ForEach(content.chips(shownSize)) { chip in
                WidgetInfoChipView(chip: chip)
            }
        }
    }

    @ViewBuilder
    private var sectionsBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(content.sections(shownSize)) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(section.question)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(section.answer)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Con tus datos (UX 2.2 · L3-7, opción B)

    private func yourDataBlock(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Panel.WidgetInfo.YourData.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("widget_info_your_data")
    }

    /// Lo que el widget dice HOY con los datos de la persona, o `nil` si no hay un dato que contar (sin movimientos,
    /// o un widget cuya ayuda genérica ya basta).
    private var personalLine: String? {
        guard let viewModel, isInPanel else { return nil }
        let currency = viewModel.defaultCurrencyCode
        // La marca de aproximado viaja con el número, como en el resto del Panel.
        func money(_ value: Double, isEstimate: Bool = false) -> String {
            appPreferences.currency(value, currencyCode: currency, isEstimate: isEstimate)
        }
        switch kind {
        case .trend:
            guard !viewModel.accounts.isEmpty else { return nil }
            return L10n.Panel.WidgetInfo.YourData.trend(
                money(viewModel.panelTotalBalance, isEstimate: viewModel.panelTotalBalanceIsApproximate)
            )
        case .cashFlow:
            let period = viewModel.heroPeriodWidget
            guard period.income != 0 || period.expense != 0 else { return nil }
            return L10n.Panel.WidgetInfo.YourData.cashFlow(
                income: money(period.income, isEstimate: period.incomeApproximate),
                expense: money(period.expense, isEstimate: period.expenseApproximate)
            )
        case .categoriesPie, .topCategories:
            guard let top = viewModel.categoriesWidget.topSpendingCategories.first, top.amount != 0 else { return nil }
            return L10n.Panel.WidgetInfo.YourData.topSpending(name: top.category.name, amount: money(abs(top.amount)))
        case .subcategoriesPie, .topSubcategories:
            guard let top = viewModel.subcategoriesWidget.topSubcategories.first, top.amount != 0 else { return nil }
            return L10n.Panel.WidgetInfo.YourData.topSpending(name: top.subcategoryName, amount: money(abs(top.amount)))
        case .tagsPie:
            guard let top = viewModel.tagsWidget.topTags.first, top.amount != 0 else { return nil }
            return L10n.Panel.WidgetInfo.YourData.topTag(name: top.tag.name, amount: money(abs(top.amount)))
        case .scheduledPayments:
            let data = viewModel.scheduledPaymentsWidget
            guard data.activeCount > 0 else { return nil }
            return L10n.Panel.WidgetInfo.YourData.scheduled(total: money(data.monthlyTotal), pending: data.pendingCount)
        case .weekdayBar:
            guard let top = viewModel.weekdayWidget.weekdaySpending.max(by: { $0.average < $1.average }),
                  top.average > 0 else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = AppLocale.current
            let symbols = calendar.weekdaySymbols
            guard (1...symbols.count).contains(top.weekday) else { return nil }
            return L10n.Panel.WidgetInfo.YourData.weekday(symbols[top.weekday - 1])
        case .budgets, .recentRecords, .exchangeRate, .expensesByNeed, .periodComparison, .sankey:
            return nil
        }
    }
}

/// El «?» de un widget del Panel se cierra solo si llega una foto compartida y no hay un tamaño cambiado por guardar
/// (`SharedPhotoPanelSheetLogic`). Publica si está abierto y sin cambios (`SceneNavigation.isCleanPanelWidgetInfoVisible`)
/// y atiende la petición de cierre de `PanelShell`. Fuera del Panel (Estadísticas) no hace nada: esa hoja es de otra
/// pestaña y espera.
private struct PanelWidgetInfoSharedPhotoClose: ViewModifier {
    let isInPanelWindow: Bool
    let isClean: Bool
    let dismiss: () -> Void
    @Environment(SceneNavigation.self) private var navigation

    func body(content: Content) -> some View {
        content
            .onChange(of: isClean, initial: true) { _, clean in publish(clean) }
            .onChange(of: navigation.panelWidgetInfoCloseRequest) { _, _ in closeIfClean() }
            .onDisappear { if isInPanelWindow { navigation.isCleanPanelWidgetInfoVisible = false } }
    }

    private func publish(_ clean: Bool) {
        guard isInPanelWindow else { return }
        navigation.isCleanPanelWidgetInfoVisible = clean
    }

    private func closeIfClean() {
        guard isInPanelWindow, isClean else { return }
        dismiss()
    }
}
