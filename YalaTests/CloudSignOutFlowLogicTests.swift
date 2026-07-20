//
//  CloudSignOutFlowLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Cerrar sesión — camino por modo y visibilidad (H4 + G5-B)")
struct CloudSignOutFlowLogicTests {

    // Helper: la matriz de HOY (flag OFF, sin sesión backend = TODO device prod) debe ser byte-idéntica.
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
        // Sesión viva pero flag OFF (TODO device prod) → privado byte-idéntico.
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
        // Con el flag OFF / sin sesión (TODO device prod hoy) `path` NUNCA es .groupsOnlySignOut, así que
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
