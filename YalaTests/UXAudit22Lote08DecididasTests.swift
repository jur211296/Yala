//
//  UXAudit22Lote08DecididasTests.swift
//  YalaTests
//
//  Lote decidido 2.2 · 08 (widgets, iPad, teclado, botones flotantes y accesos del icono), decisiones de Jürgen del
//  2026-10-18. La lógica sin vistas de cada decisión; lo visible lo prueban el XCUITest del lote y el barrido.
//

import Foundation
import SwiftData
import Testing
import UIKit

@testable import Yala

// MARK: - L15-3 · Cada widget abre la pantalla que amplía lo que enseña

@MainActor
struct WidgetDeepLinkTests {

    private func request(_ link: String) -> StatisticsDeepLink.Request? {
        StatisticsDeepLink.request(fromDeepLink: link)
    }

    /// «Gastos» (inicio y bloqueo) abría el Panel en un sitio y el Resumen en el otro: ahora los dos, el Resumen.
    @Test func expenses_opensTheOverview() {
        #expect(request(WidgetDeepLink.expenses) == .init(tab: .insights, period: nil, focus: nil))
    }

    /// «Entradas y salidas» abría el Panel: ahora Tendencias, con esa tarjeta a la vista.
    @Test func inAndOut_opensTrends_onThatCard() {
        #expect(request(WidgetDeepLink.inAndOut) == .init(tab: .trends, period: nil, focus: .inAndOut))
    }

    /// Los de subcategorías abrían Distribución por categorías.
    @Test func subcategories_opensDistribution_onSubcategories() {
        #expect(request(WidgetDeepLink.subcategories) == .init(tab: .categories, period: nil, focus: .subcategories))
    }

    /// Una parte solo cuenta en su pestaña, y un período sigue entendiéndose detrás de la pestaña (L11-2).
    @Test func focus_onlyCountsInItsOwnTab_andPeriodsStillParse() {
        #expect(request("statistics/insights/in-and-out") == .init(tab: .insights, period: nil, focus: nil))
        #expect(request("statistics/trends/subcategories")?.focus == nil)
        #expect(request("statistics/insights/last7Days") == .init(tab: .insights, period: .last7Days))
        #expect(request("statistics/trends/thisMonth/in-and-out") == .init(tab: .trends, period: .thisMonth, focus: .inAndOut))
    }

    /// El widget va por URL (`yala://statistics/trends/in-and-out`), y el arranque lee las partes de la ruta.
    @Test func urlComponents_carryTheFocus() throws {
        let url = try #require(WidgetURLHelper.url(for: WidgetDeepLink.inAndOut))
        #expect(url.host == "statistics")
        #expect(StatisticsDeepLink.request(fromComponents: url.pathComponents)?.focus == .inAndOut)
    }

    /// «Toca para crear uno» lleva al editor nuevo por el host de siempre: `planning` y `budgets`.
    @Test func createFirst_linksUseTheExistingHosts() throws {
        let payment = try #require(WidgetURLHelper.url(for: WidgetDeepLink.newScheduledPayment))
        #expect(payment.host == "planning")
        #expect(payment.pathComponents.contains("scheduled-payments"))
        #expect(payment.pathComponents.contains("new"))
        let budget = try #require(WidgetURLHelper.url(for: WidgetDeepLink.newBudget))
        #expect(budget.host == "budgets")
        #expect(budget.pathComponents.contains("new"))
    }
}

// MARK: - L15-2 · Lo elegido a mano que ya no existe

struct WidgetSelectionFallbackTests {

    private struct Item: Equatable {
        let id: String
    }

    private let all = [Item(id: "a"), Item(id: "b"), Item(id: "c"), Item(id: "d")]

    private func resolve(_ selected: [String], limit: Int = 3) -> [String] {
        WidgetSelectionFallback.resolve(
            selectedIDs: selected, available: all, automatic: all, id: \.id, limit: limit
        ).map(\.id)
    }

    @Test func automatic_showsTheAutomaticOnes_upToTheLimit() {
        #expect(resolve([]) == ["a", "b", "c"])
    }

    @Test func chosen_keepsTheChosenOrder() {
        #expect(resolve(["c", "a"]) == ["c", "a"])
    }

    /// El caso del ticket: con lo elegido borrado, el widget decía «Sin presupuestos» aunque hubiera otros.
    @Test func everythingChosenWasDeleted_fallsBackToAutomatic() {
        #expect(resolve(["x", "y"]) == ["a", "b", "c"])
    }

    /// Si queda algo de lo elegido, se enseña eso: sigue siendo verdad y es lo que la persona pidió.
    @Test func partOfTheChoiceIsLeft_showsWhatIsLeft() {
        #expect(resolve(["x", "b"]) == ["b"])
    }

    @Test func nothingAtAll_isEmpty() {
        let none: [Item] = []
        #expect(WidgetSelectionFallback.resolve(
            selectedIDs: ["a"], available: none, automatic: none, id: \.id, limit: 3).isEmpty)
    }
}

// MARK: - L15-11 · La ventana que espera dice por qué y lleva a la otra

struct WindowBusyLogicTests {

    @Test func reason_followsTheGateOrder() {
        #expect(WindowBusyLogic.reason(isWipingData: true, signOutWorking: true) == .wiping)
        #expect(WindowBusyLogic.reason(isWipingData: false, signOutWorking: true) == .signingOut)
        #expect(WindowBusyLogic.reason(isWipingData: false, signOutWorking: false) == .starting)
    }

    @Test func signingOut_goesToTheWindowThatStartedIt() {
        let me = UUID(), driver = UUID(), leader = UUID()
        #expect(WindowBusyLogic.target(
            for: .signingOut, windowID: me, signOutDriverID: driver, leaderID: leader, aliveIDs: [leader, me, driver])
            == driver)
    }

    /// La líder tapada por el cierre que lanzó otra ventana: el botón lleva a esa otra, no a sí misma.
    @Test func leaderCoveredBySignOut_goesToTheDriver_notToItself() {
        let leader = UUID(), driver = UUID()
        #expect(WindowBusyLogic.target(
            for: .signingOut, windowID: leader, signOutDriverID: driver, leaderID: leader, aliveIDs: [leader, driver])
            == driver)
    }

    @Test func noOtherWindowAlive_noButton() {
        let me = UUID(), gone = UUID()
        #expect(WindowBusyLogic.target(
            for: .signingOut, windowID: me, signOutDriverID: gone, leaderID: me, aliveIDs: [me]) == nil)
        #expect(WindowBusyLogic.target(
            for: .starting, windowID: me, signOutDriverID: nil, leaderID: nil, aliveIDs: [me]) == nil)
    }

    @Test func starting_goesToTheLeader() {
        let me = UUID(), leader = UUID()
        #expect(WindowBusyLogic.target(
            for: .starting, windowID: me, signOutDriverID: nil, leaderID: leader, aliveIDs: [leader, me]) == leader)
    }

    /// El borrado puede lanzarlo esta misma ventana (Ajustes › Vaciar datos): ni botón ni «en la otra ventana».
    @Test func wiping_hasNoButton_andDoesNotBlameTheOtherWindow() {
        let me = UUID(), leader = UUID()
        #expect(WindowBusyLogic.target(
            for: .wiping, windowID: me, signOutDriverID: nil, leaderID: leader, aliveIDs: [leader, me]) == nil)
        #expect(WindowBusyLogic.text(for: .wiping, hasTarget: false) == .wiping)
    }

    /// «En la otra ventana» solo si hay otra ventana a la que ir: la líder tapada cuando la que cerró la sesión ya no
    /// existe dice «Cerrando tu sesión…» a secas.
    @Test func signingOut_mentionsTheOtherWindow_onlyIfThereIsOne() {
        #expect(WindowBusyLogic.text(for: .signingOut, hasTarget: true) == .signingOutElsewhere)
        #expect(WindowBusyLogic.text(for: .signingOut, hasTarget: false) == .signingOut)
    }
}

// MARK: - L15-12 · Soltar con algo abierto, y varios a la vez

@MainActor
struct ReceiptDropLote08Tests {

    /// Con una hoja o un aviso cualquiera se acepta (la hoja de lectura espera); se rechaza solo donde la ventana no
    /// opera o hay que contestar algo antes de usar Yala.
    @Test func refuses_onlyWhereTheWindowCannotOperate() {
        #expect(!ReceiptDropLogic.refusesWhile(shellBlocker: nil))
        for open in ["mainTabModal", "activeInboxAlert", "proTrialOffer", "whatsNew", "syncSettingsSheet"] {
            #expect(!ReceiptDropLogic.refusesWhile(shellBlocker: open), "\(open) es una hoja: el recibo espera")
        }
        for closed in ["splash", "bootstrapPending", "signOutWorking", "signOutRelaunch", "wipingData", "forceUpdate",
                       "followerBusy", "followerNeedsLeader", "welcomeFlow", "remoteWipeAlert"] {
            #expect(ReceiptDropLogic.refusesWhile(shellBlocker: closed), "\(closed) no opera: se rechaza")
        }
    }

    /// Los archivos de una tanda soltada se nombran como las fotos compartidas: la hoja los agrupa y cuenta los que
    /// no entraron. Un PDF conserva su extensión para trocearse en páginas.
    @Test func batchNames_areSharedImageBatchMembers() throws {
        let image = ReceiptDropLogic.batchFileName(batchID: "abc", index: 0, droppedCount: 12, isPDF: false)
        let pdf = ReceiptDropLogic.batchFileName(batchID: "abc", index: 1, droppedCount: 12, isPDF: true)
        #expect(image.hasSuffix(".jpg"))
        #expect(pdf.hasSuffix(".pdf"))
        let member = try #require(SharedImageBatch.member(fromFileName: pdf))
        #expect(member == .init(batchID: "abc", index: 1, sharedCount: 12))
        #expect(SharedImageBatch.leftOutCount(for: URL(fileURLWithPath: "/tmp/" + image)) == 2)
    }

    private static func png() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    private final class Recorder {
        var storedNames: [String] = []
        var presented: [URL] = []
        var failures: [ImageEntryFailure] = []

        func sink() -> ReceiptDropHandler.Sink {
            ReceiptDropHandler.Sink(
                store: { _, _ in nil },
                present: { self.presented.append($0) },
                fail: { self.failures.append($0) },
                storeInBatch: { _, name in
                    self.storedNames.append(name)
                    return URL(fileURLWithPath: "/tmp/" + name)
                }
            )
        }
    }

    /// De tres soltados, uno ilegible: se leen los otros dos como una tanda y se presenta el primero. Antes se leía solo
    /// el primero y el resto se perdía en silencio.
    @Test func severalDropped_areReadAsOneBatch_skippingTheUnreadable() throws {
        let recorder = Recorder()
        let outcomes = [(Self.png(), false), (Data("no es una imagen".utf8), false), (Self.png(), false)]
            .map { ReceiptDropHandler.outcome(for: $0.0, isPDF: $0.1) }
        ReceiptDropHandler.receiveBatch(outcomes, droppedCount: 3, sink: recorder.sink())
        #expect(recorder.storedNames.count == 2)
        #expect(recorder.failures.isEmpty)
        #expect(recorder.presented.count == 1)
        let first = try #require(recorder.presented.first)
        let members = recorder.storedNames.compactMap(SharedImageBatch.member(fromFileName:))
        #expect(members.map(\.index) == [0, 1], "Sin huecos: la hoja ordena por posición")
        #expect(Set(members.map(\.batchID)).count == 1, "Una sola tanda")
        #expect(first.lastPathComponent == recorder.storedNames.first)
    }

    @Test func severalDropped_allUnreadable_endInTheFailure() {
        let recorder = Recorder()
        let outcomes = [
            ReceiptDropHandler.outcome(for: nil, isPDF: true),
            ReceiptDropHandler.outcome(for: Data("x".utf8), isPDF: false),
        ]
        ReceiptDropHandler.receiveBatch(outcomes, droppedCount: 2, sink: recorder.sink())
        #expect(recorder.failures == [.unreadableFile])
        #expect(recorder.presented.isEmpty)
        #expect(recorder.storedNames.isEmpty)
    }
}

// MARK: - L15-15 · Accesos rápidos del icono

@MainActor
struct HomeScreenQuickActionsTests {

    /// Los tres entran por el enlace de su widget de entrada rápida, que ya lleva sus puertas.
    @Test func eachActionUsesItsQuickEntryLink() {
        #expect(HomeScreenQuickActions.url(forType: HomeScreenQuickActions.Action.newRecord.rawValue)?.host
            == "new-transaction")
        #expect(HomeScreenQuickActions.url(forType: HomeScreenQuickActions.Action.voice.rawValue)?.host == "voice-entry")
        #expect(HomeScreenQuickActions.url(forType: HomeScreenQuickActions.Action.image.rawValue)?.host == "image-entry")
        #expect(HomeScreenQuickActions.url(forType: "otra.app.accion") == nil)
    }

    /// Con la app cerrada el acceso llega antes del arranque: su enlace tiene que esperarlo, no perderse.
    @Test func eachLink_waitsForTheBootstrap() {
        for action in HomeScreenQuickActions.Action.allCases {
            #expect(EntryReadinessLogic.waitsForBootstrap(host: action.deepLinkPath, isInitialized: false),
                    "\(action) se perdería en un arranque en frío")
        }
    }

    /// Las tres, en el orden decidido: «Nuevo registro», «Registrar por voz», «Foto o archivo».
    @Test func order_isTheDecidedOne() {
        #expect(HomeScreenQuickActions.Action.allCases == [.newRecord, .voice, .image])
    }
}

// MARK: - L15-13 · ⌘Z deshace el último borrado unos segundos

@MainActor
@Suite("Borrar un registro espera con «Deshacer»", .serialized)
struct RecordPendingDeletionTests {

    @Test func pendingRecord_isHidden_andUndoBringsItBack_withoutDeleting() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let record = TransactionItem(date: .now, amount: -26, currencyCode: account.currencyCode, note: "Uber", account: account)
        context.insert(record)
        try context.save()
        let id = record.persistentModelID

        var committed = false
        RecordPendingDeletion.shared.request(id: id, transferPairID: nil, name: "Uber · S/ 26") { committed = true }
        #expect(RecordPendingDeletion.shared.hides(id, transferPairID: nil))

        RecordPendingDeletion.shared.undo(id)
        #expect(!RecordPendingDeletion.shared.hides(id, transferPairID: nil))
        #expect(!committed)
    }

    /// Una transferencia se borra con su pareja: mientras espera, las dos patas se esconden, y nada más.
    @Test func pendingTransfer_hidesBothLegs_andNothingElse() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let leg = TransactionItem(date: .now, amount: -50, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        let otherLeg = TransactionItem(date: .now, amount: 50, currencyCode: account.currencyCode, note: "A ahorro", account: account)
        let unrelated = TransactionItem(date: .now, amount: -9, currencyCode: account.currencyCode, note: "Café", account: account)
        context.insert(leg)
        context.insert(otherLeg)
        context.insert(unrelated)
        try context.save()

        RecordPendingDeletion.shared.request(id: leg.persistentModelID, transferPairID: "pair-1", name: "A ahorro") {}
        #expect(RecordPendingDeletion.shared.hides(leg.persistentModelID, transferPairID: "pair-1"))
        #expect(RecordPendingDeletion.shared.hides(otherLeg.persistentModelID, transferPairID: "pair-1"))
        #expect(!RecordPendingDeletion.shared.hides(unrelated.persistentModelID, transferPairID: nil))
        #expect(!RecordPendingDeletion.shared.hides(unrelated.persistentModelID, transferPairID: "pair-2"))

        RecordPendingDeletion.shared.undo(leg.persistentModelID)
        #expect(!RecordPendingDeletion.shared.hides(otherLeg.persistentModelID, transferPairID: "pair-1"))
    }

    /// La pregunta de borrado no puede decir «no se puede deshacer» cuando sí se puede.
    @Test func confirmationMessage_saysItCanBeUndone() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Diaria")
        let record = TransactionItem(date: .now, amount: -26, currencyCode: account.currencyCode, note: "Uber", account: account)
        context.insert(record)
        #expect(RecordDeleteConfirmationText.message(for: record, undoable: true) == L10n.UXL08D.undoSeconds)
        #expect(RecordDeleteConfirmationText.message(for: record) == L10n.Common.cannotUndo)
    }
}
