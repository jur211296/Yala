//
//  AccountEntryGroupsHoldTests.swift
//  YalaTests
//
//  Ticket `adopt-lineage-block-shows-connecting-for-fifteen-minutes`: al entrar desde el Welcome en una cuenta con grupos, el
//  canal de Grupos bajaba antes del claim y el puente creaba filas que el adopt leía sin linaje (15 min en «Conectando… 60 %»).
//  El arreglo es el orden: el canal no arranca hasta que el adopt decide (`AccountEntryGroupsHold`). Aquí se fija la decisión
//  del candado, que el canal lo consulta antes de arrancar, y dónde lo arma y lo suelta el Welcome.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Entrada a una cuenta · Grupos espera al adopt", .serialized)
@MainActor
struct AccountEntryGroupsHoldTests {

    private typealias Hold = AccountEntryGroupsHold
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - La decisión

    @Test func decide_table() {
        func d(_ armed: String?, since: Date?, session: String?, at offset: TimeInterval,
               inFlight: Bool = false, landed: Bool = false) -> Hold.Decision {
            Hold.decide(armedSub: armed, armedSince: since, sessionSub: session, now: t0.addingTimeInterval(offset),
                        migrationInFlight: inFlight, landed: landed)
        }
        #expect(d(nil, since: nil, session: "a", at: 0) == .release, "sin candado no frena")
        #expect(d("a", since: t0, session: "a", at: 60) == .hold, "la misma cuenta, dentro del plazo")
        #expect(d(Hold.anySession, since: t0, session: "a", at: 60) == .hold, "el comodín frena la sesión que se abra")
        #expect(d(Hold.anySession, since: t0, session: "b", at: 60) == .hold)
        #expect(d("a", since: t0, session: "b", at: 60) == .release, "otra cuenta no es esta entrada")
        #expect(d("a", since: t0, session: nil, at: 60) == .release, "sin sesión no hay canal")
        #expect(d("a", since: t0, session: "a", at: Hold.ttl - 1) == .hold)
        #expect(d("a", since: t0, session: "a", at: Hold.ttl) == .releaseAndClear, "vencido, se retira")
        #expect(d("a", since: t0, session: "a", at: -60) == .releaseAndClear, "un reloj que retrocede no deja el candado para siempre")
        #expect(d("a", since: t0, session: "a", at: Hold.ttl * 50, inFlight: true) == .hold,
                "con el adopt en vuelo frena aunque venza el plazo: el import puede tardar horas")
        #expect(d("a", since: t0, session: "a", at: -60, inFlight: true) == .hold)
        #expect(d("a", since: t0, session: "a", at: 60, inFlight: true, landed: true) == .releaseAndClear,
                "el adopt aterrizó: manda el ciclo personal")
        #expect(d("a", since: nil, session: "a", at: 60) == .releaseAndClear, "sin hora no se puede medir el plazo")
    }

    /// Review adversarial: en un arranque en frío el journal aún no está conectado y su fase es el relleno `.notStarted`.
    /// Retirar el candado ahí soltaba el canal con el adopt pendiente. Sin journal frena y NO retira, aunque el plazo venciera.
    @Test func decide_withoutJournal_holdsWithoutClearing() {
        let late = t0.addingTimeInterval(Hold.ttl * 2)
        #expect(Hold.decide(armedSub: "a", armedSince: t0, sessionSub: "a", now: late, journalConnected: false,
                            migrationInFlight: false, landed: false) == .hold)
        #expect(Hold.decide(armedSub: "a", armedSince: t0, sessionSub: "a", now: late, journalConnected: false,
                            migrationInFlight: false, landed: true) == .hold, "«aterrizado» se lee del relleno: no vale")
        #expect(Hold.decide(armedSub: nil, armedSince: nil, sessionSub: "a", now: late, journalConnected: false,
                            migrationInFlight: false, landed: false) == .release, "control: sin candado no frena")
    }

    /// Review adversarial: el adopt terminó con el modo ya en la nube y falta reabrir. Vencido el plazo, el canal levantaba su
    /// loop propio sobre el store que se va a remontar. Frena hasta aterrizar.
    @Test func decide_awaitingRemount_holdsPastTheTTL() {
        let late = t0.addingTimeInterval(Hold.ttl * 2)
        #expect(Hold.decide(armedSub: "a", armedSince: t0, sessionSub: "a", now: late, migrationInFlight: false,
                            awaitingRemount: true, landed: false) == .hold)
        #expect(Hold.decide(armedSub: "a", armedSince: t0, sessionSub: "a", now: late, migrationInFlight: false,
                            awaitingRemount: false, landed: false) == .releaseAndClear, "control")
    }

    @Test func migrationInFlight_readsTheJournal() {
        #expect(Hold.migrationInFlight(.read(phase: .claimingMigration, hasPendingEffects: false)), "el claim del adopt")
        #expect(Hold.migrationInFlight(.read(phase: .waitingForLeader, hasPendingEffects: false)))
        #expect(Hold.migrationInFlight(.read(phase: .authenticating, hasPendingEffects: false)))
        #expect(Hold.migrationInFlight(.read(phase: .notStarted, hasPendingEffects: true)),
                "el efecto del adopt que reintenta: `notStarted` + `.adoptBackendAccount`")
        #expect(!Hold.migrationInFlight(.read(phase: .notStarted, hasPendingEffects: false)), "reposo")
        #expect(!Hold.migrationInFlight(.read(phase: .failedRollback, hasPendingEffects: false)), "la salida asentada")
        #expect(Hold.migrationInFlight(.read(phase: .failedRollback, hasPendingEffects: true)), "la salida sin asentar")
        #expect(!Hold.migrationInFlight(.read(phase: .done, hasPendingEffects: false)))
        #expect(!Hold.migrationInFlight(.unreadable), "un journal ilegible decide por el plazo, no deja sin Grupos para siempre")
    }

    // MARK: - El ciclo durable

    private func withIsolatedHold(inFlight: Bool = false, landed: Bool = false, cloud: Bool = false,
                                  journalConnected: Bool = true, _ body: () throws -> Void) throws {
        let isolated = makeIsolatedDefaults(prefix: "AccountEntryGroupsHold")
        let previous = (Hold.defaults, Hold.migrationInFlightProvider, Hold.landedProvider, Hold.storageModeIsCloudProvider,
                        Hold.journalConnectedProvider, Hold.journalReadableProvider)
        Hold.defaults = isolated
        Hold.migrationInFlightProvider = { inFlight }
        Hold.landedProvider = { landed }
        Hold.storageModeIsCloudProvider = { cloud }
        Hold.journalConnectedProvider = { journalConnected }
        Hold.journalReadableProvider = { true }
        defer {
            Hold.defaults = previous.0
            Hold.migrationInFlightProvider = previous.1
            Hold.landedProvider = previous.2
            Hold.storageModeIsCloudProvider = previous.3
            Hold.journalConnectedProvider = previous.4
            Hold.journalReadableProvider = previous.5
        }
        try body()
    }

    @Test func armWithoutSession_holdsTheSessionThatOpens() throws {
        try withIsolatedHold {
            #expect(!Hold.blocksChannel(sub: "a", now: t0), "control: sin armar no frena")
            Hold.arm(sub: nil, now: t0)
            #expect(Hold.blocksChannel(sub: "a", now: t0.addingTimeInterval(30)))
            Hold.arm(sub: "a", now: t0)
            #expect(Hold.blocksChannel(sub: "a", now: t0.addingTimeInterval(30)))
            #expect(!Hold.blocksChannel(sub: "b", now: t0.addingTimeInterval(30)))
            Hold.clear()
            #expect(!Hold.blocksChannel(sub: "a", now: t0.addingTimeInterval(30)))
        }
    }

    @Test func expiredHold_isRetired() throws {
        try withIsolatedHold {
            Hold.arm(sub: "a", now: t0)
            #expect(!Hold.blocksChannel(sub: "a", now: t0.addingTimeInterval(Hold.ttl + 1)))
            #expect(!Hold.isArmed, "vencido se retira, no se queda puesto")
        }
    }

    @Test func landedAdopt_retiresTheHold() throws {
        try withIsolatedHold(inFlight: false, landed: true) {
            Hold.arm(sub: "a", now: t0)
            #expect(!Hold.blocksChannel(sub: "a", now: t0.addingTimeInterval(30)))
            #expect(!Hold.isArmed)
        }
    }

    @Test func coldStartBeforeTheJournal_keepsTheHold() throws {
        try withIsolatedHold(inFlight: false, landed: true, journalConnected: false) {
            Hold.arm(sub: "a", now: t0)
            #expect(Hold.blocksChannel(sub: "a", now: t0.addingTimeInterval(Hold.ttl * 2)))
            #expect(Hold.isArmed, "sin journal no se retira")
            Hold.releaseIfNoAdoptPending()
            #expect(Hold.isArmed, "ni al cerrarse la pantalla")
        }
    }

    @Test func adoptInFlight_keepsHoldingPastTheTTL() throws {
        try withIsolatedHold(inFlight: true) {
            Hold.arm(sub: "a", now: t0)
            #expect(Hold.blocksChannel(sub: "a", now: t0.addingTimeInterval(Hold.ttl * 3)))
            #expect(Hold.isArmed)
        }
    }

    /// Al cerrarse la pantalla del Welcome: sin adopt que proteger se retira; con el adopt en vuelo, o con el modo ya en la nube
    /// esperando el remonte, se queda.
    @Test func releaseIfNoAdoptPending_table() throws {
        for (inFlight, cloud, staysArmed) in [(false, false, false), (true, false, true), (false, true, true), (true, true, true)] {
            try withIsolatedHold(inFlight: inFlight, cloud: cloud) {
                Hold.arm(sub: "a", now: t0)
                Hold.releaseIfNoAdoptPending()
                #expect(Hold.isArmed == staysArmed, "inFlight=\(inFlight) cloud=\(cloud)")
            }
        }
    }

    // MARK: - El canal lo consulta

    private final class StubSession: SyncHTTPSession, @unchecked Sendable {
        var callCount = 0
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            let body = Data("{\"deltas\":[],\"cursors\":{},\"memberships\":[]}".utf8)
            return (body, HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!)
        }
    }

    private final class Counter: @unchecked Sendable { var count = 0 }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration("AEH-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("AEH-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration("AEH-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
                                          url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        return ModelContext(container)
    }

    /// **Con una entrada a una cuenta en curso, el canal no arranca** (la causa del ticket: bajaba antes del claim y el puente
    /// creaba lo que el adopt leía sin linaje). Control: sin el candado, el mismo cliente levanta su loop y llega a la red.
    @Test func startIfEligible_withTheHold_doesNotStartTheChannel() async throws {
        let prevRuntime = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.groupsBackendEnabled = true
        CloudSyncFlags.syncRuntimeEnabled = true
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            CloudSyncFlags.syncRuntimeEnabled = prevRuntime
        }
        for held in [true, false] {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("AEH-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            defer { discardTestStoreDirectory(dir) }
            let context = try makeContext(dir)
            let stub = StubSession()
            let checks = Counter()
            let client = GroupsSyncClient(
                tokenProvider: { "jwt" }, urlSession: stub,
                sessionCheck: { checks.count += 1; return checks.count <= 50 },
                currentUserIDProvider: { "sub-a" },
                signInLogProvider: { SessionSignInLog(entries: [.init(sub: "sub-a", at: .distantPast)]) },
                outboxMirror: nil,
                forceRefreshTokenProvider: { nil },
                canRenewSession: { false })
            client.sleeper = { _ in }
            client.completeAccountAdoptPending = { _ in false }
            var askedFor: String?
            client.accountEntryHold = { askedFor = $0; return held }
            client.startIfEligible(context: context, trigger: "foreground")
            #expect(askedFor == "sub-a", "el candado se pregunta con la cuenta de la sesión")
            if held {
                #expect(client._testLoopTask == nil, "con la entrada en curso el canal espera al adopt")
                #expect(stub.callCount == 0, "y no baja nada: el puente no tiene qué puentear")
                let pushed = await client.syncNowFromUI(timeout: .seconds(1))
                #expect(!pushed, "sin canal arrancado, tirar para refrescar tampoco baja nada")
                #expect(stub.callCount == 0)
            } else {
                let task = client._testLoopTask
                #expect(task != nil, "control: sin el candado, el loop arranca")
                await task?.value
                #expect(stub.callCount > 0, "control: y llega a la red")
            }
        }
    }

    // MARK: - Cableado

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // AccountEntry/
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El candado se consulta ANTES de fijar el `context` del canal: sin `context`, ni el push ni la UI bajan nada.
    @Test func groupsChannel_checksTheHoldBeforeKeepingItsContext() throws {
        let client = try source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")
        let start = try #require(client.range(of: "func startIfEligible(context: ModelContext, trigger: String? = nil) {"))
        let body = String(client[start.lowerBound...].prefix(2500))
        let hold = try #require(body.range(of: "guard !accountEntryHold(currentUserIDProvider()) else {"))
        let keep = try #require(body.range(of: "self.context = context"))
        #expect(hold.upperBound <= keep.lowerBound)
        #expect(client.contains("!SwiftDataConfiguration.isRunningTests && AccountEntryGroupsHold.blocksChannel(sub: $0)"))
    }

    /// El Welcome lo arma ANTES de abrir la sesión (antes del atajo de la sesión viva y de la hoja del proveedor), lo retira al
    /// entrar en una cuenta solo de grupos, y al cerrarse sin un adopt que proteger.
    @Test func welcome_armsBeforeSigningIn_andReleasesOnTheExits() throws {
        let view = try source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift")
        let ensure = try #require(view.range(of: "private func ensureSignedIn() async -> Bool {"))
        let body = String(view[ensure.lowerBound...].prefix(1500))
        let arm = try #require(body.range(of: "AccountEntryGroupsHold.arm(sub: CloudAuthService.shared.currentUserID)"))
        let shortcut = try #require(body.range(of: "guard !CloudAuthService.shared.hasSession else { return true }"))
        let signIn = try #require(body.range(of: "try await CloudAuthService.shared.signIn("))
        #expect(arm.upperBound <= shortcut.lowerBound, "armado antes del atajo de la sesión viva")
        #expect(arm.upperBound <= signIn.lowerBound, "armado antes de abrir la sesión")

        let groupsOnly = try #require(view.range(of: "case .enterGroupsOnly, .enterGroupsOnlyOfferingFullActivation:"))
        let tail = String(view[groupsOnly.lowerBound...].prefix(1500))
        let clear = try #require(tail.range(of: "AccountEntryGroupsHold.clear()"))
        let enter = try #require(tail.range(of: "onEnterGroupsOnly("))
        #expect(clear.upperBound <= enter.lowerBound, "la cuenta solo de grupos suelta el canal antes de seguir a Grupos")

        // Al soltar, el canal se arranca: el primer plano que lo habría arrancado lo frenó el candado.
        let start = try #require(tail.range(of:
            "GroupsSyncClient.shared.startIfEligible(context: modelContext, trigger: \"account-entry-groups-only\")"))
        #expect(clear.upperBound <= start.lowerBound && start.upperBound <= enter.lowerBound)

        let retry = try #require(view.range(of: "private func retryAdoptResume() async {"))
        let retryBody = String(view[retry.lowerBound...].prefix(1500))
        let rearm = try #require(retryBody.range(of: "AccountEntryGroupsHold.arm(sub: CloudAuthService.shared.currentUserID)"))
        let adopt = try #require(retryBody.range(of: "await controller.startAdoptWithExistingSession("))
        let resume = try #require(retryBody.range(of: "await controller.resumeIfNeeded()"))
        #expect(rearm.upperBound <= adopt.lowerBound && rearm.upperBound <= resume.lowerBound,
                "un adopt que se retoma o se vuelve a pedir sin pasar por ensureSignedIn vuelve a armar")

        let disappear = try #require(view.range(of: ".onDisappear {\n            flowTask?.cancel()"))
        let onDisappear = String(view[disappear.lowerBound...].prefix(300))
        #expect(onDisappear.contains("AccountEntryGroupsHold.releaseIfNoAdoptPending()"))
    }

    /// Un candado huérfano (la app se cerró en medio del Welcome) no frena a quien entra después por Grupos.
    @Test func groupsSignIn_releasesAnOrphanHoldBeforeStartingTheChannel() throws {
        let modifier = try source("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
        let clear = try #require(modifier.range(of: "AccountEntryGroupsHold.clear()"))
        let start = try #require(modifier.range(of:
            "GroupsSyncClient.shared.startIfEligible(context: modelContext, trigger: \"post-sign-in\")"))
        #expect(clear.upperBound <= start.lowerBound)
    }

    /// Sin journal, el canal frenado vuelve a preguntar cuando conecta: si no, el primer `.active` se comería el intento.
    @Test func groupsChannel_reasksWhenTheJournalConnects() throws {
        let client = try source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")
        let hold = try #require(client.range(of: "guard !accountEntryHold(currentUserIDProvider()) else {"))
        let branch = String(client[hold.lowerBound...].prefix(600))
        #expect(branch.contains("if !journalConnected() { decideLoopModeWhenJournalConnects(context: context, trigger: trigger) }"))
    }
}
