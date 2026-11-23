//
//  ImportarLote1LogicaTests.swift
//  YalaTests
//
//  Lógica pura del lote 1 de Importar registros (22-nov-2026): el orden de las fechas por archivo (H10), la huella de
//  los duplicados (H11) y el emparejado de transferencias (H9). Las fechas son las medidas en la auditoría del import.
//

import Foundation
import Testing

@testable import Yala

@Suite("Importar lote 1 · lógica pura")
struct ImportarLote1LogicaTests {

    private static let lima = TimeZone(identifier: "America/Lima") ?? .gmt
    private static let auckland = TimeZone(identifier: "Pacific/Auckland") ?? .gmt
    private static let us = Locale(identifier: "en_US")
    private static let peru = Locale(identifier: "es_PE")

    /// «Hoy» fijo: 22 de noviembre de 2026.
    private static let now: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = lima
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 20)) ?? .distantPast
    }()

    private static func ymd(_ date: Date?, in zone: TimeZone = lima) -> String? {
        guard let date else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let c = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        return String(format: "%04d-%02d-%02d %02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0)
    }

    private static func day(_ raw: String, _ order: ImportDateOrder, zone: TimeZone = lima) -> String? {
        ymd(ImportDateLogic.parseDay(raw, order: order, timeZone: zone, now: now), in: zone)
    }

    // MARK: - Fechas (H10)

    @Test("El orden del teléfono: mes/día en EE. UU., día/mes en Perú")
    func localeOrder() {
        #expect(ImportDateLogic.localeOrder(Self.us) == .monthFirst)
        #expect(ImportDateLogic.localeOrder(Self.peru) == .dayFirst)
    }

    @Test("Un archivo de EE. UU. con un 15 en el segundo número se lee mes/día entero: 03/04/2026 es el 4 de marzo")
    func fileDecidesMonthFirst() {
        let decision = ImportDateLogic.decide(for: ["03/04/2026", "03/15/2026"], locale: Self.peru)
        #expect(decision == ImportDateDecision(order: .monthFirst, decidedByFile: true, ambiguousExample: nil))
        #expect(Self.day("03/04/2026", decision.order) == "2026-03-04 12")
        #expect(Self.day("03/15/2026", decision.order) == "2026-03-15 12")
    }

    @Test("Un 27 en el primer número decide día/mes aunque el teléfono sea de EE. UU.")
    func fileDecidesDayFirst() {
        let decision = ImportDateLogic.decide(for: ["03/04/2026", "27/10/2026"], locale: Self.us)
        #expect(decision.order == .dayFirst)
        #expect(decision.decidedByFile)
        #expect(Self.day("03/04/2026", decision.order) == "2026-04-03 12")
    }

    @Test("Si nada lo decide manda el teléfono, y la vista previa recibe el ejemplo ambiguo")
    func phoneDecidesWhenFileDoesNot() {
        let us = ImportDateLogic.decide(for: ["2026-10-01", "03/04/2026", "05/05/2026"], locale: Self.us)
        #expect(us == ImportDateDecision(order: .monthFirst, decidedByFile: false, ambiguousExample: "03/04/2026"))
        let peru = ImportDateLogic.decide(for: ["03/04/2026"], locale: Self.peru)
        #expect(peru.order == .dayFirst && !peru.decidedByFile)
        // Solo ISO: nada que enseñar.
        #expect(ImportDateLogic.decide(for: ["2026-10-01"], locale: Self.us).ambiguousExample == nil)
    }

    @Test("Un archivo que se contradice usa el orden del teléfono: la fila que no casa sale inválida")
    func contradictoryFileFallsBackToThePhone() {
        let decision = ImportDateLogic.decide(for: ["27/10/2026", "10/27/2026"], locale: Self.peru)
        #expect(decision.order == .dayFirst && !decision.decidedByFile)
        #expect(Self.day("10/27/2026", decision.order) == nil)
    }

    @Test("Años de dos cifras en todas las rutas: 10/27/26 es 2026 y 27/10/99 es 1999, no 2099")
    func twoDigitYears() {
        #expect(Self.day("10/27/26", .monthFirst) == "2026-10-27 12")
        #expect(Self.day("27/10/99", .dayFirst) == "1999-10-27 12")
        #expect(Self.day("27-10-26", .dayFirst) == "2026-10-27 12")
        #expect(Self.day("27.10.26", .dayFirst) == "2026-10-27 12")
        // Este año sí; el que viene aún no ha llegado y se lee del siglo pasado.
        #expect(Self.day("01/01/27", .dayFirst) == "1927-01-01 12")
    }

    @Test("El año primero no depende del orden, con «-», «/» o «.», y la hora de la celda no estorba")
    func yearFirst() {
        for raw in ["2026-10-27", "2026/10/27", "2026.10.27", "2026-10-27T14:30", "2026-10-27 14:30:00"] {
            #expect(Self.day(raw, .monthFirst) == "2026-10-27 12", "\(raw)")
            #expect(Self.day(raw, .dayFirst) == "2026-10-27 12", "\(raw)")
        }
    }

    @Test("En Nueva Zelanda en verano la fecha se queda en su día (antes, mediodía UTC: el día siguiente)")
    func aucklandKeepsTheDay() {
        #expect(Self.day("2026-10-27", .dayFirst, zone: Self.auckland) == "2026-10-27 12")
    }

    @Test("Días que no existen y textos que no son fechas")
    func invalidDates() {
        for raw in ["31/02/2026", "00/10/2026", "13/13/2026", "hoy", "", "2026-13-01", "1/2", "12/10/202"] {
            #expect(ImportDateLogic.parseDay(raw, order: .dayFirst, timeZone: Self.lima, now: Self.now) == nil, "\(raw)")
        }
    }

    // MARK: - Duplicados (H11)

    private static func print(_ amount: Double, note: String? = nil, account: String = "A", day: Int = 3) -> ImportDuplicateLogic.Fingerprint {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = lima
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12)) ?? .distantPast
        return ImportDuplicateLogic.fingerprint(
            date: date, amount: amount, currencyCode: "pen", accountKey: account, note: note, calendar: calendar)
    }

    @Test("Reimportar el mismo archivo: todas las filas son duplicados")
    func reimportMarksEverything() {
        let file = [Self.print(-10, note: "Café"), Self.print(-10, note: "café "), Self.print(-25.5)]
        #expect(ImportDuplicateLogic.duplicateIndices(rows: file, existing: file) == [0, 1, 2])
    }

    @Test("Dos cafés iguales en un archivo nuevo entran los dos; con uno ya en la cuenta, entra uno")
    func twoCoffeesCount() {
        let file = [Self.print(-10, note: "Café"), Self.print(-10, note: "Café")]
        #expect(ImportDuplicateLogic.duplicateIndices(rows: file, existing: []).isEmpty)
        #expect(ImportDuplicateLogic.duplicateIndices(rows: file, existing: [file[0]]) == [0])
    }

    @Test("Otra cuenta, otro día, otro importe u otra nota no son el mismo movimiento")
    func fingerprintParts() {
        let base = Self.print(-10, note: "Café")
        #expect(base != Self.print(-10, note: "Café", account: "B"))
        #expect(base != Self.print(-10, note: "Café", day: 4))
        #expect(base != Self.print(-10.01, note: "Café"))
        #expect(base != Self.print(-10, note: "Té"))
        #expect(base == Self.print(-10, note: "  café  "))
    }

    // MARK: - Transferencias (H9)

    private static func leg(
        _ id: Int, _ amount: Int64, _ account: String, currency: String = "PEN", day: String = "2026-10-03",
        note: String = ""
    ) -> ImportTransferPairingLogic.Leg {
        ImportTransferPairingLogic.Leg(
            id: id, day: day, amount: amount, currencyCode: currency, accountKey: account, note: note)
    }

    @Test("PEN → USD el mismo día se empareja aunque los importes no coincidan")
    func currencyChangePairs() {
        let legs = [Self.leg(0, -3_750_000, "Banco"), Self.leg(1, 1_000_000, "Dólares", currency: "USD")]
        #expect(ImportTransferPairingLogic.pairs(legs) == [.init(outflow: 0, inflow: 1)])
    }

    @Test("Con cambio de moneda y más de una salida suelta en el día, no se adivina")
    func currencyChangeNeedsOneOfEach() {
        let legs = [
            Self.leg(0, -3_750_000, "Banco"), Self.leg(1, -500_000, "Caja"),
            Self.leg(2, 1_000_000, "Dólares", currency: "USD"),
        ]
        #expect(ImportTransferPairingLogic.pairs(legs).isEmpty)
    }

    @Test("Dos de 100 el mismo día entre cuentas distintas se emparejan por cuenta (A → B y B → A)")
    func pairsByAccount() {
        let legs = [
            Self.leg(0, -1_000_000, "A"), Self.leg(1, 1_000_000, "A"),
            Self.leg(2, -1_000_000, "B"), Self.leg(3, 1_000_000, "B"),
        ]
        let pairs = ImportTransferPairingLogic.pairs(legs)
        #expect(Set(pairs.map { "\($0.outflow)-\($0.inflow)" }) == ["0-3", "2-1"])
    }

    @Test("Dos patas de la misma cuenta no se emparejan (antes sí)")
    func sameAccountNeverPairs() {
        let legs = [Self.leg(0, -1_000_000, "A"), Self.leg(1, 1_000_000, "A")]
        #expect(ImportTransferPairingLogic.pairs(legs).isEmpty)
        #expect(ImportTransferPairingLogic.looseCount(legs) == 2)
    }

    @Test("A → B y C → D por el mismo importe: no se sabe cuál va con cuál, y la nota desempata")
    func ambiguityAndNotes() {
        let blind = [
            Self.leg(0, -1_000_000, "A"), Self.leg(1, 1_000_000, "B"),
            Self.leg(2, -1_000_000, "C"), Self.leg(3, 1_000_000, "D"),
        ]
        #expect(ImportTransferPairingLogic.pairs(blind).isEmpty)
        let noted = [
            Self.leg(0, -1_000_000, "A", note: "alquiler"), Self.leg(1, 1_000_000, "B", note: "alquiler"),
            Self.leg(2, -1_000_000, "C", note: "ahorro"), Self.leg(3, 1_000_000, "D", note: "ahorro"),
        ]
        #expect(Set(ImportTransferPairingLogic.pairs(noted).map { "\($0.outflow)-\($0.inflow)" }) == ["0-1", "2-3"])
    }

    @Test("Dos transferencias iguales de A a B el mismo día: dos parejas")
    func repeatedTransfers() {
        let legs = [
            Self.leg(0, -1_000_000, "A"), Self.leg(1, -1_000_000, "A"),
            Self.leg(2, 1_000_000, "B"), Self.leg(3, 1_000_000, "B"),
        ]
        #expect(ImportTransferPairingLogic.pairs(legs).count == 2)
    }

    @Test("Dos salidas de cuentas distintas y una sola entrada: no se sabe de cuál vino")
    func oneInflowTwoOrigins() {
        let legs = [Self.leg(0, -1_000_000, "A"), Self.leg(1, -1_000_000, "C"), Self.leg(2, 1_000_000, "B")]
        #expect(ImportTransferPairingLogic.pairs(legs).isEmpty)
    }

    // MARK: - Vista previa (H11 · H9)

    private static func row(_ number: Int, duplicate: Bool, transfer: Bool = false, amount: Double = -10,
                            account: String = "e1", currency: String = "PEN") -> ImportPreview.Row {
        ImportPreview.Row(
            date: now, amount: amount, currencyCode: currency, categoryName: "Comida", subcategoryName: "Café",
            rowNumber: number, accountKey: account, isDuplicate: duplicate, isTransfer: transfer)
    }

    @Test("La vista previa salta los duplicados por defecto e «Importarlos igual» los vuelve a contar")
    func previewSkipsDuplicatesByDefault() {
        var preview = ImportPreviewLogic.make(
            rows: [Self.row(2, duplicate: true), Self.row(3, duplicate: false), Self.row(4, duplicate: true)],
            accountNames: ["Banco"], failures: [], ignoredFutureCount: 0)
        preview.allRows = [Self.row(2, duplicate: true), Self.row(3, duplicate: false), Self.row(4, duplicate: true)]
        let skipped = ImportPreviewLogic.applying(chosen: [], importDuplicates: false, to: preview)
        #expect(skipped.count == 1)
        #expect(skipped.duplicateCount == 2)
        let all = ImportPreviewLogic.applying(chosen: [], importDuplicates: true, to: preview)
        #expect(all.count == 3)
        #expect(all.duplicateCount == 2)
    }

    @Test("La vista previa cuenta las transferencias sueltas de lo que entra")
    func previewCountsLooseTransfers() {
        let rows = [
            Self.row(2, duplicate: false, transfer: true, amount: -375, account: "e1"),
            Self.row(3, duplicate: false, transfer: true, amount: 100, account: "e2", currency: "USD"),
            Self.row(4, duplicate: false, transfer: true, amount: -50, account: "e1"),
            Self.row(5, duplicate: false, transfer: true, amount: 50, account: "e1"),
        ]
        // 2-3 se emparejan por el cambio de moneda... solo si quedan una salida y una entrada sueltas: aquí hay dos
        // salidas en el día (375 y 50, con 50 de la misma cuenta que no se empareja), así que se quedan las cuatro.
        #expect(ImportPreviewLogic.looseTransfers(in: rows) == 4)
        #expect(ImportPreviewLogic.looseTransfers(in: Array(rows.prefix(2))) == 0)
    }
}
