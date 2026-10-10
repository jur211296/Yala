//
//  ApproximateMarkWiringTests.swift
//  YalaTests
//
//  Que la señal de «aproximado» llegue de verdad a la PANTALLA.
//  Ticket `fx-presentation-still-shows-1to1`.
//
//  **Por qué hace falta este archivo, dicho sin rodeos.** Toda la cañería —converter, calculadores,
//  ViewModels— está cubierta por tests de comportamiento, y aun así se puede revertir el `isEstimate:`
//  de los cuatro `AmountText` que pintan los totales y **la suite entera sigue en verde**. Eso es
//  exactamente el bug del ticket: el número vuelve a presentarse como exacto. Un `AmountText` es una
//  `View` y afirmar su render pide un XCUITest con una cuenta multimoneda y una fila de tasas
//  incompleta — el más caro de montar de todo el ticket.
//
//  El sustituto es fijar el CABLEADO leyendo el fuente, que es el idioma que este repo ya usa para
//  el mismo compromiso (`PreferredCurrencyChangeOrderTests`, `ExchangeRateMergeWiringTests`). Es más
//  débil que un test de comportamiento —fija el texto, no el resultado— y se elige a conciencia: sin
//  él, quitar la marca de una pantalla no lo nota nadie.
//

import Foundation
import Testing

@testable import Yala

@Suite("Cableado de la marca de aproximado (source-scan)")
struct ApproximateMarkWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El número grande del Panel, en sus dos modos. El de Solo Gastos lleva **solo** el lado del
    /// gasto: es lo que impide que un ingreso antiguo mal convertido marque un número que no lo
    /// incluye.
    @Test("El hero del Panel pasa la marca, y el lado correcto en cada modo")
    func panelHeroPassesTheMark() throws {
        let src = try Self.source("Yala/App/Views/Panel/HeroMonthView.swift")

        #expect(src.contains("isEstimate: periodSummary.expenseApproximate"), """
            El hero en modo Solo Gastos pinta `periodSummary.expense`: su marca tiene que ser la del
            gasto, no la del período entero.
            """)
        #expect(src.contains("isEstimate: periodSummary.amountsAreApproximate"), """
            El hero normal pinta `available`, que agrega los dos lados.
            """)
    }

    /// VoiceOver tiene que oír lo mismo que se ve. La marca es información, y dejarla solo en el
    /// glifo la esconde justo de quien no puede verlo.
    @Test("La etiqueta de accesibilidad del Panel también lleva la marca")
    func panelAccessibilityLabelCarriesTheMark() throws {
        let src = try Self.source("Yala/App/Views/Panel/HeroMonthView.swift")
        let label = try #require(src.range(of: "private var heroAccessibilityLabel"))
        let scope = String(src[label.lowerBound...].prefix(700))

        #expect(scope.contains("isEstimate:"), """
            El monto de la etiqueta se formatea sin `isEstimate:`, así que VoiceOver lee como exacto
            el mismo número que en pantalla lleva el «≈».
            """)
    }

    /// El saldo del panorama es el caso más puro: se convierte al TC de HOY, sin ningún monto
    /// guardado en el que apoyarse. Sus tres composiciones del importe —resumen, resumen atribuido
    /// y el monto con jerarquía— tienen que llevar la marca, o dos de ellas contradicen a la tercera
    /// en la misma pantalla.
    @Test("El saldo del panorama pasa la marca en sus tres composiciones")
    func panoramaBalancePassesTheMark() throws {
        let src = try Self.source("Yala/App/Views/Panel/Sections/PanelPanoramaSection.swift")
        let ocurrencias = src.components(separatedBy: "isEstimate: viewModel.panelTotalBalanceIsApproximate").count - 1

        #expect(ocurrencias == 3, """
            Se esperaban 3 y hay \(ocurrencias). Los tres sitios pintan el MISMO saldo: si uno se
            queda sin marca, la pantalla se contradice a sí misma.
            """)
    }

    /// El hero de Tendencias muestra uno de tres números según la métrica, así que su marca no puede
    /// ser una señal única del período.
    @Test("El hero de Tendencias elige la marca de su métrica")
    func trendsHeroPicksTheMetricMark() throws {
        let src = try Self.source("Yala/App/Views/Statistics/TrendsTabView.swift")

        #expect(src.contains("isEstimate: heroKPIIsApproximate(for: summary)"), """
            Con `summary.amountsAreApproximate` a secas, un gasto mal convertido le pone «≈» al total
            de INGRESOS, donde no hubo ninguna conversión.
            """)
        let fn = try #require(src.range(of: "private func heroKPIIsApproximate"))
        let scope = String(src[fn.lowerBound...].prefix(400))
        #expect(scope.contains("incomeAmountsAreApproximate"))
        #expect(scope.contains("expenseAmountsAreApproximate"))
    }

    @Test("El hero de Estadísticas pasa la marca")
    func insightsHeroPassesTheMark() throws {
        let src = try Self.source("Yala/App/Views/Statistics/InsightsTabView.swift")
        #expect(src.contains("isEstimate: summary.amountsAreApproximate"), """
            Pinta `summary.netBalance`, que agrega los dos lados.
            """)
    }

    /// Y el productor del glifo, que es el eslabón que ningún test de la app ejercitaba: vaciar el
    /// efecto de `isEstimate` en el formateador dejaría toda la suite en verde y la app sin marca.
    @Test("El formateador antepone el símbolo de aproximado")
    func formatterPrependsTheApproximateSymbol() {
        let conMarca = CurrencyFormattingHelper.currency(
            1234.56, decimals: 2, identifier: "S/", forceSign: false, isEstimate: true
        )
        let sinMarca = CurrencyFormattingHelper.currency(
            1234.56, decimals: 2, identifier: "S/", forceSign: false, isEstimate: false
        )

        #expect(conMarca.hasPrefix("≈"), "se esperaba el prefijo «≈» y salió \(conMarca)")
        #expect(!sinMarca.hasPrefix("≈"))
        #expect(conMarca.contains(sinMarca.trimmingCharacters(in: .whitespaces)), """
            La marca ANTEPONE, no reemplaza: el número tiene que seguir siendo el mismo.
            """)
    }
}

//
//  MARK: - Superficies secundarias (`fx-approximate-mark-missing-on-secondary-surfaces`, 2026-09-09)
//
//  Mismo compromiso y misma técnica que arriba, sobre las pantallas que pintaban los MISMOS
//  importes sin la marca. Se añade aquí y no en un fichero nuevo a propósito: el molde es idéntico y
//  dos ficheros con el mismo propósito divergen.
//

@Suite("Cableado de la marca en superficies secundarias (source-scan)")
struct ApproximateMarkSecondarySurfacesWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El fuente sin las líneas que son comentario entero. Molde de `WidgetSessionSealTests`, y aquí
    /// tampoco es cosmética: los tests de abajo CUENTAN ocurrencias de símbolos que los docblocks de
    /// este mismo trabajo nombran a propósito. Documentar un invariante lo pondría en rojo sin que
    /// producción hubiera cambiado — que es la forma más tonta de que una red deje de usarse.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Fuente ya filtrado, para los tests que cuentan.
    private static func code(_ path: String) throws -> String { codeOnly(try source(path)) }

    /// El primero del AC: su summary ya traía las tres señales en la misma variable.
    @Test("Flujo de caja pasa la marca en sus cinco importes de período")
    func cashFlowWidgetPassesTheMark() throws {
        let src = try Self.code("Yala/App/Views/Panel/CashFlowWidget.swift")

        #expect(src.contains("isEstimate: summary.amountsAreApproximate"), """
            El `netFlow` del layout pequeño agrega los dos lados: su marca es la del neto.
            """)
        #expect(src.contains("isEstimate: kpiValueIsApproximate"), """
            El KPI del header muestra uno de tres números según `displayMode`. Con una señal única,
            un gasto mal convertido le pone «≈» al total de INGRESOS.
            """)
        // El EMPAREJAMIENTO, no solo la presencia de los dos símbolos: con `contains` sueltos, un
        // `case .income: return summary.expenseAmountsAreApproximate` pasaba en verde.
        let fn = try #require(src.range(of: "private var kpiValueIsApproximate"))
        let scope = String(src[fn.lowerBound...].prefix(400))
        #expect(scope.contains("case .income:            return summary.incomeAmountsAreApproximate"))
        #expect(scope.contains("case .expense:           return summary.expenseAmountsAreApproximate"))
        #expect(scope.contains("case .balance, .none:    return summary.amountsAreApproximate"))

        let income = src.components(separatedBy: "isEstimate: summary.incomeAmountsAreApproximate").count - 1
        let expense = src.components(separatedBy: "isEstimate: summary.expenseAmountsAreApproximate").count - 1
        #expect(income == 3, """
            Se esperaban 3 (barra del small, barra del medium y la etiqueta de accesibilidad del
            gráfico) y hay \(income).
            """)
        #expect(expense == 3, "ídem para el gasto; hay \(expense).")
    }

    /// La marca es información: dejarla solo en el glifo la esconde de quien no puede verlo.
    @Test("La etiqueta de accesibilidad del gráfico de flujo lleva la marca")
    func cashFlowChartAccessibilityCarriesTheMark() throws {
        let src = try Self.source("Yala/App/Views/Panel/CashFlowWidget.swift")
        let label = try #require(src.range(of: "L10n.Accessibility.cashFlowSummary("))
        // 700 y no 500: el bloque mide 454 caracteres hasta el segundo `isEstimate` y 501 hasta su
        // final, así que con 500 el test se ponía rojo por el recorte y no por el cableado.
        let scope = String(src[label.lowerBound...].prefix(700))
        #expect(scope.contains("isEstimate: summary.incomeAmountsAreApproximate"))
        #expect(scope.contains("isEstimate: summary.expenseAmountsAreApproximate"))
    }

    /// La peor omisión del ticket: la hoja existe PORQUE el saldo es multimoneda, y declaraba
    /// exacto justo el número que va a explicar.
    @Test("La hoja del saldo vivo pasa la marca, y su desglose la mide por divisa")
    func liveAnchorSheetPassesTheMark() throws {
        let src = try Self.source("Yala/App/Views/Panel/Sheets/BalanceLiveAnchorEducationSheet.swift")

        #expect(src.contains("isEstimate: liveAnchorIsApproximate"), """
            El número grande de «¿Cuánto tienes hoy?» sin marca es el caso que da nombre al ticket.
            """)
        #expect(src.contains("isEstimate: row.convertedIsApproximate"), """
            Cada fila del desglose lleva la calidad de SU conversión, no el OR del total: heredar la
            del saldo marcaría como dudosa una divisa cuya tasa sí era la de hoy.
            """)
        #expect(src.contains("convertCheckedWithLatestRate"), """
            La fila tiene que pedir la calidad, no solo el número — es la misma llamada que hace
            `LiveBalanceCalculator` para decidir la marca del total.
            """)
    }

    /// El carril entero, de punta a punta. Si un tramo se corta, la hoja recibe `false` y vuelve a
    /// mentir sin que nada se ponga rojo.
    @Test("La señal del saldo vivo recorre calculador, processor, ViewModels y vista")
    func liveAnchorSignalCrossesEveryHop() throws {
        let calc = try Self.source("Yala/App/Logic/Calculators/LiveBalanceCalculator.swift")
        #expect(calc.contains("amountsAreApproximate: breakdown.amountsAreApproximate"), """
            `LiveAnchorInfo` tiene que nacer con la señal del MISMO breakdown que le da el valor.
            """)

        let processor = try Self.source("Yala/Services/TrendDataProcessor.swift")
        #expect(processor.contains("liveAnchorIsApproximate = info.amountsAreApproximate"))
        #expect(processor.contains("liveAnchorIsApproximate: liveAnchorIsApproximate"))

        let panel = try Self.source("Yala/App/ViewModels/PanelViewModel.swift")
        #expect(panel.contains("newTrendLiveAnchorIsApproximate = result.liveAnchorIsApproximate"))
        let stats = try Self.source("Yala/App/ViewModels/StatisticsViewModel.swift")
        #expect(stats.contains("trendLiveAnchorIsApproximate = result.liveAnchorIsApproximate"))

        let chart = try Self.source("Yala/App/Views/Panel/TrendChartView.swift")
        #expect(chart.contains("liveAnchorIsApproximate: liveAnchorIsApproximate"), """
            El último salto: `TrendChartView` tiene que pasárselo a la hoja.
            """)

        // Los dos callsites de la gráfica. Si uno se queda sin pasarlo, esa pantalla abre la hoja
        // con `false` por defecto y no lo nota nadie.
        for path in [
            "Yala/App/Views/Statistics/TrendsTabView.swift",
            "Yala/App/Views/Panel/TrendsCarouselWidget.swift",
        ] {
            let src = try Self.source(path)
            #expect(src.contains("liveAnchorIsApproximate: "), "\(path) no pasa la señal a TrendChartView")
        }
    }

    @Test("El KPI de Distribución pasa la marca del régimen vivo")
    func distributionKPIPassesTheMark() throws {
        let view = try Self.source("Yala/App/Views/Statistics/CategoriesTabView.swift")
        #expect(view.contains("isEstimate: isBalanceMode ? (balanceKPI?.isApproximate ?? false) : false"), """
            La marca sigue al número, que cambia de fuente con el modo.
            """)

        let calc = try Self.source("Yala/App/Logic/Calculators/BalanceKPICalculator.swift")
        #expect(calc.contains("isApproximate: info.amountsAreApproximate"), """
            En el régimen vivo la señal viene del `LiveAnchorInfo`; si se cablea a `false`, el hero
            de Distribución vuelve a declararse exacto y toda la suite sigue verde.
            """)
    }

    @Test("Registros pasa la marca en sus tres importes")
    func recordsPassesTheMark() throws {
        let src = try Self.code("Yala/App/Views/Statistics/RecordsTabView.swift")
        #expect(src.contains("isEstimate: recordsSummary.balanceIsApproximate"))
        #expect(src.contains("isEstimate: recordsSummary.incomeIsApproximate"))
        #expect(src.contains("isEstimate: recordsSummary.expenseIsApproximate"))

        // Los dos chips van dentro de un `Button` cuyo `accessibilityLabel` TAPA la etiqueta que
        // `AmountText` se pone a sí mismo. Sin el `accessibilityValue`, VoiceOver no lee el número.
        let value = src.components(separatedBy: ".accessibilityValue(appPreferences.currency(").count - 1
        #expect(value == 2, "se esperaban 2 y hay \(value)")
    }

    @Test("Estadísticas pasa la marca en los chips y en el promedio diario")
    func insightsSecondarySurfacesPassTheMark() throws {
        let src = try Self.code("Yala/App/Views/Statistics/InsightsTabView.swift")
        let income = src.components(separatedBy: "isEstimate: summary.incomeAmountsAreApproximate").count - 1
        let expense = src.components(separatedBy: "isEstimate: summary.expenseAmountsAreApproximate").count - 1
        #expect(income == 1, "el chip de ingresos; hay \(income)")
        #expect(expense == 2, """
            El chip de gastos y el promedio diario, que es `totalExpense` dividido entre un entero
            exacto. Hay \(expense).
            """)
    }

    @Test("Tendencias y el hero del Panel marcan también sus chips")
    func heroChipsPassTheMark() throws {
        let trends = try Self.source("Yala/App/Views/Statistics/TrendsTabView.swift")
        #expect(trends.contains("isEstimate: summary.incomeAmountsAreApproximate"))
        #expect(trends.contains("isEstimate: summary.expenseAmountsAreApproximate"))

        let hero = try Self.code("Yala/App/Views/Panel/HeroMonthView.swift")
        #expect(hero.contains("isEstimate: periodSummary.incomeApproximate"))
        // `expenseApproximate` sale 3 veces: hero de Solo Gastos, pill de gasto y la etiqueta de
        // accesibilidad. Es el MISMO número en las tres, y ese es el punto: hasta hoy la pill lo
        // pintaba exacto mientras el hero de al lado lo pintaba con «≈».
        let expense = hero.components(separatedBy: "periodSummary.expenseApproximate").count - 1
        #expect(expense == 3, "se esperaban 3 y hay \(expense)")
    }

    /// El widget de inicio es el único donde la señal no existía: había que producirla.
    @Test("El widget de inicio produce la señal y la pinta")
    func homeWidgetProducesAndPaintsTheMark() throws {
        let cache = try Self.code("Yala/Services/WidgetDataCache.swift")
        // Acotado a `buildPeriodSummary`: sin el scope, la aserción se cumple con que el símbolo
        // aparezca en cualquier parte del fichero y sobrevive a quitarlo justo de aquí.
        let build = try #require(cache.range(of: "static func buildPeriodSummary("))
        let scope = String(cache[build.lowerBound...])
        let medidas = scope.components(separatedBy: "ApproximateMarkThreshold.marks(").count - 1
        #expect(medidas == 4, """
            Se esperaban 4 (ingreso, gasto, neto y saldo) y hay \(medidas). `buildPeriodSummary`
            tiene que MEDIR la proporción con el umbral compartido, no comparar a mano ni hacer un OR.
            """)
        #expect(scope.contains("approximate: balanceApproximateMagnitude, total: periodBalance"), """
            El saldo se mide contra el SALDO, no contra la facturación bruta que lo formó. Con
            `Σ|monto|` de denominador la marca no sale casi nunca, y falla justo en quien más
            historial tiene. Lo cazó la review adversarial del 2026-09-09.
            """)
        #expect(cache.contains("isExchangeRateProvisional: tx.isExchangeRateProvisional"), """
            El flag tiene que viajar en `WidgetTransaction`, o el camino de emergencia del widget
            recalcula los totales y los declara exactos sin saberlo.
            """)

        let service = try Self.source("YalaWidgets/Services/WidgetDataService.swift")
        for campo in ["incomeIsApproximate", "expenseIsApproximate", "netCashFlowIsApproximate",
                      "periodBalanceIsApproximate"] {
            #expect(service.contains("let \(campo): Bool?"), """
                `\(campo)` tiene que ser OPCIONAL en el lado que LEE. Este snapshot se decodifica
                como struct entera y sin versionado: una clave no opcional que falte en el payload
                de la versión anterior lanza `keyNotFound`, `loadSnapshot()` devuelve nil y TODOS
                los widgets de la pantalla de inicio se quedan en cero hasta que se abra la app.
                """)
        }

        for (path, campo) in [
            ("YalaWidgets/Widgets/CashFlowWidget.swift", "entry.netCashFlowIsApproximate"),
            ("YalaWidgets/Widgets/ExpenseWidget.swift", "entry.expenseIsApproximate"),
            ("YalaWidgets/Widgets/BalanceWidget.swift", "entry.balanceIsApproximate"),
            ("YalaWidgets/Widgets/CategoriesPieWidget.swift", "entry.expenseIsApproximate"),
            ("YalaWidgets/Widgets/SubcategoriesPieWidget.swift", "entry.expenseIsApproximate"),
        ] {
            let src = try Self.source(path)
            #expect(src.contains("isEstimate: \(campo)"), "\(path) no pinta la marca")
        }

        // Y el campo del LECTOR, que el bucle de arriba no cubre y ningún test de decodificación
        // alcanza: `YalaTests` no compila `YalaWidgets`.
        #expect(service.contains("let isExchangeRateProvisional: Bool?"), """
            `WidgetTransaction.isExchangeRateProvisional` tiene que ser OPCIONAL en el lado que LEE.
            Sin el `?`, un snapshot de la versión anterior con transacciones dentro lanza
            `keyNotFound` en la primera fila y apaga todos los widgets hasta que se abra la app.
            """)
    }

    /// **Los dos cuellos de botella que ningún callsite delata.** Los tests de arriba comprueban que
    /// cada pantalla PASA la señal; estos dos ficheros son el tramo siguiente, y borrar una sola
    /// línea en cualquiera de ellos apaga la marca aguas abajo con toda la suite en verde.
    /// Lo señaló la review adversarial del 2026-09-09.
    @Test("Los componentes intermedios reenvían la marca a quien la pinta")
    func passthroughComponentsForwardTheMark() throws {
        let kpi = try Self.source("YalaWidgets/Views/WidgetKPI.swift")
        #expect(kpi.contains("isEstimate: isEstimate"), """
            `WidgetKPI` es el ÚNICO camino de la marca hacia `BalanceWidget`, `ExpenseWidget` y el
            neto de Flujo de caja: si deja de reenviarla, tres widgets pierden el «≈» y sus callsites
            siguen pasándola tan campantes.
            """)

        let row = try Self.source("Yala/App/Views/Panel/Components/PanelSmallBarRow.swift")
        #expect(row.contains("isEstimate: isEstimate"), """
            Lo mismo para las dos barras del Flujo de caja compacto del Panel.
            """)
    }

    /// El asistente es la única superficie donde la marca NO es tipográfica, y eso tiene que estar
    /// fijado: el día que alguien "complete" el glifo aquí, convierte los importes en `String`.
    @Test("El asistente recibe la señal como booleano y el prompt sabe leerla")
    func assistantReceivesTheSignalAsBooleans() throws {
        let builder = try Self.source("Yala/Services/Chat/FullFinancialContextBuilder.swift")
        #expect(builder.contains("incomeIsApproximate: cashFlow.incomeAmountsAreApproximate"))
        #expect(builder.contains("expenseIsApproximate: cashFlow.expenseAmountsAreApproximate"))
        #expect(builder.contains("balanceIsApproximate: cashFlow.amountsAreApproximate"), """
            Se calculaba el `CashFlowSummary` entero y se leían 3 de sus 6 campos.
            """)

        let ctx = try Self.source("Yala/Services/Chat/FullFinancialContext.swift")
        #expect(ctx.contains("case incomeIsApproximate = \"income_is_approximate\""), """
            La clave del JSON tiene que ser la que el prompt nombra, o el modelo no la encuentra.
            """)

        let prompt = try Self.source("Yala/Services/ChatAssistantService.swift")
        #expect(prompt.contains("income_is_approximate"), """
            Sin la instrucción, los booleanos son un campo que nadie lee — exactamente lo que este
            repo ya se quitó una vez de `LiveAnchorInfo`.
            """)
    }

    /// Cuerpo de una función, acotado entre dos anclas de CÓDIGO (los comentarios ya vienen
    /// filtrados).
    ///
    /// El ancla de cierre hace falta por `WidgetDataCache`, que **sí** lee el flag crudo más abajo
    /// en la misma función y con razón (el saldo histórico no lleva ajuste). En los otros tres el
    /// fichero no tiene ninguna ocurrencia hoy, así que ahí el acotado no acota nada — pero es la
    /// misma forma para los cuatro y no cuesta nada mantenerla.
    ///
    /// Si un ancla deja de resolver, el ámbito se encoge y la aserción POSITIVA se pone roja: la
    /// dirección del fallo es la segura, un ámbito vacío nunca da falso verde.
    private static func scope(_ src: String, from: String, to: String) throws -> String {
        let inicio = try #require(src.range(of: from), "no está el ancla «\(from)»")
        let resto = String(src[inicio.upperBound...])
        let fin = try #require(resto.range(of: to), "no está el ancla «\(to)»")
        return String(resto[..<fin.lowerBound])
    }

    /// **Quién decide si un importe es aproximado cuando el importe son VARIAS filas.**
    /// Ticket `bridge-de-grupos-pierde-la-marca-de-sus-patas`.
    ///
    /// Los cuatro numeradores del umbral suman `adjustment.amountInPreferredCurrency(tx)`, que en un
    /// gasto de grupo bridgeado es la pata real MÁS las de préstamo. El flag de la fila describe
    /// solo una de ellas, y las de préstamo están suprimidas del recorrido: nadie las mira. Este
    /// scan es lo que impide que un consumidor NUEVO —o un revert de una línea— vuelva a leer el
    /// flag crudo al lado de un importe sintetizado.
    ///
    /// Los tests de comportamiento están en `GroupBridgeApproximateMarkTests`; esto solo cierra el
    /// hueco del quinto consumidor que todavía no existe.
    ///
    /// Va con `arguments:` y no con un bucle a propósito: `scope` LANZA, así que un ancla rota
    /// dentro de un `for` aborta la iteración y los ficheros siguientes se dejan de comprobar en
    /// silencio. Con `arguments:` cada fichero es un caso independiente.
    @Test("Los numeradores del umbral leen la magnitud del ajuste, no el flag de la fila",
          arguments: [
        // Desde el 2026-10-10 la regla vive en `CashFlowCalculator.resolvedAmount`, compartida por el
        // Panel y Registros (ticket `records-summary-mixes-preferred-currencies`): se fija el helper y
        // que los productores deleguen en él. El hero del Panel se sumó el mismo día
        // (`stats-aggregators-sum-stored-amounts-from-other-preferred-currencies`): resuelve con el
        // helper y su numerador sale de esa MISMA resolución.
        (fichero: "Yala/App/Logic/Calculators/HeroBucketsCalculator.swift",
         desde: "static func calculate(", hasta: "return Buckets(",
         accessor: "let resolved = CashFlowCalculator.resolvedAmount("),
        (fichero: "Yala/App/Logic/Calculators/HeroBucketsCalculator.swift",
         desde: "static func calculate(", hasta: "return Buckets(",
         accessor: "let approximate = resolved.approximateMagnitude"),
        (fichero: "Yala/App/Logic/Calculators/CashFlowCalculator.swift",
         desde: "static func resolvedAmount(", hasta: "static func calculateCashFlow(",
         accessor: "adjustment.approximateMagnitude(tx, magnitude: abs(value))"),
        (fichero: "Yala/App/Logic/Calculators/CashFlowCalculator.swift",
         desde: "static func calculateCashFlow(", hasta: "var chartData: [CashFlowData] = []",
         accessor: "let resolved = resolvedAmount("),
        (fichero: "Yala/App/ViewModels/RecordsViewModel.swift",
         desde: "private func calculateSummary(", hasta: "let newSummary = RecordsSummary(",
         accessor: "let resolved = CashFlowCalculator.resolvedAmount("),
        (fichero: "Yala/Services/WidgetDataCache.swift",
         desde: "static func buildPeriodSummary(", hasta: "var balanceApproximateMagnitude",
         accessor: "adjustment.approximateMagnitude(tx, magnitude: abs(amount))"),
    ])
    func thresholdNumeratorsReadTheAdjustmentMagnitude(
        ambito: (fichero: String, desde: String, hasta: String, accessor: String)
    ) throws {
        let cuerpo = try Self.scope(
            try Self.code(ambito.fichero), from: ambito.desde, to: ambito.hasta
        )
        #expect(cuerpo.contains(ambito.accessor), """
            \(ambito.fichero) tiene que pedirle la magnitud dudosa al ajuste
            (`\(ambito.accessor)`), y pasarle la MISMA magnitud que suma al denominador.
            """)
        #expect(!cuerpo.contains("isExchangeRateProvisional"), """
            \(ambito.fichero) lee el flag de la FILA dentro del bucle que suma el importe AJUSTADO.
            En un gasto de grupo ese importe es el NETO de varias patas y el flag describe una sola:
            un gasto del que el 90 % salió de una tasa dudosa se cuenta 100 % exacto, y como el
            umbral es un cociente, además desplaza la marca del bucket entero.
            """)
    }

    /// La contrapartida del scan de arriba: los DOS sitios donde leer el flag de la fila es lo
    /// correcto, porque el importe que los acompaña **no** lleva ajuste de bridge. Sin esto, el
    /// arreglo de este ticket invita a cablear el accessor también aquí, y ahí sí cambiaría el
    /// número que se muestra.
    @Test("El saldo histórico y la fila del widget siguen leyendo el flag de la fila")
    func unadjustedSurfacesKeepTheRowFlag() throws {
        let cache = try Self.code("Yala/Services/WidgetDataCache.swift")

        let saldo = try Self.scope(
            cache, from: "if let allTx = allTransactionsForBalance {",
            to: "let topCategories = buildTopCategories("
        )
        #expect(saldo.contains("tx.isExchangeRateProvisional"), """
            El saldo histórico suma `preferredAmount(tx)` SIN ajuste —los saldos reflejan montos
            reales, no «mi parte»—, así que su marca es la de la fila. Cablear aquí el accessor del
            ajuste emparejaría una magnitud neteada con un importe sin netear.
            """)

        // La fila de `WidgetTransaction` también lleva su flag crudo, y eso ya lo fija
        // `homeWidgetProducesAndPaintsTheMark` unos tests más arriba: no se repite aquí.
    }
}

@Suite("El umbral replicado en el widget no puede divergir del de la app")
struct WidgetApproximateThresholdParityTests {

    /// `ApproximateMarkThreshold` no está en la membership del target `YalaWidgetsExtension`, así
    /// que su camino de emergencia replica el umbral. Una réplica sin test de paridad es una copia
    /// que se queda atrás en silencio.
    private func replica(approximate: Double, total: Double) -> Bool {
        let noiseFloor = 0.01
        let fraction = 0.05
        let approximateMagnitude = abs(approximate)
        guard approximateMagnitude > noiseFloor else { return false }
        let totalMagnitude = abs(total)
        guard totalMagnitude > noiseFloor else { return true }
        return approximateMagnitude >= fraction * totalMagnitude * (1 - 1e-9)
    }

    /// **Por qué este test lee el CUERPO ENTERO y no dos literales.** La primera versión grepeaba
    /// `let fraction = 0.05` y poco más, y la review adversarial del 2026-09-09 lo tumbó: invertir
    /// los dos guards, cambiar `>=` por `>` o quitar la tolerancia relativa dejaba la suite en
    /// verde. Y no hay alternativa por comportamiento: `YalaTests` compila `YalaTests` + el target
    /// `Yala`, **nunca `YalaWidgets`** (`project.pbxproj`), así que `marksApproximate` es
    /// inalcanzable desde aquí — igual que `WidgetDataService.loadSnapshot`, que ya se vigila así en
    /// `WidgetSessionSealTests`. Fijar el cuerpo normalizado es la red más fuerte disponible.
    @Test("La réplica del widget es el mismo algoritmo, línea a línea")
    func replicaMatchesTheSourceOfTruth() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let service = try String(
            contentsOf: root.appendingPathComponent("YalaWidgets/Services/WidgetDataService.swift"),
            encoding: .utf8
        )
        let fn = try #require(service.range(of: "private static func marksApproximate"))
        let cuerpo = String(service[fn.lowerBound...].prefix(700))

        // Cada paso del algoritmo, en orden y con su forma exacta. Normalizado a una sola línea sin
        // espacios de más para que reindentar no lo rompa.
        let plano = cuerpo
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: " ")

        for paso in [
            "let noiseFloor = 0.01",
            "let fraction = 0.05",
            "let approximateMagnitude = abs(approximate)",
            "guard approximateMagnitude > noiseFloor else { return false }",
            "let totalMagnitude = abs(total)",
            "guard totalMagnitude > noiseFloor else { return true }",
            "return approximateMagnitude >= fraction * totalMagnitude * (1 - 1e-9)",
        ] {
            #expect(plano.contains(paso), """
                La réplica del widget perdió «\(paso)». No es cosmético: cada uno de estos pasos
                cambia el resultado en algún borde, y aquí no hay test de comportamiento posible.
                """)
        }

        // Y el ORDEN de los dos guards, que decide el caso «denominador inservible».
        let iNum = try #require(plano.range(of: "guard approximateMagnitude > noiseFloor"))
        let iDen = try #require(plano.range(of: "guard totalMagnitude > noiseFloor"))
        #expect(iNum.lowerBound < iDen.lowerBound, """
            El guard del NUMERADOR va primero. Invertidos, un total de cero con cero aproximado
            marcaría — justo el caso que blinda al usuario monomoneda.
            """)

        #expect(ApproximateMarkThreshold.fraction == 0.05, """
            El original cambió de umbral y la réplica del widget se quedó en 0.05: el mismo saldo
            saldría marcado en la app y exacto en la pantalla de inicio.
            """)
    }

    @Test("Réplica y original responden lo mismo en los bordes que importan")
    func replicaAgreesWithTheOriginal() {
        let casos: [(Double, Double)] = [
            (0, 1000),          // nada aproximado
            (0.005, 1000),      // por debajo del suelo de ruido
            (49, 1000),         // 4,9 % — no llega
            (50, 1000),         // 5 % exacto — el borde inclusivo
            (0.15, 3.0),        // el 5 % que en binario se queda corto por un ulp
            (500, 1000),        // 50 %
            (100, 0.001),       // denominador inservible
            (0.005, 0.05),      // 10 % del total, pero el numerador no llega al suelo de ruido
            (0.02, 0.005),      // numerador sobre el suelo, denominador por debajo
            (0, 0),             // todo en cero
            (-60, 1000),        // magnitudes: el signo no debe importar
            (60, -1000),
        ]
        for (approximate, total) in casos {
            #expect(
                replica(approximate: approximate, total: total)
                    == ApproximateMarkThreshold.marks(approximate: approximate, total: total),
                "divergen en (aproximado: \(approximate), total: \(total))"
            )
        }
    }
}
