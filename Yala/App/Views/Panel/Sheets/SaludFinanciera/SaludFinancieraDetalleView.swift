//
//  SaludFinancieraDetalleView.swift
//  Yala
//
//  El contenido de la hoja de la nota TOTAL, en tres secciones y en tono de consejero (opción A de Jürgen, 20-nov-2026):
//  la nota con una frase que dice qué la mueve más y las cápsulas como índice; luego Presupuestos, Compromisos y Ritmo,
//  cada una con su estado, lo suyo y «Para mejorar esta parte». Sin rojo alarmista ni cifras negativas grandes: lo que
//  no cuadra va en ámbar y con un consejo. Cómo se calcula la nota queda plegado al final.
//
//  La nota llega del Panel; lo demás lo lee `SaludFinancieraDetalleCargador` al aparecer.
//

import SwiftData
import SwiftUI

struct SaludFinancieraDetalleView: View {
    let score: FinancialScore
    let hasBudgets: Bool
    /// Cierra la hoja y lleva a la vista de lo tocado.
    let abrir: (SaludFinancieraDetalleDestino) -> Void
    /// Baja a una sección (las cápsulas son el índice). Lo pone quien tiene el scroll.
    var bajarA: (SaludFinancieraDetalleLogica.Seccion) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.amountsHidden) private var amountsHidden

    @State private var cargador = SaludFinancieraDetalleCargador()
    @State private var muestraComoSeCalcula = false
    /// El presupuesto cuyo límite se ajusta y el límite propuesto, con el editor encima de la hoja. Van juntos en el
    /// `item` para que la hoja no lea el límite de otro `@State` (`swiftui-ds.md`, «`.sheet` con el contenido de OTRO
    /// `@State`»).
    @State private var presupuestoAEditar: AjusteDeLimite?

    // A11Y-DT: el anillo crece con el tamaño del texto.
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 84
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 14

    /// A tamaños de accesibilidad los importes bajan a su propia línea y la cabecera se apila: nunca se cortan.
    private var esAX: Bool { dynamicTypeSize.isAccessibilitySize }

    private typealias Texto = L10n.SaludFinancieraDetalle
    private typealias Logica = SaludFinancieraDetalleLogica
    private typealias Datos = SaludFinancieraDetalleCargador.Datos

    #if DEBUG
    private let muestra = SaludFinancieraDetalleMuestra.actual
    #endif

    /// La nota que se pinta: la del Panel, o la de la muestra de los XCUITest.
    private var nota: FinancialScore {
        #if DEBUG
        return muestra?.score ?? score
        #else
        return score
        #endif
    }

    private var moneda: String { appPreferences.defaultCurrencyCode.rawValue }
    private var soloGastos: Bool { sessionState.isExpensesOnlyMode }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            cabecera(cargador.datos)
            if let datos = cargador.datos {
                seccionPresupuestos(datos)
                seccionCompromisos(datos)
                seccionRitmo(datos)
                if !soloGastos { seccionTeQueda }
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                    Text(Texto.cargando)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xl)
                .transition(.loadingPlaceholder)
            }
            comoSeCalcula
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await cargar() }
        .sheet(item: $presupuestoAEditar) { ajuste in
            BudgetEditorView(budget: ajuste.budget, proposedLimit: ajuste.limite)
        }
    }

    private func cargar() async {
        #if DEBUG
        if let muestra {
            cargador.usar(muestra.datos)
            return
        }
        #endif
        await cargador.cargar(
            context: modelContext,
            score: score,
            currencyCode: moneda,
            coverageScope: FinancialScoreCalculator.CoverageScope(
                includeGroupsInTotal: appPreferences.includeGroupsInPanelTotal,
                moneyOverrides: PanelMoneyScopeLogic.decode(appPreferences.panelMoneyAccountOverrides)
            ),
            includeGroupTransactionsInStats: appPreferences.includeGroupTransactionsInStats,
            esPro: FeatureGateService.shared.isProUser
        )
    }

    // MARK: - Montos en una frase

    private func monto(_ value: Double, _ currency: String? = nil, estimado: Bool = false) -> String {
        let _ = appPreferences.decimalPlaces
        // Sin espacio partible: dentro de una frase, «S/» no puede quedar al final de una línea y la cifra en la otra.
        return AmountPrivacy.text(
            appPreferences.currency(value, currencyCode: currency ?? moneda, isEstimate: estimado), hidden: amountsHidden
        ).replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    // MARK: - Cabecera

    @ViewBuilder
    private func cabecera(_ datos: Datos?) -> some View {
        let layout = esAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.lg))
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            layout {
                anillo
                Text(FinancialScoreCopy.totalHeadline(for: nota, isExpensesOnlyMode: soloGastos))
                    .font(DS.Typography.title3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("health_sheet_headline")
            }
            if let datos {
                Text(Texto.consejo(consejo(datos)))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("health_sheet_advice")
            }
            capsulas(datos)
        }
    }

    private var anillo: some View {
        ZStack {
            ScoreRingView(
                progress: nota.total.map { Double($0) / 100.0 } ?? 0,
                size: ringSize,
                lineWidth: ringSize * 0.1,
                foreground: anilloColor
            )
            Text(nota.total.map { "\($0)" } ?? L10n.Panel.Health.emptyBadge)
                .font(DS.Typography.title2)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(nota.total == nil ? DS.Semantic.disabledForeground : Color.primary)
                .padding(.horizontal, ringSize * 0.12)
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nota.total.map { L10n.Panel.Health.scoreVoiceover(score: $0) } ?? L10n.Panel.Health.noData)
        // En el anillo y no en el contenedor: un id en el contenedor pisa los de las secciones.
        .accessibilityIdentifier("health_breakdown")
    }

    private var anilloColor: AnyShapeStyle {
        guard let total = nota.total else { return AnyShapeStyle(DS.Semantic.disabledForeground.opacity(0.4)) }
        return AnyShapeStyle(FinancialScoreTint.color(for: total))
    }

    private func consejo(_ datos: Datos) -> Logica.Consejo {
        Logica.consejo(
            score: nota, presupuestos: datos.presupuestos, pagos: datos.pagos, comparacion: datos.comparacion,
            tienePagos: datos.tienePagos, isExpensesOnlyMode: soloGastos, finDeMes: datos.finDeMes
        )
    }

    /// Las tres cápsulas, en el orden de las secciones, partidas en líneas si no caben. Tocar una baja a su sección.
    private func capsulas(_ datos: Datos?) -> some View {
        FlowLayout(spacing: DS.Spacing.xs) { capsulasDePartes(datos) }
    }

    @ViewBuilder
    private func capsulasDePartes(_ datos: Datos?) -> some View {
        ForEach(Logica.Seccion.visibles(isExpensesOnlyMode: soloGastos)) { seccion in
            capsula(seccion, datos: datos)
        }
    }

    private func valor(de seccion: Logica.Seccion) -> Int? {
        switch seccion {
        case .presupuestos: nota.budget
        case .compromisos: nota.bills
        case .ritmo: nota.activity
        case .teQueda: nota.savings
        }
    }

    private func capsula(_ seccion: Logica.Seccion, datos: Datos?) -> some View {
        let valor = valor(de: seccion)
        let motivo: String? = valor == nil
            ? datos.flatMap { d in
                Logica.motivoSinNota(seccion, score: nota, presupuestos: d.presupuestos, tienePagos: d.tienePagos)
            }.map { Texto.motivo($0) } ?? "—"
            : nil
        let nombre = FinancialScoreCopy.partName(seccion.parte)
        return Button { bajarA(seccion) } label: {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(seccion.parte.tint ?? .secondary)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(nombre)
                    .foregroundStyle(.secondary)
                Text(valor.map { "\($0)" } ?? motivo ?? "—")
                    .monospacedDigit()
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.down")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .font(DS.Typography.caption)
            .lineLimit(esAX ? nil : 1)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(Color.primary.opacity(0.06), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(nombre), \(valor.map { "\($0)" } ?? motivo ?? L10n.Panel.Health.partNotCounting)")
        .accessibilityHint(Texto.capsulaPista)
        .accessibilityIdentifier("health_capsule_\(seccion.rawValue)")
    }

    // MARK: - Sección

    private func seccion(
        _ seccion: Logica.Seccion,
        estado: Logica.Estado,
        @ViewBuilder contenido: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    tituloDeSeccion(seccion)
                    Spacer(minLength: DS.Spacing.sm)
                    pastilla(estado)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    tituloDeSeccion(seccion)
                    pastilla(estado)
                }
            }
            Text(Texto.peso(Int((seccion.peso * 100).rounded())))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            contenido()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("health_section_\(seccion.rawValue)")
        .id(seccion)
    }

    private func tituloDeSeccion(_ seccion: Logica.Seccion) -> some View {
        Text(Texto.seccion(seccion))
            .font(DS.Typography.title3)
            .accessibilityAddTraits(.isHeader)
    }

    private func pastilla(_ estado: Logica.Estado) -> some View {
        let tinte: Color = switch estado {
        case .bien: .incomeAmount
        case .paraRevisar: .saludAmbar
        case .sinDatos: .secondary
        }
        return Text(Texto.estado(estado))
            .font(DS.Typography.labelSmall)
            .foregroundStyle(tinte)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(tinte.opacity(0.14), in: Capsule())
    }

    private func tarjeta(@ViewBuilder contenido: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) { contenido() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }

    private func frase(_ texto: String, id: String? = nil) -> some View {
        Text(texto)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(id ?? "")
    }

    // MARK: - Presupuestos

    @ViewBuilder
    private func seccionPresupuestos(_ datos: Datos) -> some View {
        let presupuestos = datos.presupuestos
        seccion(.presupuestos, estado: Logica.estadoPresupuestos(presupuestos)) {
            if presupuestos.isEmpty {
                sinPresupuestos(datos)
            } else {
                tarjeta {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        frase(frasePresupuestos(presupuestos), id: "health_budgets_lead")
                        if let pendiente = Logica.presupuestoQueAunNoCuenta(presupuestos, score: nota),
                           let desde = pendiente.cuentaDesde {
                            Text(Texto.empiezaDespues(pendiente.nombre, fecha: desde))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("health_budgets_starts_later")
                        }
                    }
                    .padding(DS.Spacing.md)
                    let visibles = Array(presupuestos.prefix(Logica.maximoPresupuestos))
                    ForEach(visibles) { p in
                        Divider().padding(.leading, DS.Spacing.md)
                        filaPresupuesto(p)
                    }
                    if presupuestos.count > visibles.count {
                        Divider().padding(.leading, DS.Spacing.md)
                        filaEnlace(Texto.verTodosPresupuestos(presupuestos.count), icono: "list.bullet",
                                   id: "health_budgets_see_all") { abrir(.presupuestos) }
                    }
                }
                paraMejorarPresupuestos(datos)
            }
        }
    }

    private func frasePresupuestos(_ presupuestos: [Logica.Presupuesto]) -> String {
        let pasados = Logica.ordenar(presupuestos).filter(\.sePaso)
        switch pasados.count {
        case 0:
            if presupuestos.count == 1, let unico = presupuestos.first { return Texto.unoDentro(unico.nombre) }
            if let queda = Logica.quedaEntreTodos(presupuestos) {
                return Texto.todosDentroQueda(presupuestos.count, monto: monto(queda.monto, queda.moneda))
            }
            return Texto.todosDentro(presupuestos.count)
        case 1:
            let p = pasados[0]
            let otros = presupuestos.count - 1
            let cifra = monto(-p.restante, p.moneda)
            return otros == 0 ? Texto.soloPasado(p.nombre, monto: cifra)
                : Texto.pasadoYOtros(p.nombre, monto: cifra, otros: otros)
        default:
            return Texto.variosPasados(pasados.count)
        }
    }

    private func filaPresupuesto(_ p: Logica.Presupuesto) -> some View {
        Button { abrir(.presupuesto(p.id)) } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: p.icono)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(hex: p.color))
                        .frame(width: iconSize * 0.75, height: iconSize * 0.75)
                        .background(Color(hex: p.color).opacity(0.15), in: Circle())
                        .accessibilityHidden(true)
                    Text(p.nombre)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .lineLimit(esAX ? nil : 2)
                    Spacer(minLength: DS.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                // Pasado: barra en ámbar, nunca en rosa.
                BudgetProgressBar(percentage: p.porcentaje, color: p.sePaso ? Color.saludAmbarRellenoHex : p.color,
                                  isExceeded: false)
                // A tamaños de accesibilidad, una cifra por línea: nunca se cortan.
                if esAX {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        AmountText(value: p.gastado, currencyCode: p.moneda, font: DS.Typography.caption)
                        AmountText(value: p.limite, currencyCode: p.moneda, font: DS.Typography.caption, tint: .secondary)
                        restante(p)
                    }
                } else {
                    HStack(spacing: DS.Spacing.xs) {
                        AmountText(value: p.gastado, currencyCode: p.moneda, font: DS.Typography.caption)
                        Text(verbatim: "/").font(DS.Typography.caption).foregroundStyle(.secondary)
                        AmountText(value: p.limite, currencyCode: p.moneda, font: DS.Typography.caption, tint: .secondary)
                        Spacer(minLength: DS.Spacing.sm)
                        restante(p)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("health_budget_row")
    }

    private func restante(_ p: Logica.Presupuesto) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(p.restante < 0 ? Texto.tePasastePor : Texto.teQuedan)
                .font(DS.Typography.caption)
                .foregroundStyle(p.restante < 0 ? AnyShapeStyle(Color.saludAmbar) : AnyShapeStyle(.secondary))
            AmountText(value: abs(p.restante), currencyCode: p.moneda, font: DS.Typography.caption,
                       tint: p.restante < 0 ? .color(Color.saludAmbar) : .primary)
        }
    }

    @ViewBuilder
    private func paraMejorarPresupuestos(_ datos: Datos) -> some View {
        if let peor = Logica.presupuestoAMejorar(datos.presupuestos) {
            let propuesta = Logica.propuestaDeLimite(historial: peor.historial, limite: peor.limite)
            Text(Texto.paraMejorar)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.secondary)
                .padding(.top, DS.Spacing.xs)
                .accessibilityAddTraits(.isHeader)
            tarjeta {
                VStack(alignment: .leading, spacing: 0) {
                    let filas = filasParaMejorar(datos, peor: peor, propuesta: propuesta)
                    ForEach(Array(filas.enumerated()), id: \.offset) { indice, fila in
                        if indice > 0 { Divider().padding(.leading, DS.Spacing.md + iconSize + DS.Spacing.md) }
                        fila
                    }
                }
            }
        } else {
            Text(Texto.nadaQueAjustar)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, DS.Spacing.xs)
                .accessibilityIdentifier("health_budgets_nothing_to_adjust")
        }
    }

    private func filasParaMejorar(
        _ datos: Datos, peor: Logica.Presupuesto, propuesta: Logica.PropuestaDeLimite?
    ) -> [AnyView] {
        var filas: [AnyView] = []
        if datos.esPro {
            if let ia = datos.tarjetaIA {
                filas.append(AnyView(consejoFila(
                    icono: "sparkles", etiqueta: Texto.iaEtiqueta, cuerpo: "\(ia.texto) \(ia.consejo)",
                    enlace: Texto.iaBoton, id: "health_improve_ai"
                ) { abrir(.resumenIA) }))
            }
        }
        if let propuesta {
            filas.append(AnyView(consejoFila(
                icono: "arrow.up.and.down", etiqueta: Texto.ajustarTitulo,
                cuerpo: Texto.ajustarDetalle(peor.nombre, veces: propuesta.vecesPasado, periodos: propuesta.periodos,
                                             promedio: monto(propuesta.promedio, peor.moneda),
                                             limite: monto(propuesta.limite, peor.moneda)),
                enlace: Texto.ajustarBoton, id: "health_improve_adjust_limit"
            ) { abrirEditor(peor.id, limite: propuesta.limite) }))
        }
        if !peor.dondeMasPesa.isEmpty {
            let lista = peor.dondeMasPesa.map { "\($0.nombre) \(monto($0.monto, peor.moneda))" }
                .formatted(.list(type: .and).locale(LanguageManager.resolved.locale))
            let filtro = peor.dondeMasPesa.first?.filtro ?? .ninguno
            filas.append(AnyView(consejoFila(
                icono: "scissors", etiqueta: Texto.recortarTitulo(solo: propuesta == nil),
                cuerpo: Texto.recortarDetalle(peor.nombre, lista: lista),
                enlace: Texto.recortarBoton, id: "health_improve_cut"
            ) { abrir(.registrosFiltrados(filtro)) }))
        }
        if datos.esPro, datos.tarjetaIA == nil {
            filas.append(AnyView(consejoFila(
                icono: "sparkles", etiqueta: Texto.iaSinResumenTitulo, cuerpo: Texto.iaSinResumenDetalle,
                enlace: Texto.iaBoton, id: "health_improve_ai_summary"
            ) { abrir(.resumenIA) }))
        }
        if !datos.esPro {
            filas.append(AnyView(lineaPro))
        }
        return filas
    }

    private var lineaPro: some View {
        Button { abrir(.pro) } label: {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                Text(Texto.lineaPro)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Texto.lineaProBoton)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.thAccentText)
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("health_improve_pro_line")
    }

    /// Abre el editor del presupuesto con el límite propuesto ya escrito; la persona lo confirma con Guardar.
    private func abrirEditor(_ id: UUID, limite: Double) {
        var descriptor = FetchDescriptor<Budget>(predicate: #Predicate<Budget> { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            presupuestoAEditar = try modelContext.fetch(descriptor).first.map { AjusteDeLimite(budget: $0, limite: limite) }
        } catch {
            #if DEBUG
            print("SaludFinancieraDetalleView: Error: \(error)")
            #endif
        }
        // La muestra de los XCUITest no tiene presupuestos en el almacén: lleva a Presupuestos.
        if presupuestoAEditar == nil { abrir(.presupuesto(id)) }
    }

    @ViewBuilder
    private func sinPresupuestos(_ datos: Datos) -> some View {
        tarjeta {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                frase(Texto.sinPresupuestos(peso: Int((FinancialScoreCalculator.weightBudget * 100).rounded())),
                      id: "health_budgets_empty_lead")
                if let sugerida = datos.categoriaSugerida {
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        icono("lightbulb", tinte: AnyShapeStyle(.thAccentText))
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(Texto.porDondeEmpezar)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.secondary)
                            Text(Texto.sugerencia(sugerida.nombre, monto: monto(sugerida.promedioMensual, sugerida.moneda)))
                                .font(DS.Typography.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("health_budgets_suggestion")
                }
                YalaPrimaryButton(Texto.crearPresupuesto, icon: "plus") { abrir(.presupuestos) }
                    .accessibilityIdentifier("health_budgets_empty")
            }
            .padding(DS.Spacing.md)
        }
    }

    // MARK: - Compromisos

    @ViewBuilder
    private func seccionCompromisos(_ datos: Datos) -> some View {
        seccion(.compromisos, estado: Logica.estadoCompromisos(tienePagos: datos.tienePagos, pagos: datos.pagos,
                                                                 comparacion: soloGastos ? nil : datos.comparacion)) {
            if !datos.tienePagos {
                sinPagos(datos)
            } else {
                tarjeta {
                    ForEach(datos.pagos.filter(\.vencido)) { vencido in
                        filaAviso(Texto.vencido(vencido), icono: "calendar.badge.clock", id: "health_commit_overdue") {
                            abrir(.pago(vencido.id))
                        }
                        Divider().padding(.leading, DS.Spacing.md)
                    }
                    comparacionBloque(datos)
                        .padding(DS.Spacing.md)
                    if !datos.pagos.isEmpty {
                        Divider().padding(.leading, DS.Spacing.md)
                        Text(Texto.pendientes(datos.pagos.count, hasta: datos.finDeMes))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.top, DS.Spacing.sm)
                        ForEach(datos.pagos.prefix(Logica.maximoPagos)) { pago in
                            filaPago(pago)
                        }
                    }
                    Divider().padding(.leading, DS.Spacing.md)
                    let noAlcanza = datos.comparacion.map { !$0.alcanza } ?? false
                    filaEnlace(noAlcanza && !soloGastos ? Texto.revisarOMover : Texto.verTusPagos,
                               icono: "calendar", id: "health_commit_open_payments") { abrir(.pagos) }
                }
            }
        }
    }

    @ViewBuilder
    private func comparacionBloque(_ datos: Datos) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let c = datos.comparacion {
                if datos.pagos.isEmpty {
                    frase(Texto.todoPagado(datos.finDeMes), id: "health_commit_lead")
                    if let proximo = datos.proximoPago {
                        Text(Texto.proximoPago(proximo.nombre, fecha: proximo.fecha))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if soloGastos {
                    frase(Texto.compromisosFraseSoloGastos(falta: monto(c.faltaPagar, estimado: c.faltaEsAproximado)),
                          id: "health_commit_lead")
                } else {
                    let falta = monto(c.faltaPagar, estimado: c.faltaEsAproximado)
                    let dinero = monto(c.dineroHoy, estimado: c.dineroEsAproximado)
                    let segunda = c.alcanza
                        ? Texto.alcanza(sobra: monto(c.diferencia, estimado: c.diferenciaEsAproximada))
                        : Texto.noAlcanza(mesSiguiente: Texto.mes(datos.finDeMes.addingTimeInterval(1)))
                    frase("\(Texto.compromisosFrase(falta: falta, dinero: dinero)) \(segunda)", id: "health_commit_lead")
                    barras(c)
                    if c.cuentaApuntadoFuturo {
                        lineaSecundaria(Texto.apuntadoFuturo(monto(abs(c.apuntadoFuturo)), resta: c.apuntadoFuturo < 0),
                                        id: "health_commit_future_dated")
                    }
                    if !c.alcanza {
                        Text(Texto.faltarian(monto(-c.diferencia, estimado: c.diferenciaEsAproximada)))
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(Color.saludAmbar)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("health_commit_short")
                    }
                }
                if !soloGastos {
                    ForEach(datos.cuentasEnRojo, id: \.nombre) { cuenta in
                        lineaSecundaria(Texto.cuentaEnNegativo(cuenta.nombre), id: "health_commit_negative_account")
                    }
                    if let primero = datos.ingresos.first, !datos.pagos.isEmpty {
                        lineaSecundaria(Texto.ingreso(monto(primero.monto, primero.moneda), de: primero.nombre,
                                                      fecha: primero.fecha, mas: datos.ingresos.count - 1),
                                        id: "health_commit_income")
                    }
                }
            }
        }
    }

    private func lineaSecundaria(_ texto: String, id: String) -> some View {
        Text(texto)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(id)
    }

    /// Dos barras a la misma escala: lo que falta pagar y el dinero de hoy.
    private func barras(_ c: Logica.Comparacion) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            barra(Texto.teFaltaPagar, valor: c.faltaPagar, estimado: c.faltaEsAproximado, proporcion: c.barraFalta,
                  relleno: c.alcanza ? AnyShapeStyle(.thAccent) : AnyShapeStyle(Color.saludAmbarRelleno),
                  id: "health_commit_to_pay")
            barra(Texto.tuDineroHoy, valor: c.dineroHoy, estimado: c.dineroEsAproximado, proporcion: c.barraDinero,
                  relleno: AnyShapeStyle(Color.incomeFill), id: "health_commit_money_today")
        }
    }

    private func barra(
        _ titulo: String, valor: Double, estimado: Bool, proporcion: Double, relleno: AnyShapeStyle, id: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            AdaptiveRowStack(spacing: DS.Spacing.sm) {
                Text(titulo)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            } trailing: {
                AmountText(value: valor, currencyCode: moneda, font: DS.Typography.subheadlineEmphasized,
                           isEstimate: estimado)
            }
            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(relleno)
                            .frame(width: geo.size.width * min(1, max(0, proporcion)))
                    }
                }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    private func filaPago(_ pago: Logica.Pago) -> some View {
        Button { abrir(.pago(pago.id)) } label: {
            HStack(spacing: DS.Spacing.md) {
                if !esAX { insigniaDeFecha(pago) }
                AdaptiveRowStack(spacing: DS.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(pago.nombre)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(.primary)
                            .lineLimit(esAX ? nil : 2)
                        Text(Texto.cuando(dias: pago.dias))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                } trailing: {
                    AmountText(value: pago.monto, currencyCode: pago.moneda, font: DS.Typography.subheadlineEmphasized)
                }
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("health_payment_row")
    }

    private func insigniaDeFecha(_ pago: Logica.Pago) -> some View {
        VStack(spacing: 0) {
            Text(pago.fecha, format: .dateTime.day())
                .font(DS.Typography.subheadlineEmphasized)
                .monospacedDigit()
            Text(pago.fecha, format: .dateTime.month(.abbreviated))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(width: iconSize + DS.Spacing.sm)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func sinPagos(_ datos: Datos) -> some View {
        tarjeta {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if soloGastos {
                    frase(Texto.sinPagosSinDinero, id: "health_payments_empty_lead")
                } else {
                    frase(Texto.sinPagos(dinero: monto(datos.dineroHoy)), id: "health_payments_empty_lead")
                }
                if !datos.cobrosQueSeRepiten.isEmpty {
                    Button { abrir(.pagos) } label: {
                        HStack(alignment: .top, spacing: DS.Spacing.sm) {
                            icono("arrow.triangle.2.circlepath", tinte: AnyShapeStyle(.thAccentText))
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(Texto.cobrosTitulo)
                                    .font(DS.Typography.labelSmall)
                                    .foregroundStyle(.secondary)
                                Text(Texto.cobros(Array(datos.cobrosQueSeRepiten.prefix(3))))
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(Texto.cobrosBoton)
                                    .font(DS.Typography.subheadlineEmphasized)
                                    .foregroundStyle(.thAccentText)
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: DS.Spacing.sm)
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("health_payments_recurring")
                }
                YalaPrimaryButton(Texto.agregarPago, icon: "plus") { abrir(.pagos) }
                    .accessibilityIdentifier("health_payments_empty")
            }
            .padding(DS.Spacing.md)
        }
    }

    // MARK: - Ritmo

    private func seccionRitmo(_ datos: Datos) -> some View {
        let racha = datos.racha
        return seccion(.ritmo, estado: Logica.estadoRitmo(score: nota)) {
            tarjeta {
                Button { abrir(racha.registroHoy ? .registros : .nuevoRegistro) } label: {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "flame.fill")
                                .font(DS.Typography.title3)
                                .foregroundStyle(racha.dias > 0 ? Color.saludAmbarRelleno : DS.Semantic.disabledForeground)
                                .frame(width: iconSize, height: iconSize)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(Texto.rachaDias(racha.dias))
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(.primary)
                                    .accessibilityIdentifier("health_streak_days")
                                Text(racha.registroHoy ? Texto.rachaHoy
                                     : (racha.dias > 0 ? Texto.rachaMantener : Texto.rachaEmpezar))
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .multilineTextAlignment(.leading)
                            Spacer(minLength: DS.Spacing.sm)
                            if !racha.registroHoy {
                                Text(Texto.rachaBoton)
                                    .font(DS.Typography.subheadlineEmphasized)
                                    .foregroundStyle(.thAccentText)
                            }
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        tira(racha)
                    }
                    .padding(DS.Spacing.md)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("health_streak")
            }
        }
    }

    // MARK: - Lo que te queda

    /// Cuánto entró, cuánto salió y lo que queda, con la cifra de la nota (lote 2). Sin ingresos, por qué no cuenta.
    private var seccionTeQueda: some View {
        seccion(.teQueda, estado: Logica.estadoTeQueda(score: nota)) {
            tarjeta {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    if let cifras = nota.savingsFigures, let tasa = cifras.rate {
                        let entro = monto(cifras.income, estimado: cifras.incomeIsApproximate)
                        let salio = monto(cifras.expense, estimado: cifras.expenseIsApproximate)
                        frase(cifras.left >= 0
                              ? Texto2.fraseQueda(entro: entro, salio: salio,
                                                  queda: monto(cifras.left, estimado: cifras.isApproximate),
                                                  porcentaje: Int((tasa * 100).rounded()))
                              : Texto2.fraseSePasa(entro: entro, salio: salio,
                                                   deMas: monto(-cifras.left, estimado: cifras.isApproximate)),
                              id: "health_savings_lead")
                    } else {
                        frase(Texto2.fraseSinIngresos, id: "health_savings_lead")
                    }
                }
                .padding(DS.Spacing.md)
                if nota.savingsFigures != nil {
                    Divider().padding(.leading, DS.Spacing.md)
                    filaEnlace(Texto2.boton, icono: "chart.pie", id: "health_savings_open_distribution") {
                        abrir(.distribucion)
                    }
                }
            }
        }
    }

    private typealias Texto2 = L10n.NotaSaludTeQueda

    private func tira(_ racha: Logica.Racha) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: 0) {
                ForEach(Array(racha.tira.enumerated()), id: \.offset) { indice, conRegistro in
                    let esHoy = indice == racha.tira.count - 1
                    Circle()
                        .fill(conRegistro ? AnyShapeStyle(.thAccent) : AnyShapeStyle(Color.primary.opacity(0.1)))
                        .overlay {
                            if esHoy { Circle().strokeBorder(Color.primary.opacity(0.6), lineWidth: 1.5) }
                        }
                        // Encoge con el ancho: con letra grande, 14 puntos de tamaño fijo no caben.
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: dotSize)
                        .padding(.horizontal, 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            Text(Texto.rachaTira(racha.tira.count))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - ¿Cómo se calcula?

    private var comoSeCalcula: some View {
        DisclosureGroup(isExpanded: $muestraComoSeCalcula) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(L10n.Panel.Health.totalSheetExplanation)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: DS.Spacing.sm) {
                    filaParte(L10n.Panel.Health.subScoreBudget, L10n.Panel.Health.partBudget,
                              FinancialScoreCalculator.weightBudget, nota.budget)
                    Divider()
                    filaParte(L10n.Panel.Health.subScoreBills, L10n.Panel.Health.partBills,
                              FinancialScoreCalculator.weightCommitments, nota.bills)
                    Divider()
                    filaParte(L10n.Panel.Health.subScoreActivity, L10n.Panel.Health.partActivity,
                              FinancialScoreCalculator.weightRhythm, nota.activity)
                    if !soloGastos {
                        Divider()
                        filaParte(L10n.NotaSaludTeQueda.nombre, L10n.NotaSaludTeQueda.detalleParte,
                                  FinancialScoreCalculator.weightSavings, nota.savings)
                    }
                }
                if let falta = FinancialScoreCopy.missingLine(for: nota) {
                    Text(falta)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("health_sheet_missing_parts")
                }
                Text(L10n.Panel.Health.scaleNote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, DS.Spacing.sm)
        } label: {
            Text(Texto.seccionComoSeCalcula)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)
        }
        .tint(.secondary)
        .padding(DS.Spacing.md)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityIdentifier("health_how_it_works")
    }

    private func filaParte(_ titulo: String, _ detalle: String, _ peso: Double, _ valor: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Panel.Health.partTitle(titulo, weight: Int((peso * 100).rounded())))
                    .font(DS.Typography.subheadlineEmphasized)
                Text(detalle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(valor.map { "\($0)" } ?? L10n.Panel.Health.partNotCounting)
                .font(valor == nil ? DS.Typography.caption : DS.Typography.headline)
                .monospacedDigit()
                .foregroundStyle(valor == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Piezas

    private func icono(_ nombre: String, tinte: AnyShapeStyle) -> some View {
        Image(systemName: nombre)
            .font(DS.Typography.subheadline)
            .foregroundStyle(tinte)
            .frame(width: iconSize * 0.85, height: iconSize * 0.85)
            .background(tinte.opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            .accessibilityHidden(true)
    }

    /// Un consejo con su enlace: etiqueta, cuerpo y la acción en el color del tema. Toda la fila se toca.
    private func consejoFila(
        icono nombre: String, etiqueta: String, cuerpo: String, enlace: String, id: String,
        accion: @escaping () -> Void
    ) -> some View {
        Button(action: accion) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                icono(nombre, tinte: AnyShapeStyle(.thAccentText))
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(etiqueta)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                    Text(cuerpo)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(enlace)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thAccentText)
                        .padding(.top, DS.Spacing.xxs)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    /// Un aviso tranquilo (un pago vencido): sin rojo, con su toque.
    private func filaAviso(_ texto: String, icono nombre: String, id: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                icono(nombre, tinte: AnyShapeStyle(Color.saludAmbar))
                Text(texto)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    /// Una fila de acción con chevron (nunca un botón debajo de otro).
    private func filaEnlace(_ texto: String, icono nombre: String, id: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: DS.Spacing.md) {
                icono(nombre, tinte: AnyShapeStyle(.thAccentText))
                Text(texto)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.thAccentText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// «Ajusta el límite a lo real»: el presupuesto que se abre en su editor y el límite que llega escrito.
struct AjusteDeLimite: Identifiable {
    let budget: Budget
    let limite: Double
    var id: PersistentIdentifier { budget.persistentModelID }
}

/// A dónde lleva cada toque de la hoja.
enum SaludFinancieraDetalleDestino: Equatable {
    case presupuesto(UUID)
    case presupuestos
    case pago(UUID)
    case pagos
    case cuenta(UUID)
    case nuevoRegistro
    case registros
    /// Registros con el filtro de lo que más pesa en un presupuesto.
    case registrosFiltrados(SaludFinancieraDetalleLogica.Recorte.Filtro)
    /// Estadísticas › Resumen, donde vive el resumen con IA.
    case resumenIA
    /// La hoja de Yala Pro.
    case pro
    /// Estadísticas › Distribución: en qué se va el dinero («Lo que te queda»).
    case distribucion
}

extension Color {
    // A11Y-DM: el ámbar de la hoja de Salud financiera («para revisar», «te pasaste por»), que no es el rosa de alarma.
    // Como TEXTO necesita contraste: en claro un ámbar oscuro (#9A5B00, 5,4:1 sobre blanco) y en oscuro el claro.
    static let saludAmbar = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.70, blue: 0.25, alpha: 1)
            : UIColor(red: 0.60, green: 0.36, blue: 0.0, alpha: 1)
    })
    // A11Y-DM: el mismo ámbar como RELLENO (barras, llama): la paleta vale ahí porque no lleva texto encima.
    static let saludAmbarRelleno = Color(hex: saludAmbarRellenoHex)
    static let saludAmbarRellenoHex = "F59E0B"
}
