//
//  FlujoCalculoMontoSheet.swift
//  Yala
//
//  «Cálculo del monto» de una línea del flujo de caja, rediseñada el 19-nov-2026 (Jürgen: «si pongo monto fijo, el campo
//  de monto está todo escondido abajo… ¿Podemos mejorarla? Más acorde al resto de la app»). Sustituye a
//  `CashFlowMethodPickerSheet` (vivía dentro de `CashFlowSetupView`) y es el único «Cambiar» del detalle de una línea.
//
//  - Arriba, grande y en vivo, el monto que resulta del método elegido y cómo sale (con los meses que se dejaron fuera
//    por aislados).
//  - «Monto fijo» pone su campo arriba, con el teclado, y en una línea ya creada el alcance de «Cambiar límite» (por
//    defecto «desde este mes en adelante», P3): escribir un monto es pasar a monto fijo.
//  - Cada método dice cuánto daría con tus registros y qué meses dejó fuera.
//  - La hoja abre grande: nada queda tapado por un detent a media altura.
//
//  La abre crear el plan (sobre una sugerencia, que aún no es una línea) y el detalle de una línea.
//

import SwiftData
import SwiftUI

struct FlujoCalculoMontoSheet: View {

    enum Origen {
        /// Una sugerencia del armado del plan.
        case sugerencia(SuggestedLine)
        /// Una línea ya creada, en el mes que se ve en su detalle, con lo que daría cada método (`previews`) y el
        /// límite que tiene ese mes.
        case linea(CashFlowLine, monthKey: String,
                   previews: [EstimationMethod: CashFlowProjectionCalculator.LimitEstimate], actual: Double)
    }

    let origen: Origen
    let currencyCode: String
    @Bindable var viewModel: CashFlowPlanViewModel
    var onSaved: () -> Void = {}

    @State private var metodo: EstimationMethod
    @State private var texto: String
    @State private var alcance: FlujoCambiarLimiteLogica.Alcance = .porDefecto
    @FocusState private var campoConFoco: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Lo que se lee de la línea al abrir: la hoja puede seguir presentada mientras la línea se borra (card 1w89).
    private let nombre: String
    private let esIngreso: Bool
    private let tienePago: Bool
    private let metodoInicial: EstimationMethod
    private let montoInicial: Double

    init(origen: Origen, currencyCode: String, viewModel: CashFlowPlanViewModel, onSaved: @escaping () -> Void = {}) {
        self.origen = origen
        self.currencyCode = currencyCode
        self.viewModel = viewModel
        self.onSaved = onSaved
        let inicial: EstimationMethod
        let monto: Double
        switch origen {
        case .sugerencia(let linea):
            nombre = linea.name
            esIngreso = linea.isIncome
            tienePago = linea.scheduledPayment != nil
            inicial = linea.estimationMethod
            monto = linea.suggestedAmount
        case .linea(let line, let monthKey, _, let actual):
            nombre = line.name
            esIngreso = line.isIncome
            tienePago = line.scheduledPayment != nil
            // Un mes con un monto escrito (un cambio «desde» o un ajuste de un mes) ya es un monto fijo.
            let escrito = CashFlowAmountChangeLogic.change(for: monthKey, in: line.amountChanges) != nil
                || line.monthOverride(for: monthKey) != nil
            inicial = escrito ? .manual : line.method
            monto = actual
        }
        metodoInicial = inicial
        montoInicial = monto
        _metodo = State(initialValue: inicial)
        _texto = State(initialValue: inicial == .manual ? CashFlowStartingBalanceSheet.editableText(monto) : "")
    }

    // MARK: - Datos

    private var metodos: [EstimationMethod] {
        var lista: [EstimationMethod] = [.average6m, .average3m, .lastMonth, .manual]
        if tienePago { lista.insert(.scheduled, at: 0) }
        // Una línea con un método que esta lista ya no ofrece lo conserva a la vista, elegido.
        if !lista.contains(metodoInicial) { lista.insert(metodoInicial, at: 0) }
        return lista
    }

    private var esLineaCreada: Bool {
        if case .linea = origen { return true }
        return false
    }

    /// Lo que daría un método con tus registros, y cómo sale. `nil` en monto fijo.
    private func estimacion(_ metodo: EstimationMethod) -> CashFlowProjectionCalculator.LimitEstimate? {
        switch origen {
        case .sugerencia(let linea):
            guard metodo != .manual else { return nil }
            return CashFlowProjectionCalculator.LimitEstimate(
                method: metodo, amount: viewModel.previewAmount(for: linea, method: metodo),
                usedMonths: [], isolatedMonths: []
            )
        case .linea(_, _, let previews, let actual):
            if let estimate = previews[metodo] { return estimate }
            if metodo == metodoInicial, metodo != .manual {
                return .init(method: metodo, amount: actual, usedMonths: [], isolatedMonths: [])
            }
            return nil
        }
    }

    private var montoEscrito: Double? { FlujoCambiarLimiteLogica.montoEscrito(texto) }

    /// El monto que resulta del método elegido, el de arriba.
    private var resultado: Double? {
        metodo == .manual ? montoEscrito : estimacion(metodo)?.amount
    }

    private var puedeGuardar: Bool {
        if metodo == .manual { return montoEscrito != nil }
        return true
    }

    private func formato(_ valor: Double) -> String {
        appPreferences.currency(valor, currencyCode: currencyCode)
    }

    private var mesElegido: String? {
        guard case .linea(_, let monthKey, _, _) = origen,
              let date = CashFlowDetailLineRow.monthDate(monthKey) else { return nil }
        return CashFlowMonthSummaryLogic.monthName(date)
    }

    // MARK: - Vista

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                        resultadoCard
                        if metodo == .manual {
                            fijoCard
                                .id("fijo")
                            if esLineaCreada { alcanceCard }
                        }
                        metodosCard
                        Text(L10n.FlujoDetalleLinea.limitesMoviles)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("cashflow_method_moving_note")
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.lg)
                    .readableColumn()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: metodo) { anterior, nuevo in
                    guard nuevo == .manual else { campoConFoco = false; return }
                    // Parte del monto que se veía: se ajusta en vez de escribirlo desde cero.
                    if texto.isEmpty, let base = estimacion(anterior)?.amount ?? (montoInicial > 0 ? montoInicial : nil) {
                        texto = CashFlowStartingBalanceSheet.editableText(base)
                    }
                    // El campo, arriba y con el teclado: una vuelta después, cuando ya existe.
                    Task { @MainActor in
                        scroll.scrollTo("fijo", anchor: .top)
                        campoConFoco = true
                    }
                }
            }
            .accessibilityIdentifier("cashflow_method_sheet")
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.CashFlowPlan.calculationMethodTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
                YalaPrimaryButton(
                    L10n.FlujoCambiarLimite.guardar, icon: "checkmark.circle.fill",
                    isDisabled: !puedeGuardar, keepsDisabledToneInBar: true
                ) {
                    guardar()
                }
                .accessibilityIdentifier("cashflow_method_save")
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)
            }
        }
        // Grande desde el principio: a media altura, el campo del monto fijo quedaba tapado (Jürgen, 19-nov).
        .presentationDetents([.large])
    }

    // MARK: - El resultado, arriba

    private var resultadoCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(nombre)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
            Text(L10n.FlujoDetalleLinea.calculoResultado(esIngreso: esIngreso))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            AmountText(
                value: resultado ?? 0,
                currencyCode: currencyCode,
                font: DS.Typography.panelHeroAmount,
                animatesValue: true
            )
            .opacity(resultado == nil ? 0.4 : 1)
            .accessibilityIdentifier("cashflow_method_result")
            if let explicacion = explicacionDelElegido {
                Text(explicacion)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cashflow_method_result_how")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(theme.card)
        )
        .accessibilityElement(children: .combine)
    }

    /// Cómo sale el monto elegido: el método, su ventana y lo que dejó fuera; o, con monto fijo, que no cambia.
    private var explicacionDelElegido: String? {
        if metodo == .manual { return L10n.FlujoDetalleLinea.comoFijo }
        guard let estimate = estimacion(metodo), esLineaCreada else { return metodo.descriptionText }
        let aislados = L10n.FlujoDetalleLinea.listaDeMeses(estimate.isolatedMonths)
        switch metodo {
        case .average3m: return L10n.FlujoDetalleLinea.comoPromedio(meses: 3, aislados: aislados)
        case .average6m: return L10n.FlujoDetalleLinea.comoPromedio(meses: 6, aislados: aislados)
        case .average12m: return L10n.FlujoDetalleLinea.comoPromedio(meses: 12, aislados: aislados)
        case .lastMonth:
            guard let mes = estimate.usedMonths.first else { return L10n.FlujoDetalleLinea.comoSinDatos }
            return L10n.FlujoDetalleLinea.comoUltimoMes(CashFlowMonthSummaryLogic.monthInSentence(mes), aislados: aislados)
        case .trend: return L10n.FlujoDetalleLinea.comoTendencia(aislados: aislados)
        default: return metodo.descriptionText
        }
    }

    // MARK: - Monto fijo

    private var fijoCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.FlujoDetalleLinea.calculoCampoFijo)
                .font(DS.Typography.subheadlineEmphasized)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(appPreferences.currencyIdentifier(for: currencyCode))
                    .font(DS.Typography.title)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(
                    L10n.FlujoDetalleLinea.calculoCampoFijo,
                    text: $texto,
                    prompt: Text(verbatim: "0").foregroundStyle(.tertiary)
                )
                .amountKeyboard()
                .font(DS.Typography.title.weight(.bold))
                .monospacedDigit()
                .focused($campoConFoco)
                .onChange(of: texto) { _, nuevo in
                    let filtrado = AmountInputHelper.filterAmountInput(nuevo)
                    if filtrado != nuevo { texto = filtrado }
                }
                .accessibilityIdentifier("cashflow_method_manual_amount")
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(theme.card)
            )
            if montoEscrito == nil, !texto.isEmpty {
                Text(L10n.FlujoCambiarLimite.montoInvalido)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.errorForeground)
            }
        }
    }

    /// En una línea creada, qué meses cambian al escribir un monto (el alcance de «Cambiar límite», P3).
    private var alcanceCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.FlujoDetalleLinea.calculoAlcance)
                .font(DS.Typography.subheadlineEmphasized)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(FlujoCambiarLimiteLogica.Alcance.allCases.enumerated()), id: \.element) { indice, opcion in
                    if indice > 0 { Divider().padding(.leading, DS.Spacing.lg) }
                    alcanceFila(opcion)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(theme.card)
            )
        }
    }

    private func alcanceFila(_ opcion: FlujoCambiarLimiteLogica.Alcance) -> some View {
        let elegida = opcion == alcance
        return Button {
            guard opcion != alcance else { return }
            DS.Haptic.selection()
            alcance = opcion
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                Image(systemName: elegida ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.headline)
                    .foregroundStyle(elegida ? theme.accentText : Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
                Text(L10n.FlujoCambiarLimite.alcance(opcion, mes: mesElegido ?? ""))
                    .font(DS.Typography.body.weight(elegida ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Spacing.none)
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegida ? .isSelected : [])
        .accessibilityIdentifier("cashflow_method_scope_\(opcion.rawValue)")
    }

    // MARK: - Métodos

    private var metodosCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.FlujoDetalleLinea.calculoMetodos)
                .font(DS.Typography.subheadlineEmphasized)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(metodos.enumerated()), id: \.element) { indice, opcion in
                    if indice > 0 { Divider().padding(.leading, DS.Spacing.xxl + DS.Spacing.md) }
                    metodoFila(opcion)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(theme.card)
            )
        }
    }

    private func metodoFila(_ opcion: EstimationMethod) -> some View {
        let elegido = opcion == metodo
        let estimate = estimacion(opcion)
        return Button {
            guard opcion != metodo else { return }
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion, DS.Animation.selection) {
                metodo = opcion
            }
        } label: {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Image(systemName: elegido ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.headline)
                    .foregroundStyle(elegido ? theme.accentText : Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
                AdaptiveRowStack(spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(opcion.displayName)
                            .font(DS.Typography.body.weight(elegido ? .semibold : .regular))
                            .foregroundStyle(.primary)
                        Text(detalle(opcion, estimate: estimate))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } trailing: {
                    if let estimate, opcion != .manual {
                        Text(formato(estimate.amount))
                            .font(DS.Typography.amountSmall.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(elegido ? .isSelected : [])
        .accessibilityIdentifier("cashflow_method_\(opcion.rawValue)")
    }

    /// Debajo del nombre: lo que dejó fuera por aislados, o la descripción del método.
    private func detalle(_ opcion: EstimationMethod, estimate: CashFlowProjectionCalculator.LimitEstimate?) -> String {
        if let estimate, let meses = L10n.FlujoDetalleLinea.listaDeMeses(estimate.isolatedMonths) {
            return L10n.FlujoDetalleLinea.calculoSinAislados(meses)
        }
        if esLineaCreada, opcion != .manual, opcion != .scheduled, let estimate,
           estimate.usedMonths.isEmpty, estimate.amount == 0 {
            return L10n.FlujoDetalleLinea.calculoSinDatos
        }
        return opcion.descriptionText
    }

    // MARK: - Guardar

    private func guardar() {
        campoConFoco = false
        switch origen {
        case .sugerencia(let linea):
            viewModel.updateEstimationMethod(
                for: linea.id, to: metodo, manualAmount: metodo == .manual ? montoEscrito : nil
            )
        case .linea(let line, let monthKey, _, _):
            guard !line.isDeleted, line.modelContext != nil else { dismiss(); return }
            let ok: Bool
            if metodo == .manual {
                guard let monto = montoEscrito else {
                    DS.Haptic.error()
                    return
                }
                ok = viewModel.cambiarLimite(
                    line: line, monthKey: monthKey, amount: monto, alcance: alcance,
                    primerMes: viewModel.projection?.months.first?.monthKey
                )
            } else {
                ok = viewModel.aplicarMetodo(line: line, metodo: metodo, monthKey: monthKey)
            }
            guard ok else {
                DS.Haptic.error()
                return
            }
            viewModel.marcarPlanCambiado()
        }
        DS.Haptic.success()
        onSaved()
        dismiss()
    }
}

extension CashFlowPlanViewModel {

    /// Elegir un método que mira la historia en «Cálculo del monto»: vale para todos los meses y se mueve solo (límites
    /// móviles, 19-nov-2026). Retira los cambios «desde» (un monto escrito antes taparía el método en los meses que
    /// vienen) y el ajuste de un solo mes del mes desde el que se eligió (la hoja prometía la cifra del método para ese
    /// mes); los ajustes de otros meses se quedan, como hacía «Cómo se calcula · Cambiar» (L18-7). Elegir lo que ya
    /// tenía, sin nada escrito encima, no escribe nada.
    @discardableResult
    func aplicarMetodo(line: CashFlowLine, metodo: EstimationMethod, monthKey: String) -> Bool {
        guard !line.isDeleted, let ctx = line.modelContext, metodo != .manual else { return false }
        // Ajustes de ese mes: también los del legado (`overrides`) que aún no migraron.
        let ajustesDelMes = ((line.monthOverrides ?? []) + (line.overrides ?? [])).filter { $0.monthKey == monthKey }
        let mismo = line.estimationMethod == metodo.rawValue && (line.amountChangesRaw ?? "").isEmpty
            && ajustesDelMes.isEmpty
        guard !mismo else { return true }
        ajustesDelMes.forEach { ctx.delete($0) }
        line.estimationMethod = metodo.rawValue
        line.manualAmount = nil
        line.amountChangesRaw = nil
        do {
            try ctx.save()
            Self.announcePlanChange(ctx)
            return true
        } catch {
            #if DEBUG
            print("CashFlowPlanViewModel: Error cambiando el método: \(error)")
            #endif
            return false
        }
    }
}
