//
//  FlujoCambiarLimiteSheet.swift
//  Yala
//
//  «Cambiar límite» del flujo de caja (S4 del replanteo, 18-nov-2026): una sola hoja que pregunta PRIMERO qué meses
//  cambian —solo este mes / desde este mes en adelante (por defecto, P3) / todos los meses— y después el monto. Admite 0
//  y meses cerrados, y enseña cómo queda cada mes antes de guardar. La lógica: `FlujoCambiarLimiteLogica`; lo que se
//  escribe: `CashFlowPlanViewModel.cambiarLimite`.
//
//  Hoy la abre «Ajustar monto» del detalle de una línea. El detalle de línea nuevo (S3) la abrirá desde «Cambiar»: basta
//  con presentarla con `FlujoCambiarLimitePeticion`.
//

import SwiftData
import SwiftUI

/// Lo que hace falta para abrir la hoja: una línea y el mes desde el que se mira.
struct FlujoCambiarLimitePeticion: Identifiable, Equatable {
    let lineID: UUID
    let monthKey: String
    var id: String { "\(lineID.uuidString)-\(monthKey)" }
}

struct FlujoCambiarLimiteSheet: View {
    let peticion: FlujoCambiarLimitePeticion
    let line: CashFlowLine
    let currencyCode: String
    @Bindable var viewModel: CashFlowPlanViewModel
    /// Se llama tras guardar bien, antes de cerrar.
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var alcance: FlujoCambiarLimiteLogica.Alcance = .porDefecto
    @State private var texto: String = ""
    @State private var preparada = false
    /// Lo que el campo traía al abrir: si no se toca, se guarda el límite exacto, no su redondeo.
    @State private var textoInicial = ""
    @FocusState private var campoConFoco: Bool

    private typealias Logica = FlujoCambiarLimiteLogica
    private typealias Texto = L10n.FlujoCambiarLimite

    // MARK: - Datos

    /// Los meses del plan con el límite que tiene la línea en cada uno, tal como se ven hoy.
    private var meses: [Logica.Mes] {
        (viewModel.projection?.months ?? []).compactMap { mes in
            guard let lr = (mes.incomeLines + mes.expenseLines).first(where: { $0.lineID == peticion.lineID }) else {
                return nil
            }
            return Logica.Mes(
                monthKey: mes.monthKey, limite: lr.plannedAmount, tieneAjustePropio: lr.isOverride, esPasado: mes.isPast)
        }
    }

    private var mesElegido: Logica.Mes? { meses.first { $0.monthKey == peticion.monthKey } }

    private var esIngreso: Bool {
        (viewModel.projection?.months ?? []).lazy
            .compactMap { $0.incomeLines.first { $0.lineID == peticion.lineID } }
            .first != nil
    }

    private var nombreLinea: String {
        (viewModel.projection?.months ?? []).lazy
            .compactMap { ($0.incomeLines + $0.expenseLines).first { $0.lineID == peticion.lineID }?.name }
            .first ?? ""
    }

    private var monto: Double? {
        if texto == textoInicial, let exacto = mesElegido?.limite { return exacto }
        return Logica.montoEscrito(texto)
    }

    private var filas: [Logica.Fila] {
        Logica.filas(meses: meses, alcance: alcance, elegido: peticion.monthKey, monto: monto)
    }

    private func nombreMes(_ key: String) -> String {
        guard let date = CashFlowDetailLineRow.monthDate(key) else { return key }
        return CashFlowMonthSummaryLogic.monthName(date)
    }

    /// El mes como rótulo de una fila: con mayúscula inicial («Noviembre»), que dentro de una frase va en minúscula.
    private func rotuloMes(_ key: String) -> String {
        let nombre = nombreMes(key)
        return nombre.prefix(1).uppercased(with: AppLocale.current) + nombre.dropFirst()
    }

    private func formato(_ valor: Double) -> String {
        appPreferences.currency(valor, currencyCode: currencyCode)
    }

    // MARK: - Vista

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    if !nombreLinea.isEmpty {
                        Text(nombreLinea)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("flujo_cambiar_limite_linea")
                    }
                    alcanceCard
                    if mesElegido?.esPasado == true {
                        aviso(Texto.pasado(nombreMes(peticion.monthKey)))
                    }
                    montoCard
                    vistaPrevia
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
                .readableColumn()
            }
            // Al bajar a «Así quedan» el teclado se va: si no, tapa la vista previa.
            .scrollDismissesKeyboard(.immediately)
            .accessibilityIdentifier("flujo_cambiar_limite")
            .yalaScreenBackground(.subtle)
            .navigationTitle(Texto.titulo(esIngreso: esIngreso))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.cancel) {
                        dismiss()
                    }
                    .accessibilityIdentifier("flujo_cambiar_limite_cancelar")
                }
            }
            .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
                YalaPrimaryButton(
                    Texto.guardar, icon: "checkmark.circle.fill",
                    isDisabled: monto == nil, keepsDisabledToneInBar: true
                ) {
                    guardar()
                }
                .accessibilityIdentifier("flujo_cambiar_limite_guardar")
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: preparar)
    }

    private func preparar() {
        guard !preparada else { return }
        preparada = true
        texto = CashFlowStartingBalanceSheet.editableText(mesElegido?.limite ?? 0)
        textoInicial = texto
    }

    private func guardar() {
        guard let monto else {
            DS.Haptic.error()
            return
        }
        campoConFoco = false
        let ok = viewModel.cambiarLimite(
            line: line, monthKey: peticion.monthKey, amount: monto, alcance: alcance, primerMes: meses.first?.monthKey
        )
        guard ok else {
            DS.Haptic.error()
            return
        }
        DS.Haptic.success()
        onSaved()
        dismiss()
    }

    // MARK: - Alcance

    private var alcanceCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(Texto.alcanceTitulo)
                .font(DS.Typography.subheadlineEmphasized)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(Logica.Alcance.allCases.enumerated()), id: \.element) { indice, opcion in
                    if indice > 0 {
                        Divider().padding(.leading, DS.Spacing.lg)
                    }
                    opcionFila(opcion)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(theme.card)
            )
        }
    }

    private func opcionFila(_ opcion: Logica.Alcance) -> some View {
        let elegida = opcion == alcance
        return Button {
            guard opcion != alcance else { return }
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion, DS.Animation.selection) {
                alcance = opcion
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                Image(systemName: elegida ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.headline)
                    .foregroundStyle(elegida ? theme.accentText : Color(uiColor: .tertiaryLabel))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(Texto.alcance(opcion, mes: nombreMes(peticion.monthKey)))
                        .font(DS.Typography.body.weight(elegida ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(descripcion(opcion))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.none)
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegida ? .isSelected : [])
        .accessibilityIdentifier("flujo_cambiar_limite_alcance_\(opcion.rawValue)")
    }

    private func descripcion(_ opcion: Logica.Alcance) -> String {
        switch opcion {
        case .soloEsteMes:
            return Texto.descripcionSolo
        case .desdeEsteMes:
            let conservan = Logica.conservanAjuste(meses: meses, elegido: peticion.monthKey)
            guard !conservan.isEmpty else { return Texto.descripcionDesde }
            let lista = conservan.map(nombreMes).formatted(.list(type: .and).locale(AppLocale.current))
            return Texto.descripcionDesde + " " + Texto.conservan(lista)
        case .todos:
            return Texto.descripcionTodos
        }
    }

    // MARK: - Monto

    private var montoCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(Texto.montoRotulo(alcance, mes: nombreMes(peticion.monthKey), esIngreso: esIngreso))
                .font(DS.Typography.subheadlineEmphasized)
                .accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(appPreferences.currencyIdentifier(for: currencyCode))
                    .font(DS.Typography.title)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(
                    Texto.montoRotulo(alcance, mes: nombreMes(peticion.monthKey), esIngreso: esIngreso),
                    text: $texto,
                    prompt: Text(verbatim: "0").foregroundStyle(.tertiary)
                )
                .amountKeyboard()
                .font(DS.Typography.title.weight(.bold))
                .monospacedDigit()
                .focused($campoConFoco)
                .onChange(of: texto) { _, nuevo in filtrar(nuevo) }
                .accessibilityIdentifier("flujo_cambiar_limite_monto")
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(theme.card)
            )
            if let actual = mesElegido?.limite {
                Text(Texto.ahora(formato(actual)))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("flujo_cambiar_limite_ahora")
            }
            if monto == nil {
                Text(Texto.montoInvalido)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.errorForeground)
            } else if monto == 0 {
                Text(Texto.cero(esIngreso: esIngreso))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("flujo_cambiar_limite_cero")
            }
        }
    }

    private func filtrar(_ nuevo: String) {
        let filtrado = AmountInputHelper.filterAmountInput(nuevo)
        if filtrado != nuevo { texto = filtrado }
    }

    private func aviso(_ mensaje: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(mensaje)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("flujo_cambiar_limite_pasado")
    }

    // MARK: - Así quedan

    @ViewBuilder
    private var vistaPrevia: some View {
        let filas = self.filas
        if !filas.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(Texto.vistaPrevia)
                    .font(DS.Typography.subheadlineEmphasized)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: DS.Spacing.none) {
                    ForEach(Array(filas.enumerated()), id: \.element.monthKey) { indice, fila in
                        if indice > 0 {
                            Divider().padding(.leading, DS.Spacing.lg)
                        }
                        filaVista(fila)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(theme.card)
                )
            }
        }
    }

    private func filaVista(_ fila: Logica.Fila) -> some View {
        let esElegido = fila.monthKey == peticion.monthKey
        let nombre = Text(rotuloMes(fila.monthKey))
            .font(DS.Typography.body.weight(esElegido ? .semibold : .regular))
            .foregroundStyle(fila.cambia ? .primary : .secondary)
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    nombre
                    valores(fila)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Los montos no se parten: si la fila no cabe, el que pasa a dos líneas es el nombre del mes.
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                    nombre
                    Spacer(minLength: DS.Spacing.sm)
                    valores(fila)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(etiqueta(fila))
        .accessibilityIdentifier("flujo_cambiar_limite_fila_\(fila.monthKey)")
    }

    @ViewBuilder
    private func valores(_ fila: Logica.Fila) -> some View {
        if fila.cambia && !Logica.mismoMonto(fila.antes, fila.despues) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(formato(fila.antes))
                    .font(DS.Typography.caption)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                Text(formato(fila.despues))
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .monospacedDigit()
        } else if fila.cambia {
            Text(formato(fila.despues))
                .font(DS.Typography.body)
                .monospacedDigit()
        } else {
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: DS.Spacing.none) {
                Text(formato(fila.antes))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(fila.conservaAjuste ? Texto.ajustePropio : Texto.sinCambio)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func etiqueta(_ fila: Logica.Fila) -> String {
        let mes = rotuloMes(fila.monthKey)
        if fila.cambia && !Logica.mismoMonto(fila.antes, fila.despues) {
            return Texto.filaCambia(mes: mes, antes: formato(fila.antes), despues: formato(fila.despues))
        }
        if fila.cambia { return "\(mes), \(formato(fila.despues))" }
        let motivo = fila.conservaAjuste ? Texto.ajustePropio : Texto.sinCambio
        return "\(mes), \(formato(fila.antes)), \(motivo)"
    }
}
