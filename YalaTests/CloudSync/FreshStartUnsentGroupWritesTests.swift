//
//  FreshStartUnsentGroupWritesTests.swift
//  YalaTests / CloudSync
//
//  Ticket `fresh-start-wipe-kills-unsent-group-writes-silently`: «Empezar de cero» borraba el outbox de grupos —los
//  gastos de grupo apuntados sin cobertura— sin subirlos ni decirlo. Desde el 2026-09-26 los tres borrados suben primero
//  (`CloudSessionSignOut.drainGroupsBeforeFreshStart`) y el escritor se niega a tirar filas VIVAS
//  (`DataWipeService.requireNoUnsentGroupWrites`).
//
//  Dos suites. La de comportamiento fija el cinturón del escritor, que es lo que de verdad impide la pérdida: sin él,
//  un cuarto caller volvería a tirar las filas en silencio. La de cableado fija el ORDEN en los tres callers —subir antes
//  del primer borrado—, que un test de comportamiento no alcanza: el camino completo arrastra CloudKit, la red y tres
//  vistas.
//
//  **Lo que NO se prueba aquí, y por qué:** la subida con filas vivas contra el cliente real. `GroupsSyncClient.shared`
//  lee el token del llavero del simulador, y un simulador con una sesión de QA guardada haría una petición de verdad al
//  gateway desde un unit test. El desenlace «no drena ⇒ no se borra» lo cubren el cinturón (comportamiento) y el orden
//  (cableado); el guion de device-QA cubre la subida real.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("«Empezar de cero» no tira los cambios de grupos sin subir", .serialized, .wipeAppGroupMirrorIsolated)
struct FreshStartUnsentGroupWritesTests {

    private func liveRow(_ group: String = "g1") -> GroupSyncOutbox {
        GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: "SplitExpense",
            op: .upsert, hlc: "hlc", fieldsJSON: "{\"amount\":300}", author: "a",
            rejectedReason: nil)
    }

    private func deadLetter(_ group: String = "g1") -> GroupSyncOutbox {
        GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: "SplitExpense",
            op: .upsert, hlc: "hlc", fieldsJSON: "{\"amount\":300}", author: "a",
            rejectedReason: "upstream_400:x")
    }

    private func clearOutbox(_ context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        try context.save()
    }

    // MARK: - El cinturón del escritor

    /// **El canario del ticket.** Con un gasto de grupo sin subir, el borrado del dominio se NIEGA y no toca nada: ni las
    /// filas, ni el outbox, ni el sello, ni la sesión, ni las preferencias. Todo lo que hace después del cinturón es
    /// irreversible o casi, así que «se negó a medias» sería otra forma de perderlo.
    @Test func wipe_withALiveOutboxRow_refusesAndTouchesNothing() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let group = SplitGroup(name: "Viaje a Cusco")
        context.insert(group)
        context.insert(liveRow())
        try context.save()
        let groupsBefore = try context.fetchCount(FetchDescriptor<SplitGroup>())
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        var retired = 0
        var reset = 0

        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 1)) {
            try DataWipeService.wipeLocalGroupsDomain(
                in: context, defaults: defaults,
                retireCloudSession: { retired += 1 }, resetSyncState: { reset += 1 })
        }

        #expect(CloudSessionSignOut.liveGroupsPendingCount(context: context) == 1,
                "el gasto que no subió sigue en el outbox: es lo que el ticket perdía")
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == groupsBefore,
                "los grupos siguen: el borrado no empezó")
        #expect(!defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart),
                "sin sello: el relevo no ocurrió")
        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey),
                "sin arm del retiro: la sesión que tiene que subir esas filas no se toca")
        #expect(retired == 0 && reset == 0, "ni el retiro de la sesión ni la purga del espejo corrieron")
        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsBetaUnlocked),
                "las preferencias del dominio siguen: se barren después del cinturón")

        try clearOutbox(context)
        context.delete(group)
        try context.save()
    }

    /// Las dead-letter SÍ se van: el servidor ya las rechazó para siempre, y el cierre tampoco las espera. Un cinturón
    /// que contara todas las filas bloquearía «Empezar de cero» para siempre a quien tenga una.
    @Test func wipe_withOnlyDeadLetters_proceedsAndClearsThem() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        context.insert(deadLetter("g1"))
        context.insert(deadLetter("g2"))
        try context.save()

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(), retireCloudSession: {}, resetSyncState: {})

        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0)
    }

    /// El cinturón suelto, que es lo que los callers llaman ANTES de `wipeAllUserData`. Cuenta las vivas, no todas.
    @Test func requireNoUnsentGroupWrites_countsOnlyLiveRows() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        try DataWipeService.requireNoUnsentGroupWrites(in: context)

        context.insert(deadLetter())
        try context.save()
        try DataWipeService.requireNoUnsentGroupWrites(in: context)

        context.insert(liveRow("g1"))
        context.insert(liveRow("g2"))
        try context.save()
        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 2)) {
            try DataWipeService.requireNoUnsentGroupWrites(in: context)
        }
        try clearOutbox(context)
    }

    // MARK: - La subida previa, sin red

    /// Con el outbox vacío la subida sale `.drained` **sin un solo ciclo**: es el caso de casi todo el mundo, y un
    /// «Empezar de cero» que se parara aquí sería la regresión contraria. Y retira el bloqueo de un intento anterior,
    /// que se siembra antes para que esa aserción pueda fallar.
    @Test func drain_withNothingPending_isDrainedAndClearsTheBlock() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        CloudSessionSignOut.shared.noteFreshStartGroupsPending(context: context, reason: .sessionExpired)
        #expect(CloudSessionSignOut.shared.freshStartGroupsBlock != nil, "control: el bloqueo anterior está puesto")
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(context: context)
        #expect(verdict == .drained)
        #expect(CloudSessionSignOut.shared.freshStartGroupsBlock == nil)
    }

    /// El veredicto de la subida, cada desenlace. El motivo definitivo viaja TAL CUAL (el bug del 2026-09-13 era
    /// aplanarlo), y lo pasajero y la cancelación son `.transient`. `nil` solo cuando drenó.
    @Test func drainVerdict_keepsTheReason_andOnlyDrainedProceeds() {
        typealias Push = CloudSessionSignOut.BudgetedGroupsPush
        #expect(CloudSessionSignOut.freshStartBlock(for: Push.drained) == nil)
        for reason in [CloudSignOutFlowLogic.BlockReason.sessionExpired, .channelPaused, .uploadRetryLater,
                       .attestUnavailable, .permanent] {
            #expect(CloudSessionSignOut.freshStartBlock(for: Push.surfacePermanent(pending: 2, reason: reason))
                    == .init(pendingCount: 2, reason: reason))
        }
        #expect(CloudSessionSignOut.freshStartBlock(for: Push.surfaceTransient(pending: 3))
                == .init(pendingCount: 3, reason: .transient))
        #expect(CloudSessionSignOut.freshStartBlock(for: Push.cancelled(pending: 4))
                == .init(pendingCount: 4, reason: .transient))
    }

    /// Lo que el alert del shell y el cinturón dejan cuando no van a esperar: la cifra VIVA y el motivo que se pasa.
    @Test func notePending_countsTheLiveRows() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        context.insert(liveRow("g1"))
        context.insert(liveRow("g2"))
        context.insert(deadLetter())
        try context.save()
        CloudSessionSignOut.shared.noteFreshStartGroupsPending(context: context, reason: .uploadRetryLater)
        #expect(CloudSessionSignOut.shared.freshStartGroupsBlock == .init(pendingCount: 2, reason: .uploadRetryLater))
        try clearOutbox(context)
        #expect(CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context))
        #expect(CloudSessionSignOut.shared.freshStartGroupsBlock == nil, "el intento nuevo retira el bloqueo")
    }

    /// El pre-check síncrono del alert del shell: `true` solo sin filas vivas. Es lo que decide si el borrado sigue en
    /// el mismo tap o pasa por la subida.
    @Test func settledEmpty_readsLiveRowsOnly() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        #expect(CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context))

        context.insert(deadLetter())
        try context.save()
        #expect(CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context))

        context.insert(liveRow())
        try context.save()
        #expect(!CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context))
        try clearOutbox(context)
    }

    // MARK: - El copy

    /// Primero lo que importa —no se borró nada, y cuántos cambios—, detrás el motivo con el texto del cierre de sesión.
    @Test func pendingMessage_leadsWithTheCount_thenTheReason() {
        let block = CloudSessionSignOut.FreshStartGroupsBlock(pendingCount: 3, reason: .uploadRetryLater)
        #expect(SignOutBlockedCopy.freshStartGroupsPendingMessage(block)
                == L10n.Groups.FreshStartPending.lead(3) + " " + L10n.Groups.Errors.uploadRetryLater)
    }

    /// `Int.max` es «no se pudo contar»: el texto va sin cifra, nunca con un número imposible.
    @Test func pendingMessage_withoutAnHonestCount_dropsTheNumber() {
        let block = CloudSessionSignOut.FreshStartGroupsBlock(pendingCount: Int.max, reason: .sessionExpired)
        let message = SignOutBlockedCopy.freshStartGroupsPendingMessage(block)
        #expect(message.hasPrefix(L10n.Groups.FreshStartPending.leadUnknown))
        #expect(!message.contains(String(Int.max)))
    }
}

/// El ORDEN en los tres callers y el contrato de la subida (source-scan, molde `PrivateSignOutWiringTests`). Cada
/// aserción nombra lo que se rompe si alguien mueve una línea: un test de comportamiento no llega hasta aquí.
@Suite("«Empezar de cero» · cableado de la subida previa (source-scan)")
struct FreshStartUnsentGroupWritesWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de la función que abre `marker` (que termina en su `{`).
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    private static func expectOrder(_ first: String, before second: String, in body: String,
                                    _ why: Comment) throws {
        let a = try #require(body.range(of: first), "falta `\(first)`")
        let b = try #require(body.range(of: second), "falta `\(second)`")
        #expect(a.lowerBound < b.lowerBound, why)
    }

    private static let contentView = "Yala/App/ContentView.swift"
    private static let shellAlerts = "Yala/App/Views/Shared/ShellDataAlertsModifier.swift"
    private static let signOut = "Yala/Services/CloudSync/CloudSessionSignOut.swift"
    private static let dataWipe = "Yala/Utils/DataWipeService.swift"

    @Test("el borrado del teléfono sube los grupos antes de tocar nada")
    func deviceWipe_uploadsFirst() throws {
        let wipe = try Self.body(of: "private func performDeviceCorpusWipe() async -> String? {",
                                 in: Self.source(Self.contentView))
        let drain = "if let failure = await drainGroupsBeforeFreshStart() { return failure }"
        try Self.expectOrder(drain, before: "cancelWipeGrace()", in: wipe,
                             "la gracia se cancela solo cuando el borrado va a ocurrir")
        try Self.expectOrder(drain, before: "DataWipeService.wipeAllUserData(", in: wipe,
                             "sin subir antes, el borrado se lleva los gastos de grupo sin cobertura")
        try Self.expectOrder("DataWipeService.requireNoUnsentGroupWrites(in: modelContext)",
                             before: "DataWipeService.wipeAllUserData(", in: wipe,
                             "el cinturón va antes del primer borrado, o una fila tardía deja medio borrado")
        // Y si el cinturón salta, lo que se dice es «faltan cambios», no el fallo genérico: no se borró nada.
        let belt = try #require(wipe.range(of: "} catch is DataWipeService.GroupsDomainWipeError {"))
        let generic = try #require(wipe.range(of: "return \"deviceWipeFailed\""))
        #expect(belt.lowerBound < generic.lowerBound)
        #expect(wipe.contains("noteFreshStartGroupsPending(context: modelContext, reason: .uploadRetryLater)\n"
                              + "            return CloudSessionSignOut.freshStartGroupsPendingFailure"))
    }

    /// El envoltorio de `ContentView` traduce el veredicto al contrato de fallo de los borrados y vuelve a esperar al
    /// import tras subir. Un `.blocked` que devolviera `nil` dejaría seguir el borrado (el cinturón lo pararía después,
    /// en iCloud con la zona ya borrada).
    @Test("el envoltorio de ContentView no deja seguir un bloqueo y re-espera al import")
    func contentViewDrain_mapsTheVerdict() throws {
        let helper = try Self.body(of: "private func drainGroupsBeforeFreshStart() async -> String? {",
                                   in: Self.source(Self.contentView))
        #expect(helper.contains("case .drained: break"))
        #expect(helper.contains("case .blocked: return CloudSessionSignOut.freshStartGroupsPendingFailure"))
        #expect(helper.contains("case .busy: return \"signOutBusy\""))
        try Self.expectOrder("drainGroupsBeforeFreshStart(context: modelContext)",
                             before: "waitForImportQuiescence(timeout: 30)", in: helper,
                             "la espera del import va DESPUÉS de la subida, pegada al borrado")
        #expect(helper.contains("guard quiescent else { return \"importNotQuiescent\" }"))
    }

    /// La reanudación ciega del arranque se DESARMA si se para en los cambios de grupos: dejarla armada borraba todo,
    /// semanas después, en cuanto subían.
    @Test("la reanudación del arranque se desarma al pararse en los cambios de grupos")
    func blindResume_disarmsOnGroupsPending() throws {
        let check = try Self.body(of: "private func runLateICloudMirrorCheck() async {", in: Self.source(Self.contentView))
        #expect(check.contains("if failure == CloudSessionSignOut.freshStartGroupsPendingFailure {\n"
                               + "                StorageModePersistence.clearICloudCorpusWipeArm()\n            }"))
        try Self.expectOrder("StorageModePersistence.clearICloudCorpusWipeArm()", before: "guard failure == nil else { return }",
                             in: check, "el desarme va antes de salir por el fallo")
    }

    @Test("el borrado de iCloud sube los grupos antes de la zona, y solo cuando purga el dominio")
    func iCloudWipe_uploadsBeforeTheZone() throws {
        let wipe = try Self.body(of: "private func performICloudCorpusWipe(_ scope: ICloudWipeScope) async -> String? {",
                                 in: Self.source(Self.contentView))
        let drain = "let failure = await drainGroupsBeforeFreshStart()"
        try Self.expectOrder(drain, before: "await ICloudPersonalCorpusProbe.wipe()", in: wipe,
                             "parado después de la zona, iCloud ya estaría vacío con los grupos sin subir")
        #expect(wipe.contains("if scope.purgesGroupsDomain,\n           \(drain)"),
                "solo el alcance que se lleva el outbox tiene que esperarlo; los otros dos no lo tocan")
        try Self.expectOrder("if scope.purgesGroupsDomain { try DataWipeService.requireNoUnsentGroupWrites(in: modelContext) }",
                             before: "DataWipeService.wipeAllUserData(", in: wipe,
                             "entre la subida y las filas hubo un `await` (la zona): el cinturón va antes de ellas")
    }

    @Test("el alert del shell solo borra con el outbox vacío, y si no avisa en el mismo tap")
    func shellAlert_refusesWhileGroupsArePending() throws {
        let src = try Self.source(Self.shellAlerts)
        #expect(src.contains("if CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: modelContext) {\n"
                             + "                        performFreshStartWipe()\n"
                             + "                    } else {\n"
                             + "                        refuseWhileGroupsArePending()"),
                "el tap borra SOLO con el outbox vacío; si no, se niega")
        let refuse = try Self.body(of: "private func refuseWhileGroupsArePending() {", in: src)
        try Self.expectOrder("noteFreshStartGroupsPending(context: modelContext, reason: .uploadRetryLater)",
                             before: "showFreshStartWipeFailedAlert = true", in: refuse,
                             "el aviso lee el bloqueo: tiene que estar puesto antes de encenderlo")
        #expect(!refuse.contains("Task"), """
            El aviso vuelve a encenderse desde un `Task`: con el cover del Welcome desmontado por el alert, la subida \
            corre sobre una pantalla negra y el aviso compite por el anchor (review adversarial del 2026-09-26).
            """)
        let wipe = try Self.body(of: "private func performFreshStartWipe() {", in: src)
        try Self.expectOrder("DataWipeService.requireNoUnsentGroupWrites(in: modelContext)",
                             before: "DataWipeService.wipeAllUserData(", in: wipe,
                             "el cinturón va antes del primer borrado")
        try Self.expectOrder("} catch is DataWipeService.GroupsDomainWipeError {\n            refuseWhileGroupsArePending()",
                             before: "MetricsService.canary(.freshStartWipeFailed", in: wipe,
                             "el cinturón se dice como «faltan cambios», no como un borrado que falló")
        // Dos apariciones fuera de comentarios: la declaración y la llamada del tap con el outbox vacío. Una llamada
        // más se saltaría la comprobación.
        #expect(src.components(separatedBy: "performFreshStartWipe()").count - 1 == 2,
                "el borrado del alert tiene un solo llamador")
    }

    @Test("el escritor se niega antes de su primer borrado")
    func writer_checksBeforeDeleting() throws {
        let src = try Self.source(Self.dataWipe)
        let start = try #require(src.range(of: "static func wipeLocalGroupsDomain("))
        let rest = String(src[start.upperBound...])
        try Self.expectOrder("try requireNoUnsentGroupWrites(in: context)",
                             before: "try deleteLocalGroupsRows(in: context)", in: rest,
                             "el cinturón tiene que correr antes de borrar la primera fila")
    }

    @Test("la subida previa no toca la fase del coordinador, y exige que esté libre")
    func drain_leavesThePhaseAlone() throws {
        let drain = try Self.body(
            of: "func drainGroupsBeforeFreshStart(context: ModelContext) async -> FreshStartGroupsDrain {",
            in: Self.source(Self.signOut))
        #expect(!drain.contains("phase = ."), """
            La subida de «Empezar de cero» escribió la fase del coordinador. `.working` y `.blocked` los leen la matriz \
            de readiness, la fila de cierre del Perfil y la puerta de Grupos del Welcome: encenderían su propia pantalla.
            """)
        #expect(drain.contains("guard phase == .idle, !freshStartDrainInFlight else { return .busy }"),
                "con un cierre en vuelo, dos subidas del mismo outbox a la vez")
        try Self.expectOrder("freshStartDrainInFlight = true", before: "await pushGroupsWithinBudget", in: drain,
                             "la marca va antes de la primera espera de la subida")
        #expect(drain.contains("defer {\n            freshStartDrainInFlight = false"))
        // Y los dos gestos que suben el mismo outbox la respetan.
        let src = try Self.source(Self.signOut)
        #expect(src.components(separatedBy: "guard phase == .idle, !freshStartDrainInFlight else").count - 1 == 3,
                "la subida, el cierre de sesión y el desasociar")
        try Self.expectOrder("freshStartGroupsBlock = nil", before: "guard phase == .idle", in: drain,
                             "un `.busy` no puede dejar a la vista el bloqueo de un intento anterior")
        // Sin nada pendiente sale ANTES de la primera espera: la quiescencia estricta del cierre bloqueaba «Empezar de
        // cero» con cero cambios cuando el import de iCloud no se había asentado.
        let fastPath = try #require(drain.range(of: "if groupsOutboxIsSettledEmpty(context: context) { return .drained }"),
                                    "falta el atajo del outbox vacío")
        let firstAwait = try #require(drain.range(of: "await "))
        #expect(fastPath.lowerBound < firstAwait.lowerBound,
                "el atajo va antes de cualquier `await`, o el caso vacío vuelve a esperar la quiescencia")
    }

    /// El bucle del presupuesto salió de `pushGroupsForSignOut` para compartirlo. Tiene que seguir devolviendo el motivo
    /// TAL CUAL (el bug de 2026-09-13 era un ternario que lo aplanaba a `.permanent`).
    @Test("el bucle compartido devuelve el motivo sin aplanarlo")
    func budgetLoop_keepsTheReason() throws {
        let loop = try Self.body(
            of: "private func pushGroupsWithinBudget(context: ModelContext) async -> BudgetedGroupsPush {",
            in: Self.source(Self.signOut))
        #expect(loop.contains("return .surfacePermanent(pending: pending, reason: reason)"))
        #expect(!loop.contains(".permanent"), "volvió un colapso a `.permanent` en el bucle compartido")
    }

    @Test("las dos pantallas con fases enseñan «faltan cambios de grupos», no el fallo genérico")
    func screens_mapTheFailureToTheirPendingPhase() throws {
        let gate = try Self.source("Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift")
        #expect(gate.contains("phase = groupsPendingPhase(for: failure, retry: .iCloud) ?? .wipeFailed"))
        #expect(gate.contains("phase = groupsPendingPhase(for: failure, retry: .device(iCloudUnverified: iCloudUnverified))\n"
                              + "                ?? .deviceWipeFailed(iCloudUnverified: iCloudUnverified)"))
        #expect(gate.contains("if phase == .wipeFailed || isDeviceWipeFailed || isGroupsPending || isUnverified {"),
                "irse desde «faltan cambios» retira el arm, como desde cualquier borrado que no borró")
        let late = try Self.source("Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift")
        #expect(late.contains("phase = .groupsPending(block)"))
        // Salir de «faltan cambios» desarma, por el botón y por la barra: armado, el arranque reanudaba el borrado a
        // ciegas semanas después (review adversarial del 2026-09-26, las tres lentes).
        let leave = try Self.body(of: "private func leaveGroupsPending() {", in: late)
        #expect(leave.contains("StorageModePersistence.clearICloudCorpusWipeArm()"))
        #expect(late.contains("destructiveAction: leaveGroupsPending)"))
        #expect(late.contains("if case .groupsPending = phase { StorageModePersistence.clearICloudCorpusWipeArm() }"))
    }
}
