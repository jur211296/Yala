//
//  CashFlowCellDetailSheet.swift
//  Yala
//
//  El detalle de una línea del flujo de caja. Desde S3 del replanteo (18-nov-2026, variante A, decisiones en el
//  «Paso 0» del encargo `2026-11-18-flujo-detalle-de-linea`): arriba el límite del mes con «Cambiar» (abre la hoja de
//  S4), lo que falta y si sigue al ritmo, y «‹ mes ›» para recorrer el plan; debajo, seis meses de real contra límite y
//  TODOS los registros que el motor da a la línea en ese mes, por día, con «Ver en Registros». Si la línea es una
//  subcategoría, la cabecera dice su categoría y avisa de lo anotado en la madre sin subcategoría. Se retiraron la
//  gráfica diaria, la tira de ±2 meses, «Últimos registros» (5) y «Ajustar monto» al pie.
//
//  Auditoría UX 2.2 · lote 18 decidido:
//  - L18-7 (opción B): «Cómo se calcula: Promedio 6 meses · Cambiar» (abre el mismo selector que crear el plan) y, al
//    final, «Eliminar línea» a la vista. El método ya no se pinta en el color de los enlaces.
//  - L18-8 (opción A): «y los siguientes» guarda desde qué mes vale el monto nuevo; aquí se ve «Desde noviembre: S/ X
//    cada mes».
//  - S4 del replanteo (18-nov-2026, sustituye a L18-9): «Ajustar monto» abría «Cambiar límite», que preguntaba qué meses
//    cambian ANTES del monto (hoja retirada el 19-nov-2026; su alcance vive en «Cálculo del monto»). Aquí no hay campo
//    ni alerta.
//  - Lienzo «Una sola Yala»: los registros con la fila de Registros (y se puede tocar), la barra de Presupuestos.
//  - 19-nov-2026 (aislados y límites móviles): un solo «Cambiar», junto al límite, que abre «Cálculo del monto»
//    (`FlujoCalculoMontoSheet`); «Cómo se calcula» queda como texto, con la ventana y los meses que se dejaron fuera por
//    aislados. En «Últimos 6 meses», mantener una barra enseña su detalle y tocarla cambia la lista de abajo a ese mes.
//  - 20-nov-2026 (límites con pagos y monedas): bajo el límite, la cápsula «500 USD · promedio de nov. 3.70» abre
//    «Cómo se convierte»; un pago que dejó la línea se avisa una vez; y pagar en la moneda del límite justo el límite no
//    da «Te pasaste» por el tipo de cambio.
//

import Charts
import SwiftData
import SwiftUI

struct CashFlowCellDetailSheet: View {
    let lineResult: CashFlowLineResult
    let line: CashFlowLine?
    let month: CashFlowMonth
    let currencyCode: String
    let transactions: [TransactionItem]
    @Bindable var viewModel: CashFlowPlanViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(SceneNavigation.self) private var navigation

    /// Las cuentas del saldo del Panel, para leer los registros con el mismo alcance que la cifra del mes.
    @Query private var accounts: [Account]

    // Local navigation state (resets on dismiss)
    @State private var activeMonthKey: String = ""
    /// Los seis meses y cómo sale el límite: se calculan al cambiar de mes o de plan, no en cada pasada del `body`.
    @State private var datos: Datos?
    /// El mes elegido en la gráfica: la lista de abajo enseña sus registros. `nil` = el mes que se ve.
    @State private var mesDeLaLista: String?
    /// Los registros del mes de la lista.
    @State private var lista: Lista?

    /// «Cambiar» abre «Cálculo del monto» para el mes que se ve.
    @State private var calculoMonto: CalculoPeticion?

    @State private var showDeleteLineAlert = false

    /// «Se borró el pago Renta…», una vez (`FlujoAvisoPagoQuitado`).
    @State private var avisoPago: FlujoAvisoPagoQuitado.Aviso?
    /// «Cómo se convierte», con sus meses leídos al tocar la cápsula.
    @State private var comoSeConvierte: FlujoComoSeConvierteSheet.Datos?

    @State private var detailTransaction: TransactionItem?
    @State private var editingTransaction: TransactionItem?
    @State private var recordAwaitingEditor: TransactionItem?
    /// Icono y color de la categoría de la línea, copiados al abrir. «Eliminar línea» la borra y la hoja sigue presentada
    /// mientras baja: en iOS 27.x leer un modelo borrado aborta (card 1w89).
    @State private var lineIconAtOpen: LineIcon

    /// Icono y color de la subcategoría o la categoría de la línea.
    struct LineIcon {
        let iconName: String?
        let colorHex: String?

        static let none = LineIcon(iconName: nil, colorHex: nil)

        init(iconName: String?, colorHex: String?) {
            self.iconName = iconName
            self.colorHex = colorHex
        }

        init(reading line: CashFlowLine) {
            self.init(
                iconName: line.subcategory?.iconName ?? line.category?.iconName,
                colorHex: line.subcategory?.colorHex ?? line.category?.colorHex)
        }
    }

    init(
        lineResult: CashFlowLineResult,
        line: CashFlowLine?,
        month: CashFlowMonth,
        currencyCode: String,
        transactions: [TransactionItem],
        viewModel: CashFlowPlanViewModel
    ) {
        self.lineResult = lineResult
        self.line = line
        self.month = month
        self.currencyCode = currencyCode
        self.transactions = transactions
        self.viewModel = viewModel
        // Mira antes de leer: quien presenta la hoja la vuelve a crear mientras sigue abierta.
        _lineIconAtOpen = State(initialValue: Self.readable(line).map { LineIcon(reading: $0) } ?? .none)
    }

    private static func readable(_ line: CashFlowLine?) -> CashFlowLine? {
        guard let line, !line.isDeleted, line.modelContext != nil else { return nil }
        return line
    }

    /// La línea mientras se puede leer: lo que el `body` lee de ella pasa por aquí.
    private var readableLine: CashFlowLine? { Self.readable(line) }

    /// El icono vivo mientras la línea se puede leer; borrada, la copia.
    private var lineIcon: LineIcon {
        readableLine.map { LineIcon(reading: $0) } ?? lineIconAtOpen
    }

    // Derived from activeMonthKey
    private var activeMonth: CashFlowMonth? {
        viewModel.projection?.months.first { $0.monthKey == activeMonthKey }
    }

    private var activeLineResult: CashFlowLineResult? {
        guard let m = activeMonth else { return nil }
        let all = m.incomeLines + m.expenseLines
        return all.first { $0.lineID == lineResult.lineID }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                if let m = activeMonth, let lr = activeLineResult {
                    VStack(spacing: DS.Spacing.xl) {
                        content(m: m, lr: lr)
                        deleteLineButton
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xl)
                    .yalaSafeBottomPadding()
                    .dismissKeyboardOnTap()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("cashflow_cell_detail")
            .yalaScreenBackground(.subtle)
            .navigationTitle(lineResult.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("cashflow_cell_detail_close")
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            activeMonthKey = month.monthKey
            if avisoPago == nil { avisoPago = FlujoAvisoPagoQuitado.consumir(lineID: lineResult.lineID) }
        }
        .sheet(item: $comoSeConvierte) { datos in
            FlujoComoSeConvierteSheet(datos: datos)
        }
        .task(id: dataKey) { loadData() }
        .task(id: listKey) { loadList() }
        .onChange(of: activeMonthKey) { mesDeLaLista = nil }
        .sheet(item: $calculoMonto) { peticion in
            if let line = readableLine {
                FlujoCalculoMontoSheet(
                    origen: .linea(line, monthKey: peticion.monthKey, previews: previews(for: line),
                                   actual: activeLineResult?.plannedAmount ?? 0),
                    currencyCode: currencyCode,
                    viewModel: viewModel
                )
            }
        }
        .alert(L10n.CashFlowPlan.deleteLineConfirmation, isPresented: $showDeleteLineAlert) {
            Button(L10n.Action.delete, role: .destructive) {
                if let line {
                    viewModel.removeLine(line)
                }
                dismiss()
            }
            .accessibilityIdentifier("cashflow_detail_delete_confirm")
            Button(L10n.Action.cancel, role: .cancel) { }
        }
        // `item:` y no `isPresented:` + un `@State` aparte (regla de `swiftui-ds.md`): con el segundo la hoja salía vacía.
        .sheet(item: $detailTransaction, onDismiss: handleRecordDetailDismiss) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                onEdit: {
                    recordAwaitingEditor = transaction
                    detailTransaction = nil
                }
            )
        }
        .sheet(item: $editingTransaction) { transaction in
            NewTransactionView(transactionToEdit: transaction)
                .presentationDetents([.large])
        }
    }

    private func handleRecordDetailDismiss() {
        if let record = recordAwaitingEditor {
            recordAwaitingEditor = nil
            editingTransaction = record
        }
    }

    // MARK: - Header

    /// El icono y el nombre; si la línea es una subcategoría, su categoría encima («Comida» › «Restaurantes»).
    private var headerInfo: some View {
        HStack(spacing: DS.Spacing.md) {
            categoryIcon
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                if let parentCategoryName {
                    Text(parentCategoryName)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("cashflow_detail_parent_category")
                }
                Text(lineResult.name)
                    .font(DS.Typography.headline)
            }
            .accessibilityElement(children: .combine)
            Spacer()
        }
    }

    /// La categoría de una línea por subcategoría; `nil` en una línea por categoría o sin ella.
    private var parentCategoryName: String? {
        guard let sub = readableLine?.subcategory, let category = sub.category,
              !category.isDeleted, category.modelContext != nil else { return nil }
        return category.name
    }

    private var categoryIcon: some View {
        let iconName = lineIcon.iconName
        let colorHex = lineIcon.colorHex
        let hasIcon = iconName != nil && colorHex != nil

        return ZStack {
            Circle()
                .fill(hasIcon ? Color(hex: colorHex ?? "") : Color.secondary.opacity(0.2))
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
            Image(systemName: iconName ?? "questionmark")
                .font(.system(size: DS.Icon.sizeLarge, weight: .semibold))
                .foregroundStyle(hasIcon ? Color.white : Color.secondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Cómo se calcula (L18-7; informativo desde el 19-nov-2026)

    /// «Cómo se calcula: Promedio 6 meses» y debajo cómo sale este mes: la ventana y los meses que se dejaron fuera por
    /// aislados, o «Monto fijo desde noviembre». Ya no lleva su propio «Cambiar»: el único está junto al límite.
    private func methodSection(lr: CashFlowLineResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Con texto grande la fila no cabe y partía las palabras («Prome-dio»): el método baja bajo el rótulo.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.xs) {
                    methodLabel
                    Spacer(minLength: DS.Spacing.sm)
                    methodValue(lr: lr)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    methodLabel
                    methodValue(lr: lr)
                }
            }
            Text(howText(lr: lr))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("cashflow_detail_how")
            if lr.isOverride {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.secondary)
                    Text(L10n.CashFlowPlan.cellDetailOverrideActive)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Lo que dice el texto de «Cómo se calcula» del mes que se ve.
    private func howText(lr: CashFlowLineResult) -> String {
        if let texto = FlujoDetalleLineaLogica.comoSeCalcula(
            desglose: lr.limitBreakdown, monedaPlan: currencyCode,
            formato: { appPreferences.currency($0, currencyCode: currencyCode) }
        ) {
            return texto
        }
        let cambioDesde = lr.amountChangeFromMonthKey.flatMap { CashFlowDetailLineRow.monthDate($0) }
        if let liveLine = readableLine,
           let texto = FlujoDetalleLineaLogica.comoSeCalcula(
               line: liveLine, explicacion: datos?.monthKey == activeMonthKey ? datos?.historia.explicacion : nil,
               cambioDesde: cambioDesde
           ) {
            return texto
        }
        return lr.estimationMethod.descriptionText
    }

    private var methodLabel: some View {
        Text(L10n.UXL18.howItsCalculated)
            .font(DS.Typography.label)
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    private func methodValue(lr: CashFlowLineResult) -> some View {
        // Un monto escrito «desde» un mes es un monto fijo, aunque los meses de antes sigan con su promedio.
        var name = lr.amountChangeFromMonthKey != nil ? EstimationMethod.manual.displayName : lr.estimationMethod.displayName
        // «Monto fijo en USD» (encargo del 2026-11-20).
        if lr.estimationMethod == .manual, let desglose = lr.limitBreakdown, desglose.pagos.isEmpty,
           let original = desglose.original {
            name = L10n.FlujoDetalleLinea.metodoFijoEn(original.moneda)
        }
        return Text(name)
            .font(DS.Typography.label)
            .foregroundStyle(.primary)
            .fixedSize()
            .accessibilityIdentifier("cashflow_detail_method")
    }

    /// Lo que daría cada método con los registros, con el mismo índice y el mismo mes de referencia que el límite.
    private func previews(for line: CashFlowLine) -> [EstimationMethod: CashFlowProjectionCalculator.LimitEstimate] {
        guard let historia = datos?.historia else { return [:] }
        var result: [EstimationMethod: CashFlowProjectionCalculator.LimitEstimate] = [:]
        for method in [EstimationMethod.average6m, .average3m, .lastMonth, .average12m, .trend] {
            result[method] = CashFlowProjectionCalculator.explainEstimate(
                method: method, line: line, referenceDate: historia.referencia, index: historia.indice,
                calendar: .current
            )
        }
        return result
    }

    // MARK: - Contenido (S3 del replanteo, variante A: el límite primero)

    private func content(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            limitCard(m: m, lr: lr)

            if let meses = datos?.historia.meses, !meses.isEmpty {
                FlujoDetalleLineaSeisMesesView(
                    meses: meses, esIngreso: lr.isIncome, currencyCode: currencyCode, mesActivo: m.monthKey,
                    mesElegido: $mesDeLaLista
                )
                .padding(DS.Spacing.lg)
                .solidCard()
            }

            if let lista, lista.monthKey == listMonthKey {
                FlujoDetalleLineaRegistrosView(
                    dias: lista.dias,
                    mesNombre: monthName(lista.monthKey),
                    currencyCode: currencyCode,
                    // Lo real del mes, como la barra y el tooltip (sin lo programado de mañana en adelante).
                    total: lista.monthKey == m.monthKey ? nil : lista.dias.flatMap(\.registros)
                        .filter { !$0.esFechado }.reduce(0) { $0 + $1.importe },
                    volverA: lista.monthKey == m.monthKey ? nil : monthName(m.monthKey),
                    onVolver: { mesDeLaLista = nil },
                    onVerEnRegistros: canSeeInRecords ? { seeInRecords(monthKey: lista.monthKey) } : nil,
                    onAbrir: { detailTransaction = $0 }
                )
            }
        }
    }

    // MARK: - El límite (arriba, con «Cambiar»)

    private func limitCard(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            headerInfo
            monthSwitcher(m: m)

            Divider()

            if let avisoPago {
                avisoPagoView(avisoPago)
            }

            limitRow(m: m, lr: lr)

            if let capsula = capsulaDeConversion(m: m, lr: lr) {
                capsula
            }

            if m.isCurrent {
                currentProgress(m: m, lr: lr)
            } else if m.isPast {
                pastProgress(lr: lr)
            } else {
                futureProgress(lr: lr)
            }

            if let parent = parentNotice(m: m, lr: lr) {
                parent
            }

            Divider()

            methodSection(lr: lr)
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    /// «Límite de noviembre   S/ 900   Cambiar»: la cifra y su gesto en la misma fila; con texto grande, «Cambiar» baja.
    private func limitRow(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        let title = L10n.FlujoDetalleLinea.limite(mes: monthName(m.monthKey), esIngreso: lr.isIncome)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                limitAmount(title: title, lr: lr)
                Spacer(minLength: DS.Spacing.sm)
                changeLimitButton(m: m, lr: lr)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                limitAmount(title: title, lr: lr)
                changeLimitButton(m: m, lr: lr)
            }
        }
    }

    private func limitAmount(title: String, lr: CashFlowLineResult) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            AmountText(
                value: lr.plannedAmount,
                currencyCode: currencyCode,
                font: DS.Typography.title.weight(.bold).monospacedDigit(),
                isEstimate: lr.isPlannedApproximate
            )
            .accessibilityIdentifier("cashflow_detail_planned_amount")
        }
        .accessibilityElement(children: .combine)
    }

    /// Abre «Cambiar límite» (S4) para el mes que se ve. El alcance se elige allí, antes del monto.
    @ViewBuilder
    private func changeLimitButton(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        if readableLine != nil {
            Button {
                calculoMonto = CalculoPeticion(monthKey: m.monthKey)
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "pencil")
                        .accessibilityHidden(true)
                    Text(L10n.FlujoDetalleLinea.cambiar)
                }
                .font(DS.Typography.label.weight(.semibold))
                .foregroundStyle(theme.accentText)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.FlujoDetalleLinea.cambiarAccesible(esIngreso: lr.isIncome))
            .accessibilityIdentifier("cashflow_adjust_amount")
        }
    }

    /// Mes en curso: «Llevas S/ 600 de S/ 900», la barra, «Te quedan S/ 300» y el ritmo.
    private func currentProgress(m: CashFlowMonth, lr: CashFlowLineResult) -> some View {
        let real = lr.realAmount ?? 0
        let ritmo = FlujoDetalleLineaLogica.ritmo(
            real: real, limite: lr.plannedAmount, isExceeded: lr.isExceeded, esIngreso: lr.isIncome,
            esMesActual: true, realMasFechado: real + lr.datedAmount, now: .now, calendar: .current
        )
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // «Llevas S/ 600 de S/ 900» en una línea; si no cabe (texto grande), «de S/ 900» baja entero.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    soFarAmount(real: real, lr: lr)
                    ofLimitText(lr: lr)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    soFarAmount(real: real, lr: lr)
                    ofLimitText(lr: lr)
                }
            }
            .accessibilityElement(children: .combine)

            if let progress = lr.progress {
                BudgetProgressBar(
                    percentage: progress * 100,
                    color: "",
                    isExceeded: CashFlowLineSideLogic.progressIsAlarm(progress: progress, isIncome: lr.isIncome),
                    simplified: true
                )
            }

            switch ritmo {
            // Pagado en la moneda del límite sin pasar del original: la diferencia es del tipo de cambio, no un exceso
            // (encargo del 2026-11-20).
            case .excedida where excesoPorTipoDeCambio(m: m, lr: lr) != nil:
                fxSentence(m: m, lr: lr)
            // Justo en el límite (lo gastado es el límite): no hay exceso que contar. Con límites móviles es lo normal en
            // un gasto fijo de cada mes, y «Te pasaste por S/ 0.00» era falso.
            case .excedida(let porCuanto) where porCuanto >= 0.005:
                sentence(
                    L10n.FlujoDetalleLinea.excedida(appPreferences.currency(porCuanto, currencyCode: currencyCode)),
                    icon: "exclamationmark.circle.fill", tint: DS.Semantic.errorForeground, id: "cashflow_detail_exceeded"
                )
            case .excedida, .alRitmo, .ninguno:
                // Lo que falta: en un gasto, lo que te queda; en un ingreso, lo que aún no recibiste.
                let left = max(0, lr.plannedAmount - real)
                if left > 0.005 {
                    sentence(
                        L10n.FlujoDetalleLinea.quedan(appPreferences.currency(left, currencyCode: currencyCode), esIngreso: lr.isIncome),
                        icon: nil, tint: .secondary, id: "cashflow_detail_left"
                    )
                }
            }

            if case .alRitmo(let llegarias, let sePasa) = ritmo {
                // Espacio duro: en el SE la frase partía entre «~S/» y la cifra.
                let total = appPreferences.currency(llegarias, currencyCode: currencyCode)
                    .replacingOccurrences(of: " ", with: "\u{00A0}")
                sentence(
                    sePasa
                        ? L10n.FlujoDetalleLinea.ritmoSePasa(
                            total, exceso: appPreferences.currency(llegarias - lr.plannedAmount, currencyCode: currencyCode))
                        : L10n.FlujoDetalleLinea.ritmo(total),
                    icon: "speedometer", tint: sePasa ? DS.Semantic.errorForeground : .secondary, id: "cashflow_detail_pace"
                )
            }

            let scheduled = lr.datedAmount + lr.pendingAmount
            if scheduled > 0.005 {
                sentence(
                    L10n.FlujoDetalleLinea.programado(appPreferences.currency(scheduled, currencyCode: currencyCode)),
                    icon: "calendar", tint: .secondary, id: "cashflow_detail_scheduled"
                )
            }
        }
    }

    private func soFarAmount(real: Double, lr: CashFlowLineResult) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(L10n.FlujoDetalleLinea.llevas(esIngreso: lr.isIncome))
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
            AmountText(value: real, currencyCode: currencyCode, font: DS.Typography.headline.monospacedDigit())
                .accessibilityIdentifier("cashflow_detail_real_amount")
        }
        .fixedSize()
    }

    private func ofLimitText(lr: CashFlowLineResult) -> some View {
        Text(L10n.FlujoDetalleLinea.deLimite(appPreferences.currency(lr.plannedAmount, currencyCode: currencyCode)))
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .fixedSize()
    }

    /// Mes cerrado: «Gastaste S/ 820 de S/ 900» y cuánto más o menos que el límite.
    @ViewBuilder
    private func pastProgress(lr: CashFlowLineResult) -> some View {
        if let real = lr.realAmount {
            let diff = real - lr.plannedAmount
            let isGood = lr.isIncome ? diff >= -0.005 : diff <= 0.005
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.FlujoDetalleLinea.cerrado(
                    appPreferences.currency(real, currencyCode: currencyCode),
                    de: appPreferences.currency(lr.plannedAmount, currencyCode: currencyCode),
                    esIngreso: lr.isIncome
                ))
                .font(DS.Typography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("cashflow_detail_closed")
                if excesoPorTipoDeCambio(m: nil, lr: lr) != nil {
                    fxSentence(m: nil, lr: lr)
                } else if abs(diff) > 0.005 {
                    sentence(
                        L10n.FlujoDetalleLinea.diferencia(appPreferences.currency(abs(diff), currencyCode: currencyCode), esMas: diff > 0),
                        icon: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                        tint: isGood ? theme.accentText : DS.Semantic.errorForeground,
                        id: "cashflow_detail_difference"
                    )
                }
            }
        }
    }

    /// Mes que viene: lo ya programado (fechado y pagos pendientes), si hay.
    @ViewBuilder
    private func futureProgress(lr: CashFlowLineResult) -> some View {
        let scheduled = lr.datedAmount + lr.pendingAmount
        if scheduled > 0.005 {
            sentence(
                L10n.FlujoDetalleLinea.programado(appPreferences.currency(scheduled, currencyCode: currencyCode)),
                icon: "calendar", tint: .secondary, id: "cashflow_detail_scheduled"
            )
        }
    }

    /// Lo anotado en la categoría madre sin subcategoría cuando la línea es por subcategoría (ajuste de Jürgen: el
    /// detalle llega a subcategoría): cuenta en el mes y no en esta línea.
    private func parentNotice(m: CashFlowMonth, lr: CashFlowLineResult) -> AnyView? {
        guard let parentName = parentCategoryName,
              let amount = FlujoDetalleLineaLogica.anotadoEnLaMadre(
                lineID: lr.lineID, esPorSubcategoria: true, grupos: lr.isIncome ? m.incomeGroups : m.expenseGroups
              ) else { return nil }
        return AnyView(
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(L10n.FlujoDetalleLinea.anotadoEnLaMadre(
                    appPreferences.currency(amount, currencyCode: currencyCode), categoria: parentName
                ))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cashflow_detail_parent_notice")
        )
    }

    // MARK: - Límites con pagos y monedas (encargo del 2026-11-20)

    /// «Se borró el pago Renta. El límite quedó fijo en S/ 1,850.00.», una vez.
    private func avisoPagoView(_ aviso: FlujoAvisoPagoQuitado.Aviso) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(theme.accentText)
                .accessibilityHidden(true)
            Text(L10n.FlujoDetalleLinea.avisoPagoQuitado(
                nombre: aviso.nombre, destino: aviso.destino,
                fijoEn: aviso.fijoEn.map { appPreferences.currency($0, currencyCode: currencyCode) }
            ))
            .font(DS.Typography.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cashflow_detail_payment_notice")
    }

    /// «⇄ 500.00 USD · promedio de nov. 3.70 ›»: abre «Cómo se convierte». Solo con una moneda extranjera en el límite.
    private func capsulaDeConversion(m: CashFlowMonth, lr: CashFlowLineResult) -> AnyView? {
        guard let desglose = lr.limitBreakdown, desglose.monedasExtranjeras.count == 1,
              let moneda = desglose.monedasExtranjeras.first, let tasa = desglose.tasa else { return nil }
        let original = desglose.original ?? FlujoLimiteEnMoneda.Original(
            monto: desglose.pagos.filter { $0.estado == .suma && $0.moneda == moneda }
                .reduce(0) { $0 + $1.importe * Double($1.ocurrencias) },
            moneda: moneda
        )
        let texto = L10n.FlujoDetalleLinea.capsula(
            FlujoMonedaTexto.original(original.monto, moneda: original.moneda),
            mes: FlujoMonedaTexto.mesCorto(m.date), tasa: FlujoMonedaTexto.tasa(tasa), estimada: tasa.estado == .estimado
        )
        return AnyView(
            Button {
                guard let line = readableLine else { return }
                comoSeConvierte = FlujoComoSeConvierteSheet.datos(
                    line: line, mesQueSeVe: m.date, monedaPlan: currencyCode, converter: CurrencyConverter.shared,
                    hoy: .now, calendar: .current
                )
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.left.arrow.right")
                        .accessibilityHidden(true)
                    Text(texto)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionSmall.weight(.bold))
                        .accessibilityHidden(true)
                }
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .frame(minHeight: 44)
                .background(Capsule().fill(theme.accent.opacity(0.14)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.FlujoDetalleLinea.convierteTitulo)
            .accessibilityIdentifier("cashflow_detail_conversion_capsule")
        )
    }

    /// Lo que se pasó solo por el tipo de cambio en el mes que se ve: lo pagado en la moneda del límite no pasa del
    /// original. Los registros salen de la lista del mes (`lista`), que es la de ese mes.
    private func excesoPorTipoDeCambio(m: CashFlowMonth?, lr: CashFlowLineResult) -> (exceso: Double, justo: Bool)? {
        guard !lr.isIncome, let original = lr.limitBreakdown?.original, let lista,
              lista.monthKey == activeMonthKey else { return nil }
        let pagado = FlujoDetalleLineaLogica.pagadoEnMoneda(original.moneda, registros: lista.dias.flatMap(\.registros))
        return FlujoDetalleLineaLogica.excesoPorTipoDeCambio(
            real: (lr.realAmount ?? 0) + (m == nil ? 0 : lr.datedAmount), limite: lr.plannedAmount,
            original: original, pagadoEnOriginal: pagado
        )
    }

    @ViewBuilder
    private func fxSentence(m: CashFlowMonth?, lr: CashFlowLineResult) -> some View {
        if let exceso = excesoPorTipoDeCambio(m: m, lr: lr), let original = lr.limitBreakdown?.original, let lista {
            let pagado = FlujoDetalleLineaLogica.pagadoEnMoneda(original.moneda, registros: lista.dias.flatMap(\.registros)) ?? 0
            let diferencia = appPreferences.currency(exceso.exceso, currencyCode: currencyCode)
            let pagadoTexto = FlujoMonedaTexto.original(pagado, moneda: original.moneda)
            sentence(
                exceso.justo
                    ? L10n.FlujoDetalleLinea.pagasteJusto(pagadoTexto, diferencia: diferencia)
                    : L10n.FlujoDetalleLinea.pagasteDentro(
                        pagadoTexto, de: FlujoMonedaTexto.original(original.monto, moneda: original.moneda),
                        diferencia: diferencia
                    ),
                icon: "arrow.left.arrow.right", tint: .secondary, id: "cashflow_detail_fx_difference"
            )
        }
    }

    private func sentence(_ text: String, icon: String?, tint: Color, id: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    // MARK: - Cambiar de mes

    /// «‹ noviembre de 2026 ›»: recorre los meses del plan sin salir del detalle (sustituye a la tira de ±2 meses).
    private func monthSwitcher(m: CashFlowMonth) -> some View {
        let keys = viewModel.projection?.months.map(\.monthKey) ?? []
        let index = keys.firstIndex(of: m.monthKey)
        let previous = index.flatMap { $0 > 0 ? keys[$0 - 1] : nil }
        let next = index.flatMap { $0 + 1 < keys.count ? keys[$0 + 1] : nil }
        return HStack(spacing: DS.Spacing.sm) {
            monthArrow("chevron.left", target: previous, label: L10n.FlujoDetalleLinea.mesAnterior, id: "cashflow_detail_previous_month")
            Text(m.date.formatted(.dateTime.month(.wide).year()))
                .font(DS.Typography.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("cashflow_detail_month")
            monthArrow("chevron.right", target: next, label: L10n.FlujoDetalleLinea.mesSiguiente, id: "cashflow_detail_next_month")
        }
    }

    private func monthArrow(_ symbol: String, target: String?, label: String, id: String) -> some View {
        Button {
            guard let target else { return }
            // En hoja sí anima; con Reducir movimiento, sin animación (card oxyr).
            dsWithAnimation(reduceMotion, .easeInOut(duration: DS.Animation.fast)) {
                activeMonthKey = target
            }
            DS.Haptic.selection()
        } label: {
            Image(systemName: symbol)
                .font(DS.Typography.label.weight(.semibold))
                .foregroundStyle(target == nil ? Color.secondary.opacity(0.4) : theme.accentText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    // MARK: - Ver en Registros

    private var canSeeInRecords: Bool {
        guard let liveLine = readableLine else { return false }
        return liveLine.subcategory != nil || liveLine.category != nil
    }

    /// Solo esta subcategoría (o categoría) y el período del mes de la lista, y a Registros: el gesto de Distribución.
    private func seeInRecords(monthKey: String) {
        guard let liveLine = readableLine, let monthDate = CashFlowDetailLineRow.monthDate(monthKey) else { return }
        let session = SessionState.shared
        if let sub = liveLine.subcategory {
            session.selectedSubcategoryIDs = [sub.persistentModelID]
            session.selectedCategoryIDs = []
        } else if let cat = liveLine.category {
            session.selectedCategoryIDs = [cat.persistentModelID]
            session.selectedSubcategoryIDs = []
        }
        let period = FlujoDetalleLineaLogica.periodoDeRegistros(mes: monthDate, now: .now, calendar: .current)
        session.choosePeriod(period.period, customRange: period.range, stepUnit: period.period == .custom ? .month : nil)
        dismiss()
        navigation.selectMainTab(.records)
    }

    // MARK: - Datos (registros y seis meses)

    /// Lo que cambia la gráfica y la explicación del límite: el mes, el plan, los movimientos y la propia línea (su
    /// método, sus cambios «desde» y el límite que da el motor, para que «Cálculo del monto» se vea al guardar).
    private var dataKey: String {
        let lineKey = readableLine.map {
            "\($0.estimationMethod)|\($0.amountChangesRaw ?? "")|\($0.manualAmount ?? -1)|\($0.scheduledPaymentIDsRaw ?? "")"
                + "|\($0.limitExtraAmount ?? -1)|\($0.limitCurrencyCode ?? "")|\($0.limitForeignAmount ?? -1)"
        } ?? ""
        return "\(activeMonthKey)|\(viewModel.planRevision)|\(transactions.count)|\(viewModel.projection?.months.count ?? 0)"
            + "|\(lineKey)|\(activeLineResult?.plannedAmount ?? 0)"
    }

    /// El mes de la lista de registros: el elegido en la gráfica o el que se ve.
    private var listMonthKey: String { mesDeLaLista ?? activeMonthKey }

    private var listKey: String {
        "\(listMonthKey)|\(viewModel.planRevision)|\(transactions.count)|\(activeLineResult?.realAmount ?? 0)"
    }

    private func loadData() {
        guard let m = activeMonth, let liveLine = readableLine, let plan = viewModel.plan else {
            datos = nil
            return
        }
        let calendar = Calendar.current
        let converter = CurrencyConverter.shared
        let adjustment = GroupBridgeStatsAdjustment.build(from: transactions, context: modelContext)
        let planLines = FlujoDetalleLineaLogica.ordenDelPlan(plan.lines ?? [])
        guard let historia = FlujoDetalleLineaLogica.historia(
            line: liveLine, lineasPlan: planLines, transactions: scopedTransactions, historia: transactions,
            hasta: m.date, currencyCode: currencyCode, adjustment: adjustment, converter: converter, now: .now,
            calendar: calendar
        ) else {
            datos = nil
            return
        }
        datos = Datos(monthKey: m.monthKey, historia: historia)
    }

    private func loadList() {
        guard let liveLine = readableLine, let plan = viewModel.plan,
              let mes = CashFlowDetailLineRow.monthDate(listMonthKey) else {
            lista = nil
            return
        }
        let calendar = Calendar.current
        let adjustment = GroupBridgeStatsAdjustment.build(from: transactions, context: modelContext)
        let planLines = FlujoDetalleLineaLogica.ordenDelPlan(plan.lines ?? [])
        let registros = FlujoDetalleLineaLogica.registros(
            de: liveLine.id, mes: mes, lineas: planLines.map { FlujoMotorMesEntrada.linea($0) },
            transactions: scopedTransactions, currencyCode: currencyCode, adjustment: adjustment,
            converter: CurrencyConverter.shared, now: .now, calendar: calendar
        )
        lista = Lista(monthKey: listMonthKey, dias: FlujoDetalleLineaLogica.dias(registros, calendar: calendar))
    }

    /// El mismo alcance que la cifra del mes (`CashFlowPlanViewModel.recalculate`): las cuentas del saldo del Panel.
    private var scopedTransactions: [TransactionItem] {
        FlujoMotorMesEntrada.alcanceDelSaldo(
            accounts: accounts, transactions: transactions, includeGroups: appPreferences.includeGroupsInPanelTotal
        )?.transactions ?? transactions
    }

    struct Datos {
        let monthKey: String
        let historia: FlujoDetalleLineaLogica.Historia
    }

    struct Lista {
        let monthKey: String
        let dias: [FlujoDetalleLineaLogica.Dia]
    }

    /// «Cambiar» para un mes: abre «Cálculo del monto».
    struct CalculoPeticion: Identifiable {
        let monthKey: String
        var id: String { monthKey }
    }

    // MARK: - Eliminar línea (L18-7)

    @ViewBuilder
    private var deleteLineButton: some View {
        if line != nil {
            Button(role: .destructive) {
                showDeleteLineAlert = true
            } label: {
                Text(L10n.CashFlowPlan.deleteLine)
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Semantic.errorForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cashflow_detail_delete_line")
        }
    }

    // MARK: - Helpers

    /// «noviembre» desde la clave `yyyy-MM`.
    private func monthName(_ key: String) -> String {
        guard let date = CashFlowDetailLineRow.monthDate(key) else { return key }
        return CashFlowMonthSummaryLogic.monthInSentence(date)
    }
}
