//
//  FreshStartAfterAdoptExitTests.swift
//  YalaTests / CloudSync
//
//  Ticket `fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes` (decisión A de Jürgen, 2026-10-06).
//  Alguien empieza a entrar con su cuenta en la nube desde la bienvenida, el adopt falla o lo cancela, vuelve a la
//  bienvenida y elige «Soy nuevo → privacidad total». Con datos en el teléfono y cambios de grupos que no pueden subir,
//  «Borrar todo y continuar» se negaba para siempre: el adopt deja `hasCompletedOnboarding` en `true`, y el alert lo
//  tomaba por «no hay Welcome debajo». Desde aquí sigue en la puerta privada, que ofrece perderlos con su cifra.
//
//  Tres capas: la decisión pura (la celda del ticket sale roja con la guarda vieja: mutante M0), el cableado que la
//  alimenta (source-scan, porque el testigo vive en `@State` de SwiftUI) y la mitad de la puerta con cambios de OTRA
//  cuenta (espejo y filas reales: oferta con su cifra, y aceptarla borra).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - La decisión

@Suite("«Empezar de cero» tras salir de un adopt · a dónde sigue con grupos pendientes")
struct FreshStartAfterAdoptExitRoutingTests {

    typealias Logic = FreshStartAlertRoutingLogic

    /// **El caso del ticket**: el adopt salió (por error, por su techo, por linaje o cancelado) y dejó el onboarding
    /// completo; el alert se encendió con el Welcome debajo. Sigue en la puerta, no se niega.
    @Test func afterAnAdoptExit_withTheWelcomeUnderneath_continuesInTheGate() {
        #expect(Logic.pendingGroupsRoute(hasCompletedOnboarding: true, presentedOverWelcome: true) == .privateGate)
    }

    /// **Control: el camino de siempre** — onboarding sin completar, desde el Welcome.
    @Test func freshInstall_fromTheWelcome_continuesInTheGate() {
        #expect(Logic.pendingGroupsRoute(hasCompletedOnboarding: false, presentedOverWelcome: true) == .privateGate)
    }

    /// **Sin Welcome debajo y con el onboarding completo, lo de hoy**: se niega en el sitio. Abrir el Welcome ahí le
    /// plantaría el flujo de bienvenida a alguien que ya usa la app. Hoy ningún camino produce esta celda —el alert solo
    /// se dispara desde el Welcome, y el cableado de abajo cuenta los disparadores—: el caso fija la red para el día que
    /// aparezca otro.
    @Test func completedOnboarding_withoutTheWelcome_stillRefusesInPlace() {
        #expect(Logic.pendingGroupsRoute(hasCompletedOnboarding: true, presentedOverWelcome: false) == .refuseInPlace)
    }

    /// **La guarda vieja sigue siendo término**: sin onboarding completo va a la puerta aunque el testigo diga que no
    /// había Welcome. Es la celda que hoy iba a la puerta y no debe dejar de ir.
    @Test func incompleteOnboarding_withoutTheWitness_keepsGoingToTheGate() {
        #expect(Logic.pendingGroupsRoute(hasCompletedOnboarding: false, presentedOverWelcome: false) == .privateGate)
    }
}

// MARK: - El cableado

@Suite("«Empezar de cero» tras salir de un adopt · cableado (source-scan)")
struct FreshStartAfterAdoptExitWiringTests {

    private static let shell = "Yala/App/Views/Shared/ShellDataAlertsModifier.swift"
    private static let contentView = "Yala/App/ContentView.swift"
    private static let cloudSignIn = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Las líneas de código, sin comentarios: el porqué se escribe nombrando estos mismos símbolos.
    private static func code(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo en una línea: cada línea recortada y unidas por un espacio, sin las vacías.
    private static func flat(_ text: String) -> String {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func slice(from marker: String, to end: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no está: \(marker)")
        let rest = source[start.upperBound...]
        let stop = rest.range(of: end)?.lowerBound ?? rest.endIndex
        return String(rest[..<stop])
    }

    /// **La ruta pregunta a la lógica con el testigo**, y la negativa queda solo para lo que la lógica no manda a la
    /// puerta. La guarda vieja —`guard !hasCompletedOnboarding else`— ya no decide sola.
    @Test func theRoute_asksTheLogicWithTheWitness() throws {
        let src = try Self.source(Self.shell)
        let route = Self.flat(Self.code(try Self.slice(from: "private func continueInTheGateWhileGroupsArePending() {",
                                                       to: "\n    }\n", in: src)))
        #expect(route.hasPrefix(
            "guard FreshStartAlertRoutingLogic.pendingGroupsRoute( hasCompletedOnboarding: hasCompletedOnboarding, "
            + "presentedOverWelcome: freshStartAlertPresentedOverWelcome) == .privateGate else { "
            + "refuseWhileGroupsArePending() return } "
            + "WelcomePrivateICloudGateView.armDeviceWipeHandoff() "
            + "welcomeFlowInitialStep = .freshStartDeviceWipe showWelcomeFlow = true"),
            "la ruta entera: decide la lógica con el testigo, y si no niega; si sí, la puerta. Leída: \(route)")
        #expect(route.components(separatedBy: "refuseWhileGroupsArePending()").count - 1 == 1,
                "una sola negativa: la del `else` de la lógica")
        // Y el testigo es una constante que pasa ContentView, no un estado propio del modifier que nadie escribe.
        #expect(src.contains("    let freshStartAlertPresentedOverWelcome: Bool\n"))
    }

    /// **El testigo se escribe con `showWelcomeFlow` ANTES de encender el alert**, en su único disparador. Después ya no
    /// sirve: presentar el alert desmonta el cover y baja `showWelcomeFlow`.
    @Test func theWitness_isCapturedBeforeTheAlertIsShown() throws {
        let src = Self.code(try Self.source(Self.contentView))
        let trigger = try Self.slice(from: "private func startFreshPrivateOnboarding() {",
                                     to: "\n    }\n", in: src)
        let capture = try #require(trigger.range(of: "freshStartAlertPresentedOverWelcome = showWelcomeFlow"))
        let show = try #require(trigger.range(of: "showFreshStartWipeAlert = true"))
        #expect(capture.lowerBound < show.lowerBound, "capturado después, ya no hay Welcome que ver")

        // Un solo escritor del testigo y un solo disparador del alert: un segundo que encendiera el alert sin escribirlo
        // heredaría el testigo del intento anterior.
        #expect(src.components(separatedBy: "freshStartAlertPresentedOverWelcome = ").count - 1 == 1)
        #expect(src.components(separatedBy: "showFreshStartWipeAlert = true").count - 1 == 1)
        // Y llega al modifier del alert como valor, y al del Welcome como binding.
        #expect(src.contains("freshStartAlertPresentedOverWelcome: freshStartAlertPresentedOverWelcome,"))
        #expect(src.contains("freshStartAlertPresentedOverWelcome: $freshStartAlertPresentedOverWelcome,"))
    }

    /// **Las cuatro salidas del adopt comparten camino**: error, `.adoptExit` y `.lineageExit` salen por la flecha
    /// (`canGoBack`) y «Cancelar la activación» por `cancelLanded`, todas a `onBack`. Y `onBack` reabre el Welcome sin
    /// bajar `hasCompletedOnboarding`: es justo la celda (onboarding completo, Welcome debajo) de la lógica. Si algún día
    /// una de ellas saliera por otro sitio, este test lo dice antes de que la celda deje de ser la suya.
    @Test func everyAdoptExit_returnsToTheWelcomeThroughOnBack() throws {
        let view = Self.code(try Self.source(Self.cloudSignIn))
        #expect(view.contains(".welcomeBackButton(tint: .white, action: canGoBack ? onBack : nil)"))
        // Las tres fases de salida están en el `case` que deja la flecha; sin fijar el resto de la lista.
        let canGoBack = try Self.slice(from: "private var canGoBack: Bool {", to: "\n    }\n", in: view)
        let arrowCase = try #require(canGoBack.split(separator: "\n").first { $0.hasSuffix(": true") })
        for exit in [".error,", ".adoptExit,", ".lineageExit,"] {
            #expect(arrowCase.contains(exit), "la flecha ya no saca de \(exit)")
        }
        #expect(Self.flat(view).contains("if cancelLanded(controller) { onBack() return }"))
        #expect(!view.contains("hasCompletedOnboarding = false"), "una salida del adopt que bajara el flag sería la opción B")

        let content = Self.code(try Self.source(Self.contentView))
        let onBack = try Self.slice(from: "onBack: {\n                        showWelcomeCloudSignIn = false",
                                    to: "\n                    }", in: content)
        #expect(onBack.contains("welcomeFlowInitialStep = .chooser"))
        #expect(onBack.contains("showWelcomeFlow = true"))
        #expect(!onBack.contains("hasCompletedOnboarding"))
        // El `true` temprano del adopt se queda: es su kill-safety, y este ticket no la toca.
        let started = try Self.slice(from: "onAdoptStarted: {", to: "\n                    },", in: content)
        #expect(started.contains("hasCompletedOnboarding = true"))
    }

    /// **Las demás salidas del alert no cambian**: «Cancelar» y el «OK» del aviso de fallo, con su cuerpo entero (el
    /// mismo `if !hasCompletedOnboarding` de antes; tienen su ticket aparte), y el botón destructivo, que sin pendientes
    /// borra en el mismo tap.
    @Test func theOtherExits_areUnchanged() throws {
        let src = Self.code(try Self.source(Self.shell))
        let reopen = "if !hasCompletedOnboarding { welcomeFlowInitialStep = .chooser showWelcomeFlow = true }"
        let cancel = Self.flat(try Self.slice(from: "Button(L10n.Action.cancel, role: .cancel) {", to: ".tint(.primary)", in: src))
        #expect(cancel == "showFreshStartWipeAlert = false " + reopen + " }", "Cancelar: \(cancel)")
        let ok = Self.flat(try Self.slice(from: "Button(L10n.Common.ok, role: .cancel) {", to: ".tint(.primary)", in: src))
        #expect(ok == "showFreshStartWipeFailedAlert = false " + reopen + " }", "OK: \(ok)")
        let confirm = Self.flat(try Self.slice(from: "Button(L10n.Welcome.FreshStart.alertConfirm, role: .destructive) {",
                                               to: "Button(L10n.Action.cancel, role: .cancel) {", in: src))
        #expect(confirm == "showFreshStartWipeAlert = false "
                + "if !Self.purgesGroupsDomainNow() "
                + "|| CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: modelContext) { performFreshStartWipe() } "
                + "else { continueInTheGateWhileGroupsArePending() } }", "Borrar todo: \(confirm)")
    }
}

// MARK: - La puerta, con cambios de otra cuenta

@MainActor
@Suite("«Empezar de cero» tras salir de un adopt · la puerta ofrece perder los de otra cuenta",
       .serialized, .wipeAppGroupMirrorIsolated)
struct FreshStartAfterAdoptExitGateTests {

    typealias Block = CloudSessionSignOut.FreshStartGroupsBlock

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FSAdoptExit-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func clearOutbox(_ context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        try context.save()
    }

    private func resetCoordinator(_ context: ModelContext) {
        _ = CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context, witness: .quiet)
    }

    private func foreignEntry(_ i: Int) -> GroupsOutboxMirrorEntry {
        GroupsOutboxMirrorEntry(
            userID: "sub-b", syncID: UUID(), groupID: "SplitGroup-A", entityType: GroupSyncEntityType.splitExpense,
            op: SyncOutboxOp.upsert.rawValue,
            hlc: "2026-10-06T00:00:00.000Z-\(String(format: "%04d", 100 + i))-00000000000000bb",
            clientMutationID: UUID(), fieldsJSON: "{\"amount\":\"30.0000\"}", fieldHlcsJSON: nil, tombstoneReason: nil,
            author: GroupsOutboxMirror.author, createdAt: .now)
    }

    /// Qué sesión hay al volver al Welcome tras salir del adopt. La que abrió el intento se cierra al salir (regla «Y la
    /// sesión que abrió el adopt se cierra cuando el adopt sale»), así que lo normal es ninguna; si el adopt reusó una
    /// sesión que ya estaba —la de Grupos—, sigue abierta, y los cambios del espejo son de OTRA cuenta.
    enum SessionAfterTheExit: CaseIterable, Sendable {
        case closedByTheAdopt, anotherAccountOpen
        var owner: String? { self == .closedByTheAdopt ? nil : "sub-a" }
        var reason: CloudSignOutFlowLogic.BlockReason {
            self == .closedByTheAdopt ? .sessionExpired : .groupsChangesFromAnotherAccount
        }
        /// El «¿seguro?» con la cifra. Sin sesión nadie sabe de quién son y sale el texto de siempre; con la sesión de
        /// otra cuenta abierta, el neutro (`fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason`).
        func confirmBody(_ count: Int) -> String {
            self == .closedByTheAdopt
                ? L10n.Groups.FreshStartPending.lossConfirmBody(count)
                : L10n.Groups.FreshStartPending.lossConfirmBodyNeutral(count)
        }
    }

    /// El testigo con el espejo, el filtro y la regla de dueño REALES (`owner`, `nil` = sin sesión).
    private func witness(_ mirror: GroupsOutboxMirror, owner: String?) -> CloudSessionSignOut.GroupsExitWitness {
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in true },
            mirrorPending: { context, scope in
                GroupsSyncClient.mirrorEntriesMissingFromOutbox(
                    mirror: mirror, ownerID: owner, scope: scope, context: context)
            },
            mirrorPendingKeys: { context, scope in
                GroupsSyncClient.mirrorEntryKeysMissingFromOutbox(
                    mirror: mirror, ownerID: owner, scope: scope, context: context)
            })
        witness.heldForAnotherAccount = { context in
            GroupsSyncClient.liveRowsHeldForAnotherAccount(sessionOwner: owner, context: context)
        }
        witness.mirrorPendingOfAnotherAccount = { context in
            GroupsSyncClient.mirrorEntriesMissingFromOutbox(
                mirror: mirror, ownerID: owner, scope: .anotherAccount, context: context)
        }
        witness.uncapturedChanges = { _ in [] }
        witness.cycle = { _ in
            CloudSessionSignOut.GroupsCycleReading(
                outcome: .completed, channelKilled: false, attestUnavailable: false, uploadFailed: false)
        }
        return witness
    }

    /// **El criterio del ticket, en la mitad de la puerta**: dos cambios de grupos de otra cuenta en el espejo. La subida
    /// previa se para con su motivo y su cifra, ofrece perderlos, y aceptarlo deja pasar al cinturón y al borrado del
    /// dominio, que sella el relevo. Es lo que el alert, desde hoy, alcanza tras salir de un adopt.
    ///
    /// **Esta suite no toca la guarda** (la prueban las dos de arriba): fija que la puerta a la que ahora se llega tiene,
    /// en las dos sesiones posibles tras la salida, la salida que el ticket pide. Los motivos son los dos que ofrecen
    /// perderlos (`CloudSignOutFlowLogic.freshStartOffersGroupsLossExit`).
    @Test(arguments: SessionAfterTheExit.allCases)
    func anotherAccountsChanges_areOfferedWithTheirCount_andAcceptingWipes(session: SessionAfterTheExit) async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        defer {
            try? clearOutbox(context)
            resetCoordinator(context)
        }
        let dir = freshDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mirror = GroupsOutboxMirror(directoryURL: dir)
        try mirror.write(foreignEntry(0))
        try mirror.write(foreignEntry(1))
        let witness = witness(mirror, owner: session.owner)

        // 1 · La oferta, con su cifra y su motivo.
        let first = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(context: context, witness: witness)
        guard case .blocked(let block) = first else {
            Issue.record("sin bloqueo: \(first)")
            return
        }
        #expect(block.reason == session.reason)
        #expect(block.pendingCount == 2, "la cifra es lo que el borrado se llevaría")
        #expect(block.offersLossExit, "esperar no los sube: se ofrece perderlos")
        #expect(SignOutBlockedCopy.freshStartGroupsLossConfirmMessage(block) == session.confirmBody(2),
                "el «¿seguro?» dice la cifra")

        // 2 · Aceptar, y el borrado vuelve a subir con lo aceptado: sigue perdiendo exactamente eso.
        #expect(CloudSessionSignOut.shared.acceptFreshStartGroupsLoss())
        let accepted = try #require(CloudSessionSignOut.shared.takeFreshStartAcceptedLoss())
        let second = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness, accepted: accepted)
        #expect(second == .lossAccepted(accepted))

        // 3 · El cinturón deja pasar lo aceptado y el borrado del dominio termina y sella.
        try DataWipeService.requireNoUnsentGroupWrites(in: context, witness: witness, accepting: accepted)
        let defaults = makeIsolatedDefaults()
        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: defaults, retireCloudSession: {}, resetSyncState: {}, witness: witness,
            acceptedGroupsLoss: accepted)
        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart), "el relevo ocurrió entero")
    }

    /// **Control: sin aceptar, el cinturón se niega** y no se toca nada. La salida es la del «¿seguro?», no la del tap.
    @Test func withoutAccepting_theBeltRefuses() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        defer {
            try? clearOutbox(context)
            resetCoordinator(context)
        }
        let dir = freshDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let mirror = GroupsOutboxMirror(directoryURL: dir)
        try mirror.write(foreignEntry(0))
        let witness = witness(mirror, owner: nil)

        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(context: context, witness: witness)
        guard case .blocked(let block) = verdict else {
            Issue.record("sin bloqueo: \(verdict)")
            return
        }
        #expect(block.offersLossExit)
        #expect(throws: DataWipeService.GroupsDomainWipeError.self) {
            try DataWipeService.requireNoUnsentGroupWrites(in: context, witness: witness)
        }
    }
}
