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
        // La sesión caducada lleva su motivo propio desde el paso 9 (el aviso pide volver a entrar); el camino
        // `.cloud` lo sigue mostrando como permanente porque re-mapea todo bloqueo a `.permanent`.
        #expect(CloudSignOutFlowLogic.pushAllVerdict(
            livePendingCount: 5, cycleOutcome: .sessionExpired, iteration: 1, maxIterations: 10
        ) == .blocked(pendingCount: 5, reason: .sessionExpired))
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
        // Las dos son permanentes, pero la sesión caducada tiene su motivo propio desde el paso 9: se arregla
        // volviendo a entrar, y el aviso tiene que decirlo en vez de mandar a revisar la conexión.
        #expect(CloudSignOutFlowLogic.classify(.sessionExpired) == .sessionExpired)
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
        // La sesión caducada (paso 9) se trata igual: sin sesión, esperar no sube nada.
        for reason in [CloudSignOutFlowLogic.BlockReason.permanent, .sessionExpired] {
            #expect(GroupsSignOutRetryDecision.decide(
                elapsedSeconds: 0, budgetSeconds: budget, reason: reason) == .surfacePermanent)
            // Aunque quede presupuesto, un permanente jamás reintenta.
            #expect(GroupsSignOutRetryDecision.decide(
                elapsedSeconds: 100, budgetSeconds: budget, reason: reason) == .surfacePermanent)
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
