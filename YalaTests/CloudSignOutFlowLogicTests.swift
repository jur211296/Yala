//
//  CloudSignOutFlowLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Cerrar sesión — camino por modo y visibilidad (H4 + G5-B)")
struct CloudSignOutFlowLogicTests {

    // Helper: la matriz sin canal ni sesión backend debe ser byte-idéntica a la de antes de Grupos→backend.
    private func path(_ mode: StorageMode, secondary: Bool) -> CloudSignOutFlowLogic.Path {
        CloudSignOutFlowLogic.path(
            for: mode, secondarySessionActive: secondary,
            hasLiveSession: false, groupsBackendEnabled: false)
    }

    @Test
    func icloud_usesPrivateReset() {
        #expect(path(.icloud, secondary: false) == .privateReset)
    }

    @Test
    func cloud_usesCloudSecureSignOut() {
        #expect(path(.cloud, secondary: false) == .cloudSecureSignOut)
    }

    @Test
    func secondarySession_winsOverBothModes() {
        // M1 — la trampa de la atomicidad: en secundaria el modo EFECTIVO es `.cloud`; sin esta
        // rama el sign-out iría a `.cloudSecureSignOut` → armSignOutWipe → el boot borraría el
        // YalaModel del DUEÑO. La secundaria gana sobre cualquier modo.
        #expect(path(.cloud, secondary: true) == .secondaryCloudSignOut)
        #expect(path(.icloud, secondary: true) == .secondaryCloudSignOut)
    }

    // MARK: - Fila NUEVA (G5-B): solo-grupos + precedencias

    @Test
    func groupsOnly_whenFlagOnAndLiveSessionAndICloud() {
        #expect(CloudSignOutFlowLogic.path(
            for: .icloud, secondarySessionActive: false,
            hasLiveSession: true, groupsBackendEnabled: true) == .groupsOnlySignOut)
    }

    @Test
    func groupsOnly_requiresBothFlagAndSession() {
        // Flag ON pero sin sesión → privado (no hay sesión que cerrar).
        #expect(CloudSignOutFlowLogic.path(
            for: .icloud, secondarySessionActive: false,
            hasLiveSession: false, groupsBackendEnabled: true) == .privateReset)
        // Sesión viva pero canal apagado → privado byte-idéntico.
        #expect(CloudSignOutFlowLogic.path(
            for: .icloud, secondarySessionActive: false,
            hasLiveSession: true, groupsBackendEnabled: false) == .privateReset)
    }

    @Test
    func cloud_winsOverGroupsOnly() {
        // Precedencia 2 > 3: en `.cloud` el store personal lo sincroniza el motor → wipe por archivos.
        #expect(CloudSignOutFlowLogic.path(
            for: .cloud, secondarySessionActive: false,
            hasLiveSession: true, groupsBackendEnabled: true) == .cloudSecureSignOut)
    }

    @Test
    func secondary_winsOverGroupsOnly() {
        // Precedencia 1 > 3.
        #expect(CloudSignOutFlowLogic.path(
            for: .icloud, secondarySessionActive: true,
            hasLiveSession: true, groupsBackendEnabled: true) == .secondaryCloudSignOut)
    }

    // D4: `confirmMessage_mapsEachPath` ELIMINADO — `CloudSignOutFlowLogic.confirmMessage` se retiró
    // (el copy por-path lo sustituyen las filas de la hoja; ver DestructiveScopeLogicTests).

    // MARK: - Visibilidad de las filas de salida (H4 + D6 §3.3.6)

    @Test
    func signOutRow_visible_wheneverNotGroupInvite() {
        // Privado / nube (no group-invite): SIEMPRE, con o sin sesión backend.
        #expect(CloudSignOutFlowLogic.shouldShowRow(isGroupInviteMode: false, hasLiveSession: false) == true)
        #expect(CloudSignOutFlowLogic.shouldShowRow(isGroupInviteMode: false, hasLiveSession: true) == true)
    }

    @Test
    func signOutRow_inGroupInvite_onlyWithLiveSession() {
        // D6: group-invite CON sesión backend viva [FLAG] necesita superficie para
        // `.groupsOnlySignOut`; SIN sesión (5a puro, VIVO) NO ve "Cerrar sesión".
        #expect(CloudSignOutFlowLogic.shouldShowRow(isGroupInviteMode: true, hasLiveSession: true) == true)
        #expect(CloudSignOutFlowLogic.shouldShowRow(isGroupInviteMode: true, hasLiveSession: false) == false)
    }

    @Test
    func exitYalaRow_onlyInGroupInviteWithoutSession() {
        // D6: la fila "Salir de Yala en este dispositivo" es la salida del solo-grupos legado
        // 5a (group-invite SIN sesión). Fuera de group-invite JAMÁS; con sesión tampoco (esa
        // ve "Cerrar sesión de grupos").
        #expect(CloudSignOutFlowLogic.shouldShowExitYalaRow(isGroupInviteMode: true, hasLiveSession: false) == true)
        #expect(CloudSignOutFlowLogic.shouldShowExitYalaRow(isGroupInviteMode: true, hasLiveSession: true) == false)
        #expect(CloudSignOutFlowLogic.shouldShowExitYalaRow(isGroupInviteMode: false, hasLiveSession: false) == false)
        #expect(CloudSignOutFlowLogic.shouldShowExitYalaRow(isGroupInviteMode: false, hasLiveSession: true) == false)
    }

    @Test
    func exitYala_and_signOutRow_areMutuallyExclusive() {
        // Invariante D6: en ningún estado ambas filas se muestran a la vez.
        for groupInvite in [false, true] {
            for session in [false, true] {
                let row = CloudSignOutFlowLogic.shouldShowRow(
                    isGroupInviteMode: groupInvite, hasLiveSession: session)
                let exit = CloudSignOutFlowLogic.shouldShowExitYalaRow(
                    isGroupInviteMode: groupInvite, hasLiveSession: session)
                #expect(!(row && exit), "Ambas filas visibles en groupInvite=\(groupInvite) session=\(session)")
            }
        }
    }
}

@Suite("Cerrar sesión — layout de filas de salida (D2 §3.3.3)")
struct CloudSignOutRowLayoutTests {

    typealias Layout = CloudSignOutFlowLogic.RowLayout

    // MARK: - Split solo-grupos backend: path .groupsOnlySignOut ⇒ DOS filas

    @Test
    func groupsOnlyPath_splitsIntoTwoRows_regardlessOfGroupInvite() {
        // Privado completo + sesión backend (5b): fila única → split "Cerrar sesión de grupos" + "Salir de Yala".
        #expect(CloudSignOutFlowLogic.rowLayout(
            path: .groupsOnlySignOut, isGroupInviteMode: false, hasLiveSession: true)
            == .groupsSignOutPlusExitYala)
        // Group-invite CON sesión backend (5b group-invite): mismo split.
        #expect(CloudSignOutFlowLogic.rowLayout(
            path: .groupsOnlySignOut, isGroupInviteMode: true, hasLiveSession: true)
            == .groupsSignOutPlusExitYala)
    }

    // MARK: - Resto de paths: byte-idéntico a shouldShowRow / shouldShowExitYalaRow

    @Test
    func privateAndCloudAndSecondary_arePlainSignOut_whenNotGroupInvite() {
        for path in [CloudSignOutFlowLogic.Path.privateReset, .cloudSecureSignOut, .secondaryCloudSignOut] {
            #expect(CloudSignOutFlowLogic.rowLayout(
                path: path, isGroupInviteMode: false, hasLiveSession: false) == .plainSignOut)
            #expect(CloudSignOutFlowLogic.rowLayout(
                path: path, isGroupInviteMode: false, hasLiveSession: true) == .plainSignOut)
        }
    }

    @Test
    func groupInviteWithoutSession_isExitYalaOnly() {
        // Solo-grupos legado 5a (VIVO): path resuelve a .privateReset (sin sesión) → fila única "Salir de Yala".
        #expect(CloudSignOutFlowLogic.rowLayout(
            path: .privateReset, isGroupInviteMode: true, hasLiveSession: false) == .exitYalaOnly)
    }

    @Test
    func groupInviteWithSession_nonGroupsOnlyPath_isPlainSignOut() {
        // Borde defensivo: group-invite con sesión pero un path que NO es groupsOnly (p.ej. `.cloud`)
        // → shouldShowRow(true, true)=true → .plainSignOut (jamás .exitYalaOnly con sesión viva).
        #expect(CloudSignOutFlowLogic.rowLayout(
            path: .cloudSecureSignOut, isGroupInviteMode: true, hasLiveSession: true) == .plainSignOut)
    }

    @Test
    func layout_isNeverNone_forAnyValidCombination() {
        // `.none` es un default defensivo del switch (inalcanzable: shouldShowRow y shouldShowExitYalaRow
        // son complementarias — exactamente una es true en cada estado). Barrido exhaustivo.
        let paths: [CloudSignOutFlowLogic.Path] =
            [.privateReset, .cloudSecureSignOut, .secondaryCloudSignOut, .groupsOnlySignOut]
        for path in paths {
            for gi in [false, true] {
                for sess in [false, true] {
                    #expect(CloudSignOutFlowLogic.rowLayout(
                        path: path, isGroupInviteMode: gi, hasLiveSession: sess) != Layout.none,
                        "Layout .none en path=\(path) groupInvite=\(gi) session=\(sess)")
                }
            }
        }
    }

    @Test
    func flagOffMatrix_isByteIdenticalToLegacyRowVisibility() {
        // Sin canal / sin sesión `path` NUNCA es .groupsOnlySignOut, así que
        // el layout debe reproducir EXACTO las ramas shouldShowRow/shouldShowExitYalaRow de antes.
        let prodPaths: [CloudSignOutFlowLogic.Path] =
            [.privateReset, .cloudSecureSignOut, .secondaryCloudSignOut]
        for path in prodPaths {
            for gi in [false, true] {
                let layout = CloudSignOutFlowLogic.rowLayout(
                    path: path, isGroupInviteMode: gi, hasLiveSession: false)
                let expected: Layout = CloudSignOutFlowLogic.shouldShowRow(
                    isGroupInviteMode: gi, hasLiveSession: false)
                    ? .plainSignOut
                    : (CloudSignOutFlowLogic.shouldShowExitYalaRow(
                        isGroupInviteMode: gi, hasLiveSession: false) ? .exitYalaOnly : .none)
                #expect(layout == expected, "Drift en path=\(path) groupInvite=\(gi)")
            }
        }
    }
}

@Suite("Cerrar sesión — veredicto del push-all (.cloud)")
struct CloudSignOutPushAllVerdictTests {

    @Test
    func outboxEmpty_isDrained_regardlessOfCycleOutcome() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 0, cycleOutcome: .completed, iteration: 1, maxIterations: 10
        ) == .drained)
        // Ciclo con error pero outbox ya vacío → drained igual (el objetivo se cumplió).
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 0, cycleOutcome: .transient, iteration: 3, maxIterations: 10
        ) == .drained)
    }

    @Test
    func pendingWithSuccessfulCycle_keepsIterating() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 12, cycleOutcome: .completed, iteration: 2, maxIterations: 10
        ) == nil)
        // `.coalesced` (ciclo en vuelo, sin señal de fallo) también cuenta como éxito.
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 12, cycleOutcome: .coalesced, iteration: 2, maxIterations: 10
        ) == nil)
    }

    @Test
    func pendingWithFailedTransientCycle_blocksTransient() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 5, cycleOutcome: .transient, iteration: 1, maxIterations: 10
        ) == .blocked(pendingCount: 5, reason: .transient))
    }

    @Test
    func pendingWithSessionOrAccountFailure_blocksPermanent() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 5, cycleOutcome: .sessionExpired, iteration: 1, maxIterations: 10
        ) == .blocked(pendingCount: 5, reason: .permanent))
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 7, cycleOutcome: .accountUnavailable, iteration: 2, maxIterations: 10
        ) == .blocked(pendingCount: 7, reason: .permanent))
    }

    @Test
    func pendingAtMaxIterations_blocksTransient_evenWithSuccessfulCycle() {
        // Tope alcanzado con ciclo sano pero pendientes → transitorio (aún drenando).
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 3, cycleOutcome: .completed, iteration: 10, maxIterations: 10
        ) == .blocked(pendingCount: 3, reason: .transient))
    }
}

@Suite("Cerrar sesión — clasificación transitorio/permanente (H-2026-07-18-6)")
struct CloudSignOutClassifyTests {

    @Test
    func sessionOrAccountFailure_isPermanent() {
        #expect(CloudSignOutFlowLogic.classify(.sessionExpired) == .permanent)
        #expect(CloudSignOutFlowLogic.classify(.accountUnavailable) == .permanent)
    }

    @Test
    func networkOrCoalescedOrCompleted_isTransient() {
        #expect(CloudSignOutFlowLogic.classify(.transient) == .transient)
        #expect(CloudSignOutFlowLogic.classify(.completed) == .transient)
        #expect(CloudSignOutFlowLogic.classify(.coalesced) == .transient)
    }
}

@Suite("Cerrar sesión solo-grupos — decisión de retry con presupuesto (H-2026-07-18-6)")
struct GroupsSignOutRetryDecisionTests {

    private let budget = GroupsSignOutRetryDecision.budgetSeconds  // 45

    @Test
    func permanent_surfacesImmediately_regardlessOfElapsed() {
        #expect(GroupsSignOutRetryDecision.decide(
            elapsedSeconds: 0, budgetSeconds: budget, reason: .permanent) == .surfacePermanent)
        // Aunque quede presupuesto, un permanente jamás reintenta.
        #expect(GroupsSignOutRetryDecision.decide(
            elapsedSeconds: 100, budgetSeconds: budget, reason: .permanent) == .surfacePermanent)
    }

    @Test
    func transient_withinBudget_retries() {
        #expect(GroupsSignOutRetryDecision.decide(
            elapsedSeconds: 0, budgetSeconds: budget, reason: .transient)
            == .retryAfter(seconds: GroupsSignOutRetryDecision.retryIntervalSeconds))
        #expect(GroupsSignOutRetryDecision.decide(
            elapsedSeconds: 44, budgetSeconds: budget, reason: .transient)
            == .retryAfter(seconds: GroupsSignOutRetryDecision.retryIntervalSeconds))
    }

    @Test
    func transient_budgetExhausted_surfacesTransient() {
        #expect(GroupsSignOutRetryDecision.decide(
            elapsedSeconds: 46, budgetSeconds: budget, reason: .transient) == .surfaceTransient)
    }

    @Test
    func transient_atExactBudgetBoundary_surfacesTransient() {
        // elapsed == budget: el `<` es ESTRICTO → ya no reintenta (borde, no `retryAfter`).
        #expect(GroupsSignOutRetryDecision.decide(
            elapsedSeconds: budget, budgetSeconds: budget, reason: .transient) == .surfaceTransient)
    }
}

/// **La invitada tiene DOS outboxes y el cierre solo empujaba uno.**
///
/// El camino `.cloud` empuja el personal Y el de grupos, y re-verifica los dos antes de soltar
/// credenciales. El camino secundario (M1) empujaba solo el personal — mientras el wipe de arranque
/// borra igual `YalaGroups-Secondary` y `YalaSyncMeta-Secondary`, que es donde vive `GroupSyncOutbox`,
/// y la purga de frontera se lleva además el espejo del App Group, que era la red de rehidratación.
/// ⇒ los últimos gastos de grupo de la visita podían quedarse sin subir, y su copia local moría con la
/// sesión.
///
/// **Y el comentario que lo justificaba era falso**: decía que en secundaria el canal de Grupos «ni
/// corre», cuando con el canal encendido la sesión secundaria lo corre sobre su propio store — que es
/// exactamente la configuración en la que ese archivo existe.
///
/// Source-scan porque `performSecondaryCloudSignOut` es privado y su camino exige runtime de red: lo
/// que hay que fijar es que el paso EXISTA y que la re-verificación cuente los dos, y eso no se puede
/// afirmar desde fuera de otra forma. Molde `SecondaryOwnerDomainWiringTests`.
@Suite("Cerrar sesión — la sesión secundaria empuja los DOS outboxes (source-scan)")
struct SecondarySignOutPushesBothOutboxesTests {

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker))
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    private static func signOutSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(
            contentsOf: root.appendingPathComponent("Yala/Services/CloudSync/CloudSessionSignOut.swift"),
            encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("el camino secundario hace push-all de GRUPOS antes del teardown")
    func secondaryPushesGroupsOutbox() throws {
        let secondary = try Self.body(
            of: "private func performSecondaryCloudSignOut(context: ModelContext) async {",
            in: Self.signOutSource())

        let push = try #require(
            secondary.range(of: "pushAllPendingGroupsForSignOut(context: context)"), """
            El cierre de la sesión secundaria dejó de empujar el outbox de GRUPOS. El wipe de arranque \
            borra `YalaGroups-Secondary` y la purga se lleva el espejo del App Group: lo que no suba \
            aquí no sube nunca.
            """)
        let teardown = try #require(secondary.range(of: "GroupsSyncClient.shared.teardownForSignOut()"))
        #expect(push.lowerBound < teardown.lowerBound, """
            El push-all quedó DESPUÉS del teardown: la guardia de generación aborta el ciclo, así que \
            empujar ahí no empuja nada (mismo racional que el paso 2 del camino `.cloud`).
            """)
    }

    @Test("la re-verificación previa a soltar credenciales cuenta los DOS outboxes")
    func secondaryReverifiesBoth() throws {
        let secondary = try Self.body(
            of: "private func performSecondaryCloudSignOut(context: ModelContext) async {",
            in: Self.signOutSource())

        #expect(secondary.contains("controller.livePendingUploadCount()"))
        #expect(secondary.contains("Self.liveGroupsPendingCount(context: context)"), """
            La re-verificación de S2 volvió a mirar solo el outbox personal: una fila de grupos encolada \
            por un save concurrente durante el push-all pasaría el guard y moriría en el wipe.
            """)
    }
}

/// **Cuando la invitada se va y algo la bloquea, ya no se le dice siempre «revisa tu conexión».**
///
/// Las salidas de bloqueo del camino secundario emitían SIEMPRE `reason: .permanent`, y el `reason`
/// verdadero venía ya clasificado desde los dos push-all: el consumidor lo descartaba. Consecuencia:
/// un corte de red de dos segundos le decía que revisara la conexión, el presupuesto de 45 s de
/// `GroupsSignOutRetryDecision` no la alcanzaba, y `waitingForPending` no se encendía nunca ⇒ tampoco
/// veía el caption de espera.
///
/// Y sobre eso, la decisión del owner del 2026-09-03: el aviso le ofrece **salir igualmente**, porque
/// está en el móvil de otra persona y hay que devolverlo.
///
/// Source-scan por la misma razón que el suite hermano: `performSecondaryCloudSignOut` es privado y su
/// camino exige runtime de red. Lo que hay que fijar es la ESTRUCTURA — que el reason se propague, que
/// el bucle no envuelva el teardown, y que la salida forzada arme el wipe secundario y no otro.
@Suite("Cerrar sesión — la visita distingue el bloqueo transitorio y puede salir igualmente")
struct SecondarySignOutBlockClassificationTests {

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker))
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func secondaryBody() throws -> String {
        try body(
            of: "private func performSecondaryCloudSignOut(context: ModelContext) async {",
            in: source("Yala/Services/CloudSync/CloudSessionSignOut.swift"))
    }

    // MARK: - El gate puro de la salida forzada

    @Test("«salir igualmente» se ofrece SOLO en la sesión de visita y SOLO con algo pendiente")
    func forcedExitGate() {
        #expect(CloudSignOutFlowLogic.offersForcedSecondaryExit(
            isSecondaryActive: true, pendingCount: 3))
        // En el móvil propio no hay ningún teléfono que devolver: la salida no se ofrece, y el alert
        // conserva su único botón de siempre.
        #expect(!CloudSignOutFlowLogic.offersForcedSecondaryExit(
            isSecondaryActive: false, pendingCount: 3))
        // `pendingCount: 0` es el bloqueo que NO viene de datos sin subir (el guard sin controller):
        // ofrecer "salir igualmente" ahí prometería descartar algo que no existe.
        #expect(!CloudSignOutFlowLogic.offersForcedSecondaryExit(
            isSecondaryActive: true, pendingCount: 0))
        #expect(!CloudSignOutFlowLogic.offersForcedSecondaryExit(
            isSecondaryActive: false, pendingCount: 0))
    }

    // MARK: - La clasificación del bloqueo (pieza 2)

    @Test("el camino secundario decide con GroupsSignOutRetryDecision, no con `.permanent` fijo")
    func secondaryClassifiesBlock() throws {
        let secondary = try Self.secondaryBody()
        #expect(secondary.contains("GroupsSignOutRetryDecision.decide("), """
            El cierre de la sesión secundaria volvió a emitir el bloqueo sin clasificarlo. El `reason` \
            llega ya clasificado desde los dos push-all: descartarlo es lo que hacía que un corte de red \
            de dos segundos se presentara como «revisa tu conexión».
            """)
        #expect(secondary.contains("reason: .transient"), """
            Ninguna salida del camino secundario emite ya `.transient` ⇒ el copy «Un momento más» y el \
            caption de espera vuelven a ser inalcanzables para la invitada.
            """)
        #expect(secondary.contains("waitingForPending = true"), """
            El camino secundario dejó de encender `waitingForPending`: durante los reintentos la persona \
            mira un spinner mudo, que es el síntoma que H-2026-07-18-6 arregló en el otro camino.
            """)
    }

    @Test("el bucle de reintento NO envuelve el teardown")
    func retryLoopStopsBeforeTeardown() throws {
        let secondary = try Self.secondaryBody()
        let loop = try #require(secondary.range(of: "pushLoop: while true {"))
        let breakOut = try #require(secondary.range(of: "break pushLoop"))
        let teardown = try #require(secondary.range(of: "CloudSyncRuntime.shared?.teardownGuestSession()"))
        #expect(breakOut.lowerBound < teardown.lowerBound)
        #expect(loop.lowerBound < teardown.lowerBound, """
            El teardown quedó DENTRO del bucle de reintento. Después de él no hay nada que drenar \
            —`teardownGuestSession` deja el motor con `currentUserID = nil`, el mirror purgado y la \
            cadencia cancelada—, así que reintentar ahí quema los 45 s del presupuesto para llegar al \
            mismo bloqueo, con la persona esperando para devolver el móvil.
            """)
    }

    @Test("la re-verificación posterior al teardown se queda en `.permanent` a propósito")
    func postTeardownResidualStaysPermanent() throws {
        let secondary = try Self.secondaryBody()
        let teardown = try #require(secondary.range(of: "CloudSyncRuntime.shared?.teardownGuestSession()"))
        let tail = String(secondary[teardown.upperBound...])
        #expect(tail.contains("reason: .permanent"), """
            El residual de S2 pasó a `.transient`. Es el único bloqueo del camino que NO es reintentable: \
            los dos teardowns ya corrieron, así que ni un reintento interno ni el del usuario pueden \
            drenar la fila que acaba de aparecer.
            """)
        #expect(!tail.contains("GroupsSignOutRetryDecision.decide("))
    }

    // MARK: - La salida forzada (pieza 3)

    @Test("la salida forzada exige un bloqueo vivo Y una sesión secundaria")
    func forcedExitIsGuarded() throws {
        let forced = try Self.body(
            of: "func exitSecondaryDiscardingPending() async {",
            in: Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift"))
        #expect(forced.contains("guard case .blocked = phase else { return }"), """
            Sin el guard de fase, «salir igualmente» sería invocable sin que ningún bloqueo lo haya \
            ofrecido: descartaría pendientes que el push-all todavía podía subir.
            """)
        #expect(forced.contains("guard SecondarySessionStore.isActive() else { return }"), """
            Sin el guard de sesión, esta función armaría el wipe SECUNDARIO en un device que no está en \
            sesión de visita.
            """)
    }

    @Test("la salida forzada arma el wipe SECUNDARIO y no toca los archivos del dueño")
    func forcedExitArmsSecondaryWipe() throws {
        let forced = try Self.body(
            of: "func exitSecondaryDiscardingPending() async {",
            in: Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift"))
        #expect(forced.contains("SecondarySessionStore.armWipe()"))
        // `armSignOutWipe` es el del camino `.cloud`: borra los archivos del DUEÑO y devuelve el device
        // a "recién instalado". Aquí sería catastrófico — la invitada se llevaría los datos del anfitrión.
        #expect(!forced.contains("StorageModePersistence.armSignOutWipe()"), """
            La salida forzada de la visita armó el wipe del camino `.cloud`: eso borra los archivos del \
            DUEÑO del móvil, no los de la invitada.
            """)
        // Orden congelado: credenciales ANTES del arm (el arm es el disparador y va último).
        let signOut = try #require(forced.range(of: "CloudAuthService.shared.signOut()"))
        let arm = try #require(forced.range(of: "SecondarySessionStore.armWipe()"))
        #expect(signOut.lowerBound < arm.lowerBound)
        // Y sin push-all: los dos acaban de fallar, reintentarlos aquí es lo que la persona ya descartó.
        #expect(!forced.contains("pushAllPendingForSignOut()"))
        #expect(!forced.contains("pushAllPendingGroupsForSignOut("))
    }

    // MARK: - El cableado de la vista

    @Test("el aviso decide por el `pendingCount` del bloqueo que está mostrando")
    func profileViewWiresTheGate() throws {
        let profile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains("CloudSignOutFlowLogic.offersForcedSecondaryExit("), """
            ProfileView dejó de consultar el gate: o esconde la salida a la invitada, o la ofrece en el \
            móvil del dueño. Las dos son regresiones del mismo cableado.
            """)
        #expect(profile.contains("isSecondaryActive: SecondarySessionStore.isActive(), pendingCount: pending)"))
        #expect(profile.contains("await CloudSessionSignOut.shared.exitSecondaryDiscardingPending()"))
        // Los DOS alerts comparten los botones: si uno se quedara con el "OK" pelado, la invitada
        // bloqueada por un transitorio seguiría sin salida.
        #expect(profile.components(separatedBy: "signOutBlockedButtons").count - 1 >= 3, """
            Los dos alerts de bloqueo dejaron de compartir sus botones. El transitorio es JUSTO el caso \
            que más le pasa a la invitada: si ése se queda sin «salir igualmente», el fix no la alcanza.
            """)
    }
}
