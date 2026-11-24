//
//  EstadisticasFluidezCableadoTests.swift
//  YalaTests
//
//  El cableado de la memoria de Estadísticas (encargo de fluidez del 24-nov-2026), leído del código. La memoria solo es
//  segura si su firma cubre todo lo que recalcula la página montada: un observador nuevo sin su campo en la firma
//  dejaría que volver a la pestaña enseñe cifras viejas, y ningún test de lógica lo vería. Y solo ahorra algo si la
//  página la consulta al aparecer: un cambio que vuelva a calcular a secas en el `onAppear` devolvería la lentitud sin
//  ningún rojo.
//

import Foundation
import Testing

@Suite
struct EstadisticasFluidezCableadoTests {

    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El código sin comentarios, con los espacios colapsados.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n")
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { return "" }
                // Comentario al final de la línea (ninguna de las líneas que se leen aquí lleva «//» en un literal).
                if let range = trimmed.range(of: " //") { return String(trimmed[..<range.lowerBound]) }
                return trimmed
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// El cuerpo entre llaves que empieza en la primera `{` tras `marker`.
    private static func block(after marker: String, in code: String) throws -> String {
        let start = try #require(code.range(of: marker), "No está «\(marker)».")
        var depth = 0
        var opened = false
        var index = start.upperBound
        var body = ""
        while index < code.endIndex {
            let char = code[index]
            if char == "{" {
                depth += 1
                opened = true
            } else if char == "}" {
                depth -= 1
                if opened && depth == 0 { break }
            }
            if opened { body.append(char) }
            index = code.index(after: index)
        }
        return body
    }

    /// Cada `.onChange(of: X) { … }` del código: la expresión observada y lo que hace.
    private static func observers(in code: String) throws -> [(observed: String, action: String)] {
        let pattern = #"\.onChange\(of: ([A-Za-z0-9_.]+)\)\s*\{([^{}]*)\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        let ns = code as NSString
        return regex.matches(in: code, range: NSRange(location: 0, length: ns.length)).map {
            (ns.substring(with: $0.range(at: 1)), ns.substring(with: $0.range(at: 2)))
        }
    }

    /// Los campos `let nombre:` de un `struct`.
    private static func fields(ofStruct name: String, in code: String) throws -> [String] {
        let body = try block(after: "struct \(name)", in: code)
        let regex = try NSRegularExpression(pattern: #"let ([A-Za-z0-9_]+):"#)
        let ns = body as NSString
        return regex.matches(in: body, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range(at: 1))
        }
    }

    // MARK: - Tendencias

    @Test func tendencias_cadaObservadorQueRecalcula_estaEnLaFirma() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Statistics/TrendsTabView.swift"))
        let key = try Self.block(after: "private var cardsKey: TrendsCardsKey", in: code)
        let recalculan = try Self.observers(in: code).filter { $0.action.contains("scheduleTrendsRecalc") }
        #expect(recalculan.count >= 15, "El patrón ya no encuentra los observadores: revisa el test.")
        for observer in recalculan {
            #expect(key.contains(observer.observed),
                    "`\(observer.observed)` recalcula las tarjetas y no está en `cardsKey`: volver a Tendencias enseñaría cifras viejas.")
        }
        // Lo que el cálculo lee sin observarlo, y que tiene que invalidar igual.
        for extra in ["trendsViewModel.panelDateInterval", "defaultCurrencyCode", "cashFlowAccountGrouping",
                      "appPreferences.includeGroupTransactionsInStats", "firstWeekday"] {
            #expect(key.contains(extra), "`\(extra)` falta en `cardsKey`.")
        }
    }

    @Test func tendencias_alAparecer_consultaLaMemoriaAntesDeCalcular() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Statistics/TrendsTabView.swift"))
        let onAppear = try Self.block(after: ".scrollViewGlassEdges() .onAppear", in: code)
        let guarda = try #require(onAppear.range(of: "guard !restoreCardsFromMemory() else { return }"))
        let calculo = try #require(onAppear.range(of: "scheduleTrendsRecalc(debounceMs: 30)"))
        #expect(guarda.lowerBound < calculo.lowerBound)

        let recalc = try Self.block(after: "private func scheduleTrendsRecalc(", in: code)
        let firma = try #require(recalc.range(of: "let key = cardsKey"))
        let primerCalculo = try #require(recalc.range(of: "calculateCashFlowData()"))
        #expect(firma.lowerBound < primerCalculo.lowerBound, "La firma se toma antes de calcular.")
        #expect(recalc.contains("trendsViewModel.trendsCardsMemory.remember(cardsSnapshot, for: key)"))
    }

    @Test func tendencias_loGuardado_seRestauraEntero() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Statistics/TrendsTabView.swift"))
        let campos = try Self.fields(ofStruct: "TrendsCardsSnapshot", in: code)
        #expect(campos.count >= 14)
        let guarda = try Self.block(after: "private var cardsSnapshot: TrendsCardsSnapshot", in: code)
        let restaura = try Self.block(after: "private func restoreCardsFromMemory()", in: code)
        for campo in campos {
            #expect(guarda.contains("\(campo): \(campo)"), "`\(campo)` no se guarda.")
            #expect(restaura.contains("\(campo) = saved.\(campo)"), "`\(campo)` no se restaura al volver.")
        }
    }

    // MARK: - Distribución

    @Test func distribucion_cadaObservadorQueRecalcula_estaEnSuFirma() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Statistics/CategoriesTabView.swift"))
        let key = try Self.block(after: "private var distributionKey: DistributionKey", in: code)
        let sankey = try Self.block(after: "private var sankeyKey: DistributionSankeyKey", in: code)
        let todos = try Self.observers(in: code)

        let calculan = todos.filter {
            $0.action.contains("calculateData()") || $0.action.contains("recalculateAfterDataReload()")
                || $0.action.contains("onRecalc()")
        }
        #expect(calculan.count >= 15, "El patrón ya no encuentra los observadores: revisa el test.")
        for observer in calculan {
            #expect(key.contains(observer.observed),
                    "`\(observer.observed)` recalcula Distribución y no está en `distributionKey`.")
        }

        let sankeyRecalcula = todos.filter {
            $0.action.contains("recomputeSankey()") || $0.action.contains("recalculateAfterDataReload()")
        }
        #expect(sankeyRecalcula.count >= 3)
        for observer in sankeyRecalcula {
            #expect(sankey.contains(observer.observed),
                    "`\(observer.observed)` recalcula el Sankey y no está en `sankeyKey`.")
        }
        for extra in ["viewModel.panelDateInterval", "defaultCurrencyCode",
                      "appPreferences.includeGroupTransactionsInStats", "firstWeekday"] {
            #expect(key.contains(extra), "`\(extra)` falta en `distributionKey`.")
        }
    }

    @Test func distribucion_alAparecer_consultaLaMemoria_yElSankeySuFirma() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Statistics/CategoriesTabView.swift"))
        let first = try Self.block(after: "private func scheduleFirstCalculation()", in: code)
        #expect(first.contains("let restored = restoreDistributionFromMemory()"))
        #expect(first.contains("let sankeyIsCurrent = viewModel.sankeyComputedFor == sankeyKey"))
        #expect(first.contains("if !restored { calculateData() }"))
        #expect(first.contains("if !sankeyIsCurrent { recomputeSankey() }"))

        let sankey = try Self.block(after: "private func recomputeSankey()", in: code)
        let firma = try #require(sankey.range(of: "let key = sankeyKey"))
        let calculo = try #require(sankey.range(of: "viewModel.calculateSankeyData("))
        #expect(firma.lowerBound < calculo.lowerBound)
        #expect(sankey.contains("viewModel.sankeyComputedFor = key"))

        let calc = try Self.block(after: "private func calculateData()", in: code)
        let firmaCalc = try #require(calc.range(of: "let memoryKey = distributionKey"))
        let intervalo = try #require(calc.range(of: "let interval = viewModel.panelDateInterval"))
        #expect(firmaCalc.lowerBound < intervalo.lowerBound, "La firma se toma antes de calcular.")
        #expect(calc.contains("viewModel.distributionMemory.remember(distributionSnapshot, for: memoryKey)"))
    }

    @Test func distribucion_loGuardado_seRestauraEntero() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Statistics/CategoriesTabView.swift"))
        let campos = try Self.fields(ofStruct: "DistributionSnapshot", in: code)
        #expect(campos.count >= 14)
        let guarda = try Self.block(after: "private var distributionSnapshot: DistributionSnapshot", in: code)
        let restaura = try Self.block(after: "private func restoreDistributionFromMemory()", in: code)
        for campo in campos where campo != "detailSource" {
            #expect(guarda.contains("\(campo): \(campo)"), "`\(campo)` no se guarda.")
            #expect(restaura.contains("\(campo) = saved.\(campo)"), "`\(campo)` no se restaura al volver.")
        }
        // La fuente del detalle se guarda COPIADA y se vuelca en la de la página: compartir la instancia haría que el
        // cálculo siguiente reescribiera lo guardado.
        #expect(guarda.contains("detailSource: detailSource.copy()"))
        #expect(restaura.contains("detailSource.take(saved.detailSource)"))
        #expect(restaura.contains("enforceListViewLock()"))
    }

    // MARK: - «Tu dinero hoy»

    @Test func elHero_pideLaCifraALaMemoriaDelContenedor() throws {
        let hero = Self.codeOnly(try Self.repoFile("Yala/App/Views/Statistics/StatsHeroView.swift"))
        let recalc = try Self.block(after: "private func recalculateMoney(", in: hero)
        #expect(recalc.contains("memory.figure(for: inputs"))
        #expect(hero.contains("@Environment(\\.statsMoneyTodayMemory) private var moneyMemory"))

        let container = Self.codeOnly(try Self.repoFile("Yala/App/Views/Statistics/DetailContainerView.swift"))
        #expect(container.contains(".environment(\\.statsMoneyTodayMemory, moneyTodayMemory)"))
    }

    /// Lo recordado vive en el ViewModel del contenedor, sin observar: guardarlo no repinta la pestaña.
    @Test func laMemoria_viveEnElViewModelDelContenedor_sinObservar() throws {
        let vm = Self.codeOnly(try Self.repoFile("Yala/App/ViewModels/StatisticsViewModel.swift"))
        #expect(vm.contains("@ObservationIgnored var trendsCardsMemory"))
        #expect(vm.contains("@ObservationIgnored var distributionMemory"))
        #expect(vm.contains("@ObservationIgnored var sankeyComputedFor"))
    }
}
