//
//  UXAudit22Decidido02BLogicTests.swift
//  YalaTests
//
//  Lógica pura del lote decidido 2.2 · 02, sesión B (decisiones de Jürgen del 14 y el 21-oct): el buscador de categoría
//  (L2-3), la pista de los atajos (L2-8), «Mi parte» (L2-12 y L2-17), la pregunta del monto (L2-16), el relleno AA de lo
//  elegido (L2-19) y los colores de las acciones (L2-20), la tasa escrita a mano (L2-11), su rótulo (L2-11 y L2-18) y el
//  orden estable de las etiquetas (card z3by). Sin SwiftData.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Lote decidido 2.2 · 02 · sesión B · lógica")
struct UXAudit22Decidido02BLogicTests {

    // MARK: - L2-3 · Buscar una categoría

    private let groups: [(category: String, subcategories: [String])] = [
        (category: "Alimentación", subcategories: ["Restaurantes", "Delivery", "Supermercados y bodegas"]),
        (category: "Transporte", subcategories: ["Taxis y apps", "Transporte público", "Combustible"]),
    ]

    private func search(_ query: String) -> [(category: String, subcategories: [String])] {
        CategorySearchLogic.filter(
            groups, query: query, groupName: { $0 }, itemName: { $0 }, locale: Locale(identifier: "es")
        )
    }

    @Test func buscar_porElNombre_traeSoloEsa() {
        let result = search("tax")
        #expect(result.count == 1)
        #expect(result.first?.category == "Transporte")
        #expect(result.first?.subcategories == ["Taxis y apps"])
    }

    @Test func buscar_porElGrupo_sinTildes_traeTodoElGrupo() {
        let result = search("alimentacion")
        #expect(result.count == 1)
        #expect(result.first?.subcategories == ["Restaurantes", "Delivery", "Supermercados y bodegas"])
    }

    @Test func buscar_sinDistinguirMayusculasNiEspacios() {
        #expect(search("  TAXIS ").first?.subcategories == ["Taxis y apps"])
        #expect(CategorySearchLogic.matches(query: "público", name: "Transporte publico", groupName: ""))
    }

    @Test func buscar_vacio_loTraeTodo_yUnaPalabraSinSinonimo_nada() {
        #expect(search("").count == 2)
        #expect(search("   ").count == 2)
        // Sin sinónimos (decisión de Jürgen): «comida» no encuentra Alimentación.
        #expect(search("comida").isEmpty)
    }

    // MARK: - L2-8 · La pista de los atajos

    @Test func pista_rotaEntreLosTresAtajos_yDesapareceTrasSeis() {
        let shown = (0..<8).map { DescriptionShortcutHintLogic.shortcut(openingsSoFar: $0, usedShortcut: false) }
        #expect(shown == [.category, .tag, .account, .category, .tag, .account, nil, nil])
    }

    @Test func pista_noSaleSiYaUsoUnAtajo() {
        #expect(DescriptionShortcutHintLogic.shortcut(openingsSoFar: 0, usedShortcut: true) == nil)
    }

    @Test func pista_cuentaLasAperturas_ySeApagaAlUsarUnAtajo() throws {
        let defaults = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        #expect(DescriptionShortcutHintLogic.registerOpening(defaults: defaults) == .category)
        #expect(DescriptionShortcutHintLogic.registerOpening(defaults: defaults) == .tag)
        #expect(defaults.integer(forKey: DescriptionShortcutHintLogic.openingsKey) == 2)
        DescriptionShortcutHintLogic.markShortcutUsed(defaults: defaults)
        #expect(DescriptionShortcutHintLogic.registerOpening(defaults: defaults) == nil)
        #expect(defaults.integer(forKey: DescriptionShortcutHintLogic.openingsKey) == 2, "Sin pista no se cuenta.")
    }

    @Test func pista_cadaAtajoTieneSuTexto() {
        let texts = DescriptionShortcutHintLogic.Shortcut.allCases.map(\.hint)
        #expect(Set(texts).count == 3)
        #expect(!texts.contains { $0.hasPrefix("l2d.") }, "Ninguna clave cruda.")
    }

    // MARK: - L2-12 · El modo con el que abre «Mi parte» y el chip

    @Test func miParte_abreEnIguales_laPrimeraVez_yDespuesEnElUltimoUsado() {
        #expect(SplitSummaryLogic.initialType(lastUsedRaw: nil) == .equal)
        #expect(SplitSummaryLogic.initialType(lastUsedRaw: "percentage") == .percentage)
        #expect(SplitSummaryLogic.initialType(lastUsedRaw: "shares") == .shares)
        #expect(SplitSummaryLogic.initialType(lastUsedRaw: "basura") == .equal)
        #expect(SplitCalculatorFieldState().splitType == .equal)
    }

    private func money(_ value: Double) -> String { "S/ " + String(format: "%.2f", value) }

    @Test func chip_llevaElTotal_yElModo() {
        let equal = SplitSummaryLogic.chipText(type: .equal, total: 120, myValue: 3, divisor: 3, format: money)
        #expect(equal == L10n.UXL2B.splitChipEqual(total: "S/ 120.00", people: 3))
        #expect(equal.contains("S/ 120.00") && equal.contains("3"))

        let percentage = SplitSummaryLogic.chipText(type: .percentage, total: 120, myValue: 60, divisor: 100, format: money)
        #expect(percentage == L10n.UXL2B.splitChipPercentage(total: "S/ 120.00", percent: SplitSummaryLogic.percentText(60)))

        let shares = SplitSummaryLogic.chipText(type: .shares, total: 120, myValue: 2, divisor: 5, format: money)
        #expect(shares == L10n.UXL2B.splitChipShares(total: "S/ 120.00", mine: 2, of: 5))
        #expect(shares != L10n.UXL2B.splitChipShares(total: "S/ 120.00", mine: 5, of: 2))

        let exact = SplitSummaryLogic.chipText(type: .exact, total: 120, myValue: 40, divisor: nil, format: money)
        #expect(exact == L10n.UXL2B.splitChipExact(total: "S/ 120.00"))

        #expect(Set([equal, percentage, shares, exact]).count == 4)
    }

    @Test func chipDelFormulario_saleDelViewModel() {
        let vm = NewTransactionViewModel()
        #expect(vm.splitChipText(format: money) == nil)
        vm.applySplitResult(amount: 40, splitType: .equal, totalAmount: 120, myValue: 3, divisor: 3)
        #expect(vm.splitChipText(format: money) == L10n.UXL2B.splitChipEqual(total: "S/ 120.00", people: 3))
    }

    // MARK: - L2-17 · La fórmula y la barra

    @Test func formula_porModo() {
        #expect(SplitSummaryLogic.formula(type: .equal, total: 120, mine: 40, myValue: 3, divisor: 3, format: money)
            == L10n.UXL2B.splitFormulaEqual(total: "S/ 120.00", people: 3, each: "S/ 40.00"))
        #expect(SplitSummaryLogic.formula(type: .percentage, total: 120, mine: 72, myValue: 60, divisor: 100, format: money)
            == L10n.UXL2B.splitFormulaPercentage(percent: SplitSummaryLogic.percentText(60), total: "S/ 120.00"))
        #expect(SplitSummaryLogic.formula(type: .shares, total: 120, mine: 48, myValue: 2, divisor: 5, format: money)
            == L10n.UXL2B.splitFormulaShares(mine: 2, of: 5, total: "S/ 120.00"))
        #expect(SplitSummaryLogic.formula(type: .exact, total: 120, mine: 40, myValue: 40, divisor: nil, format: money)
            == L10n.UXL2B.splitFormulaExact(mine: "S/ 40.00", total: "S/ 120.00"))
    }

    @Test func barra_tuParte_yLosDemas() {
        #expect(SplitSummaryLogic.othersAmount(total: 120, mine: 40) == 80)
        #expect(SplitSummaryLogic.othersAmount(total: 120, mine: 130) == 0)
        #expect(abs(SplitSummaryLogic.myFraction(total: 120, mine: 40) - 1.0 / 3.0) < 0.0001)
        #expect(SplitSummaryLogic.myFraction(total: 0, mine: 40) == 0)
    }

    @Test func porcentaje_sinDecimalesDeRelleno() {
        let en = Locale(identifier: "en_US")
        #expect(SplitSummaryLogic.percentText(60, locale: en) == "60")
        #expect(SplitSummaryLogic.percentText(62.5, locale: en) == "62.5")
    }

    // MARK: - L2-16 · La pregunta del monto

    @Test func pregunta_segunElTipo() {
        let questions = TransactionType.allCases.map(AmountQuestionLogic.question(for:))
        #expect(Set(questions).count == TransactionType.allCases.count)
        #expect(!questions.contains { $0.hasPrefix("l2d.") })
        #expect(NewTransactionViewModel().amountString.isEmpty, "Vacío: el «0.00» es de ejemplo, no un monto escrito.")
    }

    // MARK: - L2-19 y L2-20 · Rellenos con texto blanco AA

    @Test func relleno_unColorClaro_seOscureceHastaAA() throws {
        for hex in ["#FFD60A", "#64D2FF", "#30D158", "#F59E0B", "#FB7185", "#00C2CB", "#FF9F0A"] {
            let rgb = try #require(SelectedFillContrast.rgb(fromHex: hex))
            #expect(SelectedFillContrast.whiteContrast(on: rgb) < 4.5, "\(hex) no llegaba solo")
            let fill = SelectedFillContrast.fill(for: rgb)
            #expect(SelectedFillContrast.whiteContrast(on: fill) >= 4.5, "\(hex) tiene que llegar a AA")
        }
    }

    @Test func relleno_unColorQueYaLlega_seQuedaTalCual() throws {
        let indigo = try #require(SelectedFillContrast.rgb(fromHex: "3D36B3"))
        #expect(SelectedFillContrast.fill(for: indigo) == indigo)
    }

    @Test func accionesDelFormulario_blancoEncimaAA() throws {
        for hex in [DS.FormAction.splitHex, DS.FormAction.favoriteHex, DS.FormAction.recurringHex] {
            let rgb = try #require(SelectedFillContrast.rgb(fromHex: hex))
            #expect(SelectedFillContrast.whiteContrast(on: rgb) >= 4.5, "\(hex)")
        }
        #expect(Set([DS.FormAction.splitHex, DS.FormAction.favoriteHex, DS.FormAction.recurringHex]).count == 3,
                "Un color por acción.")
    }

    @Test func hex_cortoYLargo() {
        #expect(SelectedFillContrast.rgb(fromHex: "#FFF") == SelectedFillContrast.RGB(red: 1, green: 1, blue: 1))
        #expect(SelectedFillContrast.rgb(fromHex: "000000") == SelectedFillContrast.RGB(red: 0, green: 0, blue: 0))
        #expect(SelectedFillContrast.rgb(fromHex: "zz") == nil)
    }

    // MARK: - L2-11 · La tasa escrita a mano

    @Test func tasaManual_soloEnUnGastoEnOtraDivisa() {
        #expect(ForeignManualRateLogic.manualRate(
            isManual: true, isTransfer: false, rate: 3.6, amountCurrency: "USD", preferredCurrency: "PEN") == 3.6)
        #expect(ForeignManualRateLogic.manualRate(
            isManual: false, isTransfer: false, rate: 3.6, amountCurrency: "USD", preferredCurrency: "PEN") == nil)
        #expect(ForeignManualRateLogic.manualRate(
            isManual: true, isTransfer: true, rate: 3.6, amountCurrency: "USD", preferredCurrency: "PEN") == nil)
        #expect(ForeignManualRateLogic.manualRate(
            isManual: true, isTransfer: false, rate: 3.6, amountCurrency: "PEN", preferredCurrency: "pen") == nil)
        #expect(ForeignManualRateLogic.manualRate(
            isManual: true, isTransfer: false, rate: 0, amountCurrency: "USD", preferredCurrency: "PEN") == nil)
    }

    @Test func tasaManual_convierteSinErrorDeDouble() {
        #expect(ForeignManualRateLogic.converted(-12.5, rate: 3.55) == Decimal(string: "-44.375"))
    }

    // MARK: - L2-11 y L2-18 · El rótulo de la tasa

    @Test func rotulo_hoy_oLaFechaDelRegistro() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 12)))
        let earlier = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 19, hour: 9)))
        #expect(ExchangeRateCaptionLogic.caption(for: now, now: now, calendar: calendar) == L10n.UXL2B.rateToday)
        let other = ExchangeRateCaptionLogic.caption(
            for: earlier, now: now, calendar: calendar, locale: Locale(identifier: "es"))
        #expect(other != L10n.UXL2B.rateToday)
        #expect(other.contains("19"))
    }

    // MARK: - Orden estable de las etiquetas (card z3by)

    @Test func etiquetas_ordenPropioPrimero_yLuegoAlfabetico() {
        let viaje = Tag(name: "Viaje")
        let casa = Tag(name: "casa")
        let auto = Tag(name: "Auto")
        let zeta = Tag(name: "Zeta")
        let catalog = Tag.byIDLookup([viaje, casa, auto, zeta])
        let ids: Set<UUID> = [viaje.id, casa.id, auto.id, zeta.id]

        let alphabetical = TagDisplayResolver.resolve(ids: ids, catalog: catalog).map(\.name)
        #expect(alphabetical == ["Auto", "casa", "Viaje", "Zeta"])

        let custom = TagDisplayResolver.resolve(ids: ids, catalog: catalog, order: ["Zeta", "Viaje"]).map(\.name)
        #expect(custom == ["Zeta", "Viaje", "Auto", "casa"])
    }

    @Test func etiquetas_conLimite_siempreLasMismas() {
        let tags = (1...6).map { Tag(name: "Etiqueta \($0)") }
        let catalog = Tag.byIDLookup(tags)
        let ids = Set(tags.map(\.id))
        let first = TagDisplayResolver.resolve(ids: ids, catalog: catalog, limit: 3).map(\.name)
        for _ in 0..<20 {
            // Un `Set` nuevo cada vez: el orden de recorrido cambia, el resultado no.
            let shuffled = Set(tags.shuffled().map(\.id))
            #expect(TagDisplayResolver.resolve(ids: shuffled, catalog: catalog, limit: 3).map(\.name) == first)
        }
        #expect(first == ["Etiqueta 1", "Etiqueta 2", "Etiqueta 3"])
    }
}
