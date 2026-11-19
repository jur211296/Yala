//
//  SaludFinancieraDetalleView.swift
//  Yala
//
//  El contenido de la hoja de la nota TOTAL (variante A del 18-nov-2026, «lista de acciones»): la nota arriba, lo que
//  hay que mirar, los presupuestos con su barra, los próximos pagos y si el saldo los cubre, la racha de días
//  registrando y qué hacer para subir la nota. Cada fila lleva a su vista. Cómo se calcula la nota queda plegado al final.
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

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var cargador = SaludFinancieraDetalleCargador()
    @State private var muestraComoSeCalcula = false

    // A11Y-DT: el anillo crece con el tamaño del texto.
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 76
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 32
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 14

    /// A tamaños de accesibilidad los importes bajan a su propia línea y la cabecera se apila: nunca se cortan.
    private var esAX: Bool { dynamicTypeSize.isAccessibilitySize }

    private typealias Texto = L10n.SaludFinancieraDetalle
    private typealias Logica = SaludFinancieraDetalleLogica

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            cabecera
            if let datos = cargador.datos {
                secciones(datos)
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
        .task {
            await cargador.cargar(
                context: modelContext,
                score: score,
                currencyCode: appPreferences.defaultCurrencyCode.rawValue,
                includeGroupsInTotal: appPreferences.includeGroupsInPanelTotal,
                includeGroupTransactionsInStats: appPreferences.includeGroupTransactionsInStats
            )
        }
    }

    // MARK: - Cabecera

    private var cabecera: some View {
        let layout = esAX
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.lg))
        return layout {
            ZStack {
                ScoreRingView(
                    progress: score.total.map { Double($0) / 100.0 } ?? 0,
                    size: ringSize,
                    lineWidth: ringSize * 0.1,
                    foreground: anilloColor
                )
                Text(score.total.map { "\($0)" } ?? L10n.Panel.Health.emptyBadge)
                    .font(DS.Typography.title2)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(score.total == nil ? DS.Semantic.disabledForeground : Color.primary)
                    .padding(.horizontal, ringSize * 0.12)
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(score.total.map { L10n.Panel.Health.scoreVoiceover(score: $0) } ?? L10n.Panel.Health.noData)
            // En el anillo y no en el contenedor: un id en el contenedor pisa los de las secciones.
            .accessibilityIdentifier("health_breakdown")

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(FinancialScoreCopy.totalHeadline(for: score, isExpensesOnlyMode: sessionState.isExpensesOnlyMode))
                    .font(DS.Typography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("health_sheet_headline")
                partes
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Las tres partes en una línea de cápsulas, con su nota o «—» si aún no cuenta.
    private var partes: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.xs) { capsulasDePartes }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) { capsulasDePartes }
        }
    }

    @ViewBuilder
    private var capsulasDePartes: some View {
        capsula(.budget, valor: score.budget)
        capsula(.activity, valor: score.activity)
        capsula(.bills, valor: score.bills)
    }

    private func capsula(_ parte: FinancialScoreDetailKind, valor: Int?) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(parte.tint ?? .secondary)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(FinancialScoreCopy.partName(parte))
                .foregroundStyle(.secondary)
            Text(valor.map { "\($0)" } ?? "—")
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .font(DS.Typography.caption)
        .lineLimit(esAX ? nil : 1)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(FinancialScoreCopy.partName(parte)), \(valor.map { "\($0)" } ?? L10n.Panel.Health.partNotCounting)")
    }

    private var anilloColor: AnyShapeStyle {
        guard let total = score.total else { return AnyShapeStyle(DS.Semantic.disabledForeground.opacity(0.4)) }
        return AnyShapeStyle(FinancialScoreTint.color(for: total))
    }

    // MARK: - Secciones

    @ViewBuilder
    private func secciones(_ datos: SaludFinancieraDetalleCargador.Datos) -> some View {
        let alertas = Logica.alertas(
            presupuestos: datos.presupuestos,
            pagos: datos.pagos,
            cobertura: datos.cobertura,
            cuentasEnRojo: datos.cuentasEnRojo,
            isExpensesOnlyMode: sessionState.isExpensesOnlyMode
        )
        seccion(Texto.seccionAlertas, id: "health_section_alerts") { alertasBloque(alertas) }
        seccion(Texto.seccionPresupuestos, id: "health_section_budgets") { presupuestosBloque(datos.presupuestos) }
        seccion(Texto.seccionPagos, id: "health_section_payments") { pagosBloque(datos) }
        seccion(Texto.seccionRacha, id: "health_section_streak") { rachaBloque(datos.racha) }
        let pasos = Logica.pasos(
            score: score, tienePresupuestos: hasBudgets || !datos.presupuestos.isEmpty,
            tienePagos: datos.tienePagos, racha: datos.racha
        )
        if !pasos.isEmpty {
            seccion(Texto.seccionSubir, id: "health_section_improve") { pasosBloque(pasos) }
        }
    }

    private func seccion(_ titulo: String, id: String, @ViewBuilder contenido: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(titulo)
                .font(DS.Typography.title3)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) { contenido() }
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    // MARK: Alertas

    @ViewBuilder
    private func alertasBloque(_ alertas: [Logica.Alerta]) -> some View {
        if alertas.isEmpty {
            fila(icono: "checkmark.seal.fill", tinte: AnyShapeStyle(Color.incomeAmount), titulo: Texto.sinAlertasTitulo,
                 detalle: Texto.sinAlertasDetalle, id: "health_alerts_none")
        } else {
            ForEach(Array(alertas.enumerated()), id: \.element.id) { indice, alerta in
                if indice > 0 { Divider().padding(.leading, DS.Spacing.md + iconSize + DS.Spacing.md) }
                filaAlerta(alerta)
            }
        }
    }

    @ViewBuilder
    private func filaAlerta(_ alerta: Logica.Alerta) -> some View {
        switch alerta {
        case .presupuestoPasado(let p):
            fila(icono: "exclamationmark.triangle.fill", tinte: AnyShapeStyle(Color.overBudgetText), titulo: Texto.pasadoTitulo(p.nombre),
                 detalle: Texto.pasadoDetalle, id: "health_alert_over_budget", destino: .presupuesto(p.id)) {
                AmountText(value: -p.restante, currencyCode: p.moneda, font: DS.Typography.subheadlineEmphasized,
                           tint: .color(Color.overBudgetText), forceSign: true)
            }
        case .presupuestoAlLimite(let p):
            fila(icono: "gauge.with.dots.needle.67percent", tinte: AnyShapeStyle(DS.Semantic.warningForeground),
                 titulo: p.estado == .reachedLimit ? Texto.llegoAlLimiteTitulo(p.nombre) : Texto.alLimiteTitulo(p.nombre),
                 detalle: Texto.alLimiteDetalle(porcentaje: Int(p.porcentaje.rounded())),
                 id: "health_alert_at_limit", destino: .presupuesto(p.id))
        case .presupuestosAlLimite(let lista):
            fila(icono: "gauge.with.dots.needle.67percent", tinte: AnyShapeStyle(DS.Semantic.warningForeground),
                 titulo: Texto.variosAlLimiteTitulo(lista.count),
                 detalle: lista.map(\.nombre).formatted(.list(type: .and).locale(LanguageManager.resolved.locale)),
                 id: "health_alert_at_limit", destino: .presupuestos)
        case .cuentaEnRojo(let nombre, let id):
            fila(icono: "creditcard.trianglebadge.exclamationmark", tinte: AnyShapeStyle(Color.overBudgetText),
                 titulo: Texto.cuentaEnRojoTitulo(nombre), detalle: Texto.cuentaEnRojoDetalle,
                 id: "health_alert_negative_account", destino: id.map(SaludFinancieraDetalleDestino.cuenta))
        case .pagoVencido(let p):
            fila(icono: "calendar.badge.exclamationmark", tinte: AnyShapeStyle(Color.overBudgetText), titulo: Texto.vencidoTitulo(p.nombre),
                 detalle: Texto.vencidoDetalle, id: "health_alert_overdue", destino: .pago(p.id)) {
                AmountText(value: p.monto, currencyCode: p.moneda, font: DS.Typography.subheadlineEmphasized)
            }
        case .pagosSinCubrir(let c):
            fila(icono: "banknote", tinte: AnyShapeStyle(Color.overBudgetText), titulo: Texto.sinCubrirTitulo, detalle: Texto.sinCubrirDetalle,
                 id: "health_alert_not_covered", destino: .pagos) {
                AmountText(value: c.alCierre, currencyCode: c.moneda, font: DS.Typography.subheadlineEmphasized,
                           tint: .color(Color.overBudgetText), isEstimate: c.esAproximada)
            }
        }
    }

    // MARK: Presupuestos

    @ViewBuilder
    private func presupuestosBloque(_ presupuestos: [Logica.Presupuesto]) -> some View {
        if presupuestos.isEmpty {
            vacio(icono: "chart.pie", titulo: Texto.presupuestosVacioTitulo, detalle: Texto.presupuestosVacioDetalle,
                  boton: Texto.presupuestosVacioBoton, id: "health_budgets_empty", destino: .presupuestos)
        } else {
            let visibles = Array(presupuestos.prefix(Logica.maximoPresupuestos))
            ForEach(Array(visibles.enumerated()), id: \.element.id) { indice, p in
                if indice > 0 { Divider().padding(.leading, DS.Spacing.md) }
                filaPresupuesto(p)
            }
            if presupuestos.count > visibles.count {
                Divider().padding(.leading, DS.Spacing.md)
                verTodos(Texto.verTodosPresupuestos(presupuestos.count), id: "health_budgets_see_all", destino: .presupuestos)
            }
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
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(p.nombre)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(.primary)
                            .lineLimit(esAX ? nil : 2)
                        if esAX { BudgetStatusLabel(status: p.estado, font: DS.Typography.caption) }
                    }
                    Spacer(minLength: DS.Spacing.sm)
                    if !esAX { BudgetStatusLabel(status: p.estado) }
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                BudgetProgressBar(percentage: p.porcentaje, color: p.color, isExceeded: p.estado == .overLimit)
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
                .foregroundStyle(.secondary)
            AmountText(value: abs(p.restante), currencyCode: p.moneda, font: DS.Typography.caption,
                       tint: p.restante < 0 ? .color(Color.overBudgetText) : .primary)
        }
    }

    // MARK: Pagos

    @ViewBuilder
    private func pagosBloque(_ datos: SaludFinancieraDetalleCargador.Datos) -> some View {
        if !datos.tienePagos {
            vacio(icono: "calendar.badge.plus", titulo: Texto.pagosVacioTitulo, detalle: Texto.pagosVacioDetalle,
                  boton: Texto.pagosVacioBoton, id: "health_payments_empty", destino: .pagos)
        } else {
            let visibles = Array(datos.pagos.prefix(Logica.maximoPagos))
            if visibles.isEmpty {
                Text(Texto.sinPagosCerca)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(Array(visibles.enumerated()), id: \.element.id) { indice, pago in
                if indice > 0 { Divider().padding(.leading, DS.Spacing.md + iconSize + DS.Spacing.md) }
                filaPago(pago)
            }
            if let cobertura = datos.cobertura, !sessionState.isExpensesOnlyMode {
                Divider().padding(.leading, DS.Spacing.md)
                filaCobertura(cobertura)
            }
            Divider().padding(.leading, DS.Spacing.md)
            verTodos(Texto.verTodosPagos, id: "health_payments_see_all", destino: .pagos)
        }
    }

    private func filaPago(_ pago: Logica.Pago) -> some View {
        Button { abrir(.pago(pago.id)) } label: {
            HStack(spacing: DS.Spacing.md) {
                if !esAX { insigniaDeFecha(pago) }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(pago.nombre)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .lineLimit(esAX ? nil : 2)
                    Text(Texto.cuando(dias: pago.dias))
                        .font(DS.Typography.caption)
                        .foregroundStyle(pago.dias < 0 ? AnyShapeStyle(Color.overBudgetText) : AnyShapeStyle(.secondary))
                    if esAX {
                        AmountText(value: pago.monto, currencyCode: pago.moneda, font: DS.Typography.subheadlineEmphasized)
                    }
                }
                Spacer(minLength: DS.Spacing.sm)
                if !esAX {
                    AmountText(value: pago.monto, currencyCode: pago.moneda, font: DS.Typography.subheadlineEmphasized)
                }
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

    private func filaCobertura(_ c: Logica.Cobertura) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: c.cubre ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(c.cubre ? Color.incomeAmount : Color.overBudgetText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(c.cubre ? Texto.cubre : Texto.noCubre)
                    .font(DS.Typography.subheadlineEmphasized)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.ProjectedFlow.closingBalance(MonthEndBalanceLogic.dayAndMonth(c.fechaCierre)))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if esAX { montoDeCierre(c) }
            }
            Spacer(minLength: DS.Spacing.sm)
            if !esAX { montoDeCierre(c) }
        }
        .padding(DS.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("health_payments_coverage")
    }

    private func montoDeCierre(_ c: Logica.Cobertura) -> some View {
        AmountText(value: c.alCierre, currencyCode: c.moneda, font: DS.Typography.subheadlineEmphasized,
                   tint: c.cubre ? .primary : .color(Color.overBudgetText), isEstimate: c.esAproximada)
    }

    // MARK: Racha

    private func rachaBloque(_ racha: Logica.Racha) -> some View {
        Button { abrir(racha.registroHoy ? .registros : .nuevoRegistro) } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "flame.fill")
                        .font(DS.Typography.title3)
                        .foregroundStyle(racha.dias > 0 ? DS.Semantic.warningForeground : DS.Semantic.disabledForeground)
                        .frame(width: iconSize, height: iconSize)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(Texto.rachaDias(racha.dias))
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("health_streak_days")
                        Text(racha.registroHoy ? Texto.rachaHoy : (racha.dias > 0 ? Texto.rachaMantener : Texto.rachaEmpezar))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DS.Spacing.sm)
                    if !racha.registroHoy && !esAX {
                        Text(Texto.rachaBoton)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(.thOnAccent)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(.thAccent, in: Capsule())
                    } else {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                tira(racha)
                if !racha.registroHoy && esAX {
                    Text(Texto.rachaBoton)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thOnAccent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(.thAccent, in: Capsule())
                }
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("health_streak")
    }

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

    // MARK: Para subir la nota

    @ViewBuilder
    private func pasosBloque(_ pasos: [Logica.Paso]) -> some View {
        ForEach(Array(pasos.enumerated()), id: \.element.id) { indice, paso in
            if indice > 0 { Divider().padding(.leading, DS.Spacing.md + iconSize + DS.Spacing.md) }
            fila(icono: "arrow.up.circle.fill", tinte: AnyShapeStyle(.thAccentText), titulo: Texto.paso(paso),
                 detalle: Texto.pesoDeLaParte(FinancialScoreCopy.partName(paso.parte),
                                              porcentaje: Int((peso(paso.parte) * 100).rounded())),
                 id: "health_improve_\(paso.rawValue)", destino: destino(de: paso))
        }
    }

    private func destino(de paso: Logica.Paso) -> SaludFinancieraDetalleDestino {
        switch paso {
        case .crearPresupuesto, .revisarPresupuestos: .presupuestos
        case .registrarHoy: .nuevoRegistro
        case .revisarRitmo: .registros
        case .agregarPagos, .revisarPagos: .pagos
        }
    }

    private func peso(_ parte: FinancialScoreDetailKind) -> Double {
        switch parte {
        case .budget: FinancialScoreCalculator.weightBudget
        case .activity: FinancialScoreCalculator.weightRhythm
        case .bills, .total: FinancialScoreCalculator.weightCommitments
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
                              FinancialScoreCalculator.weightBudget, score.budget)
                    Divider()
                    filaParte(L10n.Panel.Health.subScoreActivity, L10n.Panel.Health.partActivity,
                              FinancialScoreCalculator.weightRhythm, score.activity)
                    Divider()
                    filaParte(L10n.Panel.Health.subScoreBills, L10n.Panel.Health.partBills,
                              FinancialScoreCalculator.weightCommitments, score.bills)
                }
                if let falta = FinancialScoreCopy.missingLine(for: score) {
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

    private func fila(
        icono: String,
        tinte: AnyShapeStyle,
        titulo: String,
        detalle: String?,
        id: String,
        destino: SaludFinancieraDetalleDestino? = nil,
        @ViewBuilder trailing: () -> some View = { EmptyView() }
    ) -> some View {
        let contenido = HStack(spacing: DS.Spacing.md) {
            Image(systemName: icono)
                .font(DS.Typography.body)
                .foregroundStyle(tinte)
                .frame(width: iconSize, height: iconSize)
                .background(tinte.opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(titulo)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detalle {
                    Text(detalle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if esAX { trailing() }
            }
            Spacer(minLength: DS.Spacing.sm)
            if !esAX { trailing() }
            if destino != nil {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .multilineTextAlignment(.leading)
        .padding(DS.Spacing.md)
        .contentShape(Rectangle())

        return Group {
            if let destino {
                Button { abrir(destino) } label: { contenido }
                    .buttonStyle(.plain)
            } else {
                contenido
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    private func vacio(
        icono: String, titulo: String, detalle: String, boton: String, id: String,
        destino: SaludFinancieraDetalleDestino
    ) -> some View {
        Button { abrir(destino) } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: icono)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thAccentText)
                    .frame(width: iconSize, height: iconSize)
                    .background(AnyShapeStyle(.thAccent).opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(titulo)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                    Text(detalle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(boton)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thOnAccent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(.thAccent, in: Capsule())
                        .padding(.top, DS.Spacing.xs)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    private func verTodos(_ texto: String, id: String, destino: SaludFinancieraDetalleDestino) -> some View {
        Button { abrir(destino) } label: {
            HStack {
                Text(texto)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.thAccentText)
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

/// A dónde lleva cada toque de la hoja.
enum SaludFinancieraDetalleDestino: Equatable {
    case presupuesto(UUID)
    case presupuestos
    case pago(UUID)
    case pagos
    case cuenta(UUID)
    case nuevoRegistro
    case registros
}
