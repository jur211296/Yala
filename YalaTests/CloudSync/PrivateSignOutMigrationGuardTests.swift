//
//  PrivateSignOutMigrationGuardTests.swift
//  YalaTests
//
//  Cerrar la sesión privada ya no borra lo local a mitad de un paso de los datos entre iCloud y la nube (ticket
//  `private-sign-out-proceeds-with-a-migration-in-flight`, 2026-09-27).
//
//  Tres niveles, y cada uno caza algo que los otros no:
//   1. La lógica pura (`CloudSignOutFlowLogic.migrationBlockReason`): qué motivo, qué celda, y que la decisión es la del
//      predicado compartido y ninguna otra.
//   2. El escritor (`CloudSessionSignOut`): con la migración en vuelo el cierre se para por la entrada de verdad, y en
//      reposo su puerta deja pasar.
//   3. El cableado (source-scan): dónde está la puerta en el camino —antes de nada, y pegada al arm sin `await`—, que es
//      lo que un test de comportamiento no puede fijar sin correr un cierre entero contra el llavero y el App Group.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lecturas de ejemplo

private enum Reading {
    /// La celda que SÍ está en reposo: sin controller, journal sin empezar, iCloud con espejo, nada armado.
    static func make(controllerState: CloudMigrationUIState? = nil,
                     controllerIsWorking: Bool = false,
                     journalRead: JournaledPhaseRead = .phase(.notStarted),
                     persistedStorageMode: StorageMode = .icloud,
                     mirrorOffArmed: Bool = false,
                     mountedDecision: SwiftDataConfiguration.PersonalStoreDecision = .iCloudMirror) -> MigrationRestReading {
        MigrationRestReading(controllerState: controllerState, controllerIsWorking: controllerIsWorking,
                             journalRead: journalRead, persistedStorageMode: persistedStorageMode,
                             mirrorOffArmed: mirrorOffArmed, mountedDecision: mountedDecision)
    }

    static let atRest = make()
    static let uploading = make(journalRead: .phase(.uploadingSnapshot))
}

// MARK: - 1 · La lógica pura

@Suite("Cierre privado · no a mitad de una migración (lógica)")
struct PrivateSignOutMigrationReasonTests {

    typealias Logic = CloudSignOutFlowLogic
    /// Las tres celdas que borran por archivos. Solo-grupos entra: la review midió que también puede migrar.
    private static let privateKinds: [Logic.ExitKind] = [.privateOnly, .privateWithGroups, .groupsOnly]

    @Test("Control positivo: en reposo el cierre sigue, en las tres celdas")
    func enReposo_sigue() {
        for kind in Self.privateKinds {
            #expect(Logic.migrationBlockReason(kind: kind, reading: Reading.atRest) == nil, "\(kind)")
            #expect(Logic.migrationBlockReason(kind: kind, reading: Reading.make(controllerState: .idle)) == nil, "\(kind)")
            // La vuelta a iCloud terminada es reposo: la tarjeta vuelve a ofrecer migrar.
            #expect(Logic.migrationBlockReason(kind: kind, reading: Reading.make(journalRead: .phase(.icloudActive)))
                    == nil, "\(kind)")
        }
    }

    @Test("MUTACIÓN: con la subida en vuelo se para, sin controller (el journal es la fuente que queda)")
    func subidaEnVuelo_sinController_seParaConSuMotivo() {
        for kind in Self.privateKinds {
            #expect(Logic.migrationBlockReason(kind: kind, reading: Reading.uploading) == .migrationInFlight, "\(kind)")
        }
    }

    @Test("MUTACIÓN: con el controller trabajando y su estado aún en `.idle` se para (un adopt o una ida recién arrancados)")
    func controllerTrabajando_sePara() {
        #expect(Logic.migrationBlockReason(kind: .privateOnly, reading: Reading.make(controllerState: .idle,
                                                                                     controllerIsWorking: true))
                == .migrationInFlight)
    }

    @Test("Cada estado fuera de reposo para el cierre: ida, vuelta, relanzamiento, líder ajeno, nube a medias")
    func cadaEstadoFueraDeReposo_seParaEnVuelo() {
        let enVuelo: [MigrationRestReading] = [
            Reading.make(controllerState: .migrating(MigrationUIStep(fraction: 0.5, phase: .uploadingSnapshot))),
            Reading.make(journalRead: .phase(.reverseDrainAll)),
            Reading.make(journalRead: .phase(.waitingForLeader)),
            Reading.make(journalRead: .phase(.cutover(.pending))),
            // `.done` con el modo aún en `.icloud`: el cutover no persistió el modo todavía.
            Reading.make(journalRead: .phase(.done)),
            // El mirror-off armado con el espejo aún montado: toca relanzar.
            Reading.make(mirrorOffArmed: true, mountedDecision: .iCloudMirror),
        ]
        for reading in enVuelo {
            #expect(Logic.migrationBlockReason(kind: .privateOnly, reading: reading) == .migrationInFlight, "\(reading)")
        }
    }

    @Test("MUTACIÓN: una migración FALLIDA también para el cierre — es el predicado compartido, y su salida es «Reintentar»")
    func migracionFallida_tambienPara() {
        // Abrirlo es la decisión pendiente de `apple-id-change-check-stays-off-after-a-failed-migration`: este test cae el
        // día que se tome, y tiene que caer en los DOS lectores a la vez.
        #expect(Logic.migrationBlockReason(kind: .privateOnly, reading: Reading.make(journalRead: .phase(.failedRollback)))
                == .migrationInFlight)
        #expect(Logic.migrationBlockReason(kind: .privateOnly,
                                           reading: Reading.make(journalRead: .phase(.reverseFailedRollback)))
                == .migrationInFlight)
    }

    @Test("MUTACIÓN: journal ilegible y nadie sabe más ⇒ su motivo propio, que no manda a una fila que puede no estar")
    func journalIlegible_motivoPropio() {
        #expect(Logic.migrationBlockReason(kind: .privateOnly, reading: Reading.make(journalRead: .unreadable))
                == .migrationUnreadable)
        #expect(Logic.migrationBlockReason(kind: .privateOnly, reading: Reading.make(controllerState: .journalUnreadable))
                == .migrationUnreadable)
        // El controller leyó bien (`.idle`) y el journal de `MigrationPhaseStore` no: sigue sin saberse más, y el texto no
        // puede mandar a una fila que con el controller en `.idle` puede no estar (mutante de la review: quitar el
        // `controllerState != .idle`).
        #expect(Logic.migrationBlockReason(kind: .privateOnly,
                                           reading: Reading.make(controllerState: .idle, journalRead: .unreadable))
                == .migrationUnreadable)
    }

    @Test("MUTACIÓN: si el controller sabe algo, manda él — aunque el journal no se lea")
    func controllerSabeMas_mandaEl() {
        #expect(Logic.migrationBlockReason(
            kind: .privateOnly,
            reading: Reading.make(controllerState: .migrating(MigrationUIStep(fraction: 0.3, phase: .claimingMigration)),
                                  journalRead: .unreadable)) == .migrationInFlight)
        #expect(Logic.migrationBlockReason(
            kind: .privateOnly, reading: Reading.make(controllerIsWorking: true, journalRead: .unreadable))
                == .migrationInFlight)
    }

    @Test("MUTACIÓN: solo-grupos TAMBIÉN se para — nada le impide migrar, y su cierre puede borrar un store que espeja")
    func soloGrupos_tambienSePara() {
        #expect(Logic.migrationBlockReason(kind: .groupsOnly, reading: Reading.uploading) == .migrationInFlight)
        #expect(Logic.migrationBlockReason(kind: .groupsOnly, reading: Reading.make(journalRead: .unreadable))
                == .migrationUnreadable)
    }

    /// **La decisión es la del predicado compartido, y nada más.** Sobre una rejilla de lecturas, el cierre privado se para
    /// exactamente cuando la oferta del cambio de Apple ID diría «ahora no». Si alguien añade aquí un término propio, los
    /// dos lectores dejan de contestar la misma pregunta y esto se pone rojo.
    @Test("El cierre se para exactamente cuando `migrationAtRest` dice que no")
    func mismaDecisionQueElPredicadoCompartido() {
        let states: [CloudMigrationUIState?] = [nil, .idle, .journalUnreadable, .cloudActive, .waitingForLeader,
                                                .failed(.migration), .needsRelaunch(.toCloud)]
        let reads: [JournaledPhaseRead] = [.phase(.notStarted), .phase(.uploadingSnapshot), .phase(.failedRollback),
                                           .phase(.icloudActive), .phase(.done), .unreadable]
        var casos = 0
        for state in states {
            for working in [false, true] {
                for read in reads {
                    for mode in [StorageMode.icloud, .cloud] {
                        for armed in [false, true] {
                            let reading = Reading.make(controllerState: state, controllerIsWorking: working, journalRead: read,
                                                       persistedStorageMode: mode, mirrorOffArmed: armed)
                            for kind in Self.privateKinds {
                                #expect((Logic.migrationBlockReason(kind: kind, reading: reading) == nil)
                                        == AppleIDChangeCloseLogic.migrationAtRest(reading), "\(reading)")
                                casos += 1
                            }
                        }
                    }
                }
            }
        }
        #expect(casos == 7 * 2 * 6 * 2 * 2 * 3)
    }

    @Test("Los dos motivos tienen texto propio en Ajustes, distinto del genérico y entre sí")
    func copyPropio() {
        #expect(SignOutBlockedCopy.message(for: .migrationInFlight) == L10n.Settings.signOutMigrationInFlight)
        #expect(SignOutBlockedCopy.message(for: .migrationUnreadable) == L10n.Settings.signOutMigrationUnreadable)
        #expect(SignOutBlockedCopy.title(for: .migrationInFlight) == L10n.Settings.signOutBlockedTitle)
        #expect(SignOutBlockedCopy.title(for: .migrationUnreadable) == L10n.Settings.signOutBlockedTitle)
        let textos = [L10n.Settings.signOutMigrationInFlight, L10n.Settings.signOutMigrationUnreadable,
                      L10n.Settings.signOutBlockedMessage, L10n.Welcome.Groups.neutralMigrationBody]
        #expect(Set(textos).count == textos.count)
        #expect(CloudSignOutFlowLogic.BlockReason.migrationInFlight.breadcrumbSlug == "migration-in-flight")
        #expect(CloudSignOutFlowLogic.BlockReason.migrationUnreadable.breadcrumbSlug == "migration-unreadable")
    }
}

// MARK: - 2 · El escritor

/// El coordinador es un singleton con fase observable: la suite va en serie y deja la fase y el override como los encontró.
@MainActor
@Suite("Cierre por archivos · el escritor se para con la migración en vuelo", .serialized)
struct PrivateSignOutMigrationWriterTests {

    private let coordinator = CloudSessionSignOut.shared

    /// Deja el coordinador en `.idle` y sin override, antes y después.
    private func reset() {
        coordinator.acknowledgeBlocked()
        coordinator.migrationRestReadingOverride = nil
    }

    /// La celda del host de test, que tiene que ser privada: en solo-grupos la puerta no participa y `signOut` correría el
    /// cierre de verdad. Se exige ANTES de llamar, no se supone.
    private func requirePrivateCell() throws -> CloudSignOutFlowLogic.Path {
        let path = CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode, hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability,
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
        try #require(path == .privateSignOut || path == .privateWithGroupsSignOut,
                     "el host de test no está en una celda privada (\(path)): este test no mediría nada")
        return path
    }

    /// Si la puerta falla —el mutante—, el cierre de verdad llega a armar el borrado en el host de test. Se desarma
    /// DESPUÉS de las aserciones, así que no tapa nada: solo evita que el siguiente arranque del host lo ejecute.
    private func disarmIfAMutantArmed() {
        guard StorageModePersistence.isSignOutWipeArmed() else { return }
        StorageModePersistence.clearSignOutWipeArm()
        StorageModePersistence.clearSignOutWipeIncludesGroups()
    }

    @Test("MUTACIÓN: con la subida en vuelo, `signOut` se para con su motivo y NO arma el borrado")
    func signOut_conMigracionEnVuelo_seParaSinArmar() async throws {
        reset()
        defer { reset() }
        try #require(coordinator.phase == .idle, "el coordinador venía ocupado de otro test")
        try #require(!StorageModePersistence.isSignOutWipeArmed(), "el borrado venía armado de otro test")
        let path = try requirePrivateCell()

        coordinator.migrationRestReadingOverride = { Reading.uploading }
        await coordinator.signOut(context: try makeTestContext(), confirmedPath: path)

        #expect(coordinator.phase == .blocked(pendingCount: 0, reason: .migrationInFlight))
        #expect(!StorageModePersistence.isSignOutWipeArmed())
        disarmIfAMutantArmed()
    }

    @Test("Con el journal ilegible, `signOut` se para con el motivo que no manda a Almacenamiento")
    func signOut_conJournalIlegible_motivoPropio() async throws {
        reset()
        defer { reset() }
        try #require(coordinator.phase == .idle)
        try #require(!StorageModePersistence.isSignOutWipeArmed())
        let path = try requirePrivateCell()

        coordinator.migrationRestReadingOverride = { Reading.make(journalRead: .unreadable) }
        await coordinator.signOut(context: try makeTestContext(), confirmedPath: path)

        #expect(coordinator.phase == .blocked(pendingCount: 0, reason: .migrationUnreadable))
        #expect(!StorageModePersistence.isSignOutWipeArmed())
        disarmIfAMutantArmed()
    }

    @Test("Control positivo: en reposo la puerta del escritor deja pasar y no toca la fase")
    func puerta_enReposo_dejaPasar() {
        reset()
        defer { reset() }
        coordinator.migrationRestReadingOverride = { Reading.atRest }
        for kind in [CloudSignOutFlowLogic.ExitKind.privateOnly, .privateWithGroups, .groupsOnly] {
            #expect(!coordinator.blockIfMigrationNotAtRest(kind: kind), "\(kind)")
            #expect(coordinator.phase == .idle)
        }
    }

    @Test("La puerta del escritor, con la subida en vuelo: se para en las tres celdas")
    func puerta_enVuelo() {
        for kind in [CloudSignOutFlowLogic.ExitKind.privateOnly, .privateWithGroups, .groupsOnly] {
            reset()
            coordinator.migrationRestReadingOverride = { Reading.uploading }
            #expect(coordinator.blockIfMigrationNotAtRest(kind: kind), "\(kind)")
            #expect(coordinator.phase == .blocked(pendingCount: 0, reason: .migrationInFlight), "\(kind)")
        }
        reset()
    }

    @Test("Sin override, la puerta lee la lectura de producción")
    func sinOverride_leeLaDeProduccion() throws {
        reset()
        defer { reset() }
        let esperado = CloudSignOutFlowLogic.migrationBlockReason(kind: .privateOnly, reading: MigrationRestReading.live)
        #expect(coordinator.blockIfMigrationNotAtRest(kind: .privateOnly) == (esperado != nil))
        if let esperado {
            #expect(coordinator.phase == .blocked(pendingCount: 0, reason: esperado))
        } else {
            #expect(coordinator.phase == .idle)
        }
    }
}

// MARK: - 3 · El cableado

/// **Por qué source-scan.** El orden del cierre —qué pasa antes de qué, y dónde no hay `await`— no se puede observar sin
/// correr un cierre entero, que suelta la sesión del llavero, desregistra el push y arma un borrado en el host de test.
/// Molde de `SignOutSessionSurvivesTests` y `AppleIDChangeWiringTests`.
@Suite("Cierre privado · la puerta de la migración, en su sitio (source-scan)")
struct PrivateSignOutMigrationWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Sin comentarios de línea: documentar el invariante que el scan mide no puede romperlo.
    private static func code(_ path: String) throws -> String {
        let raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        return raw.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de una función, contando llaves.
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    private static let signOut = "Yala/Services/CloudSync/CloudSessionSignOut.swift"
    private static let gate = "if blockIfMigrationNotAtRest(kind: plan.kind) { return }"
    private static let gateAtArm = "if blockIfMigrationNotAtRest(kind: kind) { return }"

    @Test("MUTACIÓN: la puerta va la PRIMERA del cierre, antes de subir grupos o esperar a iCloud")
    func alEmpezar() throws {
        let fn = try Self.body(of: "private func performSessionExit(context: ModelContext, plan: CloudSignOutFlowLogic.ExitPlan) async {",
                               in: try Self.code(Self.signOut))
        let puerta = try #require(fn.range(of: Self.gate), "el cierre ya no mira la migración al empezar")
        let grupos = try #require(fn.range(
            of: "if blockIfGroupsCannotUpload(context: context, kind: plan.kind, lossExit: .sessionExit(plan)) { return }"))
        let primerAwait = try #require(fn.range(of: "await "))
        #expect(puerta.upperBound <= grupos.lowerBound)
        #expect(puerta.upperBound <= primerAwait.lowerBound, """
            la puerta de la migración quedó detrás de un `await`: el cierre sube grupos o espera a iCloud antes de mirar si
            hay una migración en vuelo, y con la sesión de grupos suelta para nada.
            """)
    }

    @Test("MUTACIÓN: al entrar en `finalizeSessionExit`, antes de soltar el canal y la sesión")
    func alRetomar() throws {
        let fn = try Self.body(of: "private func finalizeSessionExit(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, export: ExportPolicy) async {",
                               in: try Self.code(Self.signOut))
        let puerta = try #require(fn.range(of: Self.gateAtArm), """
            `finalizeSessionExit` ya no mira la migración: «Cerrar sesión igualmente», «Esperar» y «Cerrar sesión y perderlos» \
            entran por aquí sin pasar por `performSessionExit`, y sueltan la sesión que usa una migración en vuelo.
            """)
        let primerAwait = try #require(fn.range(of: "await "))
        let teardown = try #require(fn.range(of: "GroupsSyncClient.shared.teardownForSignOut()"))
        #expect(puerta.upperBound <= primerAwait.lowerBound)
        #expect(puerta.upperBound <= teardown.lowerBound)
    }

    @Test("MUTACIÓN: la puerta se re-lee PEGADA al arm, sin un `await` entre medias")
    func pegadaAlArm() throws {
        let fn = try Self.body(of: "private func armAfterCredentials(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, export: ExportPolicy) async {",
                               in: try Self.code(Self.signOut))
        let puerta = try #require(fn.range(of: Self.gateAtArm), """
            el arm ya no re-lee la migración: una que arranque durante la espera de iCloud se borra a mitad de la subida.
            """)
        let arm = try #require(fn.range(of: "StorageModePersistence.armSignOutWipe()"))
        #expect(puerta.upperBound <= arm.lowerBound)
        // Fuera del `switch` del export (dentro de una rama solo correría en esa) y antes de escribir el marcador de grupos
        // (entre él y el arm, un bloqueo dejaría el marcador puesto sin arm). Mutantes de la review.
        let grupos = try #require(fn.range(
            of: "if blockIfGroupsCannotUpload(context: context, kind: kind, lossExit: .finalize(kind: kind, export: export)) { return }"))
        let marcador = try #require(fn.range(of: "if CloudSignOutFlowLogic.wipeForgetsGroups("))
        #expect(grupos.upperBound <= puerta.lowerBound)
        #expect(puerta.upperBound <= marcador.lowerBound)
        #expect(!fn[puerta.upperBound..<arm.lowerBound].contains("await"), "hay un `await` entre la puerta y el arm")
        let ultimoAwait = try #require(fn.range(of: "await ", options: .backwards))
        #expect(ultimoAwait.upperBound <= puerta.lowerBound, "la puerta tiene que ir DESPUÉS del último `await` del cierre")
    }

    @Test("La puerta está en esos tres sitios y en ninguno más, y decide con el predicado compartido")
    func dosSitiosUnPredicado() throws {
        let src = try Self.code(Self.signOut)
        #expect(src.components(separatedBy: "blockIfMigrationNotAtRest(kind:").count - 1 == 4, "la definición y tres usos")
        let fn = try Self.body(of: "func blockIfMigrationNotAtRest(kind: CloudSignOutFlowLogic.ExitKind) -> Bool {", in: src)
        #expect(fn.contains("migrationRestReadingOverride?() ?? MigrationRestReading.live"))
        #expect(fn.contains("CloudSignOutFlowLogic.migrationBlockReason(kind: kind, reading: reading)"))
        #expect(fn.contains("phase = .blocked(pendingCount: 0, reason: reason)"))

        let logic = try Self.code("Yala/App/Logic/CloudSignOutFlowLogic.swift")
        let reason = try Self.body(of: "static func migrationBlockReason(kind: ExitKind, reading: MigrationRestReading) -> BlockReason? {",
                                   in: logic)
        #expect(reason.contains("guard !AppleIDChangeCloseLogic.migrationAtRest(reading) else { return nil }"))
    }

    @Test("MUTACIÓN: la lectura de producción lee las DOS fuentes, y la oferta del Apple ID lee por el mismo sitio")
    func unaSolaLectura() throws {
        let normalizado = { (s: String) in s.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
        let reading = try Self.body(of: "@MainActor static var live: MigrationRestReading {",
                                    in: try Self.code("Yala/Services/CloudSync/MigrationRestReading.swift"))
        let esperado = """
            MigrationRestReading(
                controllerState: CloudMigrationController.shared?.uiState,
                controllerIsWorking: CloudMigrationController.shared?.isWorking ?? false,
                journalRead: MigrationPhaseStore.shared.currentPhaseRead,
                persistedStorageMode: StorageModePersistence.read(),
                mirrorOffArmed: StorageModePersistence.isMirrorOffArmed(),
                mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision)
            """
        #expect(normalizado(reading) == normalizado(esperado))
        let boot = try Self.body(of: "private func migrationAtRestForAppleIDChange() -> Bool {",
                                 in: try Self.code("Yala/App/AppBootstrapper.swift"))
        #expect(normalizado(boot) == "AppleIDChangeCloseLogic.migrationAtRest(.live)")
    }

    @Test("Ajustes enseña el aviso con los dos motivos; la puerta del Welcome, su rama propia antes del catch-all")
    func pantallas() throws {
        let profile = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains(".signOutSessionSurvived, .migrationInFlight, .migrationUnreadable, .personalCaptureUnfinished:\n                showSignOutBlockedAlert = true"))
        let welcome = try Self.code("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        let rama = try #require(welcome.range(of: "case .blocked(_, .migrationInFlight), .blocked(_, .migrationUnreadable):"))
        let catchAll = try #require(welcome.range(of: "        case .blocked(let pending, let reason):\n"))
        #expect(rama.upperBound <= catchAll.lowerBound)
        let cuerpo = String(welcome[rama.upperBound...].prefix(900))
        #expect(cuerpo.contains("title: L10n.Welcome.Groups.neutralUnavailableTitle,"))
        #expect(cuerpo.contains("body: L10n.Welcome.Groups.neutralMigrationBody,"))
        #expect(cuerpo.contains("YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { leaveAfterBlock() }"))
    }
}
