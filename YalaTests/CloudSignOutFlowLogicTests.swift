//
//  CloudSignOutFlowLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Cerrar sesión — un camino por celda (ADR 2026-09-09, dos ejes)")
struct CloudSignOutFlowLogicTests {

    typealias Path = CloudSignOutFlowLogic.Path

    /// Defaults = la configuración de producción (canal de grupos compilado, sesión privada).
    private func path(_ mode: StorageMode, session: Bool = false,
                      groups: Bool = true, privateSession: Bool = true) -> Path {
        CloudSignOutFlowLogic.path(
            for: mode, hasLiveSession: session,
            groupsBackendEnabled: groups, hasPrivateSession: privateSession)
    }

    @Test("C · privada sin sesión en la nube → cierre privado")
    func privateWithoutCloud() {
        #expect(path(.icloud) == .privateSignOut)
    }

    @Test("D · privada + sesión de grupos → «equipo», no «salir solo de grupos»")
    func privateWithGroupsSession() {
        #expect(path(.icloud, session: true) == .privateWithGroupsSignOut)
    }

    @Test("E · nube completa → cierre de la nube, sea cual sea el resto")
    func cloud() {
        for privateSession in [true, false] {
            for session in [true, false] {
                #expect(path(.cloud, session: session, privateSession: privateSession) == .cloudSecureSignOut)
            }
        }
    }

    @Test("F · sesión en la nube solo grupos, sin sesión privada → cierre solo-grupos")
    func groupsOnlyWithoutPrivate() {
        #expect(path(.icloud, session: true, privateSession: false) == .groupsOnlySignOut)
    }

    /// El solo-grupos legado que ya no tiene sesión («5a») tampoco tiene vida privada: cierra por el camino
    /// de F, que borra lo local. La hoja privada le habría dicho «tus datos siguen en iCloud», que es falso.
    @Test("sin sesión privada, el camino es el de solo grupos, haya sesión en la nube o no")
    func noPrivateSession_isGroupsOnly_withOrWithoutSession() {
        #expect(path(.icloud, session: false, privateSession: false) == .groupsOnlySignOut)
        #expect(path(.icloud, session: true, groups: false, privateSession: false) == .groupsOnlySignOut)
    }

    @Test("sin el canal de grupos compilado, una sesión viva no convierte a la privada en «equipo»")
    func noGroupsCapability_isPrivate() {
        #expect(path(.icloud, session: true, groups: false) == .privateSignOut)
    }

    /// La puerta de quiescencia de los cierres que drenan grupos. Sin espejo no hay import con el que
    /// chocar: el término del mount es la corrección del cierre solo-grupos, que con iCloud Drive activo
    /// esperaba un «primer import» que un store neutro no emite nunca.
    @Test("la puerta de quiescencia: sin espejo es seguro siempre; con espejo y cuenta, solo asentado")
    func personalSaveSafety() {
        typealias L = CloudSignOutFlowLogic
        for account in [true, false] {
            for first in [true, false] {
                for quiet in [true, false] {
                    #expect(L.isPersonalSaveSafe(mountAttachesMirror: false, accountAvailable: account,
                                                 firstImportCompleted: first, importQuiescent: quiet))
                }
            }
        }
        #expect(L.isPersonalSaveSafe(mountAttachesMirror: true, accountAvailable: false,
                                     firstImportCompleted: false, importQuiescent: false))
        #expect(L.isPersonalSaveSafe(mountAttachesMirror: true, accountAvailable: true,
                                     firstImportCompleted: true, importQuiescent: true))
        #expect(!L.isPersonalSaveSafe(mountAttachesMirror: true, accountAvailable: true,
                                      firstImportCompleted: false, importQuiescent: true),
                "`isImportQuiescent` a secas es true ANTES del primer import: señal prematura en un restore")
        #expect(!L.isPersonalSaveSafe(mountAttachesMirror: true, accountAvailable: true,
                                      firstImportCompleted: true, importQuiescent: false))
    }

    @Test("las cuatro salidas son alcanzables y distintas: ninguna celda comparte camino")
    func everyCellHasItsOwnPath() {
        let cells: [Path] = [
            path(.icloud),                                          // C
            path(.icloud, session: true),                           // D
            path(.cloud, session: true),                            // E
            path(.icloud, session: true, privateSession: false),    // F
        ]
        #expect(Set(cells.map { "\($0)" }).count == 4, "\(cells)")
    }

    /// El reparto de los tres cierres por archivos, por tabla. La review adversarial midió que invertir un solo
    /// término —C sin esperar al export, D sin subir sus grupos— no lo cazaba ningún test. C y D esperan salvo
    /// el «sin copia» confirmado; F espera solo si su store espeja; la nube no pasa por aquí.
    @Test("quién sube grupos y quién espera al export: la tabla entera")
    func exitPlan_table() {
        typealias L = CloudSignOutFlowLogic
        for mirror in [true, false] {
            #expect(L.exitPlan(path: .privateSignOut, confirmedWithoutICloudCopy: false, mountAttachesMirror: mirror)
                    == .init(kind: .privateOnly, waitsForExport: true))
            #expect(L.exitPlan(path: .privateSignOut, confirmedWithoutICloudCopy: true, mountAttachesMirror: mirror)
                    == .init(kind: .privateOnly, waitsForExport: false))
            #expect(L.exitPlan(path: .privateWithGroupsSignOut, confirmedWithoutICloudCopy: false, mountAttachesMirror: mirror)
                    == .init(kind: .privateWithGroups, waitsForExport: true))
            #expect(L.exitPlan(path: .privateWithGroupsSignOut, confirmedWithoutICloudCopy: true, mountAttachesMirror: mirror)
                    == .init(kind: .privateWithGroups, waitsForExport: false))
            for noCopy in [true, false] {
                #expect(L.exitPlan(path: .groupsOnlySignOut, confirmedWithoutICloudCopy: noCopy, mountAttachesMirror: mirror)
                        == .init(kind: .groupsOnly, waitsForExport: mirror))
                #expect(L.exitPlan(path: .cloudSecureSignOut, confirmedWithoutICloudCopy: noCopy,
                                   mountAttachesMirror: mirror) == nil)
            }
        }
    }

    @Test("solo la privada sin cuenta en la nube no sube grupos")
    func exitKind_pushesGroups() {
        #expect(!CloudSignOutFlowLogic.ExitKind.privateOnly.pushesGroups)
        #expect(CloudSignOutFlowLogic.ExitKind.privateWithGroups.pushesGroups)
        #expect(CloudSignOutFlowLogic.ExitKind.groupsOnly.pushesGroups)
    }
}

@Suite("Cerrar sesión — veredicto del push-all (.cloud)")
struct CloudSignOutPushAllVerdictTests {

    @Test
    func outboxEmpty_isDrained_regardlessOfCycleOutcome() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 0, cycleOutcome: .completed, channelKilled: false, iteration: 1, maxIterations: 10
        ) == .drained)
        // Ciclo con error pero outbox ya vacío → drained igual (el objetivo se cumplió).
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 0, cycleOutcome: .transient, channelKilled: false, iteration: 3, maxIterations: 10
        ) == .drained)
    }

    @Test
    func pendingWithSuccessfulCycle_keepsIterating() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 12, cycleOutcome: .completed, channelKilled: false, iteration: 2, maxIterations: 10
        ) == nil)
        // `.coalesced` (ciclo en vuelo, sin señal de fallo) también cuenta como éxito.
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 12, cycleOutcome: .coalesced, channelKilled: false, iteration: 2, maxIterations: 10
        ) == nil)
    }

    @Test
    func pendingWithFailedTransientCycle_blocksTransient() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 5, cycleOutcome: .transient, channelKilled: false, iteration: 1, maxIterations: 10
        ) == .blocked(pendingCount: 5, reason: .transient))
    }

    @Test
    func pendingWithSessionOrAccountFailure_blocksPermanent() {
        // La sesión caducada lleva su motivo propio desde el paso 9 (el aviso pide volver a entrar), y desde el
        // 2026-09-15 el camino `.cloud` también lo enseña: `cloudSignOutGroupsBlockReason` ya no lo colapsa
        // (ticket `cloud-signout-collapses-a-groups-session-expiry-into-permanent`).
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 5, cycleOutcome: .sessionExpired, channelKilled: false, iteration: 1, maxIterations: 10
        ) == .blocked(pendingCount: 5, reason: .sessionExpired))
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 7, cycleOutcome: .accountUnavailable, channelKilled: false, iteration: 2, maxIterations: 10
        ) == .blocked(pendingCount: 7, reason: .permanent))
    }

    /// El veredicto PORTA el motivo del canal en pausa, no lo colapsa: es lo que la pantalla lee para
    /// elegir el aviso. Sin esto, el arreglo se quedaba en `classify` y no llegaba a nadie.
    @Test
    func pendingWithTheChannelKillSwitch_blocksAsPausedChannel() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 7, cycleOutcome: .accountUnavailable, channelKilled: true,
            iteration: 2, maxIterations: 10
        ) == .blocked(pendingCount: 7, reason: .channelPaused))
    }

    /// **Con el outbox vacío el gesto completa aunque el canal esté apagado, y eso no cambia.** Es el caso
    /// dominante —el pre-check corta sin una sola petición— y la mitad del ticket que ya funcionaba.
    @Test
    func emptyOutbox_drainsEvenWithTheChannelKilled() {
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 0, cycleOutcome: .accountUnavailable, channelKilled: true,
            iteration: 1, maxIterations: 10
        ) == .drained)
    }

    @Test
    func pendingAtMaxIterations_blocksTransient_evenWithSuccessfulCycle() {
        // Tope alcanzado con ciclo sano pero pendientes → transitorio (aún drenando).
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 3, cycleOutcome: .completed, channelKilled: false, iteration: 10, maxIterations: 10
        ) == .blocked(pendingCount: 3, reason: .transient))
    }
}

@Suite("Cerrar sesión — clasificación transitorio/permanente (H-2026-07-18-6)")
struct CloudSignOutClassifyTests {

    @Test
    func sessionOrAccountFailure_isPermanent() {
        // Las dos son permanentes, pero la sesión caducada tiene su motivo propio desde el paso 9: se arregla
        // volviendo a entrar, y el aviso tiene que decirlo en vez de mandar a revisar la conexión.
        #expect(CloudSignOutFlowLogic.classify(.sessionExpired, channelKilled: false) == .sessionExpired)
        #expect(CloudSignOutFlowLogic.classify(.accountUnavailable, channelKilled: false) == .permanent)
    }

    /// **Los dos 403 del canal de Grupos no dicen lo mismo, y el `channelKilled` es lo único que los
    /// separa.** Con el kill-switch puesto, quien tiene cambios sin subir recibía «el problema es tu
    /// cuenta» sobre una cuenta que está perfectamente: lo que pasa es que alguien bajó una palanca por
    /// un incidente. Ticket `groups-killswitch-403-blocks-detach-forever`.
    @Test
    func the403OfTheKillSwitch_isNotAnAccountVerdict() {
        #expect(CloudSignOutFlowLogic.classify(.accountUnavailable, channelKilled: true) == .channelPaused)
        #expect(CloudSignOutFlowLogic.classify(.accountUnavailable, channelKilled: false) == .permanent)
    }

    /// **El testigo del kill solo cuenta si el ciclo paró por un 403.** Es lo que impide que un kill de
    /// hace un rato tiña un fallo posterior que no tiene nada que ver: la red que se cae mientras el canal
    /// está apagado sigue siendo «espera un momento», no «el canal está en pausa». La otra mitad de esta
    /// garantía la pone el cliente, que baja el testigo al entrar en cada ciclo.
    @Test
    func killWitness_isIgnoredUnlessTheCycleStoppedOnA403() {
        #expect(CloudSignOutFlowLogic.classify(.transient, channelKilled: true) == .transient)
        #expect(CloudSignOutFlowLogic.classify(.completed, channelKilled: true) == .transient)
        #expect(CloudSignOutFlowLogic.classify(.coalesced, channelKilled: true) == .transient)
        // Y la sesión caducada sigue siendo suya: un 401 no es el kill, aunque el testigo venga puesto.
        #expect(CloudSignOutFlowLogic.classify(.sessionExpired, channelKilled: true) == .sessionExpired)
    }

    @Test
    func networkOrCoalescedOrCompleted_isTransient() {
        #expect(CloudSignOutFlowLogic.classify(.transient, channelKilled: false) == .transient)
        #expect(CloudSignOutFlowLogic.classify(.completed, channelKilled: false) == .transient)
        #expect(CloudSignOutFlowLogic.classify(.coalesced, channelKilled: false) == .transient)
    }
}

/// **El cierre en la NUBE traduce el veredicto de grupos, y hasta el 2026-09-14 lo aplanaba.** Todo lo que
/// no fuera el canal en pausa salía como `.permanent` ⇒ «revisa tu conexión»: un corte de red acertaba, y
/// un 5xx o el 403 de un cortafuegos mandaban a buscar un fallo que no existe, sin decir lo único que
/// ayuda —que se cura esperando—. Ticket `cloud-signout-collapses-every-groups-transient-into-permanent`.
@Suite("Cerrar sesión en la nube — el motivo del fallo de grupos se traduce, no se aplana")
struct CloudSignOutGroupsReasonTests {

    /// Lo pasajero se anuncia como pasajero. Es el caso del ticket, y el que el ternario viejo perdía:
    /// devolver `.permanent` aquí es exactamente el bug que se cerró.
    @Test
    func transientBecomesRetryLater_notPermanent() {
        #expect(CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(.transient) == .uploadRetryLater)
    }

    /// El kill-switch (2026-09-13) no se toca: sigue llegando con su copy propio.
    @Test
    func pausedChannelStillTravelsUntouched() {
        #expect(CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(.channelPaused) == .channelPaused)
    }

    /// **La cadena del ticket, de punta a punta**: una sesión caducada en el push de grupos del cierre en la
    /// nube acaba en el aviso que pide volver a entrar, y no en «revisa tu conexión». Cada eslabón tiene su
    /// tabla (`classify`, esta traducción y `SignOutBlockedCopy`); lo que ninguna dice es que juntos den el
    /// texto que decidió Jürgen (opción 1, 2026-09-15). Ticket
    /// `cloud-signout-collapses-a-groups-session-expiry-into-permanent`.
    @MainActor
    @Test
    func aGroupsSessionExpiryEndsInTheSignInAgainCopy() {
        let motivo = CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(
            CloudSignOutFlowLogic.classify(.sessionExpired, channelKilled: false))
        #expect(motivo == .sessionExpired)
        #expect(SignOutBlockedCopy.message(for: motivo) == L10n.Groups.Errors.sessionExpired)
        // Y el vecino no se arrastra: la cuenta no disponible sigue en el aviso que no afirma ninguna causa.
        let cuenta = CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(
            CloudSignOutFlowLogic.classify(.accountUnavailable, channelKilled: false))
        #expect(cuenta == .permanent)
        #expect(SignOutBlockedCopy.message(for: cuenta) == L10n.Settings.signOutBlockedMessage)
    }

    /// **Todo motivo tiene una traducción escrita.** El `switch` es exhaustivo, así que el compilador ya
    /// obliga; esta tabla fija además QUÉ se decidió para cada uno, y se cae si alguien cambia una fila
    /// creyendo que da igual. Los que caen en `.permanent` lo hacen a propósito.
    @Test
    func everyReasonHasATranslation() {
        let esperado: [CloudSignOutFlowLogic.BlockReason: CloudSignOutFlowLogic.BlockReason] = [
            .transient: .uploadRetryLater,
            .channelPaused: .channelPaused,
            .uploadRetryLater: .uploadRetryLater,
            // La sesión caducada viaja tal cual desde el 2026-09-15 (decisión 3A de Jürgen).
            // Ticket `cloud-signout-collapses-a-groups-session-expiry-into-permanent`.
            .sessionExpired: .sessionExpired,
            // El aviso que no afirma ninguna causa, para lo que de verdad no se sabe.
            .permanent: .permanent,
            // No los produce `classify`, así que este productor no puede emitirlos.
            .exportUnconfirmed: .permanent,
            .bridgeUnreadable: .permanent,
            .detachBusy: .permanent,
        ]
        #expect(CloudSignOutFlowLogic.BlockReason.allCases.count == esperado.count, """
            Hay un motivo de bloqueo sin traducción escrita para el cierre en la nube. Decídelo aquí: el
            `switch` no te deja compilar sin hacerlo, pero sí te deja elegir mal en silencio.
            """)
        for motivo in CloudSignOutFlowLogic.BlockReason.allCases {
            #expect(CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(motivo) == esperado[motivo])
        }
        // La tabla cubre TODO `allCases` y toda salida está en `allCases`, así que con ella verde la
        // traducción es idempotente por construcción: `f(f(x)) == f(x)`. No hace falta un test aparte —
        // el que había no podía fallar sin que fallara antes esta tabla.
    }

    /// **Cada motivo tiene su slug de log, y el que no lo tenga rompe aquí.** Sin esto, un motivo nuevo
    /// puede llegar a los logs como el slug de otro y un incidente se lee al revés.
    @Test
    func everyReasonHasItsOwnBreadcrumbSlug() {
        let slugs = CloudSignOutFlowLogic.BlockReason.allCases.map(\.breadcrumbSlug)
        #expect(Set(slugs).count == CloudSignOutFlowLogic.BlockReason.allCases.count, """
            Dos motivos comparten slug de log: en campo no se podrán distinguir.
            """)
        #expect(CloudSignOutFlowLogic.BlockReason.uploadRetryLater.breadcrumbSlug == "upload-retry-later")
        #expect(CloudSignOutFlowLogic.BlockReason.channelPaused.breadcrumbSlug == "channel-paused")
    }
}

@Suite("Cerrar sesión solo-grupos — decisión de retry con presupuesto (H-2026-07-18-6)")
struct GroupsSignOutRetryDecisionTests {

    private let budget = GroupsSignOutRetryDecision.budgetSeconds  // 45

    @Test
    func permanent_surfacesImmediately_regardlessOfElapsed() {
        // La sesión caducada (paso 9) se trata igual: sin sesión, esperar no sube nada.
        for reason in [CloudSignOutFlowLogic.BlockReason.permanent, .sessionExpired] {
            #expect(GroupsSignOutRetryDecision.decide(
                elapsedSeconds: 0, budgetSeconds: budget, reason: reason) == .surfacePermanent)
            // Aunque quede presupuesto, un permanente jamás reintenta.
            #expect(GroupsSignOutRetryDecision.decide(
                elapsedSeconds: 100, budgetSeconds: budget, reason: reason) == .surfacePermanent)
        }
    }

    /// **El canal en pausa se muestra al momento, y es una decisión de producto** (2026-09-13): el
    /// kill-switch se levanta con un deploy, así que dentro de los 45 s del presupuesto no se va a mover.
    /// Reintentar gastaría ~22 peticiones contra un 403 seguro en pleno incidente y retrasaría 45 s un
    /// aviso que ya se puede dar. Lo que sigue siendo reintentable es el gesto, que no escribió nada.
    @Test
    func pausedChannel_surfacesImmediately_withoutSpendingTheBudget() {
        for elapsed in [0.0, 1.0, 44.0, 100.0] {
            #expect(GroupsSignOutRetryDecision.decide(
                elapsedSeconds: elapsed, budgetSeconds: budget, reason: .channelPaused)
                == .surfacePermanent)
        }
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

    /// **Todo motivo tiene una decisión escrita, y un motivo nuevo tumba este test.** `decide` es una
    /// cadena de `if`, no un `switch`: el compilador NO obliga a pronunciarse, y la rama por defecto es la
    /// peor —45 s de espera y ~22 peticiones contra algo que no se cura—. Aquí la tabla es exhaustiva por
    /// construcción: el `allCases.count` se cae en cuanto aparece un motivo que nadie ha decidido.
    @Test
    func everyReasonHasADecision() {
        let esperado: [CloudSignOutFlowLogic.BlockReason: GroupsSignOutRetryDecision.Decision] = [
            // Se muestran al momento: ningún reintento del presupuesto cambia el veredicto.
            .permanent: .surfacePermanent,
            .sessionExpired: .surfacePermanent,
            .channelPaused: .surfacePermanent,
            // El fallo pasajero de la SUBIDA nace en el cierre de la nube, que no pasa por aquí. Si
            // llegara, reintentar contradiría su propio aviso («inténtalo en un rato»), así que se muestra.
            .uploadRetryLater: .surfacePermanent,
            // Se reintentan dentro del presupuesto: son los que sí se curan esperando.
            .transient: .retryAfter(seconds: GroupsSignOutRetryDecision.retryIntervalSeconds),
            // No los produce este camino, pero si llegaran, esperar tampoco arregla nada que sepamos —
            // caen en el reintento y eso es lo que hay que saber al añadir uno nuevo.
            .exportUnconfirmed: .retryAfter(seconds: GroupsSignOutRetryDecision.retryIntervalSeconds),
            .bridgeUnreadable: .retryAfter(seconds: GroupsSignOutRetryDecision.retryIntervalSeconds),
            .detachBusy: .retryAfter(seconds: GroupsSignOutRetryDecision.retryIntervalSeconds),
        ]
        #expect(CloudSignOutFlowLogic.BlockReason.allCases.count == esperado.count, """
            Hay un motivo de bloqueo sin decisión escrita. `decide` no es un `switch`, así que se lo va a
            tragar el reintento: 45 s y ~22 peticiones contra algo que quizá no se cura. Decídelo aquí.
            """)
        for motivo in CloudSignOutFlowLogic.BlockReason.allCases {
            #expect(GroupsSignOutRetryDecision.decide(
                elapsedSeconds: 0, budgetSeconds: budget, reason: motivo) == esperado[motivo])
        }
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

/// **Los cierres que borran por ARCHIVOS esperan al export y no se llevan nada sin contarlo: esa es toda
/// la seguridad del paso 9.**
///
/// Source-scan por la misma razón que las suites de arriba: el coordinador es privado y su camino exige
/// singletons de red y del espejo. Lo que hay que fijar es el ORDEN — los grupos antes de la espera, la
/// espera antes del arm, el último recuento sin `await` hasta el arm — y que ningún cierre borre filas.
@Suite("Cerrar sesión privada — espera el export y borra por archivos (source-scan)")
struct PrivateSignOutWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

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

    private static let signOutPath = "Yala/Services/CloudSync/CloudSessionSignOut.swift"
    private static let performMarker =
        "private func performSessionExit(context: ModelContext, plan: CloudSignOutFlowLogic.ExitPlan) async {"
    private static let finalizeMarker =
        "private func finalizeSessionExit(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, export: ExportPolicy) async {"
    private static let armMarker =
        "private func armAfterCredentials(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, export: ExportPolicy) async {"

    @Test("los grupos suben ANTES de la espera, y la espera va ANTES del borrado")
    func groupsThenExportThenWipe() throws {
        let perform = try Self.body(of: Self.performMarker, in: Self.source(Self.signOutPath))
        let groupsCheck = try #require(perform.range(of: "if blockIfGroupsCannotUpload(context: context, kind: plan.kind) { return }"), """
            La privada dejó de mirar sus grupos sin subir: el boot-wipe borraría el outbox de una sesión caducada.
            """)
        let push = try #require(perform.range(of: "await pushGroupsForSignOut(context: context)"))
        let gate = try #require(perform.range(of: "await confirmExportOrBlock(context: context, kind: plan.kind, credentialsReleased: false)"), """
            El cierre dejó de esperar al export de iCloud: un cambio guardado hace segundos se borraría sin \
            haber subido.
            """)
        let finalize = try #require(perform.range(of: "await finalizeSessionExit("))
        #expect(groupsCheck.lowerBound < push.lowerBound)
        #expect(push.lowerBound < gate.lowerBound)
        #expect(gate.lowerBound < finalize.lowerBound)
    }

    /// Con el espejo montado, borrar FILAS exporta los deletes a iCloud: destruiría la copia que el cierre
    /// promete conservar. Ningún cierre del coordinador puede llamar al wipe por filas.
    @Test("ningún cierre de sesión borra filas")
    func noRowWipeAnywhere() throws {
        #expect(!(try Self.source(Self.signOutPath)).contains("wipeAllUserData"))
    }

    /// Lo que se escribe mientras se cierra la sesión (las suspensiones de `signOut()` y del push token)
    /// tiene que contarse: el último recuento va DESPUÉS de soltar la sesión y no hay ni un `await` entre él y
    /// el arm, en los dos caminos que lo hacen — la espera normal y la pérdida aceptada, que vuelve a avisar
    /// si hay más de lo que se aceptó.
    @Test("el último recuento va pegado al arm, sin suspensiones de por medio")
    func finalCountIsGluedToTheArm() throws {
        let source = try Self.source(Self.signOutPath)
        let finalize = try Self.body(of: Self.finalizeMarker, in: source)
        let signOut = try #require(finalize.range(of: "await CloudAuthService.shared.signOut()"))
        let handOff = try #require(finalize.range(of: "await armAfterCredentials(context: context, kind: kind, export: export)"))
        #expect(signOut.lowerBound < handOff.lowerBound, "el recuento final tiene que ir DESPUÉS de soltar la sesión")
        let arm = try Self.body(of: Self.armMarker, in: source)
        let armCall = try #require(arm.range(of: "StorageModePersistence.armSignOutWipe()"))
        for finalCount in ["if Self.pendingPersonalExportCount(context: context) == 0 { break }",
                           "let now = Self.pendingPersonalExportCount(context: context)"] {
            let count = try #require(arm.range(of: finalCount), "falta el recuento `\(finalCount)`")
            #expect(count.lowerBound < armCall.lowerBound)
            #expect(!String(arm[count.upperBound..<armCall.lowerBound]).contains("await"), """
                Hay una suspensión entre el recuento y el arm: lo que se escriba en ella muere con el wipe sin \
                haberse contado.
                """)
        }
    }

    /// La re-verificación de grupos va tras la segunda subida y antes de soltar credenciales; el consent se
    /// olvida antes de `signOut()` (CR-2), y el arm es el disparador: va el último.
    @Test("grupos: segunda subida, residual, consent y credenciales en su orden")
    func groupsTailOrder() throws {
        let tail = try Self.body(of: Self.finalizeMarker, in: Self.source(Self.signOutPath))
        let push = try #require(tail.range(of: "await pushGroupsForSignOut(context: context)"))
        let teardown = try #require(tail.range(of: "GroupsSyncClient.shared.teardownForSignOut()"))
        let residual = try #require(tail.range(of: "Self.liveGroupsPendingCount(context: context)"))
        let consent = try #require(tail.range(of: "GroupsConsentState.clear()"))
        let signOut = try #require(tail.range(of: "await CloudAuthService.shared.signOut()"))
        #expect(push.lowerBound < teardown.lowerBound)
        #expect(teardown.lowerBound < residual.lowerBound)
        #expect(residual.lowerBound < consent.lowerBound)
        #expect(consent.lowerBound < signOut.lowerBound)
    }

    /// Sin sesión privada que conservar, el store de grupos se olvida con la sesión; en la privada sin
    /// sesión (C) solo si guarda filas del canal backend. Y ninguno de estos cierres intenta el swap.
    @Test("el store de grupos entra en el borrado por su regla, y el swap sigue siendo solo de la nube")
    func groupsMarkerRule_andNoSwap() throws {
        let source = try Self.source(Self.signOutPath)
        let finalize = try Self.body(of: Self.finalizeMarker, in: source)
        let arm = try Self.body(of: Self.armMarker, in: source)
        let groupsCheck = try #require(arm.range(of: "if blockIfGroupsCannotUpload(context: context, kind: kind) { return }"), """
            El último tramo dejó de mirar los grupos sin subir de la privada: una fila encolada durante la \
            espera moriría con el wipe.
            """)
        let marker = try #require(arm.range(of: "let forgetsGroups = kind.pushesGroups || Self.hasBackendGroupRows(context: context)"))
        #expect(groupsCheck.lowerBound < marker.lowerBound)
        #expect(arm.contains("if forgetsGroups && CloudSyncFlags.groupsBackendCompiledCapability {"))
        let tail = finalize + arm
        #expect(!tail.contains("attemptSignOutSwap"))
        #expect(!tail.contains("armGroupsOnlyWipe()"))
        #expect(!tail.contains("purgeGroupsSyncState("), """
            Volvió la purga en sesión: es un `save()` sobre el contexto compartido y el boot-wipe ya borra \
            el archivo de sync-meta.
            """)
    }

    @Test("la salida de emergencia exige el bloqueo del export vivo y vuelve a avisar si hay más")
    func emergencyExitIsGuarded() throws {
        let source = try Self.source(Self.signOutPath)
        let exit = try Self.body(of: "func exitDiscardingUnconfirmed(context: ModelContext) async {", in: source)
        #expect(exit.contains("guard case .blocked(let shown, .exportUnconfirmed) = phase else { return }"), """
            Sin el guard, «Cerrar sesión igualmente» borraría sin que ningún aviso lo haya ofrecido.
            """)
        #expect(exit.contains("now > accepted"), "entraron más cambios que los avisados: hay que volver a avisar")
        // La cifra aceptada viaja hasta el arm por los DOS caminos, antes y después de soltar la sesión…
        #expect(exit.contains("await armAfterCredentials(context: context, kind: blocked.kind, export: .acceptLoss(upTo: accepted))"))
        #expect(exit.contains("await finalizeSessionExit(context: context, kind: blocked.kind, export: .acceptLoss(upTo: accepted))"))
        // …y allí se vuelve a contar, pegado al arm.
        let arm = try Self.body(of: Self.armMarker, in: source)
        #expect(arm.contains("if now.map({ $0 > accepted }) ?? true {"))
    }

    /// «Esperar» sigue esperando y cierra solo al llegar a cero. Volver a `.idle` cancelaba el cierre sin
    /// decirlo y, tras soltar la sesión, dejaba el dispositivo sin sesión y sin borrado (review adversarial).
    @Test("«Esperar» retoma la espera donde se paró, sin volver a empezar el cierre")
    func waitResumesWhereItStopped() throws {
        let source = try Self.source(Self.signOutPath)
        let resume = try Self.body(of: "func resumeWaitingForExport(context: ModelContext) async {", in: source)
        #expect(resume.contains("guard case .blocked(_, .exportUnconfirmed) = phase else { return }"))
        #expect(resume.contains("await armAfterCredentials(context: context, kind: blocked.kind, export: .confirm)"))
        #expect(resume.contains("await finalizeSessionExit(context: context, kind: blocked.kind, export: .confirm)"))
        let profile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        let waitID = try #require(profile.range(of: ".accessibilityIdentifier(\"signout_export_wait\")"))
        let waitButton = String(profile[..<waitID.lowerBound].suffix(220))
        #expect(waitButton.contains("resumeWaitingForExport(context: modelContext)"), """
            El «Esperar» del aviso del export tiene que retomar la espera, no cerrar el aviso con \
            `acknowledgeBlocked()`.
            """)
        #expect(!waitButton.contains("acknowledgeBlocked()"))
    }

    /// La vista elige la hoja y el coordinador el borrado: si leyeran ejes distintos, la hoja prometería
    /// otro borrado. Y el coordinador no ejecuta una celda distinta de la confirmada.
    @Test("la vista y el coordinador resuelven la misma celda, y la confirmada manda")
    func viewAndCoordinatorShareTheCell() throws {
        let profile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        // En el cuerpo de `signOutRowPath`, no en todo el fichero: el literal sale también en la operación de
        // «Eliminar mi cuenta», y con él una mutación de la celda del cierre pasaba verde (review adversarial).
        let rowPath = try Self.body(of: "private var signOutRowPath: CloudSignOutFlowLogic.Path {", in: profile)
        #expect(rowPath.contains("hasPrivateSession: PrivateSessionMark.hasPrivateSession()"))
        #expect(rowPath.contains("groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability"))
        #expect(profile.contains("guard live.operation == scope.operation else {"))
        let signOut = try Self.source(Self.signOutPath)
        #expect(signOut.contains("hasPrivateSession: PrivateSessionMark.hasPrivateSession()"))
        #expect(signOut.contains("if let confirmedPath, confirmedPath != path {"))
    }
}

/// **El motivo del bloqueo tiene que LLEGAR a la pantalla, y eso no lo prueba ninguna función pura.**
///
/// `classify` puede devolver `.channelPaused` perfectamente y el arreglo seguir sin existir: entre esa
/// función y el aviso hay tres asignaciones de fase, y hasta el 2026-09-13 una de ellas colapsaba todo lo
/// que no fuera `.sessionExpired` en `.permanent`. Ahí es donde el canal en pausa se convertía en «el
/// problema es tu cuenta», y ahí es donde volvería a convertirse si alguien rehace el ternario.
///
/// Source-scan por la misma razón que las suites de arriba —el coordinador es privado y su camino exige
/// singletons de red, del espejo y de credenciales—, y sobre el CUERPO de cada método, no sobre el
/// fichero: los tres escriben `phase = .blocked(...)` y a nivel de fichero una mutación en uno pasaría
/// verde gracias a los otros dos.
///
/// Ticket `groups-killswitch-403-blocks-detach-forever`.
@Suite("Canal de Grupos en pausa — el motivo viaja hasta el aviso (source-scan)")
struct PausedChannelReasonWiringTests {

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

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

    private static let signOutPath = "Yala/Services/CloudSync/CloudSessionSignOut.swift"

    /// Colapsa todo espacio en blanco (saltos incluidos) a uno solo, para que un scan sobre varias líneas
    /// no dé un rojo falso cuando el formateador reparta el código de otra forma. Lo que se fija sigue
    /// siendo el ORDEN de los tokens, que es lo que aquí importa.
    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// **Los marcadores llevan la llave de apertura, y no es cosmético.** `body(of:)` arranca su
    /// contador en `depth = 1` justo después del marcador: sin la `{`, el contador corre sobre texto que
    /// aún no ha abierto el cuerpo y el corte se come todo lo que sigue hasta cerrar el TIPO. Medido el
    /// 2026-09-13 con el marcador de este push-all: devolvía 77 líneas con tres métodos ajenos dentro, así
    /// que las aserciones «sobre el cuerpo» eran de hecho sobre el fichero.
    private static let attemptCloseMarker = """
        private func attemptGroupsOnlyClose(
                context: ModelContext,
                quiescenceHardCap: TimeInterval
            ) async -> CloudSignOutFlowLogic.PushAllVerdict {
        """

    private static let groupsPushAllMarker = """
        private func pushAllPendingGroupsForSignOut(
                context: ModelContext,
                maxIterations: Int = 20
            ) async -> CloudSignOutFlowLogic.PushAllVerdict {
        """

    /// El push-all pide el testigo AL CLIENTE. Si alguien lo cambiara por un literal, el arreglo moriría
    /// sin que ninguna aserción de `classify` se enterase: la función pura seguiría siendo correcta.
    @Test("el push-all de grupos lee el testigo del kill, no un literal")
    func groupsPushAllReadsTheKillWitness() throws {
        let pushAll = try Self.body(
            of: Self.groupsPushAllMarker, in: try Self.source(Self.signOutPath))
        #expect(pushAll.contains("channelKilled: GroupsSyncClient.shared.stoppedByChannelKill(for: outcome)"), """
            El push-all de grupos dejó de preguntar al cliente cuál de los dos 403 paró el ciclo. Con el \
            kill-switch puesto, a quien tiene cambios sin subir se le vuelve a decir que el problema es su \
            cuenta. Y tiene que preguntarlo CON el outcome: el testigo suelto puede ser de un ciclo ajeno.
            """)
    }

    /// **El motor PERSONAL declara que su 403 no puede ser el kill, y eso hay que fijarlo.** Un
    /// `channelKilled: true` aquí le diría a una cuenta `.cloud` suspendida —que puede no tener grupos
    /// siquiera— que «los grupos están en pausa, vuelve en un rato»: falso, y encima le hace esperar algo
    /// que no llega. Lo que lo hace correcto está medido: `grep -rn 403 gateway/src/sync/` da cero
    /// emisores, así que por esa ruta el kill no viaja.
    @Test("el push-all personal declara que su 403 no es el del canal")
    func personalPushAllDeclaresNoChannelKill() throws {
        let personal = try Self.body(
            of: "func pushAllPendingForSignOut(maxIterations: Int = 20) async -> CloudSignOutFlowLogic.PushAllVerdict {",
            in: try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift"))
        #expect(personal.contains("channelKilled: false"), """
            El push-all del motor personal dejó de declarar su término del kill. En `true`, una cuenta
            suspendida sin grupos recibiría «los grupos están en pausa».
            """)
    }

    /// El retry interno ya no colapsa el motivo. Es la mitad del arreglo que vive fuera de toda función
    /// pura, y la que se deshace con un solo ternario.
    @Test("el retry interno propaga el motivo tal cual, sin aplanarlo")
    func retryLoopPropagatesTheReasonVerbatim() throws {
        let push = try Self.body(
            of: "private func pushGroupsForSignOut(context: ModelContext) async -> Bool {",
            in: try Self.source(Self.signOutPath))
        #expect(push.contains("phase = .blocked(pendingCount: pending, reason: reason)"), """
            El bloqueo del push-all dejó de propagar su motivo. Todo lo que `decide` manda mostrar al \
            momento —sesión caducada, cuenta no disponible y canal en pausa— llega a la pantalla como el \
            mismo aviso.
            """)
        #expect(!push.contains("reason: .permanent"), """
            Volvió un colapso a `.permanent` en el retry interno: es exactamente la forma del bug que este \
            ticket cerró.
            """)
    }

    /// **El paso intermedio también tiene que dejar pasar el motivo.** Entre el push-all y el retry hay un
    /// método más —`attemptGroupsOnlyClose`— y una lente adversarial midió que un colapso metido ahí
    /// devolvía el bug entero con todo lo demás en verde: los otros escaneos fijan tres puntos conocidos,
    /// no la propiedad «el motivo llega intacto». Aquí se fija que ese paso devuelve el veredicto del
    /// push-all SIN tocarlo, y que no le nacen `.blocked` nuevos por el camino.
    @Test("el paso intermedio devuelve el veredicto del push-all sin tocarlo")
    func theIntermediateStepDoesNotRewriteTheVerdict() throws {
        let attempt = try Self.body(of: Self.attemptCloseMarker, in: try Self.source(Self.signOutPath))
        #expect(attempt.contains("return await pushAllPendingGroupsForSignOut(context: context)"), """
            El paso intermedio dejó de devolver el veredicto del push-all tal cual. Una reescritura aquí
            atraviesa los otros escaneos sin tocarlos y devuelve el aviso que culpa a la cuenta.
            """)
        // Su único `.blocked` propio es el del gate de quiescencia, que sí es transitorio de verdad.
        #expect(attempt.components(separatedBy: "return .blocked").count - 1 == 1, """
            Apareció un `.blocked` nuevo en el paso intermedio: comprueba si reescribe el motivo del
            push-all antes de subir este número.
            """)
    }

    /// La celda `.cloud` sufre el mismo kill-switch: su push de grupos habla con el mismo endpoint.
    ///
    /// **Desde el 2026-09-14 el paso 2 no aplana nada: delega en una función pura y exhaustiva**
    /// (`cloudSignOutGroupsBlockReason`), y lo que aquí se fija es que SIGA delegando. El ternario que
    /// había —`reason == .channelPaused ? .channelPaused : .permanent`— salvaba al canal en pausa y
    /// convertía todo lo demás en «revisa tu conexión»: un 5xx y el 403 de un cortafuegos incluidos.
    /// Lo que se decide en esa función lo cubre `CloudSignOutGroupsReasonTests`; lo que no puede cubrir
    /// ninguna función pura es que el paso 2 la llame, que es esto.
    @Test("el cierre de la nube traduce el motivo con la función pura, sin aplanarlo")
    func cloudSignOutTranslatesTheReasonInsteadOfFlatteningIt() throws {
        let cloud = try Self.body(
            of: "private func performCloudSecureSignOut(context: ModelContext) async {",
            in: try Self.source(Self.signOutPath))
        let traduce = Self.squashed(cloud)
        #expect(traduce.contains(Self.squashed("""
            let shown = CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(reason)
            """)), """
            El paso 2 del cierre en la nube dejó de traducir el motivo del push-all de grupos. Con un \
            literal o un ternario, un corte de red, un 5xx y un cortafuegos vuelven a salir los tres como \
            «revisa tu conexión» — y el canal en pausa, como un problema de la cuenta.
            """)
        // Y lo traducido es lo que llega a la FASE, que es lo que la pantalla lee. Sin esta mitad, traducir
        // a una variable y luego escribir `reason` pasaba verde con el bug entero vivo.
        #expect(traduce.contains(Self.squashed("""
            phase = .blocked(pendingCount: pending, reason: shown)
            """)), """
            El motivo traducido dejó de alimentar la fase del bloqueo.
            """)
        // **Y el motivo deja rastro en los logs, con el slug del motivo TRADUCIDO.** Sin esta aserción el
        // breadcrumb se podía borrar entero sin romper nada —medido: el mutante sobrevivía— y en campo los
        // tres desenlaces del bloqueo vuelven a ser indistinguibles, que es lo que impide comprobar si a
        // alguien se le enseñó «revisa tu conexión» sobre un fallo que se cura esperando.
        #expect(traduce.contains(Self.squashed("""
            CloudSyncBreadcrumb.signOutGroupsBlocked(reason: shown.breadcrumbSlug)
            """)), """
            El cierre en la nube dejó de registrar POR QUÉ bloqueó el push-all de grupos.
            """)
        // El ternario nunca puede volver: es la forma exacta del bug, y su mutante es de un carácter.
        #expect(!cloud.contains("? .channelPaused : .permanent"), """
            Volvió el ternario que colapsaba el motivo en el cierre de la nube.
            """)
        // Los `.blocked` propios del camino son los CUATRO de sus guards (controller ausente, push-all
        // personal, push-all de grupos y el residual). Un quinto puede ser una reescritura del motivo.
        #expect(cloud.components(separatedBy: "phase = .blocked(").count - 1 == 4, """
            Cambió el número de bloqueos del cierre en la nube: comprueba si alguno reescribe el motivo \
            que viene del push-all de grupos.
            """)
    }

    /// **El motivo nuevo tiene que LLEGAR a la pantalla, y eso no lo prueba la función pura.** Entre ella y
    /// el aviso hay dos `switch` dentro de la vista: uno elige QUÉ alert sale y otro QUÉ dice. Si el
    /// primero lo mandara al alert de «un momento más», el aviso prometería una espera de segundos ante un
    /// servidor caído; si el segundo lo dejara en el genérico, volvería «revisa tu conexión» con todo lo
    /// demás en verde. Ticket `cloud-signout-collapses-every-groups-transient-into-permanent`.
    @Test("el aviso del cierre nombra el fallo pasajero de la subida, y por el alert que toca")
    func theSignOutAlertNamesTheTransientUploadFailure() throws {
        let profileFile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")

        // **El mensaje vive en `SignOutBlockedCopy` desde el 2026-09-15**, la tabla que Ajustes comparte con la
        // hoja del cambio de Apple ID. Se miran las dos mitades del cable: que la tabla tiene el copy y que
        // Ajustes la consume. Con la tabla bien y el consumo roto, el aviso vuelve al genérico.
        let copyFile = try Self.source("Yala/App/Views/Shared/SignOutBlockedCopy.swift")
        let message = Self.squashed(try Self.body(
            of: "static func message(for reason: CloudSignOutFlowLogic.BlockReason?) -> String {", in: copyFile))
        #expect(message.contains(
            Self.squashed("case .uploadRetryLater: return L10n.Groups.Errors.uploadRetryLater")), """
            El aviso del cierre perdió el copy del fallo pasajero de la subida: vuelve a decirle a quien \
            sufre un 5xx que revise una conexión que funciona.
            """)
        let profileMessage = Self.squashed(
            try Self.body(of: "private var signOutBlockedMessage: String {", in: profileFile))
        #expect(profileMessage.contains("SignOutBlockedCopy.message(for: signOutBlockedReason)"), """
            Ajustes dejó de leer su mensaje de la tabla compartida. Si lo recompone por su cuenta, las dos \
            pantallas que enseñan un cierre bloqueado vuelven a poder decir cosas distintas.
            """)

        // Y sale por el alert del bloqueo, no por el de «un momento más» (que promete segundos).
        //
        // **La etiqueta del `case` va con su CUERPO en el mismo literal, y eso lo cazó una lente**
        // (2026-09-14): comprobar solo la etiqueta deja pasar el mutante que cambia el cuerpo a
        // `showSignOutPendingAlert = true` — con él los CUATRO motivos del bloqueo salen por el alert de
        // «un momento más» y este test seguía verde. El fuente se normaliza antes (espacios y saltos a
        // uno solo) para que partir la línea no dé un rojo falso.
        let present = Self.squashed(try Self.body(
            of: "private func presentSignOutBlock(_ reason: CloudSignOutFlowLogic.BlockReason) {",
            in: profileFile))
        #expect(present.contains(Self.squashed("""
            case .permanent, .sessionExpired, .channelPaused, .uploadRetryLater:
                showSignOutBlockedAlert = true
            """)), """
            El fallo pasajero de la subida dejó de entrar por el alert del bloqueo. Si se fue al de \
            `.transient`, su título promete «un momento más» sobre algo que nadie ha reintentado.
            """)
        // Y la rama de `.transient` conserva la SUYA: el mutante que las une por el otro lado —meter
        // `.uploadRetryLater` aquí— tiene que romper algo, y sin esta aserción no rompe nada.
        #expect(present.contains(Self.squashed("case .transient: showSignOutPendingAlert = true")), """
            La rama de `.transient` dejó de encender su propio aviso.
            """)
        #expect(!present.contains("default:"), """
            Volvió el `default` a la elección del alert: un motivo nuevo vuelve a caer donde caiga sin que \
            nada lo advierta.
            """)
    }

    /// **Las TRES pantallas** que pueden enseñar este bloqueo nombran el canal en pausa con su copy propio.
    /// Eran dos hasta que una lente adversarial midió la tercera: `WelcomeGroupsGateView`, la puerta de
    /// grupos del Welcome, observa la MISMA fase del coordinador y su rama `.blocked` era un catch-all que
    /// decía «vuelve a entrar con esa cuenta» — un consejo que con el kill puesto no sube nada, porque el
    /// 403 no depende de la sesión.
    ///
    /// Las dos primeras lo garantizan además con `switch` EXHAUSTIVOS (sin `default`); la tercera no puede,
    /// porque el suyo es sobre la fase del coordinador y liga el motivo en un patrón — ahí este escaneo es
    /// la única red, y por eso comprueba también el ORDEN de las ramas.
    /// Y desde el 2026-09-15 hay una cuarta lectora: la hoja del cambio de Apple ID, que lee la MISMA tabla que
    /// Ajustes (`SignOutBlockedCopy`), así que el copy se mira en la tabla y el consumo en cada pantalla.
    @Test("las pantallas que enseñan el bloqueo tienen copy propio para el canal en pausa")
    func allThreeScreensNameThePausedChannel() throws {
        // **Se comprueba también que el aviso CONSUME la propiedad, y no es celo.** Una lente midió el
        // mutante: cambiar el `Text(...)` por un literal deja las dos computed MUERTAS —Swift no avisa de
        // una computed privada sin usar—, devuelve el copy genérico a las dos pantallas y deja verde todo
        // lo demás. O sea el bug del ticket, entero, invisible.
        let sectionFile = try Self.source("Yala/App/Views/Settings/GroupsAssociationSection.swift")
        let section = try Self.body(of: "private var blockedMessage: String {", in: sectionFile)
        #expect(section.contains("case .channelPaused: return L10n.Groups.Errors.channelPaused"))
        #expect(sectionFile.contains("Text(blockedMessage)"), """
            El aviso del desasociar dejó de leer su mensaje por motivo: la propiedad queda muerta y el copy
            vuelve al genérico.
            """)
        #expect(!section.contains("default:"), """
            Volvió el `default` al aviso del desasociar: un motivo nuevo vuelve a caer en «inténtalo en un \
            momento» sin que nada lo advierta.
            """)

        // Ajustes y la hoja del cambio de Apple ID leen la MISMA tabla desde el 2026-09-15
        // (`SignOutBlockedCopy`): el copy se mira en la tabla y el consumo, en cada pantalla.
        let copyFile = try Self.source("Yala/App/Views/Shared/SignOutBlockedCopy.swift")
        let copy = try Self.body(
            of: "static func message(for reason: CloudSignOutFlowLogic.BlockReason?) -> String {", in: copyFile)
        #expect(copy.contains("case .channelPaused: return L10n.Groups.Errors.channelPaused"))
        #expect(!copy.contains("default:"), """
            Volvió el `default` a la tabla del cierre bloqueado: un motivo nuevo vuelve a caer en «revisa tu \
            conexión» sin que nada lo advierta, en Ajustes y en la hoja del cambio de Apple ID a la vez.
            """)
        let profileFile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        let profile = try Self.body(of: "private var signOutBlockedMessage: String {", in: profileFile)
        #expect(profile.contains("SignOutBlockedCopy.message(for: signOutBlockedReason)"), """
            Ajustes dejó de leer la tabla compartida del cierre bloqueado.
            """)
        #expect(profileFile.contains("Text(signOutBlockedMessage)"), """
            El aviso del cierre dejó de leer su mensaje por motivo: misma muerte silenciosa.
            """)
        // Y la hoja del cambio de Apple ID la consume con el motivo REAL del bloqueo.
        let notice = try Self.source("Yala/App/Views/Shared/AppleIDCloseNoticeView.swift")
        #expect(notice.contains("message: SignOutBlockedCopy.message(for: reason)"), """
            La hoja del cambio de Apple ID dejó de enseñar el motivo del bloqueo con la tabla compartida.
            """)

        // La puerta de grupos del Welcome. Su rama propia va ANTES del catch-all, o no la alcanza nadie.
        let gate = try Self.source("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        let paused = try #require(gate.range(of: "case .blocked(_, .channelPaused):"), """
            La puerta de grupos del Welcome perdió su rama del canal en pausa: vuelve a decirle a quien \
            acepta una invitación que entre con su cuenta, sobre un 403 que no depende de la sesión.
            """)
        let catchAll = try #require(gate.range(of: "\n        case .blocked:"))
        // **El literal, dentro de SU rama y no en el fichero.** Con un `contains` a nivel de fichero,
        // intercambiar los dos `body:` —el copy de pausa al catch-all y el de «vuelve a entrar» a la rama
        // de pausa— pasaba las tres aserciones: justo el fallo que esto existe para impedir.
        let pausedBranch = String(gate[paused.upperBound..<catchAll.lowerBound])
        #expect(pausedBranch.contains("body: L10n.Groups.Errors.channelPaused"), """
            La rama del canal en pausa dejó de enseñar su copy. Si el literal sigue en el fichero, mira
            si se lo quedó el catch-all.
            """)
        #expect(paused.lowerBound < catchAll.lowerBound, """
            La rama del canal en pausa quedó DESPUÉS del catch-all `case .blocked:`: el motivo cae otra vez
            en el aviso que manda a volver a entrar.
            """)
    }
}
