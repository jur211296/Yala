//
//  ImportarGrupoParserTests.swift
//  YalaTests
//
//  Los lectores de Splitwise y Tricount dan los mismos saldos por persona que la otra app (criterio de salida del hito 6
//  de 2.3 en `docs/ROADMAP.md`), con varias monedas, repartos desiguales y los errores que paran un import.
//

import Foundation
import Testing
@testable import Yala

@Suite("Importar grupo · lectores de Splitwise y Tricount")
struct ImportarGrupoParserTests {

    private func snapshot(_ text: String, file: String? = nil) throws -> ImportedGroupSnapshot {
        try ImportedGroupSnapshotBuilder.snapshot(fromCSV: text, fileName: file)
    }

    // MARK: - Splitwise

    @Test func splitwise_unaMoneda_saldosComoLaFilaDelTotal() throws {
        let s = try snapshot(ImportarGrupoFixtures.splitwiseCusco, file: "viaje-a-cusco_2026-03-05_export.csv")
        #expect(s.source == .splitwise)
        #expect(s.people == ["Jürgen", "Ana", "Luis", "Pia"])
        #expect(s.balances == ["PEN": ["Jürgen": 11_000, "Ana": -2_000, "Luis": 0, "Pia": -9_000]])
        #expect(s.expenseCount == 3)
        #expect(s.paymentCount == 1)
        #expect(s.suggestedName == "Viaje a cusco")
        #expect(s.peopleWithBalance == ["Jürgen", "Ana", "Pia"])
        let calendar = Calendar.current
        #expect(s.firstDate.map { calendar.component(.day, from: $0) } == 1)
        #expect(s.lastDate.map { calendar.component(.day, from: $0) } == 4)
    }

    @Test func splitwise_dosMonedas_unSaldoPorMoneda_yDescripcionConSaltoDeLinea() throws {
        let s = try snapshot(ImportarGrupoFixtures.splitwiseTwoCurrencies)
        #expect(s.balances["PEN"] == ["Jürgen": 6_000, "Ana": -3_000, "Luis": -3_000])
        #expect(s.balances["USD"] == ["Jürgen": -1_500, "Ana": 3_000, "Luis": -1_500])
        #expect(s.expenseCount == 2)
        // La moneda que más mueve va primero: se propone al grupo.
        #expect(s.currencies == ["PEN", "USD"])
        #expect(s.balances(of: "Ana").map(\.currency) == ["PEN", "USD"])
    }

    @Test func splitwise_puntoYComa_yComaDecimal() throws {
        let s = try snapshot(ImportarGrupoFixtures.splitwiseSemicolonComma)
        #expect(s.balances == ["EUR": ["Marta": 1_250, "Joan": -1_250, "Pau": 0]])
        #expect(s.peopleWithBalance == ["Marta", "Joan"])
    }

    @Test func splitwise_filaDelTotalConFechaYEnOtroIdioma_noCuentaComoGasto() throws {
        let s = try snapshot(ImportarGrupoFixtures.splitwiseTotalWithDateInGerman)
        #expect(s.balances == ["EUR": ["Lena": 1_500, "Max": -1_500]])
        #expect(s.expenseCount == 1)
    }

    @Test func splitwise_dosPersonasConElMismoNombre_sonDos() throws {
        let s = try snapshot(ImportarGrupoFixtures.splitwiseSameName)
        #expect(s.people == ["Carlos", "Carlos (2)"])
        #expect(s.balances == ["USD": ["Carlos": 1_000, "Carlos (2)": -1_000]])
    }

    // MARK: - Tricount

    @Test func tricount_repartoQueRedondea_yFilaACero_sinRestos() throws {
        let s = try snapshot(ImportarGrupoFixtures.tricountRounding)
        #expect(s.balances == ["USD": ["Ana": 666, "Bea": -333, "Caro": -333]])
        #expect(s.expenseCount == 1)
    }

    @Test func tricount_columnaPorPersona_reembolsoEIngreso() throws {
        let s = try snapshot(ImportarGrupoFixtures.tricountPerPerson)
        #expect(s.source == .tricount)
        #expect(s.people == ["Clara", "Tomás", "Inés"])
        #expect(s.balances == ["EUR": ["Clara": 1_500, "Tomás": 0, "Inés": -1_500]])
        #expect(s.expenseCount == 3)
        #expect(s.paymentCount == 1)
    }

    @Test func tricount_listaDeNombres_partesIguales_conLosCentimosRepartidos() throws {
        let s = try snapshot(ImportarGrupoFixtures.tricountList)
        #expect(s.balances == ["USD": ["Ana": 366, "Bea": 267, "Caro": -633]])
    }

    @Test func tricount_partesEnLaMonedaDelTricount_cuentaLaFilaEnEsaMoneda() throws {
        let s = try snapshot(ImportarGrupoFixtures.tricountShareInDefaultCurrency)
        #expect(s.balances == ["EUR": ["Dan": 6_000, "Eva": -6_000]])
    }

    // MARK: - Errores

    @Test func noEsUnExport() {
        #expect(throws: ImportedGroupError.unrecognizedFormat) { try snapshot(ImportarGrupoFixtures.notAnExport) }
    }

    @Test func monedaDesconocida() {
        #expect(throws: ImportedGroupError.unknownCurrency("XYZ")) { try snapshot(ImportarGrupoFixtures.unknownCurrency) }
    }

    @Test func filaQueNoCuadra() {
        #expect(throws: ImportedGroupError.rowDoesNotAddUp(row: 2)) { try snapshot(ImportarGrupoFixtures.rowDoesNotAddUp) }
    }

    @Test func soloElTotal_noTraeGastos() {
        #expect(throws: ImportedGroupError.noEntries) { try snapshot(ImportarGrupoFixtures.onlyHeaderAndTotal) }
    }

    @Test func importeIlegible() {
        let text = "Date,Description,Category,Cost,Currency,A,B\n2026-01-01,Algo,General,10.00,USD,cinco,-5.00"
        #expect(throws: ImportedGroupError.unreadableAmount(row: 2)) { try snapshot(text) }
    }

    @Test func saldosQueNoSumanCero() {
        #expect(throws: ImportedGroupError.balancesDoNotAddUp(currency: "USD")) {
            try ImportedGroupSnapshotBuilder.closeBalances(["USD": ["A": 10, "B": -5]])
        }
    }

    @Test func unCentimoSueltoLoAbsorbeElSaldoMayor() throws {
        let tenAndAHalfCent = try #require(Decimal(string: "10.005", locale: Locale(identifier: "en_US_POSIX")))
        let closed = try ImportedGroupSnapshotBuilder.closeBalances(["USD": ["A": tenAndAHalfCent, "B": -10]])
        #expect(closed["USD"]?.values.reduce(0, +) == 0)
    }

    @Test func archivoNoTexto() {
        #expect(throws: ImportedGroupError.unreadableFile) {
            try ImportedGroupSnapshotBuilder.text(from: Data([0x00, 0x00, 0xD8, 0x00]))
        }
    }

    @Test func textoLatin1_seLee() throws {
        let data = try #require("Date,Description,Category,Cost,Currency,José,Inés".data(using: .isoLatin1))
        #expect(try ImportedGroupSnapshotBuilder.text(from: data).contains("Inés"))
    }
}

@Suite("Importar grupo · CSV, importes y nombres")
struct ImportarGrupoCSVTests {

    @Test(arguments: [
        ("-15.00", "-15"), ("1,234.56", "1234.56"), ("1.234,56", "1234.56"), ("12,5", "12.5"), ("1,234", "1234"),
        ("1.234.567", "1234567"), ("(3.00)", "-3"), ("S/ 20", "20"), ("+7", "7"), ("0.00", "0"),
        ("US$ 1 000,50", "1000.5"), ("S/. 20", "20"), ("kr. 100", "100"), ("20 USD", "20"), ("-S/ 5", "-5"),
    ])
    func importes(_ raw: String, _ expected: String) throws {
        let value = try #require(Decimal(string: expected, locale: Locale(identifier: "en_US_POSIX")))
        #expect(GroupExportCSV.amount(raw) == value)
    }

    @Test(arguments: ["", "abc", "1-2", "--"])
    func importesQueNoSeLeen(_ raw: String) {
        #expect(GroupExportCSV.amount(raw) == nil)
    }

    @Test func filas_comillasEscapadas_ySaltoDeLineaDentro() {
        let rows = GroupExportCSV.rows(from: "a,\"b \"\"c\"\"\",\"d\ne\"\r\n1,2,3")
        #expect(rows == [["a", "b \"c\"", "d\ne"], ["1", "2", "3"]])
    }

    @Test func filas_conBOM_yTabulador() {
        #expect(GroupExportCSV.rows(from: "\u{FEFF}x\ty\n1\t2") == [["x", "y"], ["1", "2"]])
    }

    @Test(arguments: [
        ("viaje-a-cusco_2026-03-05_export.csv", "Viaje a cusco"),
        ("Transactions Depa Miraflores.csv", "Depa Miraflores"),
        ("tricount_casa_playa.csv", "Casa playa"),
        ("2026-01-01_export.csv", nil),
    ] as [(String, String?)])
    func nombreDelArchivo(_ file: String, _ expected: String?) {
        #expect(ImportedGroupSnapshotBuilder.suggestedName(fileName: file) == expected)
    }
}
