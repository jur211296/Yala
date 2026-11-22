//
//  AtajoBancoB2B3Tests.swift
//  YalaTests
//
//  Atajo del banco, parte 2 (decisión 66, encargo del 22-nov): B2 (estado, contadores, pausa, cuenta por defecto, aviso
//  de ejemplo) y B3 (el correo de Mail). Todo lo del App Group va con un dominio aislado por test.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Atajo del banco · B2 estado y B3 correo", .serialized, .lastUsedAccountIsolated)
@MainActor
struct AtajoBancoB2B3Tests {

    nonisolated private static let lima: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }()

    nonisolated private static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        lima.date(from: DateComponents(year: y, month: m, day: d, hour: hour)) ?? .distantPast
    }

    private func isolated() -> UserDefaults {
        testDefaults(suiteName: "test.banknotice.b2.\(UUID().uuidString)")!
    }

    private let bcpText = "Consumo con tu tarjeta\nRealizaste un consumo de S/ 45.90 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES."

    // MARK: - Actividad y contadores

    @Test("Cada aviso que llega se cuenta en su mes: leídos, sin entender y no eran compras")
    func activity_countsEachReadingInItsMonth() throws {
        let defaults = isolated()
        let nov = Self.date(2026, 11, 20)
        let movement = try #require(BankNoticeParser.read(bcpText, bankHint: .bcp))
        BankNoticeActivityStore.record(movement, bank: .bcp, at: nov, defaults: defaults)
        BankNoticeActivityStore.record(.notUnderstood, bank: .bcp, at: nov, defaults: defaults)
        BankNoticeActivityStore.record(.notAMovement, bank: .bcp, at: nov, defaults: defaults)
        BankNoticeActivityStore.record(.notAMovement, bank: .bcp, at: Self.date(2026, 10, 3), defaults: defaults)

        let activity = BankNoticeActivityStore.activity(for: .bcp, defaults: defaults)
        let counts = activity.counts(for: nov, calendar: Self.lima)
        #expect(counts == BankNoticeActivity.Counts(read: 1, notUnderstood: 1, notPurchases: 1))
        #expect(activity.counts(for: Self.date(2026, 10, 3), calendar: Self.lima).notPurchases == 1)
        #expect(activity.lastMovement?.counterparty == "TAMBO+ MIRAFLORES")
        #expect(activity.lastMovement?.amount == Decimal(string: "45.90"))
        // Otro banco no se entera.
        #expect(BankNoticeActivityStore.activity(for: .interbank, defaults: defaults).arrivals.isEmpty)
        #expect(BankNoticeActivityStore.knownBanks(defaults: defaults) == [.bcp])
    }

    @Test("Se recuerdan como mucho 30 llegadas y 3 meses")
    func activity_isBounded() {
        var activity = BankNoticeActivity()
        for day in 0..<40 {
            activity.record(.notAMovement, at: Self.date(2026, 7, 1).addingTimeInterval(Double(day) * 86_400 * 4), calendar: Self.lima)
        }
        #expect(activity.arrivals.count == BankNoticeActivity.arrivalsKept)
        #expect(activity.months.count == BankNoticeActivity.monthsKept)
    }

    @Test("«Vaciar» y las fronteras de cuenta se llevan todo lo del atajo")
    func removeAll_clearsActivityAndSettings() {
        let defaults = isolated()
        BankNoticeActivityStore.record(.notAMovement, bank: .yape, at: .now, defaults: defaults)
        BankNoticeActivityStore.save(BankNoticeSettings(isPaused: true, defaultAccountShortcutID: UUID(), isSetUp: true),
                                     for: .bcp, defaults: defaults)
        #expect(BankNoticeActivityStore.allKeys(defaults: defaults).count == 2)
        BankNoticeActivityStore.removeAll(defaults: defaults)
        #expect(BankNoticeActivityStore.allKeys(defaults: defaults).isEmpty)
        #expect(BankNoticeActivityStore.knownBanks(defaults: defaults).isEmpty)
    }

    @Test("La purga de las fronteras de cuenta incluye el estado del atajo (cableado)")
    func inboundPurge_isWired() throws {
        let source = try String(
            contentsOfFile: ComercioFotoCategoriaTests.repoFile("Yala/Services/CloudSync/AppGroupInboundPurge.swift"),
            encoding: .utf8)
        #expect(source.contains("BankNoticeActivityStore.removeAll()"))
    }

    // MARK: - Estado

    private func activity(arrivalsEvery days: Int, count: Int, lastOn last: Date) -> BankNoticeActivity {
        var activity = BankNoticeActivity()
        for index in (0..<count).reversed() {
            activity.record(.notAMovement, at: last.addingTimeInterval(-Double(index * days) * 86_400), calendar: Self.lima)
        }
        return activity
    }

    @Test("Sin avisos: esperando. Con avisos: funcionando. Pausado manda sobre todo")
    func status_waitingWorkingPaused() {
        let now = Self.date(2026, 11, 22)
        #expect(BankNoticeStatus.status(activity: BankNoticeActivity(), settings: BankNoticeSettings(), now: now,
                                        calendar: Self.lima) == .waiting)
        let recent = activity(arrivalsEvery: 1, count: 3, lastOn: Self.date(2026, 11, 21))
        #expect(BankNoticeStatus.status(activity: recent, settings: BankNoticeSettings(), now: now, calendar: Self.lima)
                == .working(lastArrival: Self.date(2026, 11, 21)))
        #expect(BankNoticeStatus.status(activity: recent, settings: BankNoticeSettings(isPaused: true), now: now,
                                        calendar: Self.lima) == .paused)
    }

    @Test("El silencio solo se dice si antes llegaban con frecuencia")
    func status_silenceNeedsAHabit() {
        let now = Self.date(2026, 11, 22)
        // Llegaban a diario y hace 9 días que nada: silencio.
        let daily = activity(arrivalsEvery: 1, count: 10, lastOn: Self.date(2026, 11, 13))
        #expect(BankNoticeStatus.status(activity: daily, settings: BankNoticeSettings(), now: now, calendar: Self.lima)
                == .silent(days: 9, lastArrival: Self.date(2026, 11, 13)))
        // Con 4 avisos no hay hábito todavía.
        let few = activity(arrivalsEvery: 1, count: 4, lastOn: Self.date(2026, 11, 13))
        #expect(BankNoticeStatus.status(activity: few, settings: BankNoticeSettings(), now: now, calendar: Self.lima)
                == .working(lastArrival: Self.date(2026, 11, 13)))
        // Llegaban cada 5 días: 9 días no triplican el hueco típico.
        let sparse = activity(arrivalsEvery: 5, count: 6, lastOn: Self.date(2026, 11, 13))
        #expect(BankNoticeStatus.status(activity: sparse, settings: BankNoticeSettings(), now: now, calendar: Self.lima)
                == .working(lastArrival: Self.date(2026, 11, 13)))
        // A diario y hace 6 días: por debajo del mínimo de 7.
        let shortGap = activity(arrivalsEvery: 1, count: 10, lastOn: Self.date(2026, 11, 16))
        #expect(BankNoticeStatus.status(activity: shortGap, settings: BankNoticeSettings(), now: now, calendar: Self.lima)
                == .working(lastArrival: Self.date(2026, 11, 16)))
    }

    // MARK: - La acción de Atajos

    @Test("Pausado, la acción no encola ni cuenta lo que llega (cableado, antes de leer)")
    func intent_pausedIgnoresTheNotice() throws {
        let source = try String(
            contentsOfFile: ComercioFotoCategoriaTests.repoFile("Yala/App/Intents/BankNoticeIntent.swift"), encoding: .utf8)
        let perform = try #require(source.range(of: "func perform()"))
        let body = String(source[perform.lowerBound...])
        let pause = try #require(body.range(of: "BankNoticeActivityStore.isPaused"))
        let read = try #require(body.range(of: "await Self.read("))
        let record = try #require(body.range(of: "BankNoticeActivityStore.record("))
        let append = try #require(body.range(of: "BankNoticePendingStore.append("))
        #expect(pause.lowerBound < read.lowerBound)
        // Lo que no era una compra también cuenta: el registro va antes de la salida por `leavesDraft`.
        let leaves = try #require(body.range(of: "entry.reading.leavesDraft"))
        #expect(record.lowerBound < leaves.lowerBound)
        #expect(leaves.lowerBound < append.lowerBound)
    }

    @Test("Los avisos de ejemplo de cada banco con reglas se leen como el movimiento que dicen")
    func samples_readAsMovements() async {
        for bank in BankNoticeBank.allCases {
            let entry = await BankNoticeIntent.read(text: BankNoticeSamples.text(for: bank), bankHint: bank) { _ in nil }
            guard case .movement(let movement, let ruleID) = entry.reading else {
                Issue.record("\(bank): \(entry.reading)")
                continue
            }
            #expect(ruleID != nil, "\(bank) lo leyó una regla")
            #expect(movement.amount > 0)
        }
    }

    @Test("La línea del resultado de la prueba dice gasto, ingreso o que no se entendió")
    func sampleResultLine() {
        let format: (Decimal, String?) -> String = { amount, _ in "S/ \(amount)" }
        let expense = BankNoticeMovement(amount: 45.9, currencyCode: "PEN", ambiguousSymbol: nil, isExpense: true,
                                         counterparty: "TAMBO+", cardLast4: nil)
        #expect(BankNoticeBankView.resultLine(.movement(expense, ruleID: "x"), format: format)
                == L10n.CapturaAtajoParte2.Bank.testExpense("S/ 45.9", "TAMBO+"))
        #expect(BankNoticeBankView.resultLine(.notUnderstood, format: format) == L10n.CapturaAtajoParte2.Bank.testNotUnderstood)
        #expect(BankNoticeBankView.resultLine(.notAMovement, format: format) == L10n.CapturaAtajoParte2.Bank.testNotAMovement)
    }

    // MARK: - Cuenta por defecto

    @Test("La cuenta por defecto entra cuando el aviso no dice cuál, y solo en su moneda")
    func defaultAccount_appliesOnlyInItsCurrency() throws {
        let context = try makeTestContext()
        let defaults = isolated()
        let debito = makeTestAccount(context: context, name: "Débito", currencyCode: "PEN")
        let dolares = makeTestAccount(context: context, name: "Ahorros USD", currencyCode: "USD")
        let accounts = [debito, dolares]
        BankNoticeActivityStore.save(BankNoticeSettings(defaultAccountShortcutID: debito.shortcutID), for: .yape, defaults: defaults)
        #expect(BankNoticeDraftService.defaultAccount(for: .yape, currency: "PEN", in: accounts, defaults: defaults) === debito)
        #expect(BankNoticeDraftService.defaultAccount(for: .yape, currency: nil, in: accounts, defaults: defaults) === debito)
        #expect(BankNoticeDraftService.defaultAccount(for: .yape, currency: "USD", in: accounts, defaults: defaults) == nil)
        #expect(BankNoticeDraftService.defaultAccount(for: .bcp, currency: "PEN", in: accounts, defaults: defaults) == nil)
        debito.isArchived = true
        #expect(BankNoticeDraftService.defaultAccount(for: .yape, currency: "PEN", in: accounts, defaults: defaults) == nil)
    }

    @Test("Lo que dice el aviso manda sobre la cuenta por defecto (cableado)")
    func defaultAccount_goesAfterTheNotice() throws {
        let source = try String(contentsOfFile: ComercioFotoCategoriaTests.repoFile(
            "Yala/App/Logic/AtajoBanco/BankNoticeDraftService.swift"), encoding: .utf8)
        let notice = try #require(source.range(of: "let account = accountFromNotice("))
        let fallback = try #require(source.range(of: "?? defaultAccount(for: entry.bank"))
        let currency = try #require(source.range(of: "?? ApplePayDraftService.matchedAccount("))
        #expect(notice.lowerBound < fallback.lowerBound)
        #expect(fallback.lowerBound < currency.lowerBound)
    }

    // MARK: - B3: el correo de Mail

    private let mailBCP = """
    Hola Juan,
    Constancia de consumo
    Realizaste un consumo con tu Tarjeta de Débito BCP ****4821.
    Monto: S/ 45.90
    Comercio: TAMBO+ MIRAFLORES
    Fecha y hora: 21/11/2026 09:41
    Número de operación: 123456
    Este correo es informativo. No respondas a este mensaje.
    Conoce nuestras promociones y descuentos exclusivos. Nunca te pediremos tu clave ni tu código de seguridad.
    """

    @Test("El correo se recorta en el pie y se leen los campos «Monto» y «Comercio»")
    func mail_readsTheLabelledFields() throws {
        let cleaned = BankNoticeMail.cleaned(mailBCP)
        #expect(!cleaned.contains("promociones"))
        #expect(cleaned.contains("Comercio: TAMBO+ MIRAFLORES"))
        guard case .movement(let movement, let ruleID)? = BankNoticeMail.read(mailBCP, bankHint: .bcp) else {
            Issue.record("no leyó el correo")
            return
        }
        #expect(ruleID == "mail.fields")
        #expect(movement.amount == Decimal(string: "45.90"))
        #expect(movement.currencyCode == "PEN")
        #expect(movement.counterparty == "TAMBO+ MIRAFLORES")
        #expect(movement.cardLast4 == "4821")
        #expect(movement.isExpense)
        // Sin recortar, el pie (promociones, claves) lo daba por publicidad.
        #expect(BankNoticeParser.read(mailBCP, bankHint: .bcp) != .movement(movement, ruleID: "mail.fields"))
    }

    @Test("Una tabla pasada a texto: la etiqueta en una línea y el valor en la siguiente")
    func mail_labelOnOneLineValueOnTheNext() {
        let table = "Constancia de compra\nImporte total\nS/. 120,50\nEstablecimiento\nPLAZA VEA SURCO\nAtentamente, tu banco"
        guard case .movement(let movement, _)? = BankNoticeMail.read(table, bankHint: .interbank) else {
            Issue.record("no leyó la tabla")
            return
        }
        #expect(movement.amount == Decimal(string: "120.50"))
        #expect(movement.counterparty == "PLAZA VEA SURCO")
    }

    @Test("Un correo rechazado, una anulación o uno sin gasto no se leen como gasto por los campos")
    func mail_fieldsOnlyForExpenses() {
        #expect(BankNoticeMail.readFields("Tu compra fue rechazada\nMonto: S/ 30.00\nComercio: WONG") == nil)
        #expect(BankNoticeMail.readFields("Extorno de tu compra\nMonto: S/ 30.00\nComercio: WONG") == nil)
        #expect(BankNoticeMail.readFields("Estado de cuenta\nMonto: S/ 30.00") == nil)
        // Uno de abono lo leen las reglas de siempre.
        guard case .movement(let income, _)? = BankNoticeMail.read("Recibiste S/ 50.00 de ANA TORRES.", bankHint: nil) else {
            Issue.record("no leyó el abono")
            return
        }
        #expect(!income.isExpense)
    }

    @Test("La acción con Origen «Correo» guarda el correo recortado y lee sus campos")
    func intent_mailSource_cleansAndReads() async {
        let entry = await BankNoticeIntent.read(text: mailBCP, bankHint: .bcp, isMail: true) { _ in nil }
        #expect(!entry.rawText.contains("promociones"))
        guard case .movement(let movement, let ruleID) = entry.reading else {
            Issue.record("\(entry.reading)")
            return
        }
        #expect(ruleID == "mail.fields")
        #expect(movement.counterparty == "TAMBO+ MIRAFLORES")
        // Con Origen «Notificación» (lo de siempre) el mismo texto no se recorta.
        let asNotice = await BankNoticeIntent.read(text: mailBCP, bankHint: .bcp) { _ in nil }
        #expect(asNotice.rawText == mailBCP)
    }

    @Test("Un correo larguísimo se recorta al tope")
    func mail_isCapped() {
        let long = "Constancia de consumo\n" + String(repeating: "Línea de relleno sin pie.\n", count: 200)
        #expect(BankNoticeMail.cleaned(long).count <= BankNoticeMail.maxCharacters)
    }
}
