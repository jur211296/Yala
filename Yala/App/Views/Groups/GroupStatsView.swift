//
//  GroupStatsView.swift
//  Yala
//
//  Estadísticas dentro de un grupo: totales, quién paga más, categorías, tendencia.
//

import SwiftUI
import Charts
import SwiftData

struct GroupStatsView: View {

    let expenses: [SplitExpense]
    let shares: [SplitShare]
    let members: [SplitMember]
    let settlements: [SplitSettlement]
    let currentUserMemberID: String?
    let currencyCode: String

    @State private var viewModel = GroupStatsViewModel()
    /// Moneda activa del carrusel del modo "Todas" (currencyCode de la página visible).
    @State private var allCurrenciesPage: String = ""
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        if expenses.isEmpty {
            YalaEmptyState(
                icon: "chart.pie",
                title: L10n.Groups.Stats.noExpenses
            )
        } else {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    statsSelectors
                    summaryCards
                    if viewModel.isAllCurrencies {
                        allCurrenciesContent
                    } else {
                        singleCurrencyContent
                    }
                }
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .scrollViewGlassEdges()
            .onAppear { loadStats() }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.recalculate()
                syncCarouselPage()
            }
            .onChange(of: viewModel.currencySelection) { _, _ in
                viewModel.recalculate()
                syncCarouselPage()
            }
        }
    }

    // MARK: - Content (moneda única vs "Todas")

    /// Modo `.currency`: layout clásico de una sola moneda.
    @ViewBuilder
    private var singleCurrencyContent: some View {
        if !viewModel.memberSpending.isEmpty {
            memberBarChart(spending: viewModel.memberSpending, currencyCode: viewModel.activeCurrencyCode)
        }
        categorySection
        if viewModel.monthlyTrend.count >= 2 {
            monthlyTrendChart(trend: viewModel.monthlyTrend)
        }
    }

    /// Modo `.all`: donut convertido (arriba) + carrusel con una página por moneda.
    @ViewBuilder
    private var allCurrenciesContent: some View {
        categorySection
        if !viewModel.perCurrencyStats.isEmpty {
            allCurrenciesCarousel
        }
    }

    /// Donut de categorías o, si todo está sin clasificar, el hint. Compartido por ambos modos.
    @ViewBuilder
    private var categorySection: some View {
        if viewModel.allUncategorized {
            uncategorizedHint
        } else if !viewModel.categoryBreakdown.isEmpty {
            categoryPieChart
        }
    }

    // MARK: - Selectors (moneda + período, estilo menú)

    private var statsSelectors: some View {
        HStack(spacing: DS.Spacing.sm) {
            if viewModel.availableCurrencies.count > 1 {
                currencyMenu
            }
            periodMenu
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    private var currencyMenu: some View {
        Menu {
            Button {
                viewModel.currencySelection = .all
            } label: {
                HStack {
                    Text(L10n.Common.all)
                    if viewModel.isAllCurrencies {
                        Image(systemName: "checkmark").accessibilityHidden(true)
                    }
                }
            }
            ForEach(viewModel.availableCurrencies, id: \.self) { code in
                Button {
                    viewModel.currencySelection = .currency(code)
                } label: {
                    HStack {
                        Text(currencyLabel(code))
                        if viewModel.selectedCurrencyCode == code {
                            Image(systemName: "checkmark").accessibilityHidden(true)
                        }
                    }
                }
            }
        } label: {
            statsMenuLabel(icon: nil, text: currencyMenuLabelText)
        }
    }

    /// Texto del botón del menú de moneda ("Todas" o el símbolo/código de la seleccionada).
    private var currencyMenuLabelText: String {
        guard let code = viewModel.selectedCurrencyCode else { return L10n.Common.all }
        return currencyLabel(code)
    }

    private var periodMenu: some View {
        Menu {
            ForEach(GroupStatsPeriod.allCases) { period in
                Button {
                    viewModel.selectedPeriod = period
                } label: {
                    HStack {
                        Text(period.displayName)
                        if viewModel.selectedPeriod == period {
                            Image(systemName: "checkmark").accessibilityHidden(true)
                        }
                    }
                }
            }
        } label: {
            statsMenuLabel(icon: "calendar", text: viewModel.selectedPeriod.displayName)
        }
    }

    private func statsMenuLabel(icon: String?, text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon).font(DS.Typography.labelSmall)
            }
            Text(text).font(DS.Typography.labelSmall)
            Image(systemName: "chevron.down").font(DS.Typography.labelTiny)
        }
        .foregroundStyle(.thPrimaryText)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(Capsule())
        .fixedSize()
    }

    /// Símbolo o código de la moneda según la preferencia del usuario.
    private func currencyLabel(_ code: String) -> String {
        switch appPreferences.currencyDisplayFormat {
        case .symbol: return CurrencyCode.symbol(for: code)
        case .code: return code
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            summaryCard(
                title: L10n.Groups.Stats.totalSpent,
                amounts: viewModel.totalsByCurrency,
                color: .primary
            )

            summaryCard(
                title: L10n.Groups.Stats.myPortion,
                amounts: viewModel.myPortionsByCurrency.map { (currencyCode: $0.currencyCode, total: $0.amount) },
                color: theme.accent
            )
        }
    }

    /// Tarjeta de resumen: un monto por moneda apilado (todas las monedas del período).
    private func summaryCard(title: String, amounts: [(currencyCode: String, total: Double)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            if amounts.isEmpty {
                Text(appPreferences.currency(0, currencyCode: viewModel.activeCurrencyCode))
                    .font(DS.Typography.headline)
                    .foregroundStyle(color)
            } else {
                ForEach(amounts, id: \.currencyCode) { entry in
                    Text(appPreferences.currency(entry.total, currencyCode: entry.currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
    }

    // MARK: - Member Bar Chart (Who Pays Most)

    private func memberBarChart(spending: [MemberSpending], currencyCode: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Stats.whoMadeMostPayments)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            Chart(spending) { member in
                BarMark(
                    x: .value("amount", member.totalPaid),
                    y: .value("member", member.displayName)
                )
                .foregroundStyle(theme.accent.gradient)
                .cornerRadius(DS.Radius.xs)
                .annotation(position: .trailing) {
                    // El contenido de `.annotation` se hostea fuera del árbol de
                    // la vista y no propaga environment objects @Observable, así
                    // que aquí NO se puede usar `AmountText` (lee
                    // `@Environment(AppPreferences.self)`). Se formatea con el
                    // `appPreferences` ya resuelto de la vista y el `currencyCode`
                    // recibido como parámetro — mismo patrón que el resto de la app.
                    Text(appPreferences.currency(member.totalPaid, currencyCode: currencyCode))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("\(member.displayName): \(appPreferences.currency(member.totalPaid, currencyCode: currencyCode))")
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(DS.Typography.caption)
                }
            }
            .frame(height: CGFloat(max(spending.count, 1)) * 44)
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
        }
    }

    // MARK: - Uncategorized Hint (placeholder en vez del pie chart de 1 segmento)

    private var uncategorizedHint: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.pie")
                .font(DS.Typography.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(L10n.Groups.Stats.assignCategoriesHint)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, DS.Spacing.xl)
        .frame(maxWidth: .infinity)
        .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
    }

    // MARK: - Category Pie Chart

    private var categoryPieChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Stats.categories)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            // Modo "Todas": el donut convierte todas las monedas a la preferida del
            // usuario (es porcentual, no puede mezclar). La nota lo comunica con "≈".
            if viewModel.categoriesWereConverted {
                Text(L10n.Groups.Stats.convertedToNote(currencyLabel(viewModel.targetCurrency)))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .padding(.leading, DS.Spacing.sm)
            }

            DonutChartView(slices: categorySlices)
                .frame(height: 260) // A11Y-DT: fixed chart height for consistent layout
                .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
        }
    }

    /// Mapea el desglose por subcategoría al slice genérico del donut compartido.
    private var categorySlices: [DonutSlice] {
        viewModel.categoryBreakdown.map { cat in
            DonutSlice(
                id: cat.subcategoryName,
                name: cat.subcategoryName,
                iconName: cat.iconName,
                colorHex: cat.colorHex,
                amount: cat.amount,
                percentage: cat.percentage
            )
        }
    }

    // MARK: - Monthly Trend

    private func monthlyTrendChart(trend: [GroupMonthlyTrend]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Stats.monthlyTrend)
                .font(DS.Typography.headline)
                .padding(.leading, DS.Spacing.sm)

            Chart(trend) { point in
                LineMark(
                    x: .value("month", point.month, unit: .month),
                    y: .value("amount", point.totalSpent)
                )
                .foregroundStyle(theme.accent)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("month", point.month, unit: .month),
                    y: .value("amount", point.totalSpent)
                )
                .foregroundStyle(theme.accent.opacity(0.15))
                .interpolationMethod(.catmullRom)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .font(DS.Typography.captionSmall)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                        .font(DS.Typography.captionSmall)
                }
            }
            .frame(height: 180) // A11Y-DT: fixed chart height for consistent layout
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.xl)
        }
    }

    // MARK: - All Currencies Carousel

    /// Carrusel del modo "Todas": una página por moneda con su "quién paga" + su tendencia.
    /// Ambos gráficos viven en la misma página → la moneda nunca se desincroniza.
    private var allCurrenciesCarousel: some View {
        VStack(spacing: DS.Spacing.md) {
            TabView(selection: $allCurrenciesPage) {
                ForEach(viewModel.perCurrencyStats) { stat in
                    VStack(spacing: DS.Spacing.xxl) {
                        memberBarChart(spending: stat.memberSpending, currencyCode: stat.currencyCode)
                        if stat.monthlyTrend.count >= 2 {
                            monthlyTrendChart(trend: stat.monthlyTrend)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DS.Spacing.xxs)
                    .tag(stat.currencyCode)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: carouselHeight)

            if viewModel.perCurrencyStats.count > 1 {
                currencyPageDots
            }
        }
    }

    /// Indicadores de página (una cápsula por moneda). Patrón de `CategoriesTabView`.
    private var currencyPageDots: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(viewModel.perCurrencyStats) { stat in
                let isActive = allCurrenciesPage == stat.currencyCode
                Capsule()
                    .fill(isActive ? theme.primaryText.opacity(0.6) : theme.secondaryText.opacity(0.25))
                    .frame(width: isActive ? 18 : 6, height: 3)
                    .contentShape(Rectangle().inset(by: -8))
                    .onTapGesture {
                        DS.Haptic.selection()
                        dsWithAnimation(reduceMotion) { allCurrenciesPage = stat.currencyCode }
                    }
                    .accessibilityLabel(currencyLabel(stat.currencyCode))
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Altura del carrusel = la página más alta (cada página alinea su contenido
    /// arriba con un `Spacer`), para que deslizar no cause saltos verticales.
    /// Estimación holgada: cada chart tiene altura fija (filas×44 / 180) + `chartChrome`
    /// para el título `headline`, el padding del `solidCard` y el `spacing` del VStack,
    /// con colchón para Dynamic Type. `.page` no scrollea si se queda corto → validar AX5
    /// en device-QA.
    private var carouselHeight: CGFloat {
        let chartChrome: CGFloat = 110
        let heights = viewModel.perCurrencyStats.map { stat -> CGFloat in
            let memberBlock = CGFloat(max(stat.memberSpending.count, 1)) * 44 + chartChrome
            let trendBlock: CGFloat = stat.monthlyTrend.count >= 2 ? (180 + chartChrome) : 0
            return memberBlock + trendBlock
        }
        return heights.max() ?? 300
    }

    // MARK: - Helpers

    private func loadStats() {
        viewModel.setContext(modelContext)
        viewModel.loadStats(
            expenses: expenses,
            shares: shares,
            members: members,
            settlements: settlements,
            currentUserMemberID: currentUserMemberID,
            currencyCode: currencyCode,
            preferredCurrency: appPreferences.defaultCurrencyCode.rawValue
        )
        syncCarouselPage()
    }

    /// Mantiene la página del carrusel en una moneda válida tras cambiar período/moneda.
    private func syncCarouselPage() {
        let codes = viewModel.perCurrencyStats.map(\.currencyCode)
        if !codes.contains(allCurrenciesPage) {
            allCurrenciesPage = codes.first ?? ""
        }
    }
}
