//
//  AsistenteCuentaView.swift
//  Yala
//
//  «Nueva cuenta» por pasos (encargo del 18-nov): una pregunta por pantalla con el valor sugerido ya elegido, «Usar
//  formulario» arriba y, al final, el resumen con la tarjeta de la cuenta y «Crear cuenta». Segundo asistente sobre
//  `AsistenteCreacionView`. Las preguntas, sus textos y el guardado son los de «Primera cuenta» de Primeros pasos
//  (`L10n.PrimerosPasos23.Account`, `FirstAccountCreator`), con una sola moneda, como el formulario. Lo que no pregunta
//  (número de cuenta, «Excluir de las estadísticas», color propio) queda como en el formulario recién abierto, y se
//  cambia después en Editar cuenta.
//

import SwiftData
import SwiftUI

struct AsistenteCuentaView: View {
    typealias Logica = AsistenteCuentaLogica
    private typealias T = L10n.PrimerosPasos23.Account
    private typealias A = L10n.AsistenteCuenta

    @Bindable var estado: AsistenteCuentaEstado
    /// Se creó la cuenta, o se descartó: quien presenta cierra la hoja.
    let alCerrar: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppPreferences.self) private var appPreferences

    @State private var creando = false
    @State private var fallo = false
    @State private var eligeOtraMoneda = false
    @FocusState private var campo: Campo?

    private enum Campo: Hashable { case nombre, saldo }

    private var paso: Logica.Paso { estado.navegador.actual }
    private var esTarjeta: Bool { estado.tipo.isCard }
    private var tituloCrear: String { dynamicTypeSize.isAccessibilitySize ? A.crearCorto : A.crear }

    var body: some View {
        AsistenteCreacionView(
            titulo: A.titulo,
            pregunta: pregunta,
            detalle: detalle,
            indice: estado.navegador.indice(en: estado.pasos),
            total: estado.pasos.count,
            identidad: paso.rawValue,
            tituloPrincipal: paso == .resumen ? tituloCrear : L10n.Action.next,
            puedeSeguir: estado.puedeSeguir && !creando,
            puedeRetroceder: estado.navegador.puedeRetroceder,
            tieneRespuestas: estado.navegador.tieneRespuestas,
            tituloDescartar: A.descartarTitulo,
            ocupado: creando,
            alSeguir: seguir,
            alRetroceder: retroceder,
            alUsarFormulario: { estado.usarFormulario() },
            alCerrar: alCerrar
        ) {
            respuesta
        }
        .onChange(of: paso) { _, nuevo in alEntrar(en: nuevo) }
        .sheet(isPresented: $eligeOtraMoneda) {
            AsistenteCuentaSelectorMoneda(inicial: CurrencyCode(rawValue: estado.moneda) ?? .usd) { codigo in
                estado.moneda = codigo.rawValue
            }
        }
        .alert(L10n.Common.error, isPresented: $fallo) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Common.saveError)
        }
    }

    // MARK: - Pregunta

    private var pregunta: String {
        switch paso {
        case .tipo: return A.tipoPregunta
        case .moneda: return esTarjeta ? T.currencyQuestionCard : T.currencyQuestion
        case .nombre: return T.nameEditQuestion
        case .saldo: return esTarjeta ? T.balanceQuestionCardSingle : T.balanceQuestionSingle
        case .cierre: return T.statementQuestion
        case .pago: return T.paymentQuestion
        case .recordatorio: return T.reminderQuestion
        case .resumen: return A.resumenPregunta
        }
    }

    private var detalle: String? {
        switch paso {
        case .tipo: return A.tipoDetalle
        case .moneda: return esTarjeta ? A.monedaDetalleTarjeta : A.monedaDetalle
        case .nombre: return T.nameSubtitle
        case .saldo: return esTarjeta ? T.balanceSubtitleCard : T.balanceSubtitle
        case .cierre: return T.statementSubtitle
        case .pago: return T.paymentSubtitle
        case .recordatorio:
            return estado.diaDeCierre == nil ? T.reminderSubtitleNoStatement : T.reminderSubtitle
        case .resumen: return A.resumenDetalle
        }
    }

    // MARK: - Respuesta

    @ViewBuilder
    private var respuesta: some View {
        switch paso {
        case .tipo: tipo
        case .moneda: moneda
        case .nombre: nombre
        case .saldo: saldo
        case .cierre: dia($estado.diaDeCierre, id: "asistente_cuenta_cierre")
        case .pago: dia($estado.diaDePago, id: "asistente_cuenta_pago")
        case .recordatorio: recordatorio
        case .resumen: resumen
        }
    }

    private var tipo: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(Logica.Tipo.allCases, id: \.self) { tipo in
                AsistenteOpcion(
                    titulo: FirstAccountFlowView.kindTitle(tipo),
                    detalle: FirstAccountFlowView.kindHint(tipo),
                    icono: iconName(for: tipo.accountType),
                    elegida: estado.tipo == tipo,
                    id: "asistente_cuenta_tipo_\(tipo.rawValue)"
                ) {
                    estado.tipo = tipo
                }
            }
        }
    }

    private var moneda: some View {
        let opciones = Logica.opcionesDeMoneda(
            principal: appPreferences.defaultCurrencyCode.rawValue,
            secundarias: appPreferences.secondaryCurrencies,
            elegida: estado.moneda
        )
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(opciones, id: \.self) { codigo in
                AsistenteOpcion(
                    titulo: Self.nombreMoneda(codigo),
                    detalle: "\(codigo) · \(CurrencyCode(rawValue: codigo)?.symbol ?? codigo)",
                    elegida: estado.moneda == codigo,
                    id: "asistente_cuenta_moneda_\(codigo)"
                ) {
                    estado.moneda = codigo
                }
            }
            AsistenteOpcion(
                titulo: A.otraMoneda,
                detalle: A.otraMonedaPista,
                icono: "globe",
                elegida: false,
                id: "asistente_cuenta_moneda_otra"
            ) {
                eligeOtraMoneda = true
            }
        }
    }

    private var nombre: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            AsistenteTarjeta {
                TextField("", text: $estado.nombre, prompt: Text(T.namePlaceholder).yalaFieldPrompt())
                    .font(DS.Typography.title3)
                    .yalaFieldText()
                    .focused($campo, equals: .nombre)
                    .submitLabel(.next)
                    .onSubmit { if estado.puedeSeguir { seguir() } }
                    .onChange(of: estado.nombre) { _, _ in
                        if campo == .nombre { estado.nombreEditado = true }
                    }
                    .padding(DS.Spacing.lg)
                    .accessibilityLabel(T.nameEditQuestion)
                    .accessibilityIdentifier("asistente_cuenta_nombre")
            }
            if estado.nombreRepetido {
                Label(A.nombreRepetido, systemImage: "exclamationmark.circle.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(DS.Semantic.errorForeground)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("asistente_cuenta_nombre_repetido")
            }
        }
    }

    private var saldo: some View {
        AsistenteTarjeta {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                // En tarjeta lo escrito es siempre lo que se debe: sin signo.
                if !esTarjeta {
                    Button {
                        DS.Haptic.selection()
                        estado.saldoNegativo.toggle()
                    } label: {
                        Text(verbatim: estado.saldoNegativo ? "−" : "+")
                            .font(DS.Typography.title2.weight(.bold))
                            .foregroundStyle(estado.saldoNegativo ? Color.hotPink : Color.primary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.primary.opacity(0.08)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(estado.saldoNegativo ? T.signNegative : T.signPositive)
                    .accessibilityIdentifier("asistente_cuenta_signo")
                }
                Text(CurrencyCode(rawValue: estado.moneda)?.symbol ?? estado.moneda)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("", text: $estado.saldoTexto, prompt: Text(verbatim: "0").yalaFieldPrompt())
                    .font(DS.Typography.largeTitle.weight(.bold))
                    .yalaFieldText()
                    .amountKeyboard()
                    .focused($campo, equals: .saldo)
                    .onChange(of: estado.saldoTexto) { _, nuevo in filtrarSaldo(nuevo) }
                    .accessibilityLabel(pregunta)
                    .accessibilityIdentifier("asistente_cuenta_saldo")
            }
            .padding(DS.Spacing.lg)
        }
    }

    /// Un día del 1 al 31, o «No lo sé» (arriba, el sugerido).
    private func dia(_ seleccion: Binding<Int?>, id: String) -> some View {
        AsistenteTarjeta {
            Picker(A.diaEtiqueta, selection: seleccion) {
                Text(T.dontKnow).tag(Int?.none)
                ForEach(1...31, id: \.self) { dia in
                    Text(A.dia(dia)).tag(Int?.some(dia))
                }
            }
            .pickerStyle(.wheel)
            .accessibilityLabel(A.diaEtiqueta)
            .accessibilityIdentifier(id)
            .padding(.horizontal, DS.Spacing.sm)
        }
    }

    private var recordatorio: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(Logica.opcionesDeRecordatorio(diaDeCierre: estado.diaDeCierre), id: \.self) { dias in
                AsistenteOpcion(
                    titulo: FirstAccountFlowView.reminderLabel(dias),
                    icono: "bell.fill",
                    elegida: estado.recordatorio == dias,
                    id: "asistente_cuenta_recordatorio_\(dias)"
                ) {
                    estado.recordatorio = dias
                }
            }
            AsistenteOpcion(
                titulo: T.noReminder,
                icono: "bell.slash.fill",
                elegida: estado.recordatorio == nil,
                id: "asistente_cuenta_recordatorio_ninguno"
            ) {
                estado.recordatorio = nil
            }
        }
    }

    // MARK: - Resumen

    private var resumen: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            FirstAccountCardPreview(
                draft: Logica.borrador(estado.respuestas),
                suggestedName: Logica.nombreLimpio(estado.nombre)
            )
            AsistenteTarjeta {
                fila(.tipo, A.resumenTipo, FirstAccountFlowView.kindTitle(estado.tipo))
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.moneda, A.resumenMoneda, valorMoneda)
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.nombre, A.resumenNombre, Logica.nombreLimpio(estado.nombre))
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.saldo, esTarjeta ? A.resumenDeuda : A.resumenSaldo, valorSaldo)
                if esTarjeta {
                    Divider().padding(.leading, DS.Spacing.lg)
                    fila(.cierre, A.resumenCierre, valorDia(estado.diaDeCierre))
                    Divider().padding(.leading, DS.Spacing.lg)
                    fila(.pago, A.resumenPago, valorDia(estado.diaDePago))
                    if estado.diaDePago != nil {
                        Divider().padding(.leading, DS.Spacing.lg)
                        fila(.recordatorio, A.resumenRecordatorio, valorRecordatorio)
                    }
                }
            }
        }
    }

    private func fila(_ destino: Logica.Paso, _ etiqueta: String, _ valor: String) -> some View {
        AsistenteResumenFila(etiqueta: etiqueta, valor: valor, id: "asistente_cuenta_resumen_\(destino.rawValue)") {
            estado.navegador.cambiar(destino, desde: .resumen)
        }
    }

    private var valorMoneda: String {
        "\(Self.nombreMoneda(estado.moneda)) (\(estado.moneda))"
    }

    /// «Sol peruano»: el nombre de la moneda con la primera letra en mayúscula (el catálogo lo da en minúscula, para
    /// usarlo dentro de una frase).
    static func nombreMoneda(_ codigo: String) -> String {
        guard let nombre = CurrencyCode(rawValue: codigo)?.localizedName, let primera = nombre.first else {
            return codigo
        }
        return String(primera).localizedCapitalized + nombre.dropFirst()
    }

    private var valorSaldo: String {
        let guardado = Logica.saldoGuardado(estado.respuestas)
        let texto = appPreferences.currency(abs(guardado), currencyCode: estado.moneda)
        return !esTarjeta && guardado < 0 ? "−" + texto : texto
    }

    private func valorDia(_ dia: Int?) -> String {
        dia.map { A.dia($0) } ?? T.dontKnow
    }

    private var valorRecordatorio: String {
        estado.recordatorio.map { FirstAccountFlowView.reminderLabel($0) } ?? T.noReminder
    }

    // MARK: - Avance

    private func alEntrar(en paso: Logica.Paso) {
        campo = nil
        switch paso {
        case .nombre:
            if !estado.nombreEditado || Logica.nombreLimpio(estado.nombre).isEmpty {
                estado.nombre = estado.nombrePropuesto(FirstAccountFlowView.suggestedName(for: estado.tipo))
                estado.nombreEditado = false
            }
        case .recordatorio:
            estado.prepararRecordatorio()
        default:
            break
        }
    }

    private func filtrarSaldo(_ texto: String) {
        let filtrado = AmountInputHelper.filterAmountInput(texto)
        if filtrado != texto { estado.saldoTexto = filtrado }
    }

    private func seguir() {
        guard estado.puedeSeguir else { return }
        switch paso {
        case .resumen:
            crear()
        case .recordatorio where estado.recordatorio != nil:
            pedirPermisoYSeguir()
        default:
            estado.navegador.avanzar(en: estado.pasos)
        }
    }

    private func retroceder() {
        estado.navegador.retroceder(en: estado.pasos)
    }

    /// Elegir un recordatorio pide el permiso de iOS si nunca se pidió, como Primeros pasos (Y23-17).
    private func pedirPermisoYSeguir() {
        guard !creando else { return }
        creando = true
        Task { @MainActor in
            var permitido = true
            #if DEBUG
            if !UITestHooks.isActive { permitido = await TutorialPermissionMoments.remindMeChosen() }
            #else
            permitido = await TutorialPermissionMoments.remindMeChosen()
            #endif
            creando = false
            guard estado.navegador.actual == .recordatorio else { return }
            estado.avisosPermitidos = permitido
            estado.navegador.avanzar(en: estado.pasos)
        }
    }

    /// Crea con el mismo guardado que Primeros pasos: la cuenta con su tipo y color, el saldo inicial y, en tarjeta, los
    /// días y el recordatorio (lo programa `CreditCardReminderScheduler` al subir `dataVersion`).
    private func crear() {
        guard !creando else { return }
        creando = true
        defer { creando = false }
        let nombre = Logica.nombreLimpio(estado.nombre)
        do {
            try FirstAccountCreator.create(Logica.borrador(estado.respuestas), suggestedName: nombre, in: modelContext)
        } catch {
            #if DEBUG
            print("AsistenteCuentaView: Error: creating the account: \(error)")
            #endif
            fallo = true
            return
        }
        DS.Haptic.success()
        alCerrar()
    }
}

/// El selector de monedas de la app, con la elegida marcada: solo avisa si se elige otra.
private struct AsistenteCuentaSelectorMoneda: View {
    let alElegir: (CurrencyCode) -> Void
    @State private var seleccion: CurrencyCode

    init(inicial: CurrencyCode, alElegir: @escaping (CurrencyCode) -> Void) {
        _seleccion = State(initialValue: inicial)
        self.alElegir = alElegir
    }

    var body: some View {
        CurrencyPickerSheet(selectedCurrency: $seleccion)
            .onChange(of: seleccion) { _, codigo in alElegir(codigo) }
    }
}
