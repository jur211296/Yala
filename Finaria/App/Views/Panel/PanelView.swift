//
//  PanelView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftData
import SwiftUI
import UIKit

// MARK: - Panel (pantalla de inicio)

struct PanelView: View {

    init() {
        // FIN-56: Eliminamos el fondo gris por defecto del TabView en modo página
        // (UIPageViewController y su UIScrollView interno) para que se vea
        // únicamente el PanelBackgroundView.
        let pageViewBackground = UIView.appearance(
            whenContainedInInstancesOf: [UIPageViewController.self]
        )
        pageViewBackground.backgroundColor = .clear

        let scrollViewBackground = UIScrollView.appearance(
            whenContainedInInstancesOf: [UIPageViewController.self]
        )
        scrollViewBackground.backgroundColor = .clear
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    // FIN-46: Transacciones usadas para calcular saldos actuales por cuenta
    @Query(sort: \TransactionItem.date, order: .reverse)
    private var transactions: [TransactionItem]

    @State private var isPresentingAccountForm = false
    @State private var isPresentingSettings = false
    // FIN-57: Estado para la hoja de periodo personalizado y sus borradores
    @State private var isPresentingCustomPeriodSheet = false
    @State private var customPeriodStartDraft = Date()
    @State private var customPeriodEndDraft = Date()
    @State private var customPeriodErrorMessage: String?

    /// FIN-56: Cuenta actualmente seleccionada en el carrusel de cuentas del Panel.
    @State private var selectedAccountID: PersistentIdentifier?


    /// FIN-56: Cuenta que se está editando en el formulario de cuenta.
    /// Si es `nil`, el formulario se usa para crear una nueva cuenta.
    @State private var accountToEdit: Account?


    /// FIN-56: Índice de la columna que está alineada al borde izquierdo del carrusel.
    /// Se usa junto con `.scrollPosition` y `.scrollTargetBehavior(.viewAligned)` para
    /// que el scroll horizontal haga "snap" de una columna a la vez.
    @State private var leadingColumnIndex: Int? = 0
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""
    // FIN-57: Persistencia del filtro de periodo seleccionado en el Panel
    @AppStorage("panelPeriodType") private var panelPeriodTypeRaw: String = PanelPeriodType.thisMonth.rawValue
    @AppStorage("panelPeriodCustomStartISO") private var panelPeriodCustomStartISO: String = ""
    @AppStorage("panelPeriodCustomEndISO") private var panelPeriodCustomEndISO: String = ""

    private var defaultCurrency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
    }

    private var accountsSortOrderNames: [String] {
        accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
    }

    /// FIN-57: Filtro de periodo global del Panel reconstruido a partir de @AppStorage.
    private var panelPeriodFilter: PanelPeriodFilter {
        let periodType = PanelPeriodType(rawValue: panelPeriodTypeRaw) ?? .thisMonth

        let isoFormatter = ISO8601DateFormatter()
        let startDate = isoFormatter.date(from: panelPeriodCustomStartISO)
        let endDate = isoFormatter.date(from: panelPeriodCustomEndISO)

        return PanelPeriodFilter(
            type: periodType,
            customStartDate: startDate,
            customEndDate: endDate
        )
    }

    /// FIN-57: Intervalo de fechas efectivo que el Panel expone para sus tarjetas hijas.
    /// Esta propiedad se utilizará en historias posteriores para filtrar estadísticas por rango.
    private var panelDateInterval: DateInterval {
        panelPeriodFilter.dateInterval()
    }

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    private var orderedActiveAccounts: [Account] {
        let order = accountsSortOrderNames
        let indexByName = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

        return activeAccounts.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]

            switch (ia, ib) {
            case (let x?, let y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name < b.name
            }
        }
    }

    /// FIN-56: Cuenta seleccionada a partir del identificador persistente.
    private var selectedAccount: Account? {
        guard let id = selectedAccountID else { return nil }
        return orderedActiveAccounts.first { $0.persistentModelID == id }
    }

    // FIN-46: Saldo actual en moneda nativa de la cuenta
    // No modificar esta función sin revisar el impacto en todas las vistas
    // que muestran saldos por cuenta.
    private func currentBalance(for account: Account) -> Double {
        let currentDecimal = AccountBalanceCalculator.currentBalance(
            for: account,
            allTransactions: transactions
        )
        let nsNumber = currentDecimal as NSDecimalNumber
        return nsNumber.doubleValue
    }

    // Saldo total en la divisa preferida configurada en Ajustes (FIN-47)
    private var totalBalanceInDefaultCurrency: Double {
        // Divisa preferida desde Ajustes (AppStorage)
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen

        // Solo cuentas incluidas en estadísticas y no archivadas
        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
        }

        // Acumulamos el saldo actual de cada cuenta, convertido a la divisa preferida.
        let totalDecimal: Decimal = eligibleAccounts.reduce(0) { partial, account in
            // Saldo actual de la cuenta en su propia moneda (FIN-46)
            let currentBalance = AccountBalanceCalculator.currentBalance(
                for: account,
                allTransactions: transactions
            )

            // Código de moneda de la cuenta normalizado a CurrencyCode
            let sourceCurrency =
                CurrencyCode(
                    rawValue: normalizeCurrencyCode(account.currencyCode)
                ) ?? preferredCurrency

            // Convertimos el saldo de la cuenta a la divisa preferida
            let converted = convertToPreferredCurrency(
                amount: currentBalance,
                from: sourceCurrency,
                to: preferredCurrency
            )

            return partial + converted
        }

        let nsNumber = totalDecimal as NSDecimalNumber
        return nsNumber.doubleValue
    }

    /// FIN-56: Saldo que se muestra en el Panel. Si hay una cuenta seleccionada,
    /// se muestra solo el saldo de esa cuenta; en caso contrario, el saldo total.
    private var displayedBalanceInDefaultCurrency: Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen

        if let account = selectedAccount,
           !account.isArchived,
           !account.excludeFromStatistics {
            let currentBalanceDecimal = AccountBalanceCalculator.currentBalance(
                for: account,
                allTransactions: transactions
            )

            let sourceCurrency = CurrencyCode(
                rawValue: normalizeCurrencyCode(account.currencyCode)
            ) ?? preferredCurrency

            let converted = convertToPreferredCurrency(
                amount: currentBalanceDecimal,
                from: sourceCurrency,
                to: preferredCurrency
            )

            let nsNumber = converted as NSDecimalNumber
            return nsNumber.doubleValue
        }

        return totalBalanceInDefaultCurrency
    }

    // FIN-47: Conversión básica entre divisas hacia la divisa preferida.
    // En esta versión utilizamos un esquema simple con tasas por defecto cuando
    // no haya lógica de tipos de cambio más avanzada disponible.
    //
    // Tasas por defecto (ejemplo de FIN-47):
    // 1 USD = 3.54 PEN
    // 1 EUR = 3.89 PEN
    //
    // Estrategia:
    // - Convertimos primero el monto a PEN.
    // - Luego, si la divisa preferida no es PEN, convertimos de PEN a la divisa objetivo.
    private func convertToPreferredCurrency(
        amount: Decimal,
        from source: CurrencyCode,
        to target: CurrencyCode
    ) -> Decimal {
        // Si la divisa ya es la preferida, devolvemos el monto tal cual.
        if source == target {
            return amount
        }

        // Tasas de ejemplo tomadas como referencia para PEN (FIN-47).
        let usdToPen = Decimal(string: "3.54") ?? Decimal(3.54)
        let eurToPen = Decimal(string: "3.89") ?? Decimal(3.89)

        // Helpers internos para convertir PEN a otras divisas
        func penToUsd(_ pen: Decimal) -> Decimal {
            guard usdToPen != 0 else { return pen }
            return pen / usdToPen
        }

        func penToEur(_ pen: Decimal) -> Decimal {
            guard eurToPen != 0 else { return pen }
            return pen / eurToPen
        }

        // Paso 1: convertir a PEN
        let amountInPen: Decimal
        switch source {
        case .pen:
            amountInPen = amount
        case .usd:
            amountInPen = amount * usdToPen
        case .eur:
            amountInPen = amount * eurToPen
        }

        // Paso 2: convertir de PEN a la divisa destino
        switch target {
        case .pen:
            return amountInPen
        case .usd:
            return penToUsd(amountInPen)
        case .eur:
            return penToEur(amountInPen)
        }
    }

    private var formattedDisplayedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: displayedBalanceInDefaultCurrency)) ?? "0.00"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        accountsSection
                        periodFilterSection
                        totalBalanceSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Panel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $isPresentingAccountForm) {
                // FIN-56: El mismo formulario se usa para crear o editar cuentas.
                // - Si `accountToEdit` es nil, estamos creando una nueva cuenta.
                // - Si no es nil, estamos editando una cuenta existente y debemos
                //   excluir su propio nombre de la validación de duplicados.
                let namesForValidation: [String] = {
                    guard let editingAccount = accountToEdit else {
                        return accounts.map { $0.name }
                    }
                    return accounts
                        .filter { $0.persistentModelID != editingAccount.persistentModelID }
                        .map { $0.name }
                }()

                AccountFormView(
                    existingNames: namesForValidation,
                    accountToEdit: accountToEdit
                )
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsRootView()
            }
            .sheet(isPresented: $isPresentingCustomPeriodSheet) {
                customPeriodSheetContent
                    .presentationDetents([.height(230)])
            }
        }
        // -----------------------------------------------------------------
        // FIN-18: Semilla de categorías por defecto
        //
        // Esta llamada inicializa las categorías y subcategorías SOLO si
        // todavía no existe ninguna categoría en la base de datos.
        //
        // NO eliminar ni modificar esta llamada sin revisar el impacto en
        // la experiencia de onboarding y sin aprobación explícita del PO.
        // -----------------------------------------------------------------
        .onAppear {
            seedCategoriesIfNeeded(in: modelContext)
            // FIN-56: Ya no se selecciona ninguna cuenta por defecto.
            // El Panel inicia mostrando el saldo total hasta que el usuario
            // toque una tarjeta para filtrar por cuenta.
            // Además, garantizamos que el orden persistido incluya todas
            // las cuentas activas y que las nuevas queden al final.
            ensureAccountsSortOrderConsistency()
        }
        .onChange(of: accounts) {
            // FIN-56: Cada vez que cambie la lista de cuentas (creación,
            // edición de nombre, archivado, etc.), sincronizamos el orden
            // persistido para que nuevas cuentas queden al final.
            ensureAccountsSortOrderConsistency()
        }
    }

    // Sección de tarjetas de cuentas (incluye tarjeta "Agregar cuenta")
    //
    // FIN-56: Carrusel 2x2 con scroll horizontal paginado, indicador de páginas
    // y selección visual por color de cuenta. No modificar sin aprobación explícita
    // del usuario, ya que es la base del nuevo diseño de cuentas en Panel.
    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cuentas")
                .font(.title2.weight(.semibold))

            accountsCarousel
        }
    }

    /// FIN-56: Carrusel 2x2 de cuentas con desplazamiento suave por columna.
    /// Cada "columna" es un stack vertical de hasta 2 tarjetas (arriba/abajo).
    /// Se usa un ScrollView horizontal continuo, sin duplicar columnas entre
    /// páginas. Los indicadores de página son personalizados y se muestran
    /// siempre debajo del contenedor.
    @ViewBuilder
    private var accountsCarousel: some View {
        let accountsForGrid = orderedActiveAccounts

        // Construimos la lista de "cards": primero todas las cuentas activas,
        // luego la tarjeta "Agregar cuenta" al final.
        let totalCards = accountsForGrid.count + 1
        let cardIndices = Array(0..<totalCards)

        // Agrupamos los índices en columnas (máximo 2 tarjetas por columna).
        let columns: [[Int]] = stride(from: 0, to: totalCards, by: 2).map { start in
            let end = min(start + 2, totalCards)
            return Array(cardIndices[start..<end])
        }

        let columnsCount = columns.count

        // Número lógico de "páginas" para el indicador: con 2 columnas visibles
        // a la vez, moverse una columna a la derecha cuenta como una nueva página.
        let pageCount: Int = {
            switch columnsCount {
            case 0:
                return 1
            case 1, 2:
                return 1
            default:
                // Con 3 columnas: 2 páginas (0->1, 1->2), etc.
                return max(columnsCount - 1, 1)
            }
        }()

        let pageIndices: [Int] = Array(0..<pageCount)
        // Página actual para los indicadores, derivada del índice de columna
        // alineada al borde izquierdo. Cuando solo hay una "página" lógica,
        // este valor se mantiene en 0.
        let currentPage: Int = {
            guard pageCount > 1 else { return 0 }
            let rawIndex = leadingColumnIndex ?? 0
            return max(0, min(pageCount - 1, rawIndex))
        }()

        VStack(spacing: 4) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing: CGFloat = 12

                // FIN-56: El carrusel usa todo el ancho disponible, sin "peek"
                // lateral. Mostramos exactamente dos columnas completas en cada
                // tramo visible.
                let contentWidth = totalWidth
                let columnWidth = (contentWidth - spacing) / 2

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(0..<columnsCount, id: \.self) { colIndex in
                            accountsColumnView(
                                indices: columns[colIndex],
                                accountsForGrid: accountsForGrid
                            )
                            .frame(width: columnWidth)
                        }
                    }
                    // FIN-56: Cada columna es un "target" de paginación. Con
                    // `.viewAligned`, el scroll hace snap alineando siempre
                    // una columna completa al borde izquierdo.
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $leadingColumnIndex)
                .frame(width: contentWidth, height: 210)
            }
            // Altura fija del contenedor del carrusel dentro del ScrollView vertical.
            .frame(height: 210)

            // Indicador de páginas personalizado, siempre debajo de las tarjetas.
            if pageCount > 1 {
                HStack(spacing: 6) {
                    ForEach(pageIndices, id: \.self) { page in
                        Circle()
                            .fill(
                                page == currentPage
                                    ? Color.gray.opacity(0.9)
                                    : Color.gray.opacity(0.3)
                            )
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }


    /// FIN-56: Columna vertical de hasta 2 tarjetas (arriba/abajo).
    @ViewBuilder
    private func accountsColumnView(
        indices: [Int],
        accountsForGrid: [Account]
    ) -> some View {
        VStack(spacing: 12) {
            if indices.indices.contains(0) {
                accountsCardView(
                    cardIndex: indices[0],
                    accountsForGrid: accountsForGrid
                )
            }
            if indices.indices.contains(1) {
                accountsCardView(
                    cardIndex: indices[1],
                    accountsForGrid: accountsForGrid
                )
            }
        }
        // Alineamos siempre la columna al tope para que, cuando solo haya
        // una tarjeta (por ejemplo la 5ta caja), aparezca arriba y no
        // centrada verticalmente.
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// FIN-56: Renderiza una tarjeta individual del carrusel (cuenta o "Agregar cuenta").
    @ViewBuilder
    private func accountsCardView(
        cardIndex: Int,
        accountsForGrid: [Account]
    ) -> some View {
        if cardIndex < accountsForGrid.count {
            let account = accountsForGrid[cardIndex]
            let isSelected = selectedAccountID == account.persistentModelID

            AccountCardView(
                account: account,
                currentBalance: currentBalance(for: account),
                isSelected: isSelected,
                onEditTapped: {
                    // FIN-56: Abrimos el formulario en modo edición para esta cuenta.
                    accountToEdit = account
                    isPresentingAccountForm = true
                }
            )
            .onTapGesture {
                // FIN-56: Tocar una tarjeta selecciona esa cuenta como activa.
                // Al tocar de nuevo la misma tarjeta, se deselecciona y el Panel
                // puede volver a mostrar datos agregados (todas las cuentas).
                if selectedAccountID == account.persistentModelID {
                    selectedAccountID = nil
                } else {
                    selectedAccountID = account.persistentModelID
                }
            }
        } else {
            // Tarjeta "Agregar cuenta".
            AddAccountCardView {
                // FIN-56: Nueva cuenta: limpiamos `accountToEdit` y mostramos el formulario.
                accountToEdit = nil
                isPresentingAccountForm = true
            }
        }
    }

    /// FIN-56: Garantiza que el orden de cuentas (`accountsSortOrderNamesRaw`)
    /// incluya todas las cuentas activas y que cualquier cuenta nueva se añada
    /// SIEMPRE al final del orden actual, evitando que caiga en el orden alfabético
    /// por defecto del `@Query`.
    private func ensureAccountsSortOrderConsistency() {
        // Nombres de cuentas activas (no archivadas) según el modelo actual.
        let activeNames = activeAccounts.map { $0.name }

        // Si no hay cuentas activas, limpiamos el orden persistido.
        guard !activeNames.isEmpty else {
            if !accountsSortOrderNamesRaw.isEmpty {
                accountsSortOrderNamesRaw = ""
            }
            return
        }

        // Partimos del orden actual, pero solo conservamos nombres que sigan existiendo
        // y que sigan activos.
        var newOrder = accountsSortOrderNames.filter { activeNames.contains($0) }

        // Para cualquier cuenta activa cuyo nombre no esté en `newOrder`, la añadimos
        // al final. Esto hace que NUEVAS cuentas queden siempre al final del orden.
        for name in activeNames where !newOrder.contains(name) {
            newOrder.append(name)
        }

        let newRaw = newOrder.joined(separator: "|")

        // Solo actualizamos AppStorage si hay un cambio real, para evitar escrituras
        // innecesarias y posibles bucles de actualización.
        if newRaw != accountsSortOrderNamesRaw {
            accountsSortOrderNamesRaw = newRaw
        }
    }

    private var totalBalanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
            let preferredInfo = currencyInfo(for: preferredCurrency)

            // FIN-56: Cuando hay una cuenta seleccionada, mostramos una "cajita"
            // de filtro eliminable por encima del título. Al tocarla, se deshace
            // el filtro y el Panel vuelve a mostrar el saldo total agregado.
            if let account = selectedAccount {
                HStack {
                    HStack(spacing: 6) {
                        // FIN-56: Cajita de filtro con nombre de la cuenta y botón de cierre.
                        Text(account.name)
                            .font(.caption)

                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .foregroundStyle(.primary)
                    .onTapGesture {
                        // FIN-56: Al tocar la cajita de filtro, se limpia la selección
                        // y se deshace el filtro por cuenta.
                        selectedAccountID = nil
                    }

                    Spacer()
                }
            }

            // El título se mantiene siempre como "Saldo total" para reforzar
            // que el número representa el saldo mostrado actualmente, ya sea
            // filtrado o agregado.
            Text("Saldo total")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(preferredInfo.code) \(formattedDisplayedBalance)")
                .font(.title3.weight(.semibold))
        }
        .padding(.top, 8)
    }
}

// MARK: - FIN-57: Period Filter Section and Helpers

// FIN-57: Control segmentado de periodo flotante bajo las cajas de cuentas.
private extension PanelView {
    private var periodFilterSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                // Fondo gris claro tipo “segmented control” iOS
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(uiColor: .systemGray5))

                HStack(spacing: 0) {
                    periodSegmentButton(title: "Esta semana", type: .thisWeek)
                    periodSegmentButton(title: "Este mes", type: .thisMonth)
                    periodSegmentButton(title: "Este año", type: .thisYear)
                    periodCustomSegmentButton()
                }
                .padding(2)
            }
            .frame(height: 32)
        }
    }

    /// FIN-57: Botón genérico para los segmentos estándar del filtro de periodo.
    private func periodSegmentButton(
        title: String,
        type: PanelPeriodType
    ) -> some View {
        let isSelected = panelPeriodFilter.type == type

        return Button {
            panelPeriodTypeRaw = type.rawValue
        } label: {
            Text(title)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if isSelected {
                    // Solo el segmento seleccionado tiene “pastilla” blanca
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                } else {
                    Color.clear
                }
            }
        )
        .foregroundStyle(isSelected ? Color.black : Color.primary)
    }

    /// FIN-57: Segmento "Personalizado" que abre la hoja de selección de fechas.
    private func periodCustomSegmentButton() -> some View {
        let isSelected = panelPeriodFilter.type == .custom

        return Button {
            prepareCustomPeriodDraft()
            isPresentingCustomPeriodSheet = true
        } label: {
            Text("Personalizado")
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                } else {
                    Color.clear
                }
            }
        )
        .foregroundStyle(isSelected ? Color.black : Color.primary)
    }

    /// FIN-57: Inicializa los borradores del rango personalizado manteniendo el periodo previo.
    private func prepareCustomPeriodDraft() {
        customPeriodErrorMessage = nil

        let isoFormatter = ISO8601DateFormatter()
        if let savedStart = isoFormatter.date(from: panelPeriodCustomStartISO),
           let savedEnd = isoFormatter.date(from: panelPeriodCustomEndISO),
           savedStart <= savedEnd {
            customPeriodStartDraft = savedStart
            customPeriodEndDraft = savedEnd
            return
        }

        let interval = panelDateInterval
        customPeriodStartDraft = interval.start
        customPeriodEndDraft = interval.end
    }

    /// FIN-57: Hoja modal para seleccionar el periodo personalizado (Desde / Hasta) con diseño simple.
    private var customPeriodSheetContent: some View {
        NavigationStack {
            ZStack {
                // Fondo tipo "liquid glass" suave que respeta el contenido del Panel.
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Título único, sin subtítulos adicionales para mantenerlo simple.
                    Text("Periodo personalizado")
                        .font(.headline)
                        .padding(.top, 12)

                    // Contenido principal: solo dos campos de fecha, sin tarjeta extra.
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Desde")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DatePicker(
                                "",
                                selection: $customPeriodStartDraft,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hasta")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DatePicker(
                                "",
                                selection: $customPeriodEndDraft,
                                in: customPeriodStartDraft...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                    }
                    .padding(.horizontal, 4)

                    if let error = customPeriodErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    // Zona de acciones: misma jerarquía visual que el resto de Finaria.
                    HStack(spacing: 12) {
                        Button {
                            // FIN-57: Cancelar mantiene el periodo previamente activo.
                            isPresentingCustomPeriodSheet = false
                        } label: {
                            Text("Cancelar")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.secondary)

                        Button {
                            applyCustomPeriod()
                        } label: {
                            Text("Aplicar")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.black)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    /// FIN-57: Aplica el rango personalizado validando que la fecha de fin no sea anterior al inicio.
    private func applyCustomPeriod() {
        customPeriodErrorMessage = nil

        let start = customPeriodStartDraft
        let end = customPeriodEndDraft

        if end < start {
            customPeriodErrorMessage = "La fecha de fin no puede ser anterior a la fecha de inicio."
            return
        }

        let isoFormatter = ISO8601DateFormatter()
        panelPeriodCustomStartISO = isoFormatter.string(from: start)
        panelPeriodCustomEndISO = isoFormatter.string(from: end)
        panelPeriodTypeRaw = PanelPeriodType.custom.rawValue

        isPresentingCustomPeriodSheet = false
    }
}

