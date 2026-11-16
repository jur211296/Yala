//
//  GroupStatsView.swift
//  Yala
//
//  Estadísticas dentro de un grupo: totales, quién paga más, categorías, tendencia.
//

import SwiftUI
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
    /// Fecha enfocada (scrub) de la gráfica de tendencia en modo moneda única.
    @State private var trendFocusedDate: Date?
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var memberBarHeight: CGFloat = 16 // A11Y-DT: @ScaledMetric
    /// Alto medido de cada página del carrusel de «Todas» (lote 06 de mejoras 2.3): con filas de texto, la estimación
    /// fija se quedaba corta con texto grande y cortaba la página.
    @State private var carouselPageHeights: [String: CGFloat] = [:]
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
                VStack(spacing: DS.Spacing.lg) {
                    statsHero
                    if viewModel.isAllCurrencies {
                        allCurrenciesContent
                    } else {
                        singleCurrencyContent
                    }
                }
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.safeBottom)
                // Ventana ancha: las estadísticas del grupo a 700 pt, centradas (decisión 7 de la revisión 2.3).
                .readableColumn()
            }
            .scrollViewGlassEdges()
            .onAppear { loadStats() }
            .onDisappear { viewModel.cancelRecalculation() }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                // Debounced: coalesce swipes rápidos del carrusel de período.
                viewModel.scheduleRecalculate()
                trendFocusedDate = nil
            }
            .onChange(of: viewModel.currencySelection) { _, _ in
                viewModel.scheduleRecalculate()
                trendFocusedDate = nil
            }
            // El carrusel se re-sincroniza cuando el set de monedas cambia — DESPUÉS de que el
            // recalculate (debounced) actualice `perCurrencyStats`, NO antes (leería códigos stale
            // y podría dejar `allCurrenciesPage` apuntando a una página inválida por 150ms+).
            .onChange(of: viewModel.perCurrencyStats.map(\.currencyCode)) { _, _ in
                syncCarouselPage()
            }
        }
    }

    // MARK: - Content (moneda única vs "Todas")

    /// Modo `.currency`: una sola moneda. Orden: quién paga → tendencia → distribución.
    @ViewBuilder
    private var singleCurrencyContent: some View {
        currencyPeriodHeader(currencyCode: viewModel.activeCurrencyCode)
        if !viewModel.memberSpending.isEmpty {
            memberBarChart(spending: viewModel.memberSpending, currencyCode: viewModel.activeCurrencyCode)
        }
        if let trendInput = GroupTrendChartAdapter.makeInput(from: viewModel.monthlyTrend) {
            monthlyTrendChart(input: trendInput, currencyCode: viewModel.activeCurrencyCode, focusedDate: $trendFocusedDate)
        }
        categorySection
    }

    /// Modo `.all`: carrusel por moneda (quién paga → tendencia) + donut convertido al final.
    @ViewBuilder
    private var allCurrenciesContent: some View {
        if !viewModel.perCurrencyStats.isEmpty {
            allCurrenciesCarousel
        }
        categorySection
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

    // MARK: - Selectores (moneda + período, con la cápsula de Estadísticas)

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
            PeriodSelectorLabel(title: currencyMenuLabelText, icon: nil)
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
            PeriodSelectorLabel(title: viewModel.selectedPeriod.displayName)
        }
    }

    /// Símbolo o código de la moneda según la preferencia del usuario.
    private func currencyLabel(_ code: String) -> String {
        switch appPreferences.currencyDisplayFormat {
        case .symbol: return CurrencyCode.symbol(for: code)
        case .code: return code
        }
    }

    // MARK: - Hero (lienzo «Una sola Yala», 4A)

    /// La cabecera de Estadísticas: «Total gastado» con la cápsula del período a su derecha (y la de divisa, solo si el
    /// grupo tiene más de una), la cifra de 36 pt y debajo lo tuyo. Antes, dos menús propios y dos tarjetas.
    private var statsHero: some View {
        HeroHeader {
            HeroHeaderLabel(text: L10n.Groups.Stats.totalSpent)
        } period: {
            HStack(spacing: DS.Spacing.sm) {
                if viewModel.availableCurrencies.count > 1 {
                    currencyMenu
                }
                periodMenu
            }
        } content: {
            let totals = viewModel.totalsByCurrency
            if let first = totals.first {
                heroAmount(first.total, currencyCode: first.currencyCode)
            } else {
                heroAmount(0, currencyCode: viewModel.activeCurrencyCode)
            }
            if totals.count > 1 {
                Text("+ " + totals.dropFirst()
                    .map { appPreferences.currency($0.total, currencyCode: $0.currencyCode) }
                    .joined(separator: " + "))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            myPortionLine
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_stats_hero")
    }

    private func heroAmount(_ value: Double, currencyCode: String) -> some View {
        AmountText(
            value: value,
            currencyCode: currencyCode,
            font: DS.Typography.panelHeroAmount,
            secondaryFont: DS.Typography.panelHeroAmountSecondary,
            forceFullPrecision: true
        )
    }

    /// «Mi parte: S/ 410.00 + $ 123.34», con «lo que te tocaba» debajo (UX 2.2 · L13-13: no es lo que pagaste).
    @ViewBuilder
    private var myPortionLine: some View {
        let portions = viewModel.myPortionsByCurrency
        if !portions.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.none) {
                Text("\(L10n.Groups.Stats.myPortion): " + portions
                    .map { appPreferences.currency($0.amount, currencyCode: $0.currencyCode) }
                    .joined(separator: " + "))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                Text(L10n.Groups.Stats.myPortionHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Section header (patrón del resto de la app: título externo al card)

    /// El título de sección de la app (`YalaSectionHeader`), sobre la tarjeta.
    private func sectionHeader(_ title: String) -> some View {
        YalaSectionHeader(title)
            .accessibilityAddTraits(.isHeader)
    }

    /// Encabezado de contexto: identifica la moneda y el período activos. Da
    /// claridad en moneda única y, sobre todo, en cada página del carrusel del
    /// modo "Todas" (saber qué moneda es cada página). El nombre usa el mismo
    /// patrón que el carrusel multimoneda de `TrendsTabView`.
    private func currencyPeriodHeader(currencyCode: String) -> some View {
        let name = Locale.current.localizedString(forCurrencyCode: currencyCode)?.capitalized ?? currencyCode
        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text("\(name) (\(currencyLabel(currencyCode)))")
                .font(DS.Typography.title3)
                .foregroundStyle(.thPrimaryText)
            Text(viewModel.selectedPeriod.displayName)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Member Bar Chart (Who Pays Most)

    /// Una fila por persona: el nombre arriba y, debajo, la barra con el importe al final. Lote 06 de mejoras 2.3: era
    /// una gráfica con 44 pt fijos por persona y la barra pasaba por encima del nombre, también a tamaño normal; con
    /// filas, el alto lo da el texto.
    private func memberBarChart(spending: [MemberSpending], currencyCode: String) -> some View {
        let top = spending.map(\.totalPaid).max() ?? 0
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(L10n.Groups.Stats.whoMadeMostPayments)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ForEach(spending) { member in
                    memberRow(member, ratio: top > 0 ? member.totalPaid / top : 0, currencyCode: currencyCode)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panelCard()
        }
    }

    private func memberRow(_ member: MemberSpending, ratio: Double, currencyCode: String) -> some View {
        let amount = appPreferences.currency(member.totalPaid, currencyCode: currencyCode)
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(member.displayName)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if dynamicTypeSize.isAccessibilitySize {
                // Con texto de accesibilidad el importe baja a su línea (regla de `swiftui-ds.md`).
                memberBar(ratio: ratio)
                memberAmount(amount)
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    memberBar(ratio: ratio)
                    memberAmount(amount)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(member.displayName): \(amount)")
        .accessibilityIdentifier("group_stats_who_paid_row")
    }

    /// La barra se dibuja en el `overlay` de su carril, que es lo que se mide (regla del iPhone Duo de `swiftui-ds.md`).
    private func memberBar(ratio: Double) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: memberBarHeight)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                        .fill(theme.accent)
                        .frame(width: max(proxy.size.width * ratio, memberBarHeight / 2))
                }
            }
            .accessibilityHidden(true)
    }

    private func memberAmount(_ amount: String) -> some View {
        Text(amount)
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize()
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
        .panelCard()
    }

    // MARK: - Category Pie Chart

    private var categoryPieChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(L10n.Groups.Stats.categories)

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Modo "Todas": el donut convierte todas las monedas a la preferida del
                // usuario (es porcentual, no puede mezclar). La nota lo comunica con "≈".
                if viewModel.categoriesWereConverted {
                    Text(L10n.Groups.Stats.convertedToNote(currencyLabel(viewModel.targetCurrency)))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }

                DonutChartView(slices: categorySlices)
                    .frame(height: 260) // A11Y-DT: fixed chart height for consistent layout
            }
            .panelCard()
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

    // MARK: - Monthly Trend (TrendChartView compartido — diseño y hover idénticos)

    /// Tendencia mensual de gastos. Reutiliza `TrendChartView` (el de la pestaña
    /// Tendencias) para que la línea, el área, los ejes y el hover/tooltip sean
    /// idénticos al resto de la app. `showTodayIndicators: false` porque un
    /// histórico de grupo no tiene saldo vivo. En el carrusel multimoneda
    /// `focusedDate` es `.constant(nil)` (el scrub chocaría con el swipe de página).
    /// `scrubbable: false` (carrusel) desactiva el hit-testing del chart para que
    /// el `chartXSelection` no capture el swipe horizontal del `TabView .page`
    /// (no hay scrub en el carrusel — `focusedDate` es `.constant(nil)`).
    private func monthlyTrendChart(
        input: GroupTrendChartAdapter.Input,
        currencyCode: String,
        focusedDate: Binding<Date?>,
        scrubbable: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(L10n.Groups.Stats.monthlyTrend)

            TrendChartView(
                trendPoints: input.points,
                rawPoints: input.points,
                yDomain: input.yDomain,
                grouping: .month,
                interval: input.interval,
                currencyCode: currencyCode,
                trendType: .expense,
                focusedDate: focusedDate,
                period: .allTime,
                chartHeight: 170,
                showTodayIndicators: false,
                showPointMarks: true,
                dataLabelDates: input.dataLabelDates
            )
            .allowsHitTesting(scrubbable)
            .panelCard()
        }
    }

    // MARK: - All Currencies Carousel

    /// Carrusel del modo "Todas": una página por moneda con su "quién paga" + su tendencia.
    /// Ambos gráficos viven en la misma página → la moneda nunca se desincroniza.
    private var allCurrenciesCarousel: some View {
        VStack(spacing: DS.Spacing.md) {
            TabView(selection: $allCurrenciesPage) {
                ForEach(viewModel.perCurrencyStats) { stat in
                    VStack(spacing: DS.Spacing.lg) {
                        VStack(spacing: DS.Spacing.lg) {
                            currencyPeriodHeader(currencyCode: stat.currencyCode)
                            memberBarChart(spending: stat.memberSpending, currencyCode: stat.currencyCode)
                            if let trendInput = GroupTrendChartAdapter.makeInput(from: stat.monthlyTrend) {
                                monthlyTrendChart(input: trendInput, currencyCode: stat.currencyCode, focusedDate: .constant(nil), scrubbable: false)
                            }
                        }
                        // Su alto ideal, no el de la página: así la medida no depende del alto que se le da.
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                            carouselPageHeights[stat.currencyCode] = height
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
                        // La página cambia en seco; los puntos los anima la implícita de abajo (card oxyr).
                        allCurrenciesPage = stat.currencyCode
                    }
                    .accessibilityLabel(currencyLabel(stat.currencyCode))
            }
        }
        // Implícita: en una pestaña un `withAnimation` no anima (card oxyr).
        .animation(reduceMotion ? nil : DS.Animation.selection, value: allCurrenciesPage)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Altura del carrusel = la página más alta (cada página alinea su contenido
    /// arriba con un `Spacer`), para que deslizar no cause saltos verticales.
    /// Desglose realista por bloque (evita el hueco que dejaba la estimación
    /// holgada anterior): header de sección (~22) + `spacing.sm` + padding del
    /// `panelCard` (lg×2); más el header de moneda y el margen de las etiquetas
    /// de datos de la tendencia. `.page` no scrollea si se queda corto → validar
    /// AX5 en device-QA.
    private var carouselHeight: CGFloat {
        let sectionChrome: CGFloat = 22 + DS.Spacing.sm + DS.Spacing.lg * 2
        let currencyHeader: CGFloat = 46
        let dataLabelPad: CGFloat = 18
        let interBlock = DS.Spacing.lg
        let heights = viewModel.perCurrencyStats.map { stat -> CGFloat in
            let memberBlock = CGFloat(max(stat.memberSpending.count, 1)) * 44 + sectionChrome
            let hasTrend = GroupTrendChartAdapter.makeInput(from: stat.monthlyTrend) != nil
            let trendBlock: CGFloat = hasTrend ? (170 + sectionChrome + dataLabelPad) : 0
            return currencyHeader + interBlock + memberBlock + (hasTrend ? interBlock + trendBlock : 0)
        }
        // Lo medido manda cuando es mayor: la estimación se queda como suelo para las páginas aún sin medir.
        let measured = carouselPageHeights.values.max() ?? 0
        return max(heights.max() ?? 360, measured)
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
