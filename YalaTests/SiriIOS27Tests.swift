//
//  SiriIOS27Tests.swift
//  YalaTests
//
//  Card «Integrar Yala con el nuevo Siri con IA de iOS 27» (2.2) y sus dos hermanas:
//  · Preguntas a Siri sin abrir la app: «¿cuánto gasté?» y «¿cuánto tengo?» (`SiriFinanceAnswer`, `SiriFinanceSnapshot`).
//  · «Abrir cuenta» con el esquema `.system.open` (iOS 27) y el enlace `accounts/<shortcutID>`.
//  · Las frases de Siri en portugués existen de verdad (`AppShortcuts.xcstrings`), medido en lo que Siri entrena.
//  · Los errores y la pregunta de «Anotar con Siri» se resuelven en la app, no por el sistema (salían en inglés).
//

import Foundation
import Testing
@testable import Yala

private enum SiriRepo {
    static func text(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    /// Sin líneas de comentario: documentar lo que el test prohíbe no puede ponerlo en rojo.
    static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    static func string(_ key: String, lang: String) throws -> String? {
        let source = try text("Yala/Resources/\(lang).lproj/Localizable.strings")
        for line in source.split(separator: "\n") where line.hasPrefix("\"\(key)\" = \"") {
            var value = line.dropFirst("\"\(key)\" = \"".count)
            guard value.hasSuffix("\";") else { continue }
            value = value.dropLast(2)
            return value.replacingOccurrences(of: "\\\"", with: "\"")
        }
        return nil
    }

    static let languages = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                            "pt", "pt-BR", "pt-PT", "zh-Hans"]

    /// El bundle de un idioma de la app, para traducir en un test sin cambiar el idioma del proceso.
    static func bundle(_ lang: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: lang, ofType: "lproj"), "La app no trae \(lang).lproj")
        return try #require(Bundle(path: path))
    }

    static func metadataURL() throws -> URL {
        try #require(Bundle.main.url(forResource: "Metadata", withExtension: "appintents"),
                     "La app no trae Metadata.appintents: el test tiene que correr alojado en la app.")
    }
}

// MARK: - Fixtures

private enum SiriFixture {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima")!
        calendar.firstWeekday = 2
        return calendar
    }

    /// 18-oct-2026 15:00 en Lima.
    static let now: Date = {
        var components = DateComponents(year: 2026, month: 10, day: 18, hour: 15)
        components.timeZone = TimeZone(identifier: "America/Lima")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    static func period(_ period: SiriSpendingPeriod, at date: Date, expense: Double, approximate: Bool = false)
        -> SiriFinanceSnapshot.Period {
        let interval = period.detailPeriod.dateInterval(now: date, calendar: calendar)
        return .init(key: period.rawValue, start: interval.start, end: interval.end, expense: expense,
                     expenseIsApproximate: approximate)
    }

    static func snapshot(builtAt: Date = now, monthExpense: Double = 1234.5, approximate: Bool = false)
        -> SiriFinanceSnapshot {
        SiriFinanceSnapshot(
            version: SiriFinanceSnapshot.currentVersion,
            builtAt: builtAt,
            preferredCurrencyCode: "PEN",
            totalBalance: 5000,
            totalBalanceIsApproximate: false,
            periods: SiriSpendingPeriod.allCases.map { p in
                period(p, at: builtAt, expense: p == .thisMonth ? monthExpense : 10, approximate: approximate)
            },
            accounts: [
                .init(id: "A1", name: "BCP Ahorros", lines: [.init(currencyCode: "PEN", balance: 3000)]),
                .init(id: "A2", name: "Visa", lines: [.init(currencyCode: "PEN", balance: -200),
                                                      .init(currencyCode: "USD", balance: -40)])
            ]
        )
    }

    static func summary(expense: Double, expenseApproximate: Bool?, balanceApproximate: Bool? = nil) -> WidgetPeriodSummary {
        WidgetPeriodSummary(
            totalIncome: 0, totalExpense: expense, netCashFlow: -expense,
            topCategories: [], topSubcategories: [], cashFlowPoints: [],
            periodBalance: nil,
            incomeIsApproximate: nil, expenseIsApproximate: expenseApproximate,
            netCashFlowIsApproximate: nil, periodBalanceIsApproximate: balanceApproximate
        )
    }

    static func widget(summaries: [String: WidgetPeriodSummary], total: Double = 900,
                       allTime: WidgetPeriodSummary? = nil) -> WidgetDataSnapshot {
        WidgetDataSnapshot(
            lastUpdated: now, preferredCurrencyCode: "PEN", currencyDisplayFormat: "symbol",
            accountBalances: [], totalBalance: total, transactions: [], budgets: [], scheduledPayments: [],
            trendData: WidgetTrendData(dailyPoints: [], weeklyPoints: [], monthlyPoints: []),
            thisMonthSummary: summaries["thisMonth"] ?? summary(expense: 0, expenseApproximate: nil),
            allTimeSummary: allTime ?? summary(expense: 0, expenseApproximate: nil),
            periodSummaries: summaries
        )
    }

    static func account(_ id: UUID, parent: UUID? = nil, currency: String = "PEN", name: String,
                        archived: Bool = false, system: Bool = false, excluded: Bool = false,
                        balance: Double = 0) -> SiriAccountInput {
        SiriAccountInput(
            node: AccountLineNode(id: id, parentID: parent, currencyCode: currency, isArchived: archived, isSystem: system),
            name: name, excludedFromStatistics: excluded, nativeBalance: balance
        )
    }
}

// MARK: - Qué contesta

@Suite("Siri iOS 27 · lo que contesta «¿cuánto gasté?» y «¿cuánto tengo?»")
@MainActor
struct SiriFinanceAnswerTests {

    let calendar = SiriFixture.calendar
    let now = SiriFixture.now

    @Test func sinFoto_pideAbrirYala_nuncaUnCero() {
        #expect(SiriFinanceAnswerLogic.spending(snapshot: nil, groupsOnly: false, period: .thisMonth,
                                                now: now, calendar: calendar) == .noData)
        #expect(SiriFinanceAnswerLogic.balance(snapshot: nil, groupsOnly: false, expensesOnly: false, accountID: nil,
                                               now: now, calendar: calendar) == .noData)
    }

    @Test func soloGrupos_loDice_aunqueHayaFoto() {
        let snapshot = SiriFixture.snapshot()
        #expect(SiriFinanceAnswerLogic.spending(snapshot: snapshot, groupsOnly: true, period: .thisMonth,
                                                now: now, calendar: calendar) == .groupsOnly)
        #expect(SiriFinanceAnswerLogic.balance(snapshot: snapshot, groupsOnly: true, expensesOnly: false,
                                               accountID: "A1", now: now, calendar: calendar) == .groupsOnly)
    }

    @Test func fotoDeHoy_daElGastoDelMes_sinFecha() {
        let answer = SiriFinanceAnswerLogic.spending(snapshot: SiriFixture.snapshot(), groupsOnly: false,
                                                     period: .thisMonth, now: now, calendar: calendar)
        #expect(answer == .spending(period: .thisMonth, amount: 1234.5, currencyCode: "PEN", approximate: false, asOf: nil))
    }

    /// Una foto de ayer, del mismo mes, contesta y dice de cuándo es.
    @Test func fotoDeAyerDelMismoMes_contesta_yDiceDeCuandoEs() throws {
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let answer = SiriFinanceAnswerLogic.spending(snapshot: SiriFixture.snapshot(builtAt: yesterday), groupsOnly: false,
                                                     period: .thisMonth, now: now, calendar: calendar)
        #expect(answer == .spending(period: .thisMonth, amount: 1234.5, currencyCode: "PEN", approximate: false,
                                    asOf: yesterday))
    }

    /// El «este mes» de una foto de septiembre es septiembre: en octubre no se contesta con él.
    @Test func fotoDeOtroMes_noInventa() throws {
        let september = try #require(calendar.date(byAdding: .month, value: -1, to: now))
        let snapshot = SiriFixture.snapshot(builtAt: september)
        #expect(SiriFinanceAnswerLogic.spending(snapshot: snapshot, groupsOnly: false, period: .thisMonth,
                                                now: now, calendar: calendar) == .stale)
        // Y su «mes pasado» es agosto, no septiembre.
        #expect(SiriFinanceAnswerLogic.spending(snapshot: snapshot, groupsOnly: false, period: .lastMonth,
                                                now: now, calendar: calendar) == .stale)
        // El año sí es el mismo: contesta, con su fecha.
        guard case .spending(.thisYear, _, _, _, let asOf) = SiriFinanceAnswerLogic.spending(
            snapshot: snapshot, groupsOnly: false, period: .thisYear, now: now, calendar: calendar) else {
            Issue.record("El año de la foto es el de ahora: tenía que contestar.")
            return
        }
        #expect(asOf == september)
    }

    @Test func gastoAproximado_loDice() {
        let answer = SiriFinanceAnswerLogic.spending(snapshot: SiriFixture.snapshot(approximate: true), groupsOnly: false,
                                                     period: .thisMonth, now: now, calendar: calendar)
        #expect(answer == .spending(period: .thisMonth, amount: 1234.5, currencyCode: "PEN", approximate: true, asOf: nil))
    }

    @Test func saldoTotal_esElDeLaFoto() {
        #expect(SiriFinanceAnswerLogic.balance(snapshot: SiriFixture.snapshot(), groupsOnly: false, expensesOnly: false,
                                               accountID: nil, now: now, calendar: calendar)
                == .totalBalance(amount: 5000, currencyCode: "PEN", approximate: false, asOf: nil))
    }

    @Test func saldoDeUnaTarjetaConDosDivisas_dicelasDos() {
        let answer = SiriFinanceAnswerLogic.balance(snapshot: SiriFixture.snapshot(), groupsOnly: false, expensesOnly: false,
                                                    accountID: "A2", now: now, calendar: calendar)
        #expect(answer == .accountBalance(name: "Visa", lines: [.init(currencyCode: "PEN", balance: -200),
                                                                .init(currencyCode: "USD", balance: -40)], asOf: nil))
    }

    @Test func cuentaQueYaNoEsta_loDice() {
        #expect(SiriFinanceAnswerLogic.balance(snapshot: SiriFixture.snapshot(), groupsOnly: false, expensesOnly: false,
                                               accountID: "borrada", now: now, calendar: calendar) == .accountNotFound)
    }

    /// En solo gastos el Panel no enseña saldos sino lo gastado: Siri dice lo mismo, también si se pidió una cuenta.
    @Test func soloGastos_contestaLoGastadoEsteMes() {
        let expected = SiriFinanceAnswer.expensesOnlySpending(amount: 1234.5, currencyCode: "PEN", approximate: false, asOf: nil)
        #expect(SiriFinanceAnswerLogic.balance(snapshot: SiriFixture.snapshot(), groupsOnly: false, expensesOnly: true,
                                               accountID: nil, now: now, calendar: calendar) == expected)
        #expect(SiriFinanceAnswerLogic.balance(snapshot: SiriFixture.snapshot(), groupsOnly: false, expensesOnly: true,
                                               accountID: "A1", now: now, calendar: calendar) == expected)
    }

    @Test func soloGastosConFotoDeOtroMes_noInventa() throws {
        let september = try #require(calendar.date(byAdding: .month, value: -1, to: now))
        #expect(SiriFinanceAnswerLogic.balance(snapshot: SiriFixture.snapshot(builtAt: september), groupsOnly: false,
                                               expensesOnly: true, accountID: nil, now: now, calendar: calendar) == .stale)
    }
}

// MARK: - La foto

@Suite("Siri iOS 27 · la foto que leen las preguntas")
@MainActor
struct SiriFinanceSnapshotBuilderTests {

    /// Las tarjetas del Panel: la línea en dólares va dentro de su tarjeta; archivadas, de sistema y excluidas, fuera.
    @Test func cuentas_comoLasTarjetasDelPanel() {
        let visa = UUID(), visaUSD = UUID(), ahorros = UUID(), archivada = UUID(), sistema = UUID(), excluida = UUID()
        let cards = SiriFinanceSnapshotBuilder.cards(from: [
            SiriFixture.account(visa, name: "Visa", balance: -200),
            SiriFixture.account(visaUSD, parent: visa, currency: "USD", name: "Visa · USD", balance: -40),
            SiriFixture.account(ahorros, name: "Ahorros", balance: 3000),
            SiriFixture.account(archivada, name: "Vieja", archived: true, balance: 5),
            SiriFixture.account(sistema, name: "Grupos", system: true, balance: 7),
            SiriFixture.account(excluida, name: "Inversión", excluded: true, balance: 9)
        ])
        #expect(cards.map(\.name) == ["Visa", "Ahorros"])
        #expect(cards.first?.id == visa.uuidString)
        #expect(cards.first?.lines == [.init(currencyCode: "PEN", balance: -200), .init(currencyCode: "USD", balance: -40)])
    }

    /// Una línea cuya principal está archivada se lee suelta (la regla de `AccountLineLogic`).
    @Test func lineaDeUnaPrincipalArchivada_saleSuelta() {
        let principal = UUID(), linea = UUID()
        let cards = SiriFinanceSnapshotBuilder.cards(from: [
            SiriFixture.account(principal, name: "Visa", archived: true),
            SiriFixture.account(linea, parent: principal, currency: "USD", name: "Visa · USD", balance: -40)
        ])
        #expect(cards.map(\.name) == ["Visa · USD"])
    }

    /// Los totales salen del snapshot de los widgets: Siri y el widget dicen lo mismo. Y cada período lleva su inicio.
    @Test func periodos_salenDeLosWidgets_conSuInicio() throws {
        let calendar = SiriFixture.calendar
        let widget = SiriFixture.widget(
            summaries: [
                "thisWeek": SiriFixture.summary(expense: 50, expenseApproximate: nil),
                "thisMonth": SiriFixture.summary(expense: 700, expenseApproximate: true),
                "lastMonth": SiriFixture.summary(expense: 900, expenseApproximate: false),
                "thisYear": SiriFixture.summary(expense: 8000, expenseApproximate: nil),
                "last7Days": SiriFixture.summary(expense: 1, expenseApproximate: nil)
            ],
            total: 4321,
            allTime: SiriFixture.summary(expense: 0, expenseApproximate: nil, balanceApproximate: true)
        )
        let snapshot = SiriFinanceSnapshotBuilder.make(widget: widget, accounts: [], now: SiriFixture.now, calendar: calendar)

        #expect(snapshot.periods.map(\.key) == ["thisWeek", "thisMonth", "lastMonth", "thisYear"])
        let month = try #require(snapshot.period("thisMonth"))
        #expect(month.expense == 700)
        #expect(month.expenseIsApproximate)
        #expect(month.start == DetailPeriod.thisMonth.dateInterval(now: SiriFixture.now, calendar: calendar).start)
        #expect(snapshot.period("lastMonth")?.expenseIsApproximate == false)
        #expect(snapshot.totalBalance == 4321)
        #expect(snapshot.totalBalanceIsApproximate)
        #expect(snapshot.builtAt == SiriFixture.now)
        #expect(snapshot.preferredCurrencyCode == "PEN")
    }
}

@Suite("Siri iOS 27 · la foto vive y muere con la de los widgets", .serialized)
@MainActor
struct SiriFinanceSnapshotStoreTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test func seGuardaYSeLee() {
        let defaults = makeDefaults()
        let snapshot = SiriFixture.snapshot()
        SiriFinanceSnapshotStore.write(snapshot, to: defaults)
        #expect(SiriFinanceSnapshotStore.read(from: defaults) == snapshot)
    }

    /// Lo que borra la caché de los widgets (cerrar sesión, vaciar datos) se lleva también la de Siri.
    @Test func clearCacheDeLosWidgets_seLlevaLaDeSiri() {
        let defaults = makeDefaults()
        SiriFinanceSnapshotStore.write(SiriFixture.snapshot(), to: defaults)
        WidgetDataCache.clearCache(in: defaults)
        #expect(SiriFinanceSnapshotStore.read(from: defaults) == nil)
    }

    @Test func otraVersionOLaBasura_seLeenComoSinFoto() throws {
        let defaults = makeDefaults()
        defaults.set(Data("no es json".utf8), forKey: SiriFinanceSnapshot.storageKey)
        #expect(SiriFinanceSnapshotStore.read(from: defaults) == nil)

        let base = SiriFixture.snapshot()
        let future = SiriFinanceSnapshot(version: SiriFinanceSnapshot.currentVersion + 1, builtAt: base.builtAt,
                                         preferredCurrencyCode: "PEN", totalBalance: 1, totalBalanceIsApproximate: false,
                                         periods: [], accounts: [])
        defaults.set(try JSONEncoder().encode(future), forKey: SiriFinanceSnapshot.storageKey)
        #expect(SiriFinanceSnapshotStore.read(from: defaults) == nil)
    }

    /// Una clave PROPIA: nunca la del snapshot de los widgets, cuyo decode es todo o nada.
    @Test func laClaveNoEsLaDeLosWidgets() {
        #expect(SiriFinanceSnapshot.storageKey != WidgetDataCache.cacheKey)
    }

    /// El escritor y el borrador son los de los widgets: `updateCache` la escribe y `clearCache` la borra.
    @Test func cableado_updateCacheEscribe_clearCacheBorra() throws {
        let source = SiriRepo.codeOnly(try SiriRepo.text("Yala/Services/WidgetDataCache.swift"))
        #expect(source.contains("SiriFinanceSnapshotStore.write(built.siri, to: sharedDefaults)"))
        #expect(source.contains("SiriFinanceSnapshotStore.clear(in: defaults)"))
        // Un solo «ahora» para los períodos de los widgets y la foto de Siri.
        #expect(source.contains("period.dateInterval(now: periodsNow)"))
        #expect(source.contains("now: periodsNow,"))
    }
}

// MARK: - Cómo suena

@Suite("Siri iOS 27 · lo que se oye, en el idioma del iPhone")
@MainActor
struct SiriFinanceSpeechTests {

    static let keys = ["siri.query.noData", "siri.query.groupsOnly", "siri.query.stale", "siri.query.accountNotFound",
                       "siri.query.approximate", "siri.query.asOf", "siri.query.spending.thisWeek",
                       "siri.query.spending.thisMonth", "siri.query.spending.lastMonth", "siri.query.spending.thisYear",
                       "siri.query.balance.total", "siri.query.balance.account", "siri.query.balance.expensesOnly",
                       "siri.query.period.thisWeek", "siri.query.period.thisMonth", "siri.query.period.lastMonth",
                       "siri.query.period.thisYear", "siri.query.period.type", "siri.query.param.period",
                       "siri.query.param.account", "siri.entity.account",
                       "shortcut.spending.title", "shortcut.spending.description", "shortcut.spending.shortTitle",
                       "shortcut.balance.title", "shortcut.balance.description", "shortcut.balance.shortTitle",
                       "shortcut.openAccount.title", "shortcut.openAccount.description"]

    private static func placeholders(_ value: String) -> [String] {
        let regex = /%(\d\$)?@/
        return value.matches(of: regex).map { String($0.output.0) }
    }

    /// Cada texto, en los 16 idiomas y con los mismos huecos que en español.
    @Test(arguments: SiriRepo.languages)
    func todasLasClaves_enCadaIdioma_conSusHuecos(_ lang: String) throws {
        for key in Self.keys {
            let value = try #require(try SiriRepo.string(key, lang: lang), "Falta \(key) en \(lang).")
            let reference = try #require(try SiriRepo.string(key, lang: "es"))
            #expect(Self.placeholders(value).count == Self.placeholders(reference).count,
                    "\(lang) · \(key): «\(value)» no tiene los huecos de «\(reference)».")
            #expect(!value.localizedCaseInsensitiveContains("openai"), "\(lang) · \(key) nombra al proveedor de IA.")
        }
    }

    private func render(_ answer: SiriFinanceAnswer, lang: String) throws -> String {
        let bundle = try SiriRepo.bundle(lang)
        return SiriFinanceSpeech.text(
            for: answer,
            localize: { bundle.localizedString(forKey: $0, value: "⚠️\($0)", table: nil) },
            currency: { value, code in "\(code) \(String(format: "%.2f", value))" },
            date: { _ in "17 oct" },
            list: { $0.joined(separator: " + ") }
        )
    }

    @Test func gastoDelMes_enEspanol() throws {
        let text = try render(.spending(period: .thisMonth, amount: -120, currencyCode: "PEN", approximate: false, asOf: nil),
                              lang: "es")
        #expect(text == "Este mes llevas gastado PEN 120.00.")
    }

    @Test func gastoAproximadoYDeAyer_dicenLasDosCosas() throws {
        let text = try render(.spending(period: .lastMonth, amount: 90, currencyCode: "PEN", approximate: true,
                                        asOf: SiriFixture.now), lang: "es")
        #expect(text == "El mes pasado gastaste PEN 90.00. Es aproximado: falta confirmar algún tipo de cambio. "
                + "Según tus datos del 17 oct.")
    }

    @Test func saldoDeUnaTarjeta_enPortugues() throws {
        let text = try render(.accountBalance(name: "Visa", lines: [.init(currencyCode: "BRL", balance: -200),
                                                                    .init(currencyCode: "USD", balance: -40)], asOf: nil),
                              lang: "pt-BR")
        #expect(text == "Saldo de Visa: BRL -200.00 + USD -40.00.")
    }

    /// Ninguna respuesta se queda en la clave.
    @Test(arguments: SiriRepo.languages)
    func ningunaRespuesta_dejaLaClave(_ lang: String) throws {
        let answers: [SiriFinanceAnswer] = [
            .noData, .groupsOnly, .stale, .accountNotFound,
            .spending(period: .thisWeek, amount: 1, currencyCode: "PEN", approximate: true, asOf: SiriFixture.now),
            .spending(period: .thisYear, amount: 1, currencyCode: "PEN", approximate: false, asOf: nil),
            .totalBalance(amount: 1, currencyCode: "PEN", approximate: true, asOf: nil),
            .accountBalance(name: "A", lines: [.init(currencyCode: "PEN", balance: 1)], asOf: SiriFixture.now),
            .expensesOnlySpending(amount: 1, currencyCode: "PEN", approximate: false, asOf: nil)
        ]
        for answer in answers {
            let text = try render(answer, lang: lang)
            #expect(!text.contains("⚠️") && !text.contains("siri.query"), "\(lang): «\(text)»")
        }
    }
}

// MARK: - Errores de «Anotar con Siri»

@Suite("Siri · las respuestas de Yala se resuelven en la app (salían en inglés con el iPhone en español)")
struct IntentSpeechTests {

    static let intentFiles = ["Yala/App/Intents/QuickExpenseIntent.swift", "Yala/App/Intents/SiriQueryIntents.swift",
                              "Yala/App/Intents/AppShortcutsProvider.swift", "Yala/Shared/ControlCenterIntents.swift"]

    /// `.result(dialog: "clave")` y `requestValue("clave")` dejan la clave al sistema, que la resolvía en inglés.
    @Test(arguments: intentFiles)
    func ningunaClaveLiteral_enUnDialogoNiEnUnaPregunta(_ path: String) throws {
        let source = SiriRepo.codeOnly(try SiriRepo.text(path))
        #expect(!source.contains("dialog: \""), "\(path): un `dialog:` con clave literal.")
        #expect(!source.contains("requestValue(\""), "\(path): una pregunta con clave literal.")
        if !path.hasSuffix("SiriQueryIntents.swift") {
            #expect(!source.contains("IntentDialog(stringLiteral:"), "\(path): un `IntentDialog` fuera de `IntentSpeech`.")
        }
    }

    /// Las cuatro respuestas de error y la pregunta pasan por `IntentSpeech`.
    @Test func lasCuatroRespuestasYLaPregunta_vanPorIntentSpeech() throws {
        let source = SiriRepo.codeOnly(try SiriRepo.text("Yala/App/Intents/QuickExpenseIntent.swift"))
        for key in ["shortcut.siriNatural.error.noText", "shortcut.siriNatural.error.proRequired",
                    "shortcut.error.noAccount", "shortcut.siriNatural.error.parsingFailedHelp"] {
            #expect(source.contains("dialog: IntentSpeech.dialog(\"\(key)\")"), "\(key) no pasa por IntentSpeech.")
        }
        #expect(source.contains("$text.requestValue(IntentSpeech.dialog(\"shortcut.siriNatural.dialog.askText\"))"))
    }

    /// Con el iPhone en español, esos textos salen en español (y no son el inglés).
    @Test(arguments: ["es", "es-419", "es-ES", "es-AR", "pt-BR"])
    func lasRespuestasExistenEnEseIdioma(_ lang: String) throws {
        let bundle = try SiriRepo.bundle(lang)
        let english = try SiriRepo.bundle("en")
        for key in ["shortcut.siriNatural.error.noText", "shortcut.siriNatural.error.proRequired",
                    "shortcut.error.noAccount", "shortcut.siriNatural.error.parsingFailedHelp",
                    "shortcut.siriNatural.dialog.askText"] {
            let value = bundle.localizedString(forKey: key, value: "⚠️", table: nil)
            #expect(value != "⚠️" && value != key, "\(lang): falta \(key)")
            #expect(value != english.localizedString(forKey: key, value: nil, table: nil), "\(lang) · \(key) sale en inglés")
        }
    }
}

// MARK: - Frases de Siri en portugués

/// Lo que Siri entrena por idioma: las frases de cada `AppShortcut` del código (las CLAVES) y, donde el bundle trae
/// `<idioma>.lproj/AppShortcuts.strings` (compilado de `AppShortcuts.xcstrings`), sus traducciones.
///
/// Medido en el bundle el 2026-10-18 (`Metadata.appintents/root.ssu.yaml`, lo que entrena Siri): un idioma con ese
/// fichero entrena SOLO las frases traducidas; uno sin él, las claves tal cual. El `.yaml` no sirve de oráculo: un build
/// incremental regenera `Metadata.appintents` sin volver a entrenar y lo deja fuera (medido ese mismo día).
private enum SiriTraining {
    /// Acción («SiriNaturalEntryIntent») → sus frases tal como están en `AppShortcutsProvider`, con
    /// `${applicationName}` y `${period}` como en la clave compilada.
    static func keysByIntent() throws -> [String: [String]] {
        let source = SiriRepo.codeOnly(try SiriRepo.text("Yala/App/Intents/AppShortcutsProvider.swift"))
        var result: [String: [String]] = [:]
        var intent: String?
        for raw in source.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("intent: "), let name = line.dropFirst("intent: ".count).split(separator: "(").first {
                intent = String(name)
            } else if let intent, line.hasPrefix("\""), line.contains("\\(.applicationName)") {
                var phrase = line.trimmingCharacters(in: CharacterSet(charactersIn: "\","))
                phrase = phrase.replacingOccurrences(of: "\\(.applicationName)", with: "${applicationName}")
                    .replacingOccurrences(of: "\\(\\.$period)", with: "${period}")
                result[intent, default: []].append(phrase)
            }
        }
        return result
    }

    /// Las frases de `intent` que Siri entrena en `lang`, con «Yala» en el sitio del nombre de la app.
    static func phrases(_ intent: String, lang: String) throws -> [String] {
        let keys = try #require(try keysByIntent()[intent], "\(intent) no está en AppShortcutsProvider.")
        let trained: [String]
        if let table = translations(lang) {
            trained = keys.compactMap { table[$0] }
        } else {
            trained = keys
        }
        return trained.map { $0.replacingOccurrences(of: "${applicationName}", with: "Yala") }
    }

    /// El `AppShortcuts.strings` compilado de ese idioma, o `nil` si el bundle no lo trae.
    static func translations(_ lang: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: "AppShortcuts", ofType: "strings", inDirectory: nil,
                                          forLocalization: lang),
              URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent == "\(lang).lproj" else { return nil }
        return NSDictionary(contentsOfFile: path) as? [String: String]
    }

    static func quoted(_ value: String) -> String {
        let parts = value.split(separator: "\"", omittingEmptySubsequences: false)
        return parts.count >= 3 ? String(parts[1]) : value
    }
}

@Suite("Siri · las frases que la app enseña en portugués existen en Siri")
struct SiriPhrasesPortugueseTests {

    /// Cada frase que enseña la app (Ajustes › Siri y Atajos y el consejo de Siri), con la acción a la que va.
    static let shown: [(key: String, intent: String)] = [
        ("siriShortcuts.siri.phrase", "SiriNaturalEntryIntent"),
        ("siriShortcuts.siri.alt1", "SiriNaturalEntryIntent"),
        ("siriShortcuts.siri.alt2", "SiriNaturalEntryIntent"),
        ("tips.siri.detail", "SiriNaturalEntryIntent"),
        ("siriShortcuts.phrase.quick", "QuickExpenseIntent"),
        ("siriShortcuts.phrase.voice", "VoiceEntryIntent"),
        ("siriShortcuts.phrase.image", "ImageEntryIntent"),
        ("siriShortcuts.phrase.applePay", "ApplePayTransactionIntent")
    ]

    @Test(arguments: ["pt", "pt-BR", "pt-PT"])
    func cadaFraseQueEnsenaLaApp_laEntrenaSiri(_ lang: String) throws {
        #expect(SiriTraining.translations(lang) != nil, "La app no trae \(lang).lproj/AppShortcuts.strings.")
        for (key, intent) in Self.shown {
            let value = try #require(try SiriRepo.string(key, lang: lang), "Falta \(key) en \(lang).")
            let phrase = SiriTraining.quoted(value)
            let trained = try SiriTraining.phrases(intent, lang: lang)
            #expect(trained.contains(phrase), "\(lang) · \(key): la app enseña «\(phrase)» y Siri entrena \(trained).")
        }
    }

    /// Cada traducción del catálogo es de una frase que existe en el código: una clave huérfana no se entrena nunca.
    @Test(arguments: ["pt", "pt-BR", "pt-PT"])
    func cadaTraduccion_esDeUnaFraseDelCodigo(_ lang: String) throws {
        let keys = Set(try SiriTraining.keysByIntent().values.flatMap { $0 })
        let table = try #require(SiriTraining.translations(lang))
        for key in table.keys { #expect(keys.contains(key), "\(lang): «\(key)» no es una frase de AppShortcutsProvider.") }
    }

    /// Las preguntas nuevas también se pueden decir en portugués.
    @Test(arguments: ["pt", "pt-BR", "pt-PT"])
    func lasPreguntas_tienenFraseEnPortugues(_ lang: String) throws {
        #expect(try SiriTraining.phrases("SpendingQueryIntent", lang: lang).contains("Quanto gastei no Yala"))
        #expect(try SiriTraining.phrases("BalanceQueryIntent", lang: lang).contains("Quanto tenho no Yala"))
    }

    /// El catálogo no cambia lo que entrena el resto: en español, inglés y los siete idiomas de L15-5 siguen las frases
    /// del código (español e inglés), como antes de este cambio.
    @Test(arguments: ["es", "es-419", "en", "de", "fr", "it", "ja", "nl", "pl", "zh-Hans"])
    func losDemasIdiomas_siguenConLasFrasesDelCodigo(_ lang: String) throws {
        #expect(SiriTraining.translations(lang) == nil, "\(lang) trae AppShortcuts.strings: dejaría de entrenar las frases del código.")
        let natural = try SiriTraining.phrases("SiriNaturalEntryIntent", lang: lang)
        #expect(natural.contains("Anota un gasto en Yala") && natural.contains("Note an expense in Yala"),
                "\(lang): \(natural)")
    }
}

// MARK: - Metadatos de las acciones nuevas

@Suite("Siri iOS 27 · cómo se declaran las acciones nuevas")
struct SiriQueryMetadataTests {

    private func actions() throws -> [String: Any] {
        let data = try Data(contentsOf: try SiriRepo.metadataURL().appending(path: "extract.actionsdata"))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(json["actions"] as? [String: Any])
    }

    /// Las preguntas dicen importes en voz alta: piden el iPhone desbloqueado y no abren la app.
    @Test(arguments: ["SpendingQueryIntent", "BalanceQueryIntent"])
    func lasPreguntas_pidenDesbloquear_yNoAbrenLaApp(_ name: String) throws {
        let action = try #require(try actions()[name] as? [String: Any], "\(name) no está en los metadatos.")
        // 1 = `requiresAuthentication` (0 sería `alwaysAllowed`).
        #expect(action["authenticationPolicy"] as? Int == 1)
        #expect(action["openAppWhenRun"] as? Bool == false)
    }

    /// «Abrir cuenta» adopta el esquema de sistema `open`, solo en iOS 27 (y solo se compila con el SDK de iOS 27).
    #if compiler(>=6.3)
    @Test func abrirCuenta_adoptaElEsquemaDeSistema_soloEnIOS27() throws {
        let action = try #require(try actions()["OpenAccountIntent"] as? [String: Any])
        let schemas = try #require(action["assistantDefinedSchemas"] as? [[String: Any]])
        #expect(schemas.contains { $0["domain"] as? String == "system" && $0["name"] as? String == "OpenIntent" })
        let availability = try #require(action["availabilityAnnotations"] as? [String: [String: String]])
        #expect(availability["LNPlatformNameIOS"]?["introducedVersion"] == "27.0")
    }
    #endif
}

// MARK: - Cuentas

@Suite("Siri iOS 27 · encontrar y abrir una cuenta")
struct SiriAccountTests {

    let accounts: [SiriFinanceSnapshot.Account] = [
        .init(id: "1", name: "BCP Ahorros", lines: []),
        .init(id: "2", name: "Visa Interbank", lines: []),
        .init(id: "3", name: "Visa", lines: [])
    ]

    @Test func porPalabra_sinTildesNiMayusculas() {
        #expect(SiriAccountMatching.matches("bcp", in: accounts).map(\.id) == ["1"])
        #expect(SiriAccountMatching.matches("ÁHORROS", in: accounts).map(\.id) == ["1"])
    }

    /// Si el nombre casa entero, gana ese: «Visa» no es «Visa Interbank».
    @Test func elNombreExacto_gana() {
        #expect(SiriAccountMatching.matches("visa", in: accounts).map(\.id) == ["3"])
        #expect(SiriAccountMatching.matches("interbank", in: accounts).map(\.id) == ["2"])
    }

    @Test func sinTexto_todas_yNadaQueCase_ninguna() {
        #expect(SiriAccountMatching.matches("  ", in: accounts).count == 3)
        #expect(SiriAccountMatching.matches("scotiabank", in: accounts).isEmpty)
    }

    /// `yala://accounts/<shortcutID>`, el enlace que la app ya sabe abrir (el del aviso de la tarjeta).
    @MainActor
    @Test func elEnlace_esElDelAvisoDeLaTarjeta() throws {
        let id = UUID()
        let url = try #require(SiriAccountDeepLink.url(forAccountID: id.uuidString))
        #expect(url.host == "accounts")
        #expect(AlertDeepLink.account.id(fromDeepLink: "accounts" + url.path) == id)
        #expect(SiriAccountDeepLink.url(forAccountID: "no-es-un-uuid") == nil)
    }

    /// La app entiende ese enlace: apunta la cuenta y navega al Panel, que abre su ficha.
    @Test func laAppEntiendeElEnlace() throws {
        let source = SiriRepo.codeOnly(try SiriRepo.text("Yala/App/AppBootstrapper.swift"))
        let range = try #require(source.range(of: "case \"accounts\":"))
        let body = source[range.upperBound...].prefix(400)
        #expect(body.contains("AlertDeepLinkTarget.account.request(accountID)"))
        #expect(body.contains("setOrDeferDeepLink(.panel)"))
    }
}
