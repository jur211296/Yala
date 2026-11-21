//
//  AsistentePagoPlanificadoView.swift
//  Yala
//
//  «Nuevo pago planificado» por pasos (encargo del 17-nov): una pregunta por pantalla con lo sugerido ya elegido,
//  «Usar formulario» arriba y, al final, el resumen con «Crear pago». Segundo asistente sobre `AsistenteCreacionView`
//  (molde: `AsistentePresupuestoView`). Las respuestas de tipo, día y aviso son las de Primeros pasos
//  (`FirstScheduledPaymentFlowView`). Desde el 21-nov pregunta también si es un gasto compartido (solo con algún grupo
//  activo: grupo, moneda y división) y «¿Algo más?» (cuenta, descripción, etiquetas, fecha de fin y activo, ya puestos),
//  en `AsistentePagoCompartidoPasos`, y guarda con `AsistentePagoPlanificadoCreador`. Lo que no pregunta (cobro en vez
//  de pago, «Cada N») queda como en el formulario recién abierto.
//

import SwiftData
import SwiftUI

struct AsistentePagoPlanificadoView: View {
    typealias Logica = AsistentePagoPlanificadoLogica
    private typealias T = L10n.PrimerosPasos23.Payment
    private typealias P = L10n.PrimerosPasos23.Plan
    private typealias A = L10n.AsistentePagoPlanificado
    private typealias Flujo = FirstScheduledPaymentFlowView

    @Bindable var estado: AsistentePagoPlanificadoEstado
    /// Se guardó el pago (para el aviso «Primer pago: …» de la lista).
    let alGuardar: (UUID) -> Void
    /// Se creó el pago, o se descartó: quien presenta cierra la hoja.
    let alCerrar: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppPreferences.self) private var appPreferences

    // Datos de la persona (se vuelven a leer si el contenido se rehace: no son respuestas).
    @State private var subcategoriasPorTipo: [Logica.Tipo: Subcategory] = [:]
    @State private var cuentaNombre = ""
    @State private var moneda = CurrencyCode.usd.rawValue
    @State private var didLoad = false
    @State private var muestraOtra = false
    /// La subcategoría elegida en «Otra subcategoría» (la hoja escribe aquí).
    @State private var otra: Subcategory?
    @State private var otraAlAbrir: PersistentIdentifier?
    @State private var creando = false
    @State private var fallo = false
    @State private var muestraPermiso = false
    /// Los grupos activos (no archivados ni ocultos), las cuentas y las etiquetas: datos, no respuestas.
    @State private var grupos: [SplitGroup] = []
    @State private var miembrosPorZona: [String: Int] = [:]
    @State private var cuentas: [Account] = []
    @State private var etiquetas: [Tag] = []
    @State private var cuentaPorDefecto: Account?
    @FocusState private var nombreEnfocado: Bool
    @FocusState private var montoEnfocado: Bool

    private var paso: Logica.Paso { estado.navegador.actual }
    private var draft: FirstScheduledPaymentDraft { estado.draft }
    private var tituloCrear: String {
        dynamicTypeSize.isAccessibilitySize ? A.crearCorto : A.crear
    }

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
            alRetroceder: { estado.navegador.retroceder(en: estado.pasos) },
            alUsarFormulario: { estado.usarFormulario() },
            alCerrar: alCerrar
        ) {
            respuesta
        }
        .onAppear(perform: cargar)
        .onChange(of: paso) { _, nuevo in alEntrar(en: nuevo) }
        .modifier(AsistentePagoPresentaciones(
            muestraOtra: $muestraOtra, otra: $otra, alCerrarOtra: aplicarOtra,
            fallo: $fallo, muestraPermiso: $muestraPermiso, alCerrarPermiso: alCerrar
        ))
    }

    // MARK: - Pregunta

    private var pregunta: String {
        switch paso {
        case .tipo: return T.kindQuestion
        case .nombre: return A.nombrePregunta
        case .monto: return A.montoPregunta
        case .compartido: return A.compartidoPregunta
        case .reparto: return A.repartoPregunta
        case .frecuencia: return A.frecuenciaPregunta
        case .dia: return A.diaPregunta(draft.frequency)
        case .aviso: return T.reminderQuestion
        case .algoMas: return A.algoMasPregunta
        case .resumen: return A.resumenPregunta
        }
    }

    private var detalle: String? {
        switch paso {
        case .tipo: return T.kindSubtitle
        case .nombre: return A.nombreDetalle
        case .monto: return A.montoDetalle
        case .compartido: return A.compartidoDetalle
        case .reparto: return A.repartoDetalle
        case .frecuencia: return A.frecuenciaDetalle
        case .dia: return A.diaDetalle
        case .aviso: return T.reminderSubtitle
        case .algoMas: return A.algoMasDetalle
        case .resumen: return A.resumenDetalle
        }
    }

    // MARK: - Respuesta

    @ViewBuilder
    private var respuesta: some View {
        switch paso {
        case .tipo: tipo
        case .nombre: nombre
        case .monto: monto
        case .compartido:
            AsistentePasoCompartido(estado: estado, grupos: grupos,
                                    miembrosActivos: { miembrosPorZona[$0.cloudKitZoneID] ?? 0 })
        case .reparto: AsistentePasoReparto(estado: estado, grupos: grupos)
        case .frecuencia: frecuencia
        case .dia: dia
        case .aviso: aviso
        case .algoMas:
            AsistentePasoAlgoMas(estado: estado, cuentas: cuentas, etiquetas: etiquetas,
                                 cuentaPorDefecto: cuentaPorDefectoActual)
        case .resumen: resumen
        }
    }

    private var tipo: some View {
        VStack(spacing: DS.Spacing.md) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm),
                                     count: TutorialGridColumns.count(3, dynamicTypeSize: dynamicTypeSize)),
                      spacing: DS.Spacing.sm) {
                ForEach(Logica.Tipo.allCases.filter { subcategoriasPorTipo[$0] != nil }) { tipo in
                    TutorialSelectableTile(
                        icon: tipo.seedIcon,
                        color: color(de: subcategoriasPorTipo[tipo]),
                        title: Flujo.kindTitle(tipo),
                        isOn: draft.kind == tipo,
                        id: "asistente_pago_tipo_\(tipo.rawValue)"
                    ) { elegir(tipo) }
                }
            }
            if draft.kind == nil, let otra = subcategoriaElegida {
                AsistenteOpcion(titulo: otra.name, detalle: otra.category?.name, icono: otra.iconName ?? "tag.fill",
                                elegida: true, id: "asistente_pago_otra_elegida") { abrirOtra() }
            } else {
                Button(T.otherSubcategory, action: abrirOtra)
                    .font(DS.Typography.body.weight(.semibold))
                    .foregroundStyle(theme.accentText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("asistente_pago_otra")
            }
            TutorialToggleRow(title: T.isSubscription, hint: T.isSubscriptionHint, isOn: $estado.draft.isSubscription,
                              id: "asistente_pago_suscripcion")
        }
    }

    private var nombre: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AsistenteTarjeta {
                TextField("", text: $estado.draft.name, prompt: Text(T.detailsNamePlaceholder).yalaFieldPrompt())
                    .font(DS.Typography.title3)
                    .yalaFieldText()
                    .focused($nombreEnfocado)
                    .submitLabel(.next)
                    .onSubmit { if estado.puedeSeguir { seguir() } }
                    .onChange(of: estado.draft.name) { _, _ in
                        if nombreEnfocado { estado.nombreEditado = true }
                    }
                    .padding(DS.Spacing.lg)
                    .accessibilityLabel(A.nombrePregunta)
                    .accessibilityIdentifier("asistente_pago_nombre")
            }
            if let tipo = draft.kind {
                FlowLayout(spacing: DS.Spacing.sm) {
                    ForEach(Flujo.examples(for: tipo), id: \.self) { ejemplo in
                        TutorialChip(title: ejemplo, isOn: draft.name == ejemplo, id: "asistente_pago_ejemplo") {
                            estado.draft.name = ejemplo
                            estado.nombreEditado = true
                            nombreEnfocado = false
                        }
                    }
                }
            }
        }
    }

    private var monto: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AsistenteTarjeta {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(CurrencyCode(rawValue: moneda)?.symbol ?? moneda)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("", text: $estado.montoTexto, prompt: Text(verbatim: "0").yalaFieldPrompt())
                        .font(DS.Typography.largeTitle.weight(.bold))
                        .yalaFieldText()
                        .amountKeyboard()
                        .focused($montoEnfocado)
                        .onChange(of: estado.montoTexto) { _, nuevo in filtrarMonto(nuevo) }
                        .accessibilityLabel(A.montoPregunta)
                        .accessibilityIdentifier("asistente_pago_monto")
                }
                .padding(DS.Spacing.lg)
            }
            TutorialToggleRow(title: T.detailsVariable, hint: T.detailsVariableHint,
                              isOn: $estado.draft.isVariableAmount, id: "asistente_pago_variable")
        }
    }

    private var frecuencia: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(Logica.Frecuencia.allCases) { opcion in
                AsistenteOpcion(titulo: Flujo.frequencyTitle(opcion), detalle: A.frecuenciaPista(opcion),
                                elegida: draft.frequency == opcion, id: "asistente_pago_frecuencia_\(opcion.rawValue)") {
                    estado.draft.frequency = opcion
                }
            }
        }
    }

    @ViewBuilder
    private var dia: some View {
        switch draft.frequency {
        case .monthly: diaDelMes
        case .weekly: diaDeLaSemana
        case .yearly, .once:
            AsistenteTarjeta {
                DatePicker(T.whenDate, selection: $estado.draft.date, in: rangoDeFechas, displayedComponents: .date)
                    .padding(DS.Spacing.md)
                    .accessibilityIdentifier("asistente_pago_fecha")
            }
        }
    }

    /// «Una vez», de hoy en adelante (como el formulario de un pago nuevo); «Cada año», cualquier fecha (cuenta el día y
    /// el mes).
    private var rangoDeFechas: PartialRangeFrom<Date> {
        draft.frequency == .once ? Calendar.current.startOfDay(for: .now)... : Date.distantPast...
    }

    private var diaDelMes: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(Logica.diasDelMes(), id: \.self) { numero in
                    TutorialChip(title: "\(numero)", isOn: draft.dayOfMonth == numero, id: "asistente_pago_dia_\(numero)") {
                        estado.draft.dayOfMonth = numero
                    }
                }
            }
            AsistenteTarjeta {
                // Un `Picker` de menú fuera de una lista solo pinta el valor: el rótulo va en su fila.
                HStack(spacing: DS.Spacing.sm) {
                    Text(A.otroDia)
                        .font(DS.Typography.body)
                    Spacer(minLength: DS.Spacing.sm)
                    Picker(A.otroDia, selection: $estado.draft.dayOfMonth) {
                        ForEach(1...31, id: \.self) { numero in
                            Text(verbatim: "\(numero)").tag(numero)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityLabel(A.otroDia)
                    .accessibilityIdentifier("asistente_pago_otro_dia")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
            }
        }
    }

    private var diaDeLaSemana: some View {
        let nombres = Calendar.current.standaloneWeekdaySymbols
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(FirstScheduledPaymentFlowLogic.weekdaysMondayFirst, id: \.self) { dia in
                AsistenteOpcion(titulo: nombres[dia - 1].capitalized(with: AppLocale.current),
                                elegida: draft.weekday == dia, id: "asistente_pago_semana_\(dia)") {
                    estado.draft.weekday = dia
                }
            }
        }
    }

    private var aviso: some View {
        let opciones: [(Logica.Aviso, String, String)] = [
            (.threeDaysBefore, T.reminderThreeDays, "bell.badge.fill"),
            (.oneDayBefore, T.reminderOneDay, "bell.fill"),
            (.sameDay, T.reminderSameDay, "calendar.badge.clock"),
            (.none, P.noThanks, "bell.slash.fill"),
        ]
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(opciones, id: \.0) { opcion, titulo, icono in
                AsistenteOpcion(titulo: titulo, icono: icono, elegida: (draft.reminder ?? Logica.Aviso.none) == opcion,
                                id: "asistente_pago_aviso_\(opcion.rawValue)") {
                    estado.draft.reminder = opcion
                }
            }
        }
    }

    // MARK: - Resumen

    private var resumen: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            FirstPaymentCardPreview(
                name: Logica.nombreLimpio(draft.name),
                look: aspecto,
                due: primerPago.map { TutorialPlanningMath.dueInText($0) },
                // La tarjeta pone ella el «≈» y el signo (como en Primeros pasos): el monto va sin marca.
                // Compartido, tu parte: es lo que la lista enseñará del pago (el total va en la frase y en «Monto»).
                amount: montoDeLaTarjeta.map { appPreferences.currency($0, currencyCode: monedaVisible) },
                isEstimate: draft.isVariableAmount,
                subcategoryName: subcategoriaElegida?.name,
                accountName: cuentaPorDefectoActual?.name ?? cuentaNombre,
                isSubscription: draft.isSubscription,
                summary: frase
            )
            AsistenteTarjeta {
                fila(.tipo, A.resumenTipo, valorTipo)
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.nombre, A.resumenNombre, Logica.nombreLimpio(draft.name))
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.monto, A.resumenMonto, estado.monto.map(dinero) ?? "—")
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.frecuencia, A.resumenFrecuencia, Flujo.frequencyTitle(draft.frequency))
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.dia, A.resumenCuando, valorCuando)
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.aviso, A.resumenAviso, valorAviso)
                if estado.tieneGrupos {
                    Divider().padding(.leading, DS.Spacing.lg)
                    fila(.compartido, A.resumenCompartido, valorCompartido)
                    if estado.reparto.grupoZona != nil {
                        Divider().padding(.leading, DS.Spacing.lg)
                        fila(.reparto, A.resumenDivision, valorDivision)
                    }
                }
            }
            AsistenteTarjeta {
                fila(.algoMas, A.resumenCuenta, cuentaPorDefectoActual?.name ?? "—")
                if !Logica.nombreLimpio(estado.extras.note).isEmpty {
                    Divider().padding(.leading, DS.Spacing.lg)
                    fila(.algoMas, A.resumenNota, Logica.nombreLimpio(estado.extras.note))
                }
                if estado.reparto.grupoZona == nil && !estado.extras.tagIDs.isEmpty {
                    Divider().padding(.leading, DS.Spacing.lg)
                    fila(.algoMas, A.resumenEtiquetas, valorEtiquetas)
                }
                if let fin = estado.extras.endDate, draft.frequency.isRecurring {
                    Divider().padding(.leading, DS.Spacing.lg)
                    fila(.algoMas, A.resumenTermina, ScheduledPaymentDateText.dayMonthLong(fin))
                }
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.algoMas, A.resumenEstado, estado.extras.isActive ? L10n.Scheduled.Editor.active : A.pausado)
            }
        }
    }

    /// «No, es solo mío» o el nombre del grupo.
    private var valorCompartido: String {
        guard let zona = estado.reparto.grupoZona else { return A.soloMio }
        return grupos.first { $0.cloudKitZoneID == zona }?.name ?? "—"
    }

    /// «Entre 2 · Partes iguales · Tu parte S/ 60.00».
    private var valorDivision: String {
        guard estado.reparto.listo else { return NSLocalizedString("common.select", comment: "") }
        let parte = appPreferences.currency(estado.reparto.miParte, currencyCode: estado.reparto.moneda,
                                            isEstimate: draft.isVariableAmount)
        return L10n.Scheduled.GroupExpense.splitSummary(estado.reparto.participantes.count,
                                                        estado.reparto.tipo.shortName, parte)
    }

    private var valorEtiquetas: String {
        etiquetas.filter { estado.extras.tagIDs.contains($0.persistentModelID) }.map(\.name)
            .formatted(.list(type: .and).locale(AppLocale.current))
    }

    /// La cuenta con la que se guardará: la elegida en «¿Algo más?» o la última usada (de la moneda del gasto, si es
    /// compartido).
    private var cuentaPorDefectoActual: Account? {
        let moneda = estado.reparto.grupoZona == nil ? nil : estado.reparto.moneda
        if let id = estado.extras.accountID, let elegida = cuentas.first(where: { $0.persistentModelID == id }),
           moneda == nil || elegida.currencyCode == moneda {
            return elegida
        }
        guard let moneda else { return cuentaPorDefecto }
        if cuentaPorDefecto?.currencyCode == moneda { return cuentaPorDefecto }
        return cuentas.first { $0.currencyCode == moneda }
    }

    private func fila(_ destino: Logica.Paso, _ etiqueta: String, _ valor: String) -> some View {
        AsistenteResumenFila(etiqueta: etiqueta, valor: valor, id: "asistente_pago_resumen_\(destino.rawValue)") {
            estado.navegador.cambiar(destino, desde: .resumen)
        }
    }

    private var valorTipo: String {
        let nombre = draft.kind.map { Flujo.kindTitle($0) } ?? subcategoriaElegida?.name ?? "—"
        return draft.isSubscription ? "\(nombre) · \(L10n.Scheduled.Category.subscription)" : nombre
    }

    private var valorCuando: String {
        switch draft.frequency {
        case .monthly: return A.elDia(draft.dayOfMonth)
        case .weekly:
            return Calendar.current.standaloneWeekdaySymbols[draft.weekday - 1].capitalized(with: AppLocale.current)
        case .yearly, .once: return ScheduledPaymentDateText.dayMonthLong(draft.date)
        }
    }

    private var valorAviso: String {
        switch draft.reminder ?? Logica.Aviso.none {
        case .threeDaysBefore: return T.reminderThreeDays
        case .oneDayBefore: return T.reminderOneDay
        case .sameDay: return T.reminderSameDay
        case .none: return A.sinAviso
        }
    }

    private var subcategoriaElegida: Subcategory? {
        if let tipo = draft.kind { return subcategoriasPorTipo[tipo] }
        guard let id = draft.subcategoryID else { return nil }
        return otra?.persistentModelID == id ? otra : modelContext.model(for: id) as? Subcategory
    }

    private var aspecto: (icon: String, color: Color) {
        (draft.kind?.seedIcon ?? subcategoriaElegida?.iconName ?? "calendar.badge.clock", color(de: subcategoriaElegida))
    }

    private func color(de subcategoria: Subcategory?) -> Color {
        if let hex = subcategoria?.category?.colorHex { return Color(hex: hex) }
        return theme.accent
    }

    /// La fecha del primer pago con lo elegido (la misma cuenta que el formulario).
    private var primerPago: Date? {
        TutorialPlanningMath.paymentFirstDue(
            frequency: draft.frequency, dayOfMonth: draft.dayOfMonth, weekday: draft.weekday, date: draft.date)
    }

    /// «≈ S/ 80.00 cada mes, el día 1. Primer pago: 1 de diciembre.» (la línea del formulario).
    private var frase: String? {
        guard let monto = estado.monto, let primer = primerPago else { return nil }
        let texto = appPreferences.currency(monto, currencyCode: monedaVisible, forceFullPrecision: true,
                                            isEstimate: draft.isVariableAmount)
        return TutorialPlanningMath.paymentSummary(
            amountText: texto, frequency: draft.frequency, dayOfMonth: draft.dayOfMonth, date: draft.date, due: primer)
    }

    private var montoDeLaTarjeta: Double? {
        estado.compartido == nil ? estado.monto : estado.reparto.miParte
    }

    /// La moneda en que se enseñan los montos: la del gasto compartido, o la de la cuenta.
    private var monedaVisible: String {
        estado.reparto.grupoZona == nil ? moneda : estado.reparto.moneda
    }

    private func dinero(_ valor: Double) -> String {
        appPreferences.currency(valor, currencyCode: monedaVisible, forceFullPrecision: true,
                                isEstimate: draft.isVariableAmount)
    }

    // MARK: - Avance

    private func cargar() {
        guard !didLoad else { return }
        didLoad = true
        let viewModel = ScheduledPaymentEditorViewModel()
        viewModel.setContext(modelContext, deletionService: EntityDeletionService.shared)
        let cuenta = viewModel.lastUsedAccount() ?? viewModel.activeAccounts.first
        cuentaNombre = cuenta?.name ?? ""
        cuentaPorDefecto = cuenta
        moneda = cuenta?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue
        cuentas = viewModel.activeAccounts
        etiquetas = viewModel.activeTags
        subcategoriasPorTipo = Flujo.kindSubcategories(in: modelContext)
        cargarGrupos()
    }

    /// Los grupos activos: ni archivados ni ocultos para todos, y en los que sigues como miembro activo; con cuántos
    /// miembros activos tiene cada uno. Sin ninguno, no se pregunta si es compartido.
    private func cargarGrupos() {
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { !$0.isArchived && !$0.isHiddenForAll }, sortBy: [SortDescriptor(\.name)])
        do {
            grupos = try modelContext.fetch(descriptor)
                .filter { AsistenteRepartoPuente.soyMiembroActivo(de: $0, in: modelContext) }
            var conteo: [String: Int] = [:]
            for grupo in grupos {
                conteo[grupo.cloudKitZoneID] = AsistenteRepartoPuente.miembros(de: grupo, in: modelContext)
                    .filter(\.isActive).count
            }
            miembrosPorZona = conteo
        } catch {
            #if DEBUG
            print("AsistentePagoPlanificadoView: Error fetching groups: \(error)")
            #endif
            grupos = []
        }
        estado.tieneGrupos = !grupos.isEmpty
        // Un grupo elegido que dejó de estar disponible no se guarda.
        if let zona = estado.reparto.grupoZona, !grupos.contains(where: { $0.cloudKitZoneID == zona }) {
            estado.reparto = AsistentePagoPlanificadoReparto()
        }
    }

    private func elegir(_ tipo: Logica.Tipo) {
        guard let subcategoria = subcategoriasPorTipo[tipo] else { return }
        otra = nil
        estado.draft.kind = tipo
        estado.draft.subcategoryID = subcategoria.persistentModelID
        estado.draft.isVariableAmount = tipo.isVariableAmount
        estado.draft.isSubscription = tipo.isSubscription
    }

    private func abrirOtra() {
        otraAlAbrir = otra?.persistentModelID
        muestraOtra = true
    }

    /// Al cerrarse la hoja de «Otra subcategoría»: la elegida queda marcada. Cerrarla sin elegir otra no toca nada.
    private func aplicarOtra() {
        guard let elegida = otra, elegida.persistentModelID != otraAlAbrir else { return }
        estado.draft.kind = nil
        estado.draft.subcategoryID = elegida.persistentModelID
        estado.draft.isVariableAmount = false
    }

    /// El nombre propuesto sigue al tipo hasta que la persona escribe el suyo.
    private var nombrePropuesto: String {
        if let tipo = draft.kind { return Flujo.prefilledName(tipo) }
        return subcategoriaElegida?.name ?? ""
    }

    private func alEntrar(en paso: Logica.Paso) {
        nombreEnfocado = false
        montoEnfocado = false
        // La parte propia sigue al monto de ahora (se puede volver atrás a cambiarlo).
        if paso == .reparto || paso == .resumen, estado.reparto.grupoZona != nil {
            estado.reparto = AsistenteRepartoPuente.recalcular(estado.reparto, grupos: grupos, monto: estado.monto,
                                                               in: modelContext)
        }
        if paso == .nombre, !estado.nombreEditado || Logica.nombreLimpio(draft.name).isEmpty {
            estado.draft.name = nombrePropuesto
            estado.nombreEditado = false
        }
    }

    private func filtrarMonto(_ texto: String) {
        let filtrado = AmountInputHelper.filterAmountInput(texto)
        if filtrado != texto { estado.montoTexto = filtrado }
    }

    private func seguir() {
        guard estado.puedeSeguir else { return }
        if paso == .resumen {
            crear()
        } else {
            estado.navegador.avanzar(en: estado.pasos)
        }
    }

    /// Guarda con el ViewModel del formulario (`AsistentePagoPlanificadoCreador`, con lo compartido y «¿Algo más?») y
    /// apunta lo mismo que el formulario: el primer pago de Primeros pasos y el aviso «Primer pago: …». Con aviso
    /// elegido, la hoja del permiso de notificaciones, como el formulario al guardar un pago nuevo.
    private func crear() {
        guard !creando, let valor = estado.monto else { return }
        creando = true
        var borrador = estado.draft
        borrador.name = Logica.nombreLimpio(borrador.name)
        borrador.amount = valor
        if estado.reparto.grupoZona != nil {
            estado.reparto = AsistenteRepartoPuente.recalcular(estado.reparto, grupos: grupos, monto: valor,
                                                               in: modelContext)
        }
        let pago: ScheduledPayment
        do {
            pago = try AsistentePagoPlanificadoCreador.crear(
                borrador, monto: valor, compartido: estado.compartido, miParte: estado.reparto.miParte,
                extras: estado.extras, defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
                in: modelContext)
        } catch {
            #if DEBUG
            print("AsistentePagoPlanificadoView: Error: creating the payment: \(error)")
            #endif
            creando = false
            fallo = true
            return
        }
        DS.Haptic.success()
        alGuardar(pago.id)
        ScheduledPaymentEditorView.noteCreated(name: borrador.name, paymentID: pago.id, in: modelContext)
        guard (borrador.reminder ?? Logica.Aviso.none).wantsReminder else {
            alCerrar()
            return
        }
        Task { @MainActor in
            if await NotificationPrimerMoments.claim(.scheduledPayment) {
                muestraPermiso = true
            } else {
                alCerrar()
            }
        }
    }
}

/// La hoja de «Otra subcategoría», el error al guardar y la hoja del permiso de notificaciones. En su propio modificador
/// para no alargar el `body` (`swiftui-ds.md`, el compilador del CI).
private struct AsistentePagoPresentaciones: ViewModifier {
    @Binding var muestraOtra: Bool
    @Binding var otra: Subcategory?
    let alCerrarOtra: () -> Void
    @Binding var fallo: Bool
    @Binding var muestraPermiso: Bool
    let alCerrarPermiso: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $muestraOtra, onDismiss: alCerrarOtra) {
                SubcategorySelectorSheet(selectedSubcategory: $otra, transactionType: .expense)
            }
            .alert(L10n.Common.error, isPresented: $fallo) {
                Button(L10n.Common.understood, role: .cancel) {}
            } message: {
                Text(L10n.Common.saveError)
            }
            .notificationPrimerSheet(isPresented: $muestraPermiso, context: .scheduledPayment, onDismiss: alCerrarPermiso)
    }
}
