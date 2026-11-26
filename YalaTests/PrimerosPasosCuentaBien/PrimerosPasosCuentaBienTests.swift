//
//  PrimerosPasosCuentaBienTests.swift
//  YalaTests
//
//  Primer lote de la observación del iPhone 14 (25-nov-2026): que cada paso de Primeros pasos cuente bien.
//  1. «Solo gastos» se hace de cero: el alta no crea la cuenta de gastos y el paso 1 no sale hecho.
//  2. La guía del primer registro no se salta «Tu cuenta ya está puesta» con una cuenta de dos monedas.
//  3. El widget de Pagos planificados enseña el próximo vencimiento aunque caiga el mes que viene.
//  4. Pasar las historias del paso 7 hasta «Terminar» deja el paso hecho.
//  5. «Ahora no» tras la intro de Grupos deja el paso 5 hecho, y el aviso ya no dice «lo viste al entrar».
//

import Foundation
import SwiftData
import Testing

@testable import Yala

/// Lee un fichero del repo sin comentarios, para los scans del cableado.
private enum CuentaBienSource {
    static func code(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: "\n")
    }

    static func strings(_ locale: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot.appending(path: "Yala/Resources/\(locale).lproj/Localizable.strings"), encoding: .utf8)
    }

    static let locales = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl", "pt",
                          "pt-BR", "pt-PT", "zh-Hans"]
}

// MARK: - 1 · «Solo gastos» de cero

@MainActor
@Suite("Primeros pasos cuenta bien · «Solo gastos» de cero", .serialized)
struct SoloGastosDeCeroTests {

    /// Con el bug, «Solo gastos» dejaba una cuenta («Gastos Soles») y el paso 1 salía hecho por `autoDetect`.
    @Test func theAlta_createsNoAccount_withExpensesOnly() throws {
        let context = try makeTestContext()
        WelcomeConversationCommit.writeStore(currency: .pen, tracking: .expensesOnly, context: context)
        #expect(try context.fetch(FetchDescriptor<Account>()).isEmpty)
    }

    /// La cuenta del Panel sale con el paso 1 en los dos modos: hasta hacerlo, ni la cuenta ni el saldo grande.
    @Test func thePanel_showsTheAccountWithStepOne() {
        let before = PrimerosPasosPanelGate.make(deckInProgress: true, accountStepResolved: false,
                                                 recordStepResolved: false, planningShown: false)
        let after = PrimerosPasosPanelGate.make(deckInProgress: true, accountStepResolved: true,
                                                recordStepResolved: false, planningShown: false)
        #expect(!before.showsAccounts)
        #expect(!before.showsBalanceHero)
        #expect(after.showsAccounts)
        #expect(after.showsBalanceHero)
    }

    /// Lo que el alta ya no hace, en el código: ni crea la cuenta ni pinta «Tus gastos van a…».
    @Test func wiring_noExpensesAccountAnywhere() throws {
        let alta = try CuentaBienSource.code("Yala/App/Views/Onboarding/WelcomeConversationView.swift")
        #expect(!alta.contains("createsExpensesAccount"))
        let logic = try CuentaBienSource.code("Yala/App/Logic/WelcomeConversationLogic.swift")
        #expect(!logic.contains("createsExpensesAccount"))
        for locale in CuentaBienSource.locales {
            #expect(!(try CuentaBienSource.strings(locale)).contains("\"setup.deck.firstExpense.note\""), "\(locale)")
        }
    }
}

// MARK: - 2 · Guía del primer registro

@MainActor
@Suite("Primeros pasos cuenta bien · guía del registro con dos monedas")
struct GuiaRegistroDosMonedasTests {

    private func account(_ name: String, archived: Bool = false, system: Bool = false) -> Account {
        Account(name: name, currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "checking",
                isArchived: archived, isSystemAccount: system)
    }

    /// «Ahorros» con soles y dólares son dos filas (la principal y su línea en USD): una sola cuenta para la persona.
    @Test func aTwoCurrencyAccount_isASingleAccount() {
        let main = account("Ahorros")
        let usdLine = account("Ahorros · USD")
        usdLine.currencyCode = "USD"
        usdLine.parentAccountID = main.shortcutID
        #expect(NewRecordTutorialGuide.hasSingleAccount([main, usdLine]))
        // Y la guía pasa por «Tu cuenta ya está puesta» en vez de saltar al nombre.
        let step = NewRecordTutorialGuide.step(
            hasAmount: true, hasCategory: true, current: NewRecordTutorialGuide.Step.category.rawValue,
            hasSingleAccount: NewRecordTutorialGuide.hasSingleAccount([main, usdLine]))
        #expect(step == NewRecordTutorialGuide.Step.account.rawValue)
    }

    /// Un enlace cuya principal no está (huérfano) no se reconoce como línea: cuenta como otra cuenta, como en el límite
    /// Free (`billableUserAccounts`, falla cerrado).
    @Test func anOrphanedLink_countsAsAnotherAccount() {
        let main = account("Ahorros")
        let orphan = account("Huérfana · USD")
        orphan.currencyCode = "USD"
        orphan.parentAccountID = UUID()
        #expect(!NewRecordTutorialGuide.hasSingleAccount([main, orphan]))
    }

    @Test func twoAccounts_skipTheAccountStep() {
        #expect(!NewRecordTutorialGuide.hasSingleAccount([account("Ahorros"), account("Efectivo")]))
    }

    /// Las archivadas y las de sistema de Grupos no son cuentas que la persona vea al registrar.
    @Test func archivedAndSystemAccounts_doNotCount() {
        let accounts = [account("Ahorros"), account("Vieja", archived: true), account("Grupos", system: true)]
        #expect(NewRecordTutorialGuide.hasSingleAccount(accounts))
    }

    @Test func wiring_theFormCountsVisibleAccounts() throws {
        let form = try CuentaBienSource.code("Yala/App/Views/Transactions/NewTransactionView.swift")
        #expect(form.contains("hasSingleAccount: NewRecordTutorialGuide.hasSingleAccount(viewModel.accounts),"))
        #expect(!form.contains("accounts.count <= 1"))
    }
}

// MARK: - 3 · Widget de Pagos planificados: el próximo aunque sea el mes que viene

@MainActor
@Suite("Primeros pasos cuenta bien · próximos pagos del widget")
struct ProximosPagosWidgetTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func params(recurring: Bool, due: Date, dayOfMonth: Int? = nil, endDate: Date? = nil)
        -> ScheduledPaymentDateCalculator.PaymentParams {
        ScheduledPaymentDateCalculator.PaymentParams(
            isRecurring: recurring, recurrenceType: "monthly", recurrenceInterval: 1, nextDueDate: due,
            createdAt: date(2026, 11, 25), endDate: endDate, dayOfMonth: dayOfMonth, selectedWeekdays: nil,
            yearlyMonth: nil, yearlyDay: nil)
    }

    /// El caso del iPhone: el 25 de noviembre se crea «Películas y series» para el 20 de diciembre. Este mes no tiene
    /// ninguna fecha (por eso el widget quedaba vacío) y el próximo es el 20 de diciembre.
    @Test func aPaymentCreatedAfterItsDate_showsNextMonth() throws {
        let november = date(2026, 11, 25)
        let p = params(recurring: false, due: date(2026, 12, 20))
        #expect(ScheduledPaymentDateCalculator.paymentDatesInMonth(params: p, month: november, calendar: calendar).isEmpty)
        let next = try #require(ScheduledPaymentsUpcomingLogic.nextOccurrence(
            afterMonthOf: november, params: p, isSkipped: { _ in false }, calendar: calendar))
        #expect(calendar.isDate(next, inSameDayAs: date(2026, 12, 20)))
    }

    /// Un pago del día 1 a las 00:00 del mes que viene no cae en este mes (el mes es semiabierto) y sale como próximo.
    @Test func aPaymentOnTheFirstAtMidnight_isNextMonthOnly() throws {
        let november = date(2026, 11, 25)
        let p = params(recurring: false, due: date(2026, 12, 1, hour: 0))
        #expect(ScheduledPaymentDateCalculator.paymentDatesInMonth(params: p, month: november, calendar: calendar).isEmpty)
        let next = try #require(ScheduledPaymentsUpcomingLogic.nextOccurrence(
            afterMonthOf: november, params: p, isSkipped: { _ in false }, calendar: calendar))
        #expect(calendar.isDate(next, inSameDayAs: date(2026, 12, 1)))
    }

    /// Un mes saltado no cuenta: el próximo es el siguiente.
    @Test func aSkippedOccurrence_isPassedOver() throws {
        let p = params(recurring: true, due: date(2026, 12, 5), dayOfMonth: 5)
        let december5 = date(2026, 12, 5)
        let calendar = calendar
        let next = try #require(ScheduledPaymentsUpcomingLogic.nextOccurrence(
            afterMonthOf: date(2026, 11, 25), params: p,
            isSkipped: { calendar.isDate($0, inSameDayAs: december5) }, calendar: calendar))
        #expect(calendar.isDate(next, inSameDayAs: date(2027, 1, 5)))
    }

    /// Sin próximo (un pago de una vez ya pasado, una fecha de fin): nada que enseñar.
    @Test func noNextOccurrence_isNil() {
        let past = params(recurring: false, due: date(2026, 10, 2))
        #expect(ScheduledPaymentsUpcomingLogic.nextOccurrence(
            afterMonthOf: date(2026, 11, 25), params: past, isSkipped: { _ in false }, calendar: calendar) == nil)
        let ended = params(recurring: true, due: date(2026, 11, 5), dayOfMonth: 5, endDate: date(2026, 11, 30))
        #expect(ScheduledPaymentsUpcomingLogic.nextOccurrence(
            afterMonthOf: date(2026, 11, 25), params: ended, isSkipped: { _ in false }, calendar: calendar) == nil)
    }

    /// Solo con el mes de hoy a la vista: con «Mes pasado» el widget sigue siendo de ese mes.
    @Test func looksAhead_onlyForTheCurrentMonth() {
        let now = date(2026, 11, 25)
        #expect(ScheduledPaymentsUpcomingLogic.looksAhead(displayMonth: date(2026, 11, 2), now: now, calendar: calendar))
        #expect(!ScheduledPaymentsUpcomingLogic.looksAhead(displayMonth: date(2026, 10, 25), now: now, calendar: calendar))
    }

    /// El Panel suma el próximo de cada pago sin nada pendiente este mes; el widget pequeño lo enseña en vez del vacío,
    /// y la ficha «Con tus datos» lo nombra.
    @Test func wiring_panelWidgetAndSheet() throws {
        let vm = try CuentaBienSource.code("Yala/App/ViewModels/PanelViewModel.swift")
        #expect(vm.contains("for payment in filtered where !paymentsWithPendingInMonth.contains(payment.id) {"))
        #expect(vm.contains("guard let date = ScheduledPaymentsUpcomingLogic.nextOccurrence("))
        #expect(vm.contains(".prefix(ScheduledPaymentsUpcomingLogic.maxItems)"))
        let widget = try CuentaBienSource.code("Yala/App/Views/Panel/ScheduledPaymentsWidget.swift")
        #expect(!widget.contains("data.activeCount == 0 || data.monthlyTotal == 0"))
        #expect(widget.contains("smallNextPayment(next)"))
        // «Próximo pago» no nombra un ingreso planificado (el sueldo): el widget y la ficha se saltan los ingresos.
        #expect(widget.contains("data.upcomingPayments.first(where: { !$0.isIncome })"))
        let sheet = try CuentaBienSource.code("Yala/App/Views/Panel/InfoSheets/WidgetInfoSheet.swift")
        #expect(sheet.contains("L10n.Panel.WidgetInfo.YourData.scheduledNext(name: next.name, date: date)"))
        #expect(sheet.contains("data.upcomingPayments.first(where: { !$0.isIncome })"))
    }

    @Test func theNextPaymentLine_isInEveryLanguage() throws {
        for locale in CuentaBienSource.locales {
            let strings = try CuentaBienSource.strings(locale)
            let line = strings.components(separatedBy: "\n")
                .first { $0.hasPrefix("\"panel.widgetInfo.yourData.scheduledNext\" = ") }
            #expect(line?.contains("%1$@") == true && line?.contains("%2$@") == true, "\(locale)")
        }
    }
}

// MARK: - 4 · Paso 7: «Terminar» cuenta

@Suite("Primeros pasos cuenta bien · paso 7 hasta «Terminar»")
struct Paso7TerminarCuentaTests {

    /// Con el bug, pasar las historias sin abrir ningún «Enséñame cómo» dejaba el paso «para después».
    @Test func finishingTheStories_completesTheStep() {
        #expect(HomeScreenTutorialLogic.resolution(of: .finished(anyDone: false)) == .completed)
        #expect(HomeScreenTutorialLogic.resolution(of: .finished(anyDone: true)) == .completed)
    }

    @Test func skippingOrClosing_doNotComplete() {
        #expect(HomeScreenTutorialLogic.resolution(of: .skippedStep) == .skipped)
        #expect(HomeScreenTutorialLogic.resolution(of: .closed) == nil)
    }
}

// MARK: - 5 · Grupos: ver la intro basta

@Suite("Primeros pasos cuenta bien · Grupos con «Ahora no»")
struct GruposAhoraNoCuentaTests {

    typealias E = GroupsTutorialLogic.Exit

    /// Con el bug, «Ahora no» dejaba el paso 5 omitido hasta que existiera un grupo.
    @Test func seeingTheIntro_completesTheStep() {
        #expect(GroupsTutorialLogic.deckResolution(E.seenNotNow) == .completed)
        #expect(GroupsTutorialLogic.deckResolution(E.createGroup) == .completed)
        #expect(GroupsTutorialLogic.deckResolution(E.joinWithLink) == .completed)
    }

    @Test func skippingOrGoingBack_doNotComplete() {
        #expect(GroupsTutorialLogic.deckResolution(E.skipped) == .skipped)
        #expect(GroupsTutorialLogic.deckResolution(E.closed) == nil)
    }

    @Test func wiring_afterGroupsMarksTheStepByTheResolution() throws {
        let presentations = try CuentaBienSource.code("Yala/App/Views/Panel/PrimerosPasosPlanningPresentations.swift")
        #expect(presentations.contains("switch GroupsTutorialLogic.deckResolution(record.exit) {"))
        #expect(presentations.contains("case .completed: SetupChecklistManager.shared.markCompleted(.groups)"))
    }

    /// El aviso de «ya lo conoces» no dice dónde lo vio: podía verlo un momento antes desde Primeros pasos.
    @Test func theAlreadySeenNotice_doesNotSayWhenYouJoined() throws {
        let phrases = ["al entrar", "when you joined", "beim Einstieg", "en arrivant", "all’inizio", "bij het starten",
                       "na początku", "ao entrar", "进来时"]
        for locale in CuentaBienSource.locales {
            let line = try CuentaBienSource.strings(locale).components(separatedBy: "\n")
                .first { $0.hasPrefix("\"pasos23.groups.alreadySeen\" = ") }
            let text = try #require(line, "\(locale)")
            #expect(!phrases.contains { text.contains($0) }, "\(locale): \(text)")
        }
    }
}
