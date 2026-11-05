//
//  RestoreLoteN3Tests.swift
//  YalaTests
//
//  Lote N3 · Restaurar y Almacenamiento (2026-11-05).
//  - Card 14hc: el faro del iCloud-KV que llega TARDE repinta un desenlace vacío decidido sin él.
//  - Card grgz: «Encontramos tus datos» deja rastro en el log, con las cifras que decidieron.
//

import Foundation
import Testing
@testable import Yala

@Suite("Lote N3 · Restaurar repinta cuando el faro llega tarde (card 14hc)")
struct RestoreLateBeaconTests {

    private typealias Outcome = WelcomeRestoreEmptyOutcome

    /// Escuchan los dos desenlaces decididos SIN faro; el de la pausa ya lo tiene.
    @Test func onlyTheOutcomesDecidedWithoutABeacon_listen() {
        #expect(Outcome.listensForLateBeacon(.notFound))
        #expect(Outcome.listensForLateBeacon(.cloudUnverified))
        #expect(!Outcome.listensForLateBeacon(.cloudPaused))
    }

    /// El caso del ticket: reinstalar CON red. La config llegó (kill puesto) y el faro no; al llegar el faro, el
    /// «No encontramos tus datos» pasa a «la nube está en pausa».
    @Test func notFound_withTheKillOn_becomesCloudPaused_whenTheBeaconArrives() {
        #expect(Outcome.afterLateBeacon(current: .notFound, beaconLinked: true,
                                         cloudConfigKnown: true, remoteCloudEnabled: false) == .cloudPaused)
    }

    /// Sin red: las dos señales en blanco daban «no pudimos comprobar». El faro gana a la config que falta.
    @Test func cloudUnverified_becomesCloudPaused_whenTheBeaconArrives() {
        #expect(Outcome.afterLateBeacon(current: .cloudUnverified, beaconLinked: true,
                                         cloudConfigKnown: false, remoteCloudEnabled: false) == .cloudPaused)
    }

    /// Un cambio del iCloud-KV que no trae el faro no repinta nada (cualquier preferencia sincronizada lo dispara).
    @Test func aKeyValueChangeWithoutTheBeacon_changesNothing() {
        #expect(Outcome.afterLateBeacon(current: .notFound, beaconLinked: false,
                                         cloudConfigKnown: true, remoteCloudEnabled: false) == nil)
        #expect(Outcome.afterLateBeacon(current: .cloudUnverified, beaconLinked: false,
                                         cloudConfigKnown: false, remoteCloudEnabled: false) == nil)
    }

    /// Con la nube abierta y el faro, `resolve` sigue diciendo `.notFound` (la puerta de entrar está abierta):
    /// repintar no inventa otro desenlace.
    @Test func withTheCloudOpen_theBeaconDoesNotChangeNotFound() {
        #expect(Outcome.afterLateBeacon(current: .notFound, beaconLinked: true,
                                         cloudConfigKnown: true, remoteCloudEnabled: true) == nil)
    }

    /// `.cloudPaused` no escucha: aunque el faro desaparezca, no se repinta desde ahí.
    @Test func cloudPaused_neverRepaints() {
        #expect(Outcome.afterLateBeacon(current: .cloudPaused, beaconLinked: false,
                                         cloudConfigKnown: true, remoteCloudEnabled: true) == nil)
    }
}

@Suite("Lote N3 · Restaurar · cableado (source-scan)")
struct RestoreLoteN3WiringTests {

    private static let viewPath = "Yala/App/Views/Onboarding/WelcomeRestoreView.swift"

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func body(of marker: String, in source: String) throws -> [String] {
        let start = try #require(source.range(of: marker), "no encuentro «\(marker)»")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    /// La escucha cuelga de la pantalla con `id: state` (se cancela al salir del desenlace) y escucha al EMISOR real:
    /// con la puerta como `object:` no dispararía nunca.
    @Test func theScreen_listensToTheRealEmitter_andRepaintsOnce() throws {
        let view = try Self.source(Self.viewPath)
        #expect(view.contains(".task(id: state) { await listenForLateBeacon() }"))
        let listen = try Self.body(of: "private func listenForLateBeacon() async {", in: view)
        #expect(listen.first
                == "guard let shown = shownEmptyOutcome, WelcomeRestoreEmptyOutcome.listensForLateBeacon(shown) else { return }")
        // Una lectura antes de suscribirse (el faro que llegó entre la decisión y el render) y otra por aviso.
        #expect(listen.dropFirst().first == "if repaintIfTheBeaconArrived() { return }")
        #expect(listen.contains("named: OwnerKeyValueStore.didChangeExternallyNotification,"))
        #expect(listen.contains("object: OwnerKeyValueStore.notificationSource) {"))
        #expect(listen.filter { $0 == "if repaintIfTheBeaconArrived() { return }" }.count == 2)
        let repaint = try Self.body(of: "private func repaintIfTheBeaconArrived() -> Bool {", in: view)
        #expect(repaint.contains("beaconLinked: CloudBeacon().isCloudAccountLinked,"))
        #expect(repaint.contains("RestoreBreadcrumb.lateBeacon(from: current, to: next)"))
        #expect(repaint.contains("state = Self.viewState(for: next)"))
    }

    /// Cada desenlace va a SU estado: un swap compila y deja la tabla en verde.
    @Test func eachOutcome_paintsItsOwnState() throws {
        let view = try Self.source(Self.viewPath)
        let map = try Self.body(of: "private static func viewState(for outcome: WelcomeRestoreEmptyOutcome) -> ViewState {",
                                in: view)
        #expect(map == [
            "switch outcome {",
            "case .notFound: return .notFound",
            "case .cloudPaused: return .cloudPaused",
            "case .cloudUnverified: return .cloudUnverified",
            "}",
        ])
    }

    /// Card 39ww: la tarjeta recibe el motor parado, y el controller lo calcula con el estado del runtime y los efectos
    /// pendientes del journal. Sin el argumento, `decide` cae a su default `false` y vuelve el check verde.
    @Test func theSyncCard_receivesTheStoppedEngine() throws {
        let view = try Self.source("Yala/App/Views/Settings/StorageSettingsView.swift")
        #expect(view.contains("engineIsHealthy: controller.syncEngineIsHealthy, engineIsStopped: controller.syncEngineIsStopped) {"))
        #expect(view.contains("case .stopped(let pending):"))
        let controller = try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift")
        let health = try Self.body(of: "private func refreshSyncEngineHealth() {", in: controller)
        #expect(health.contains("syncEngineIsStopped = SyncStatusSectionLogic.engineIsStopped("))
        #expect(health.contains("state: CloudSyncRuntime.shared?.state, migrationEffectsPending: pendingEffectCount > 0)"))
    }

    /// Card grgz: la rama `.found` deja su miga ANTES de cambiar de estado, con el desenlace de la espera. Card lokl: la
    /// nota de la copia anterior a la nube sale con el faro.
    @Test func theFoundBranch_leavesABreadcrumb_andNotesAPreCloudCopy() throws {
        let view = try Self.source(Self.viewPath)
        let branch = try #require(view.range(of: "if summary.hasAnyData {"))
        let lines = String(view[branch.upperBound...]).split(separator: "\n").prefix(4)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        // Card lokl: el faro se lee ANTES de pintar, y la nota sale solo con él. Card grgz: la miga, antes del estado.
        #expect(lines == [
            "foundCopyPredatesCloud = CloudBeacon().isCloudAccountLinked",
            "RestoreBreadcrumb.found(summary, settlement: settlement,",
            "beaconLinked: foundCopyPredatesCloud)",
            "state = .found(summary)",
        ])
        let content = try Self.body(of: "private func foundContent(summary: ICloudAccountSummary) -> some View {", in: view)
        let note = try #require(content.firstIndex(of: "if foundCopyPredatesCloud {"))
        #expect(content[note + 2] == "Text(L10n.Welcome.Restore.foundPreCloudNote)")
        // La nota no toca los botones (decisión A).
        #expect(content.contains("YalaPrimaryButton(L10n.UXLote6.restoreBringBack) {"))
    }
}

@Suite("Lote N3 · Restaurar deja rastro al encontrar datos (card grgz)")
@MainActor
struct RestoreFoundBreadcrumbTests {

    private func summary(tx: Int = 0, accounts: Int = 0, categories: Int = 0, budgets: Int = 0,
                         groups: Int = 0) -> ICloudAccountSummary {
        ICloudAccountSummary(userName: "Ana", accountsCount: accounts, transactionsCount: tx, budgetsCount: budgets,
                             groupsCount: groups, primaryCurrencyCode: "PEN", categoriesCount: categories)
    }

    /// Las cinco cifras, cada una en su sitio, y cómo terminó la espera. Valores distintos en cada casilla: con dos
    /// iguales, un swap entre ellas pasaría.
    @Test func theMessage_carriesEveryCount_andTheSettlement() {
        let message = RestoreBreadcrumb.foundMessage(
            summary(tx: 11, accounts: 2, categories: 7, budgets: 3, groups: 5), settlement: .inconclusive,
            beaconLinked: true)
        #expect(message == "FOUND tx=11 accounts=2 categories=7 budgets=3 groups=5 import=inconclusive beacon=true")
        #expect(RestoreBreadcrumb.foundMessage(summary(tx: 1), settlement: .inconclusive, beaconLinked: false)
                    .hasSuffix(" beacon=false"))
    }

    /// Sin datos personales: ni el nombre ni la moneda viajan al log, que va fuera de `#if DEBUG`.
    @Test func theMessage_hasNoPersonalData() {
        let message = RestoreBreadcrumb.foundMessage(summary(budgets: 1), settlement: .settledEmpty, beaconLinked: false)
        #expect(!message.contains("Ana"))
        #expect(!message.contains("PEN"))
    }
}
