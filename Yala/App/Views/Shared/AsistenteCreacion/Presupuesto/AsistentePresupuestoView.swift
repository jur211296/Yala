//
//  AsistentePresupuestoView.swift
//  Yala
//
//  «Nuevo presupuesto» por pasos (encargo del 17-nov): una pregunta por pantalla con el valor sugerido ya elegido,
//  «Usar formulario» arriba y, al final, el resumen con «Crear presupuesto». Primer asistente sobre
//  `AsistenteCreacionView`. Las preguntas y sus opciones son las de Primeros pasos (`L10n.PrimerosPasos23.Budget`), y lo
//  gastado se calcula con la misma regla (`TutorialPlanningMath`). Lo que no pregunta (cuentas, etiquetas, necesidad,
//  gastos de grupo, widget, subcategorías sueltas) queda como en el formulario recién abierto.
//

import SwiftData
import SwiftUI

struct AsistentePresupuestoView: View {
    typealias Logica = AsistentePresupuestoLogica
    private typealias T = L10n.PrimerosPasos23.Budget
    private typealias P = L10n.PrimerosPasos23.Plan

    @Bindable var estado: AsistentePresupuestoEstado
    /// Se creó el presupuesto, o se descartó: quien presenta cierra la hoja.
    let alCerrar: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState

    // Datos de la persona (se vuelven a leer si el contenido se rehace: no son respuestas).
    @State private var categorias: [Category] = []
    @State private var movimientos: [TransactionItem] = []
    @State private var movimientosDesde: Date?
    @State private var didLoad = false
    @State private var creando = false
    @State private var fallo = false
    @FocusState private var topeEnfocado: Bool
    @FocusState private var nombreEnfocado: Bool

    private var paso: Logica.Paso { estado.navegador.actual }
    private var tituloCrear: String {
        dynamicTypeSize.isAccessibilitySize ? L10n.AsistentePresupuesto.crearCorto : L10n.AsistentePresupuesto.crear
    }
    private var moneda: String { appPreferences.defaultCurrencyCode.rawValue }

    var body: some View {
        AsistenteCreacionView(
            titulo: L10n.AsistentePresupuesto.titulo,
            pregunta: pregunta,
            detalle: detalle,
            indice: estado.navegador.indice(en: estado.pasos),
            total: estado.pasos.count,
            identidad: paso.rawValue,
            tituloPrincipal: paso == .resumen ? tituloCrear : L10n.Action.next,
            puedeSeguir: estado.puedeSeguir && !creando,
            puedeRetroceder: estado.navegador.puedeRetroceder,
            tieneRespuestas: estado.navegador.tieneRespuestas,
            tituloDescartar: L10n.AsistentePresupuesto.descartarTitulo,
            ocupado: creando,
            alSeguir: seguir,
            alRetroceder: retroceder,
            alUsarFormulario: usarFormulario,
            alCerrar: alCerrar
        ) {
            respuesta
        }
        .onAppear(perform: cargar)
        .onChange(of: paso) { _, nuevo in alEntrar(en: nuevo) }
        .alert(L10n.Common.error, isPresented: $fallo) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Common.saveError)
        }
    }

    // MARK: - Pregunta

    private var pregunta: String {
        switch paso {
        case .alcance: return T.scopeQuestion
        case .categorias: return T.categoriesQuestion
        case .periodo: return T.periodQuestion
        case .fechas: return T.datesQuestion
        case .tope:
            switch estado.periodo {
            case .weekly: return T.limitQuestionWeekly
            case .yearly: return T.limitQuestionYearly
            case .unique: return T.limitQuestionOnce
            case .monthly: return T.limitQuestionMonthly
            }
        case .nombre: return T.nameEditQuestion
        case .aviso: return T.alertQuestion
        case .resumen: return L10n.AsistentePresupuesto.resumenPregunta
        }
    }

    private var detalle: String? {
        switch paso {
        case .alcance: return T.scopeSubtitle
        case .categorias: return categorias.isEmpty ? L10n.AsistentePresupuesto.sinCategorias : T.categoriesSubtitle
        case .periodo: return T.periodSubtitle
        case .fechas: return T.datesSubtitle
        case .tope:
            let anterior = gastadoAnterior
            return anterior > 0
                ? L10n.AsistentePresupuesto.gastadoAnterior(estado.periodo, dinero(anterior))
                : T.limitRoundNumber
        case .nombre: return T.nameSubtitle
        case .aviso: return T.alertSubtitle
        case .resumen: return L10n.AsistentePresupuesto.resumenDetalle
        }
    }

    // MARK: - Respuesta

    @ViewBuilder
    private var respuesta: some View {
        switch paso {
        case .alcance: alcance
        case .categorias: categoriasRejilla
        case .periodo: periodo
        case .fechas: fechas
        case .tope: tope
        case .nombre: nombre
        case .aviso: aviso
        case .resumen: resumen
        }
    }

    private var alcance: some View {
        VStack(spacing: DS.Spacing.sm) {
            AsistenteOpcion(titulo: T.scopeAll, detalle: T.scopeAllHint, icono: "chart.pie.fill",
                            elegida: estado.alcance == .all, id: "asistente_presupuesto_alcance_todos") {
                estado.alcance = .all
            }
            AsistenteOpcion(titulo: T.scopeCategories, detalle: T.scopeCategoriesHint, icono: "square.grid.2x2.fill",
                            elegida: estado.alcance == .categories, id: "asistente_presupuesto_alcance_categorias") {
                estado.alcance = .categories
            }
        }
    }

    private var categoriasRejilla: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm),
                                 count: TutorialGridColumns.count(3, dynamicTypeSize: dynamicTypeSize)),
                  spacing: DS.Spacing.sm) {
            ForEach(categorias) { categoria in
                let gastado = gastadoEsteMes(subcategorias: subcategorias(de: categoria))
                TutorialSelectableTile(
                    icon: categoria.iconName ?? "tag.fill",
                    color: Color(hex: categoria.colorHex),
                    title: categoria.name,
                    caption: gastado > 0 ? T.categoriesSpent(dinero(gastado)) : nil,
                    isOn: estado.categorias.contains(categoria.persistentModelID),
                    id: "asistente_presupuesto_categoria"
                ) { alternar(categoria) }
            }
        }
    }

    private var periodo: some View {
        let opciones: [(BudgetPeriodType, String, String)] = [
            (.monthly, BudgetPeriodType.monthly.localizedName, T.periodMonthlyHint),
            (.weekly, BudgetPeriodType.weekly.localizedName, T.periodWeeklyHint),
            (.yearly, BudgetPeriodType.yearly.localizedName, T.periodYearlyHint),
            (.unique, T.periodOnce, T.periodOnceHint),
        ]
        return VStack(spacing: DS.Spacing.sm) {
            ForEach(opciones, id: \.0) { tipo, titulo, pista in
                AsistenteOpcion(titulo: titulo, detalle: pista, elegida: estado.periodo == tipo,
                                id: "asistente_presupuesto_periodo_\(tipo.rawValue)") {
                    estado.periodo = tipo
                }
            }
        }
    }

    private var fechas: some View {
        AsistenteTarjeta {
            DatePicker(T.datesFrom, selection: $estado.inicio, displayedComponents: .date)
                .padding(DS.Spacing.md)
            Divider()
            DatePicker(T.datesTo, selection: $estado.fin, in: estado.inicio..., displayedComponents: .date)
                .padding(DS.Spacing.md)
        }
    }

    private var tope: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AsistenteTarjeta {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(CurrencyCode(rawValue: moneda)?.symbol ?? moneda)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("", text: $estado.topeTexto,
                              prompt: Text(verbatim: "0").yalaFieldPrompt())
                        .font(DS.Typography.largeTitle.weight(.bold))
                        .yalaFieldText()
                        .amountKeyboard()
                        .focused($topeEnfocado)
                        .onChange(of: estado.topeTexto) { _, nuevo in filtrarTope(nuevo) }
                        .accessibilityLabel(pregunta)
                        .accessibilityIdentifier("asistente_presupuesto_tope")
                }
                .padding(DS.Spacing.lg)
            }
            let sugerencias = Logica.sugerencias(gastadoAnterior: gastadoAnterior)
            if !sugerencias.isEmpty {
                FlowLayout(spacing: DS.Spacing.sm) {
                    ForEach(Array(sugerencias.enumerated()), id: \.offset) { indice, sugerencia in
                        sugerenciaChip(sugerencia.0, valor: sugerencia.1, indice: indice)
                    }
                }
            }
        }
    }

    private func sugerenciaChip(_ tipo: Logica.Sugerencia, valor: Double, indice: Int) -> some View {
        let elegida = estado.tope == valor
        return Button {
            DS.Haptic.selection()
            estado.topeTexto = AmountInputHelper.formatWithGrouping(valor)
            topeEnfocado = false
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(dinero(valor))
                    .font(DS.Typography.subheadline.weight(.semibold))
                Text(L10n.AsistentePresupuesto.sugerencia(tipo))
                    .font(DS.Typography.caption)
                    .foregroundStyle(elegida ? theme.onAccent.opacity(0.85) : Color.secondary)
            }
            .foregroundStyle(elegida ? theme.onAccent : .primary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(elegida ? theme.accent : theme.card))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(elegida ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("asistente_presupuesto_sugerencia_\(indice)")
    }

    private var nombre: some View {
        AsistenteTarjeta {
            TextField("", text: $estado.nombre, prompt: Text(T.namePlaceholder).yalaFieldPrompt())
                .font(DS.Typography.title3)
                .yalaFieldText()
                .focused($nombreEnfocado)
                .submitLabel(.next)
                .onSubmit { if estado.puedeSeguir { seguir() } }
                .onChange(of: estado.nombre) { _, _ in
                    if nombreEnfocado { estado.nombreEditado = true }
                }
                .padding(DS.Spacing.lg)
                .accessibilityLabel(T.nameEditQuestion)
                .accessibilityIdentifier("asistente_presupuesto_nombre")
        }
    }

    private var aviso: some View {
        VStack(spacing: DS.Spacing.sm) {
            AsistenteOpcion(titulo: T.alertAt75, detalle: T.alertAt75Hint, icono: "bell.badge.fill",
                            elegida: estado.aviso == .at75And100, id: "asistente_presupuesto_aviso_75") {
                estado.aviso = .at75And100
            }
            AsistenteOpcion(titulo: T.alertAt100, icono: "bell.fill", elegida: estado.aviso == .at100,
                            id: "asistente_presupuesto_aviso_100") {
                estado.aviso = .at100
            }
            AsistenteOpcion(titulo: P.noThanks, icono: "bell.slash.fill", elegida: estado.aviso == .none,
                            id: "asistente_presupuesto_aviso_ninguno") {
                estado.aviso = .none
            }
        }
    }

    // MARK: - Resumen

    private var resumen: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            FirstBudgetCardPreview(
                name: Logica.nombreLimpio(estado.nombre),
                isNamePlaceholder: false,
                look: aspecto,
                caption: leyendaTarjeta,
                limit: estado.tope,
                spent: gastadoActual,
                currencyCode: moneda,
                alert: estado.aviso
            )
            AsistenteTarjeta {
                fila(.alcance, L10n.AsistentePresupuesto.resumenCuenta, valorAlcance)
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.periodo, L10n.AsistentePresupuesto.resumenPeriodo, nombrePeriodo)
                if estado.periodo == .unique {
                    Divider().padding(.leading, DS.Spacing.lg)
                    fila(.fechas, L10n.AsistentePresupuesto.resumenFechas, valorFechas)
                }
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.tope, L10n.AsistentePresupuesto.resumenTope, estado.tope.map(dinero) ?? "—")
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.nombre, L10n.AsistentePresupuesto.resumenNombre, Logica.nombreLimpio(estado.nombre))
                Divider().padding(.leading, DS.Spacing.lg)
                fila(.aviso, L10n.AsistentePresupuesto.resumenAviso, valorAviso)
            }
        }
    }

    private func fila(_ destino: Logica.Paso, _ etiqueta: String, _ valor: String) -> some View {
        AsistenteResumenFila(etiqueta: etiqueta, valor: valor, id: "asistente_presupuesto_resumen_\(destino.rawValue)") {
            estado.navegador.cambiar(destino, desde: .resumen)
        }
    }

    private var valorAlcance: String {
        guard estado.alcance == .categories else { return T.scopeAll }
        return categoriasElegidas.map(\.name).formatted(.list(type: .and))
    }

    private var nombrePeriodo: String {
        estado.periodo == .unique ? T.periodOnce : estado.periodo.localizedName
    }

    private var valorFechas: String {
        let inicio = estado.inicio.formatted(date: .abbreviated, time: .omitted)
        let fin = estado.fin.formatted(date: .abbreviated, time: .omitted)
        return "\(inicio) – \(fin)"
    }

    private var valorAviso: String {
        switch estado.aviso {
        case .at75And100: return T.cardAlert75
        case .at100: return T.cardAlert100
        case .none: return L10n.AsistentePresupuesto.sinAvisos
        }
    }

    /// Icono y color de la tarjeta: el de la categoría si es una sola; si no, la tarta del acento (como Primeros pasos).
    private var aspecto: (icon: String, color: Color) {
        if estado.alcance == .categories, categoriasElegidas.count == 1, let unica = categoriasElegidas.first {
            return (unica.iconName ?? "tag.fill", Color(hex: unica.colorHex))
        }
        return ("chart.pie.fill", theme.accent)
    }

    private var leyendaTarjeta: String {
        guard let limite = estado.tope else { return nombrePeriodo }
        return P.spentOfLimit(dinero(gastadoActual), dinero(limite)) + " · " + nombrePeriodo
    }

    // MARK: - Lo gastado

    private var categoriasElegidas: [Category] {
        estado.categorias.compactMap { id in categorias.first { $0.persistentModelID == id } }
    }

    private var subcategoriasElegidas: [UUID] {
        guard estado.alcance == .categories else { return [] }
        var vistas: Set<UUID> = []
        return categoriasElegidas.flatMap { subcategorias(de: $0) }.filter { vistas.insert($0).inserted }
    }

    private func subcategoriasVisibles(de categoria: Category) -> [Subcategory] {
        (categoria.subcategories ?? [])
            .filter { $0.isVisible && !$0.isAnySystem }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func subcategorias(de categoria: Category) -> [UUID] {
        subcategoriasVisibles(de: categoria).map(\.shortcutID)
    }

    private func gastado(subcategorias: [UUID], periodo: BudgetPeriodType, ahora: Date = .now) -> Double {
        TutorialPlanningMath.budgetSpent(
            subcategoryIDs: subcategorias, period: periodo, currencyCode: moneda, transactions: movimientos,
            startDate: estado.inicio, endDate: estado.fin, now: ahora)
    }

    private func gastadoEsteMes(subcategorias: [UUID]) -> Double {
        gastado(subcategorias: subcategorias, periodo: .monthly)
    }

    /// Lo gastado en el período en curso con lo elegido (la barra de la tarjeta del resumen).
    private var gastadoActual: Double {
        gastado(subcategorias: subcategoriasElegidas, periodo: estado.periodo)
    }

    /// Lo gastado el período anterior con lo elegido: de ahí salen los topes sugeridos.
    private var gastadoAnterior: Double {
        guard let fecha = Logica.fechaDelPeriodoAnterior(estado.periodo) else { return 0 }
        return gastado(subcategorias: subcategoriasElegidas, periodo: estado.periodo, ahora: fecha)
    }

    private func dinero(_ valor: Double) -> String {
        appPreferences.currency(valor, currencyCode: moneda)
    }

    // MARK: - Avance

    private func cargar() {
        guard !didLoad else { return }
        didLoad = true
        do {
            let todas = try modelContext.fetch(FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)]))
            categorias = todas.filter {
                !$0.isIncome && !$0.isSystem && $0.isVisible && !subcategoriasVisibles(de: $0).isEmpty
            }
        } catch {
            #if DEBUG
            print("AsistentePresupuestoView: Error: loading categories: \(error)")
            #endif
        }
        cargarMovimientos()
    }

    /// Los movimientos desde el principio del período anterior (para el tope sugerido) o desde el inicio de «Una sola
    /// vez», lo que sea antes. Solo se vuelve a leer si hace falta ir más atrás.
    private func cargarMovimientos() {
        let calendar = Calendar.current
        let anterior = Logica.fechaDelPeriodoAnterior(estado.periodo) ?? .now
        var desde = calendar.date(byAdding: .day, value: -7, to: min(anterior, calendar.startOfDay(for: .now))) ?? anterior
        if let inicioMes = calendar.date(from: calendar.dateComponents([.year, .month], from: anterior)) {
            desde = min(desde, inicioMes)
        }
        if estado.periodo == .yearly,
           let inicioAno = calendar.date(from: calendar.dateComponents([.year], from: anterior)) {
            desde = min(desde, inicioAno)
        }
        if estado.periodo == .unique { desde = min(desde, calendar.startOfDay(for: estado.inicio)) }
        if let ya = movimientosDesde, ya <= desde { return }
        let descriptor = FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.date >= desde })
        do {
            movimientos = try modelContext.fetch(descriptor)
            movimientosDesde = desde
        } catch {
            #if DEBUG
            print("AsistentePresupuestoView: Error: loading records: \(error)")
            #endif
        }
    }

    private func alternar(_ categoria: Category) {
        if let indice = estado.categorias.firstIndex(of: categoria.persistentModelID) {
            estado.categorias.remove(at: indice)
        } else {
            estado.categorias.append(categoria.persistentModelID)
        }
    }

    private var nombreSugerido: String {
        Logica.nombreSugerido(
            alcance: estado.alcance,
            periodo: estado.periodo,
            categorias: categoriasElegidas.map(\.name),
            todos: L10n.AsistentePresupuesto.nombreTodos(estado.periodo),
            unidas: { T.nameJoined($0, $1) },
            porDefecto: T.nameFallback
        )
    }

    private func alEntrar(en paso: Logica.Paso) {
        topeEnfocado = false
        nombreEnfocado = false
        switch paso {
        case .tope:
            cargarMovimientos()
        case .nombre:
            if !estado.nombreEditado || Logica.nombreLimpio(estado.nombre).isEmpty {
                estado.nombre = nombreSugerido
                estado.nombreEditado = false
            }
        default:
            break
        }
    }

    private func filtrarTope(_ texto: String) {
        let filtrado = AmountInputHelper.filterAmountInput(texto)
        if filtrado != texto { estado.topeTexto = filtrado }
    }

    private func seguir() {
        guard estado.puedeSeguir else { return }
        switch paso {
        case .resumen:
            crear()
        case .aviso where estado.aviso.isEnabled:
            pedirPermisoYSeguir()
        default:
            estado.navegador.avanzar(en: estado.pasos)
        }
    }

    private func retroceder() {
        estado.navegador.retroceder(en: estado.pasos)
    }

    private func usarFormulario() {
        estado.usarFormulario(subcategorias: subcategoriasElegidas)
    }

    /// Elegir un aviso pide el permiso de iOS si nunca se pidió, como Primeros pasos (Y23-17); si queda permitido, al
    /// crear se enciende el interruptor general de las alertas de presupuesto.
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
            guard estado.navegador.actual == .aviso else { return }
            estado.avisosPermitidos = permitido
            estado.navegador.avanzar(en: estado.pasos)
        }
    }

    /// Crea con el ViewModel del formulario (las mismas reglas de guardado) y apunta lo mismo que el formulario: el
    /// primer presupuesto de Primeros pasos y el widget.
    private func crear() {
        guard !creando, let limite = estado.tope else { return }
        creando = true
        defer { creando = false }
        let viewModel = BudgetEditorViewModel()
        viewModel.setContext(modelContext, deletionService: EntityDeletionService.shared)
        let quiero = Set(subcategoriasElegidas)
        let subcategoriaIDs = Set(viewModel.allSubcategories.filter { quiero.contains($0.shortcutID) }.map(\.persistentModelID))
        let calendar = Calendar.current
        let nombre = Logica.nombreLimpio(estado.nombre)
        guard let guardado = viewModel.saveBudget(
            existing: nil,
            name: nombre,
            limitAmount: limite,
            currencyCode: moneda,
            periodType: estado.periodo,
            startDate: calendar.startOfDay(for: estado.inicio),
            endDate: calendar.startOfDay(for: estado.fin),
            isActive: true,
            selectedAccounts: [],
            selectedSubcategories: subcategoriaIDs,
            selectedTags: [],
            selectedNeeds: [],
            alertEnabled: estado.aviso.isEnabled,
            alertThresholds: estado.aviso.thresholds,
            includeSharedExpenses: true
        ) else {
            fallo = true
            return
        }
        DS.Haptic.success()
        if estado.aviso.isEnabled, estado.avisosPermitidos { appPreferences.budgetAlertsEnabled = true }
        sessionState.needsBudgetsWidgetRefresh = true
        BudgetEditorView.noteCreated(name: nombre, savedID: guardado, in: modelContext)
        alCerrar()
    }
}
