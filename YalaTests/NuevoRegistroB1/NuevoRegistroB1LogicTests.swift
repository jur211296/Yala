//
//  NuevoRegistroB1LogicTests.swift
//  YalaTests
//
//  Hoja B1 de Nuevo registro y éxito minimalista (Jürgen, 2026-11-20). Lo que decide la hoja sin pintar nada
//  (`NuevoRegistroB1Logic.swift`): el autocompletado de una sugerencia (ajuste 4, un caso por regla), la fila de abajo
//  siempre en una línea (ajuste 1), la cápsula de moneda, el estimado junto al monto, los títulos, el «#2» y el orden de
//  la pantalla de éxito (ajuste 3).
//

import CoreGraphics
import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Nuevo registro B1 · lógica")
struct NuevoRegistroB1LogicTests {

    // MARK: - Autocompletar al elegir una sugerencia (ajuste 4)

    private typealias Sample = DescriptionAutofillSample<String>
    private typealias Consensus = DescriptionAutofillConsensus<String>

    private let gym = UUID()
    private let work = UUID()

    private func current(
        account: String? = "bcp", baseline: String? = "bcp", subcategory: String? = nil, tags: Set<UUID> = [],
        last: Consensus = .none
    ) -> DescriptionAutofillCurrent<String> {
        DescriptionAutofillCurrent(
            account: account, baselineAccount: baseline, subcategory: subcategory, tags: tags, lastAutofill: last)
    }

    @Test func todosConLaMismaCuentaSubcategoriaYEtiqueta_seAsignanLosTres() {
        let samples = [
            Sample(account: "interbank", subcategory: "gimnasio", tags: [gym]),
            Sample(account: "interbank", subcategory: "gimnasio", tags: [gym]),
        ]
        let consensus = DescriptionAutofillLogic.consensus(samples)
        #expect(consensus == Consensus(account: "interbank", subcategory: "gimnasio", tags: [gym]))
        #expect(DescriptionAutofillLogic.plan(consensus, current: current()) == consensus)
    }

    @Test func cuentasDistintas_laCuentaNoSeToca_peroLaSubcategoriaSi() {
        let samples = [
            Sample(account: "interbank", subcategory: "gimnasio", tags: []),
            Sample(account: "bcp", subcategory: "gimnasio", tags: []),
        ]
        let consensus = DescriptionAutofillLogic.consensus(samples)
        #expect(consensus.account == nil)
        #expect(consensus.subcategory == "gimnasio")
    }

    @Test func subcategoriasDistintas_laSubcategoriaNoSeToca_peroLaCuentaSi() {
        let samples = [
            Sample(account: "interbank", subcategory: "gimnasio", tags: []),
            Sample(account: "interbank", subcategory: "deporte", tags: []),
        ]
        let consensus = DescriptionAutofillLogic.consensus(samples)
        #expect(consensus.account == "interbank")
        #expect(consensus.subcategory == nil)
    }

    @Test func etiquetasDistintas_lasEtiquetasNoSeTocan() {
        let samples = [
            Sample(account: "interbank", subcategory: "gimnasio", tags: [gym]),
            Sample(account: "interbank", subcategory: "gimnasio", tags: [gym, work]),
        ]
        #expect(DescriptionAutofillLogic.consensus(samples).tags == nil)
    }

    @Test func sinEtiquetasEnNinguno_noHayEtiquetasQuePoner() {
        let samples = [Sample(account: "interbank", subcategory: "gimnasio", tags: [])]
        #expect(DescriptionAutofillLogic.consensus(samples).tags == nil)
    }

    @Test func unRegistroSinCuenta_rompeElAcuerdoDeLaCuenta() {
        let samples = [
            Sample(account: "interbank", subcategory: "gimnasio", tags: []),
            Sample(account: nil, subcategory: "gimnasio", tags: []),
        ]
        #expect(DescriptionAutofillLogic.consensus(samples).account == nil)
    }

    @Test func sinRegistrosAnteriores_noSeTocaNada() {
        #expect(DescriptionAutofillLogic.consensus([Sample]()) == .none)
    }

    @Test func laCuentaElegidaAMano_noSePisa() {
        let consensus = Consensus(account: "interbank", subcategory: "gimnasio", tags: [gym])
        // Abrió con «bcp» (la precargada) y la persona eligió «scotia».
        let plan = DescriptionAutofillLogic.plan(consensus, current: current(account: "scotia", baseline: "bcp"))
        #expect(plan.account == nil)
        #expect(plan.subcategory == "gimnasio")
        #expect(plan.tags == [gym])
    }

    @Test func laCuentaPrecargada_siSeCambia() {
        let consensus = Consensus(account: "interbank", subcategory: nil, tags: nil)
        #expect(DescriptionAutofillLogic.plan(consensus, current: current(account: "bcp", baseline: "bcp")).account
            == "interbank")
    }

    @Test func laSubcategoriaYaPuesta_noSePisa() {
        let consensus = Consensus(account: "interbank", subcategory: "gimnasio", tags: nil)
        let plan = DescriptionAutofillLogic.plan(consensus, current: current(subcategory: "restaurantes"))
        #expect(plan.subcategory == nil)
        #expect(plan.account == "interbank")
    }

    @Test func lasEtiquetasYaPuestas_noSePisan() {
        let consensus = Consensus(account: nil, subcategory: nil, tags: [gym])
        #expect(DescriptionAutofillLogic.plan(consensus, current: current(tags: [work])).tags == nil)
    }

    @Test func loQuePusoElAutocompletadoAnterior_otraSugerenciaPuedeCambiarlo() {
        let consensus = Consensus(account: "bbva", subcategory: "deporte", tags: [work])
        let previous = Consensus(account: "interbank", subcategory: "gimnasio", tags: [gym])
        let plan = DescriptionAutofillLogic.plan(
            consensus,
            current: current(account: "interbank", baseline: "bcp", subcategory: "gimnasio", tags: [gym], last: previous))
        #expect(plan == consensus)
    }

    @Test func laClave_separaGastoDeIngreso_yNormaliza() {
        #expect(DescriptionAutofillLogic.key(note: "  SmartFit  J1 ", isIncome: false) == "e:smartfit j1")
        #expect(DescriptionAutofillLogic.key(note: "Sueldo", isIncome: true) == "i:sueldo")
        let index = DescriptionAutofillLogic.index(rows: [
            (note: "Smartfit J1", isIncome: false, sample: Sample(account: "a", subcategory: "s", tags: [])),
            (note: "smartfit  j1", isIncome: false, sample: Sample(account: "a", subcategory: "s", tags: [])),
            (note: "Smartfit J1", isIncome: true, sample: Sample(account: "b", subcategory: "t", tags: [])),
            (note: "   ", isIncome: false, sample: Sample(account: "c", subcategory: "u", tags: [])),
        ])
        #expect(index.count == 2)
        #expect(index["e:smartfit j1"]?.account == "a")
        #expect(index["i:smartfit j1"]?.account == "b")
    }

    // MARK: - La fila de abajo en una línea (ajuste 1)

    @Test func filaQueCabe_conservaLosAnchosIdeales() {
        let widths = OneLineChipRowLogic.widths(ideals: [60, 120, 40], flexible: [false, true, false], maxWidth: 400,
                                                spacing: 8)
        #expect(widths == [60, 120, 40])
    }

    @Test func filaQueNoCabe_encogeSoloLaCuenta() {
        let widths = OneLineChipRowLogic.widths(ideals: [60, 300, 40], flexible: [false, true, false], maxWidth: 300,
                                                spacing: 8)
        #expect(widths[0] == 60)
        #expect(widths[2] == 40)
        #expect(widths[1] == CGFloat(184))  // 300 de ancho − 16 de huecos − 100 de los fijos
        #expect(widths.reduce(0, +) + 16 <= 300)
    }

    @Test func transferencia_lasDosCuentasSeRepartenLoQueQueda() {
        let widths = OneLineChipRowLogic.widths(ideals: [200, 80], flexible: [true, true], maxWidth: 250, spacing: 10)
        // 240 libres: la corta conserva sus 80 y la larga se queda con el resto.
        #expect(widths == [160, 80])
        let even = OneLineChipRowLogic.widths(ideals: [300, 300], flexible: [true, true], maxWidth: 250, spacing: 10)
        #expect(even == [120, 120])
    }

    @Test func niConLaCuentaAlMinimo_todosComparten_yNuncaPasanDelAncho() {
        let widths = OneLineChipRowLogic.widths(ideals: [200, 300, 150], flexible: [false, true, false], maxWidth: 240,
                                                spacing: 8)
        #expect(widths.reduce(0, +) + 16 <= 240.0001)
        #expect(zip(widths, [200, 300, 150]).allSatisfy { $0 <= $1 })
    }

    // MARK: - El estimado junto al monto (ajuste 5)

    @Test func estimado_aLaDerechaSiCabe_debajoSiNo() {
        #expect(AmountEstimatePlacementLogic.isInline(mainWidth: 200, estimateWidth: 90, spacing: 8, maxWidth: 343))
        #expect(!AmountEstimatePlacementLogic.isInline(mainWidth: 280, estimateWidth: 90, spacing: 8, maxWidth: 343))
    }

    // MARK: - La cápsula de moneda

    private let accounts: [AmountCurrencyAccount<String>] = [
        AmountCurrencyAccount(id: "bcp", currencyCode: "PEN"),
        AmountCurrencyAccount(id: "visa", currencyCode: "PEN", cardMembers: ["visa", "visa-usd"]),
        AmountCurrencyAccount(id: "visa-usd", currencyCode: "USD", cardMembers: ["visa", "visa-usd"]),
        AmountCurrencyAccount(id: "ahorros-usd", currencyCode: "usd"),
        AmountCurrencyAccount(id: "euros", currencyCode: "EUR"),
    ]

    @Test func monedas_laDelFormularioPrimero_ydespuesPorCuentas() {
        let options = AmountCurrencyMenuLogic.options(accounts: accounts, current: "EUR")
        #expect(options.map(\.currencyCode) == ["EUR", "PEN", "USD"])
        #expect(options.map(\.accountCount) == [1, 2, 2])
    }

    @Test func unaSolaMoneda_laCapsulaNoOfreceNada() {
        let options = AmountCurrencyMenuLogic.options(
            accounts: [AmountCurrencyAccount(id: "bcp", currencyCode: "PEN")], current: "PEN")
        #expect(options.count == 1)
    }

    @Test func elegirMoneda_lineaDeLaTarjeta_oPrimeraCuenta_oLaMisma() {
        #expect(AmountCurrencyMenuLogic.target(for: "USD", selected: "visa", accounts: accounts) == "visa-usd")
        #expect(AmountCurrencyMenuLogic.target(for: "USD", selected: "bcp", accounts: accounts) == "visa-usd")
        #expect(AmountCurrencyMenuLogic.target(for: "PEN", selected: "bcp", accounts: accounts) == "bcp")
        #expect(AmountCurrencyMenuLogic.target(for: "JPY", selected: "bcp", accounts: accounts) == nil)
    }

    // MARK: - Títulos, «#2» y el éxito

    @Test func titulo_abreElMenuSoloEnUnRegistroNuevoConLosTresTipos() {
        #expect(NewRecordTitleLogic.opensTypeMenu(mode: .new, isExpensesOnly: false, isFromGroup: false))
        #expect(!NewRecordTitleLogic.opensTypeMenu(mode: .edit, isExpensesOnly: false, isFromGroup: false))
        #expect(!NewRecordTitleLogic.opensTypeMenu(mode: .duplicate, isExpensesOnly: false, isFromGroup: false))
        #expect(!NewRecordTitleLogic.opensTypeMenu(mode: .new, isExpensesOnly: true, isFromGroup: false))
        #expect(!NewRecordTitleLogic.opensTypeMenu(mode: .new, isExpensesOnly: false, isFromGroup: true))
    }

    @Test func etiquetas_soloElNumero() {
        #expect(TagCountChipLogic.label(count: 0) == "#")
        #expect(TagCountChipLogic.label(count: 2) == "#2")
        #expect(TagCountChipLogic.label(count: 12) == "#12")
    }

    @Test func exito_ordenDeLosDatos() {
        #expect(TransactionSuccessFieldOrder.fields(isTransfer: false, hasSubcategory: true, hasNeed: true, hasTags: true)
            == [.date, .account, .subcategory, .need, .tags])
        #expect(TransactionSuccessFieldOrder.fields(isTransfer: false, hasSubcategory: true, hasNeed: false, hasTags: false)
            == [.date, .account, .subcategory])
        #expect(TransactionSuccessFieldOrder.fields(isTransfer: true, hasSubcategory: false, hasNeed: false, hasTags: false)
            == [.date, .transferAccounts])
    }

    // MARK: - La tabla de textos, en los 16 idiomas

    @Test func tablaPropia_conTodasLasClavesEnLos16Idiomas() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: root.path)
            .filter { $0.hasSuffix(".lproj") && $0 != "Base.lproj" }
        #expect(locales.count == 16)
        for locale in locales {
            let url = root.appendingPathComponent("\(locale)/NuevoRegistroB1.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String], "falta la tabla en \(locale)")
            for key in NuevoRegistroB1Text.allKeys {
                #expect(!(table["nr.\(key)"] ?? "").isEmpty, "\(locale) sin nr.\(key)")
            }
            #expect(table.count == NuevoRegistroB1Text.allKeys.count, "\(locale): claves de más")
        }
    }

    @Test func textosEnEspanolNeutro() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources/es-419.lproj/NuevoRegistroB1.strings")
        let table = try #require(NSDictionary(contentsOf: root) as? [String: String])
        #expect(table["nr.addAnother"] == "Agregar otro")
        #expect(table["nr.save.withAmount"] == "Guardar %@")
        #expect(table["nr.success.saved.expense"] == "Gasto guardado")
    }
}
