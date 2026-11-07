//
//  CurrencyConverterRowMemoTests.swift
//  YalaTests
//
//  Card «Convertir importes de otra fecha hace un fetch de tasas por llamada» (Time Profiler del 2026-10-30: ~170 ms
//  de un arranque en `convertChecked` → `fetchExchangeRate`). `resolveRates` lee ahora cada fila una vez por pasada
//  (`CurrencyConverter.rowMemo`), y lo que importa tanto como el ahorro es que la memoria NO tape una fila mejor que
//  llega después: el bug de siempre de este módulo (`currency-fx.md`).
//
//  Cada caso de invalidación lleva su control: sin la retirada, la conversión seguiría con la tasa vieja.
//

import CoreData
import Foundation
import SwiftData
import Testing
import os.lock

@testable import Yala

@MainActor
@Suite("Converter · cada fila de tasas se lee una vez por pasada", .serialized)
struct CurrencyConverterRowMemoTests {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// Un día fijo del pasado: la fila de «hoy» no interviene.
    private let day: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 6
        components.day = 15
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? .distantPast
    }()

    private func makeContext() throws -> ModelContext {
        let schema = Schema([ExchangeRate.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    @discardableResult
    private func insertRow(_ rates: [String: Double], on date: Date, into context: ModelContext) throws -> ExchangeRate {
        let row = try ExchangeRate(dateKey: Self.dateFormatter.string(from: date), base: "USD", ratesDictionary: rates)
        context.insert(row)
        return row
    }

    // MARK: - Los avisos ajenos

    /// Apunta los avisos que retiran la memoria (`CurrencyConverter.init`) y que llegan mientras el test mide.
    ///
    /// La memoria se retira con CUALQUIER guardado de CUALQUIER contexto del proceso, a propósito, y el proceso de los
    /// tests es la app anfitriona: un guardado suyo en otro hilo cae dentro de la ventana y obliga a releer. Eso es el
    /// diseño, no un fallo, pero rompía las aserciones de «no vuelve a leer» y «sigue lo leído» (rojo 3/3 en el CI del
    /// 2026-11-06, verde en local). Con esto, la ventana que se ensucia se repite, y si no sale ninguna limpia el rojo
    /// dice qué aviso la ensució.
    private final class ForeignDropRecorder: @unchecked Sendable {
        private let seen = OSAllocatedUnfairLock<[String]>(initialState: [])
        private var observers: [NSObjectProtocol] = []

        init() {
            let seen = self.seen
            let center = NotificationCenter.default
            for name in [Notification.Name.yalaExchangeRatesUpdated, .NSPersistentStoreRemoteChange, ModelContext.didSave] {
                observers.append(center.addObserver(forName: name, object: nil, queue: nil) { note in
                    let source = note.object.map { String(describing: type(of: $0)) } ?? "nil"
                    let thread = Thread.isMainThread ? "principal" : "otro hilo"
                    seen.withLock { $0.append("\(note.name.rawValue) · \(source) · \(thread)") }
                })
            }
        }

        /// Deja de escuchar y devuelve lo que llegó.
        func stop() -> [String] {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers = []
            return seen.withLock { $0 }
        }

        deinit { for observer in observers { NotificationCenter.default.removeObserver(observer) } }
    }

    private static let cleanWindowAttempts = 5

    /// Corre `measure` hasta que una pasada no oiga ningún aviso ajeno, y devuelve lo que midió esa pasada. Si las
    /// `cleanWindowAttempts` se ensucian, registra el rojo con lo que oyó y devuelve `nil`. `prepare` corre antes de
    /// escuchar en cada intento: el `save()` del propio fixture también avisa, y no es ajeno.
    private func inACleanWindow<P, T>(prepare: () throws -> P, measure: (P) throws -> T) throws -> T? {
        var heard: [[String]] = []
        for _ in 0..<Self.cleanWindowAttempts {
            let prepared = try prepare()
            let recorder = ForeignDropRecorder()
            let measured = try measure(prepared)
            let foreign = recorder.stop()
            if foreign.isEmpty { return measured }
            heard.append(foreign)
        }
        Issue.record("Ninguna de \(Self.cleanWindowAttempts) pasadas salió sin avisos ajenos que retiran la memoria: \(heard)")
        return nil
    }

    // MARK: - El ahorro

    @Test func manyConversionsOfTheSameDay_readTheRowsOnce() throws {
        let context = try makeContext()
        // Falta PEN en la fila del día: cada conversión baja también al escalón de las filas anteriores.
        try insertRow(["USD": 1, "EUR": 0.9], on: day, into: context)
        try insertRow(["USD": 1, "EUR": 0.9, "PEN": 3.7], on: day.addingTimeInterval(-86_400), into: context)
        try context.save()

        let window = try inACleanWindow(prepare: {}) {
            let converter = CurrencyConverter()
            let first = converter.convertChecked(100, from: "EUR", to: "PEN", on: day, context: context)
            let afterFirst = converter._testRateRowFetches
            for _ in 0..<50 {
                let again = converter.convertChecked(100, from: "EUR", to: "PEN", on: day, context: context)
                #expect(again.amount == first.amount)
                #expect(again.quality == first.quality)
            }
            return (first: first, afterFirst: afterFirst, afterAll: converter._testRateRowFetches)
        }
        guard let window else { return }
        #expect(window.afterFirst == 2, "La primera conversión lee la fila del día y las anteriores.")
        #expect(window.afterAll == window.afterFirst, "Las 50 siguientes no vuelven a leer.")
        #expect(window.first.quality == .carriedForward(fromDateKey: Self.dateFormatter.string(from: day.addingTimeInterval(-86_400))))
    }

    @Test func memoAgreesWithAFreshConverter_onEveryRung() throws {
        let context = try makeContext()
        try insertRow(["USD": 1, "EUR": 0.9, "JPY": 0], on: day, into: context)        // JPY inservible
        try insertRow(["USD": 1, "PEN": 3.7], on: day.addingTimeInterval(-86_400), into: context)
        try context.save()

        let warm = CurrencyConverter()
        let pairs: [(String, String)] = [("EUR", "USD"), ("EUR", "PEN"), ("JPY", "EUR"), ("CHF", "EUR"), ("USD", "USD")]
        for _ in 0..<2 {
            for (from, to) in pairs {
                let memo = warm.convertChecked(1_000, from: from, to: to, on: day, context: context)
                let fresh = CurrencyConverter().convertChecked(1_000, from: from, to: to, on: day, context: context)
                #expect(memo.amount == fresh.amount, "\(from)→\(to)")
                #expect(memo.quality == fresh.quality, "\(from)→\(to)")
            }
        }
    }

    // MARK: - Lo que la retira

    @Test func aSaveThatWritesABetterRow_isSeenInTheSamePass() throws {
        let context = try makeContext()
        try insertRow(["USD": 1, "EUR": 0.9], on: day, into: context)
        try context.save()

        let converter = CurrencyConverter()
        let before = converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context)
        #expect(before.quality == .staticFallback)

        // Llega la fila completa del día (lo que haría el pull del Modo Nube o el espejo, sin notificación).
        let rows = try context.fetch(FetchDescriptor<ExchangeRate>())
        for row in rows { context.delete(row) }
        try insertRow(["USD": 1, "EUR": 0.9, "PEN": 4], on: day, into: context)
        try context.save()

        let after = converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context)
        #expect(after.quality == .exact)
        #expect(after.amount == 400)
    }

    /// Lee la fila a 3, la cambia a 4 SIN guardar y vuelve a convertir: el control de que, dentro de la pasada y sin
    /// guardado ni aviso, sigue lo leído. Cada intento con su store, para que el siguiente parta otra vez de 3.
    private func readThenChangeWithoutSaving() throws -> (converter: CurrencyConverter, context: ModelContext, control: Decimal)? {
        try inACleanWindow(prepare: {
            let context = try makeContext()
            let row = try insertRow(["USD": 1, "PEN": 3], on: day, into: context)
            try context.save()
            return (context, row)
        }) { context, row in
            let converter = CurrencyConverter()
            #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 300)
            row.rates = try JSONEncoder().encode(["USD": 1.0, "PEN": 4.0])
            let control = converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount
            return (converter, context, control)
        }
    }

    @Test func theRatesNotification_dropsWhatWasRead() throws {
        // Cambio SIN guardar: solo la notificación puede retirar lo leído.
        guard let (converter, context, control) = try readThenChangeWithoutSaving() else { return }
        #expect(control == 300, "Control: dentro de la pasada, sin guardado ni aviso, sigue lo leído.")

        NotificationCenter.default.post(name: .yalaExchangeRatesUpdated, object: nil)
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 400)
    }

    @Test func anotherContext_doesNotReadTheFirstOnesRows() throws {
        let first = try makeContext()
        try insertRow(["USD": 1, "PEN": 3], on: day, into: first)
        try first.save()
        let second = try makeContext()
        try insertRow(["USD": 1, "PEN": 4], on: day, into: second)
        try second.save()

        let converter = CurrencyConverter()
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: first).amount == 300)
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: second).amount == 400)
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: first).amount == 300)
    }

    @Test func theNextTurnOfTheMainActor_readsAgain() async throws {
        let context = try makeContext()
        let row = try insertRow(["USD": 1, "PEN": 3], on: day, into: context)
        try context.save()

        let converter = CurrencyConverter()
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 300)

        // Cambio que no avisa por ningún lado (como un import del espejo que aún no notificó): vale en la vuelta siguiente.
        row.rates = try JSONEncoder().encode(["USD": 1.0, "PEN": 4.0])
        var seen: Decimal = 0
        for _ in 0..<20 {
            await Task.yield()
            seen = converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount
            if seen == 400 { break }
        }
        #expect(seen == 400)
    }

    @Test func aRemoteStoreChange_dropsWhatWasRead() throws {
        guard let (converter, context, control) = try readThenChangeWithoutSaving() else { return }
        #expect(control == 300, "Control: dentro de la pasada, sin guardado ni aviso, sigue lo leído.")

        // Lo que postea Core Data cuando el espejo de iCloud importa (sin pasar por `ModelContext.didSave` aquí).
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        #expect(converter.convertChecked(100, from: "USD", to: "PEN", on: day, context: context).amount == 400)
    }
}
