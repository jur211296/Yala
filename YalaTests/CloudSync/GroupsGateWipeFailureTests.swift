//
//  GroupsGateWipeFailureTests.swift
//  YalaTests / CloudSync
//
//  Ticket `sign-out-wipe-abort-loops-the-groups-gate`: **si el borrado del arranque no puede borrar los archivos, la
//  puerta de Grupos deja de entrar en bucle.**
//
//  El bucle medido: la puerta arma el borrado y persiste su destino → el arranque aborta en el guard S3 y, con el modo
//  en `.icloud`, desarma → los datos y el espejo siguen → el arranque retoma la puerta → la puerta mide lo mismo y
//  vuelve a armar (en la rama del organizador, sin preguntar) → «reabre Yala» → vuelta al principio. Cada vuelta cancela
//  además las notificaciones locales y vacía el widget.
//
//  Dos mitades: el hook deja un testigo cuando aborta un borrado que armó la puerta (variante inyectable, sin archivos
//  ni `UserDefaults.standard`), y la puerta lo mira ANTES de medir y no arma nada (source-scan: la decisión vive en una
//  vista con `CloudSessionSignOut.shared` dentro; su recorrido de verdad lo hace el XCUITest
//  `WelcomeChooserUITests.testGroupsGate_afterAWipeThatCouldNotDelete_saysSoAndDoesNotRetry`).
//

import Foundation
import Testing

@testable import Yala

@Suite("La puerta de Grupos tras un borrado de arranque que no pudo borrar")
struct GroupsGateWipeFailureTests {

    typealias Destination = WelcomeMirrorRelaunchLogic.Destination

    /// Los destinos que NO escribe la puerta, más «ninguno».
    static let notFromTheGate: [Destination?] =
        Destination.allCases.filter { $0 != .groupsOrganizer && $0 != .groupsInvite }.map { Optional($0) } + [nil]

    /// Un teléfono al que la puerta de Grupos acaba de devolver al neutro: modo `.icloud` (celdas privada y solo-grupos),
    /// borrado armado y el destino que la puerta persiste justo después del arm.
    private func armedByGate(prefix: String, destination: Destination? = .groupsOrganizer,
                             mode: StorageMode = .icloud) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: prefix)
        StorageModePersistence.write(mode, defaults: defaults)
        if mode == .cloud { defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey) }
        StorageModePersistence.armSignOutWipe(defaults)
        if let destination { WelcomePendingDestinationStore.set(destination, defaults: defaults) }
        return defaults
    }

    /// Corre el hook y devuelve (cancelaciones, resets).
    private func runWipe(_ defaults: UserDefaults, deletes: Bool) -> (cancels: Int, resets: Int) {
        var cancels = 0, resets = 0
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in deletes },
            resetPrefs: { resets += 1 },
            cancelNotifications: { cancels += 1 })
        return (cancels, resets)
    }

    // MARK: - El hook deja el testigo

    @Test("El borrado que armó la puerta y no pudo borrar deja el testigo, y desarma como siempre",
          arguments: [Destination.groupsOrganizer, .groupsInvite])
    func abortArmedByTheGate_leavesTheWitness(destination: Destination) {
        let defaults = armedByGate(prefix: "ggwf.abort.\(destination.rawValue)", destination: destination)
        let run = runWipe(defaults, deletes: false)

        #expect(GroupsGateWipeFailureMarker.isPending(defaults),
                "Sin testigo, la puerta retoma, mide lo mismo y vuelve a armar: el bucle del ticket.")
        // Lo de antes no cambia: con el espejo montado, reintentar se llevaría cambios que nadie esperó a exportar.
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults))
        #expect(run.cancels == 0, "el store sigue vivo: sus recordatorios también")
        #expect(run.resets == 0)
        // El destino sigue ahí para que el arranque retome la puerta, que es quien tiene que decirlo.
        #expect(WelcomePendingDestinationStore.peek(defaults) == destination)
    }

    /// **Solo la puerta.** Un cierre de Ajustes que aborta deja a la persona en la app, y una marca sin lector acabaría
    /// leyéndola una puerta que no la armó — diciendo «no pudimos» sin haber intentado nada.
    @Test("Un borrado que no armó la puerta no deja testigo al abortar", arguments: notFromTheGate)
    func abortNotArmedByTheGate_leavesNoWitness(destination: Destination?) {
        let defaults = armedByGate(prefix: "ggwf.other.\(destination?.rawValue ?? "none")", destination: destination)
        _ = runWipe(defaults, deletes: false)
        #expect(!GroupsGateWipeFailureMarker.isPending(defaults))
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults), "el abort `.icloud` desarma igual")
    }

    /// En `.cloud` el abort NO desarma: el arranque siguiente reintenta, y ahí no hay bucle de la puerta que cortar. El
    /// testigo va dentro de la rama que desarma, no delante del `if`.
    @Test("En .cloud el abort reintenta y no deja testigo")
    func abortInCloudMode_keepsTheArmAndLeavesNoWitness() {
        let defaults = armedByGate(prefix: "ggwf.cloud", mode: .cloud)
        _ = runWipe(defaults, deletes: false)
        #expect(!GroupsGateWipeFailureMarker.isPending(defaults))
        #expect(StorageModePersistence.isSignOutWipeArmed(defaults))
    }

    /// **El camino normal no cambia**: el borrado que sí puede no deja testigo, y además retira el de un intento anterior
    /// —el hecho que contaba dejó de ser verdad—.
    @Test("El borrado que completa no deja testigo y retira el de antes", arguments: [false, true])
    func completedWipe_leavesNoWitness(hadWitness: Bool) {
        let defaults = armedByGate(prefix: "ggwf.ok.\(hadWitness)")
        if hadWitness { GroupsGateWipeFailureMarker.mark(defaults) }
        let run = runWipe(defaults, deletes: true)
        #expect(!GroupsGateWipeFailureMarker.isPending(defaults))
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults))
        #expect(run.resets == 1)
        #expect(run.cancels == 1)
        #expect(StorageModePersistence.isNeutralMountArmed(defaults), "el camino feliz sigue dejando el neutro durable")
    }

    /// **El otro archivo** (review adversarial): el borrado que se lleva también los grupos no aborta si el archivo de
    /// grupos no se deja borrar —el personal ya se fue—, pero la puerta vuelve a encontrar filas y volvería a armar el
    /// mismo borrado. Si lo armó la puerta, se apunta igual; si no, no.
    @Test("Si el archivo de grupos se queda, el borrado que armó la puerta deja el testigo",
          arguments: [(Destination?.some(.groupsOrganizer), true), (.some(.groupsInvite), true),
                      (.some(.restoreICloud), false), (nil, false)])
    func groupsFileSurvives_marksOnlyWhenTheGateArmedIt(destination: Destination?, expected: Bool) {
        let defaults = armedByGate(prefix: "ggwf.groups.\(destination?.rawValue ?? "none")", destination: destination)
        StorageModePersistence.markSignOutWipeIncludesGroups(defaults)
        var deleted: [String] = []
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in deleted.append(name); return name != SwiftDataConfiguration.groupsDatabaseName },
            resetPrefs: {},
            cancelNotifications: {})
        #expect(deleted.contains(SwiftDataConfiguration.groupsDatabaseName), "control: el archivo de grupos se intentó")
        #expect(GroupsGateWipeFailureMarker.isPending(defaults) == expected)
        // El borrado personal sí se consumó: el wipe termina y desarma como siempre.
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults))
        #expect(StorageModePersistence.isNeutralMountArmed(defaults))
    }

    /// **Con `deleteFiles` fallando siempre, el bucle se corta tras el primer intento.** Tres arranques seguidos sobre el
    /// mismo teléfono: el primero aborta y apunta; en los siguientes nadie vuelve a armar —la puerta, con el testigo
    /// puesto, no arma— y el hook es un no-op: ni intenta borrar, ni cancela notificaciones, ni toca el testigo.
    @Test("Con el borrado fallando siempre, no hay una segunda vuelta")
    func persistentDeleteFailure_stopsAfterTheFirstAttempt() {
        let defaults = armedByGate(prefix: "ggwf.loop")
        var deleteCalls = 0, cancels = 0
        for _ in 0..<3 {
            // Lo que hace la puerta al retomarse: con el testigo puesto NO arma (`neutralReturnEntryPhase`, fijado abajo).
            if !GroupsGateWipeFailureMarker.isPending(defaults), !StorageModePersistence.isSignOutWipeArmed(defaults) {
                StorageModePersistence.armSignOutWipe(defaults)
            }
            SwiftDataConfiguration.performSignOutWipeIfArmed(
                defaults: defaults,
                deleteFiles: { _, _ in deleteCalls += 1; return false },
                resetPrefs: {},
                cancelNotifications: { cancels += 1 })
            // El arranque consume el destino al retomar la puerta.
            _ = WelcomePendingDestinationStore.consume(defaults)
        }
        #expect(deleteCalls == 1, "un solo intento de borrado, no uno por arranque")
        #expect(cancels == 0)
        #expect(GroupsGateWipeFailureMarker.isPending(defaults), "la pantalla honesta sigue teniendo qué decir")
    }

    @Test("Qué destinos cuentan como «lo armó la puerta»", arguments: Destination.allCases)
    func armedByTheGroupsGate_isExactlyTheTwoGateDestinations(destination: Destination) {
        let expected = destination == .groupsOrganizer || destination == .groupsInvite
        #expect(GroupsGateWipeFailureMarker.armedByTheGroupsGate(pendingDestination: destination) == expected)
        #expect(!GroupsGateWipeFailureMarker.armedByTheGroupsGate(pendingDestination: nil))
    }

    /// El barrido de preferencias excluye `cloudSync.*`; así el testigo solo se va por sus tres caminos nombrados.
    @Test("La key vive bajo cloudSync.*")
    func keyLivesUnderCloudSync() {
        #expect(GroupsGateWipeFailureMarker.key.hasPrefix("cloudSync."))
    }
}

// MARK: - El orden y la puerta (source-scan)

@Suite("La puerta de Grupos tras un borrado que no pudo · cableado (source-scan)")
struct GroupsGateWipeFailureWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CloudSync
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    /// Código sin líneas de comentario: los docblocks nombran a propósito lo que prohíben.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func bodyOf(_ marker: String, in source: String) -> String? {
        guard let start = source.range(of: marker) else { return nil }
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    /// Líneas no vacías del cuerpo, sin sangría.
    private static func lines(of body: String) -> [String] {
        body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static let gateView = "Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift"
    private static let hook = "Yala/Utils/SwiftDataConfiguration.swift"

    /// **El testigo se apunta ANTES de desarmar.** Un kill entre las dos líneas repite el abort y lo vuelve a apuntar;
    /// al revés, el arranque siguiente ya no aborta —no hay arm— y el testigo no llega nunca.
    @Test("El abort apunta el testigo antes de desarmar, y solo si lo armó la puerta")
    func abortMarksBeforeDisarming() throws {
        let branch = try #require(Self.bodyOf("if StorageModePersistence.read(defaults) == .icloud {",
                                              in: try Self.code(Self.hook)))
        let flat = Self.lines(of: branch).joined(separator: " ")
        let guarded = "if GroupsGateWipeFailureMarker.armedByTheGroupsGate( "
            + "pendingDestination: WelcomePendingDestinationStore.peek(defaults)) { "
            + "GroupsGateWipeFailureMarker.mark(defaults) }"
        let mark = try #require(flat.range(of: guarded),
                                "el abort `.icloud` ya no apunta el testigo, o no lo condiciona a la puerta")
        let disarm = try #require(flat.range(of: "StorageModePersistence.clearSignOutWipeArm(defaults)"))
        #expect(mark.upperBound <= disarm.lowerBound)
    }

    /// **Las dos ramas de la puerta miran el testigo lo primero dentro de las celdas que borran**: en la del organizador
    /// medir es armar (con copia en iCloud no pregunta), y en la del invitado sería volver a preguntar por un borrado
    /// que ya se sabe que no puede. Se fija la sentencia JUSTO detrás del `case` y no un `contains`: una sentencia
    /// antepuesta que devolviera otra fase dejaría el testigo sin leer. Y NO va delante de la celda (review adversarial):
    /// en la de la nube la puerta no arma nada, y su pantalla es la que dice la verdad.
    @Test("Las dos entradas miran el testigo lo primero en las celdas que borran, y solo ahí",
          arguments: ["private func neutralReturnEntryPhase() -> Phase {",
                      "private func inviteNeutralEntryPhase() -> Phase {"])
    func entryPhasesReadTheWitnessFirstInTheWipingCells(marker: String) throws {
        let lines = Self.lines(of: try #require(Self.bodyOf(marker, in: try Self.code(Self.gateView))))
        let witness = "if GroupsGateWipeFailureMarker.isPending() { return .wipeFailed }"
        let cell = try #require(lines.firstIndex(of: "case .privateSignOut, .privateWithGroupsSignOut, .groupsOnlySignOut:"))
        #expect(lines[cell + 1] == witness)
        #expect(lines.filter { $0 == witness }.count == 1, "una sola lectura, la de las celdas que borran")
        #expect(lines.first == "guard CloudSessionSignOut.shared.phase == .idle else { return .unavailable }")
    }

    /// **La pantalla honesta no trabaja**: `runPhase` no arranca nada en `.wipeFailed`, y sus dos salidas —el botón y el
    /// «volver» de arriba— retiran el testigo antes de volver.
    @Test("La pantalla del aviso no arranca nada y sus dos salidas retiran el testigo")
    func wipeFailedDoesNoWorkAndItsExitsClearTheWitness() throws {
        let code = try Self.code(Self.gateView)
        let run = try #require(Self.bodyOf("private func runPhase() async {", in: code))
        let idle = Self.lines(of: run).joined(separator: " ")
        #expect(idle.contains(".inviteNeedsRelaunch, .inviteNeedsCloudSignIn, .wipeFailed: return"),
                "`.wipeFailed` tiene que caer en la rama que no hace nada")

        let leave = try #require(Self.bodyOf("private func leaveAfterWipeFailure() {", in: code))
        #expect(Self.lines(of: leave) == ["GroupsGateWipeFailureMarker.clear()", "onBack()"])

        let back = try #require(Self.bodyOf("private var backAction: (() -> Void)? {", in: code))
        #expect(Self.lines(of: back).joined(separator: " ").contains("case .wipeFailed: return leaveAfterWipeFailure"))

        let content = try #require(Self.bodyOf("private var content: some View {", in: code))
        let screen = try #require(content.range(of: "case .wipeFailed:"))
        let next = try #require(content[screen.upperBound...].range(of: "case ."))
        let branch = Self.lines(of: String(content[screen.upperBound..<next.lowerBound])).joined(separator: " ")
        #expect(branch.contains("YalaPrimaryButton(L10n.Welcome.Groups.gateBack) { leaveAfterWipeFailure() }"))
        #expect(!branch.contains("beginNeutralReturn") && !branch.contains("phase ="),
                "el aviso no ofrece volver a borrar ni cambia de fase por su cuenta")
        // «Reintentar» solo para el invitado, cuya puerta pregunta antes de borrar.
        #expect(branch.contains("if purpose.invitedGroupID != nil { YalaSecondaryButton(L10n.Action.retry) { retryAfterWipeFailure() }"))
        let retry = try #require(Self.bodyOf("private func retryAfterWipeFailure() {", in: code))
        #expect(Self.lines(of: retry) == ["guard purpose.invitedGroupID != nil else { return }",
                                          "GroupsGateWipeFailureMarker.clear()", "phase = .checking"],
                "en la rama del organizador re-medir es armar: el reintento no puede llegar ahí")
    }

    /// Cuando la puerta deja pasar ya no hay nada que borrar: el testigo se retira en las dos ramas, antes de salir.
    @Test("La puerta que deja pasar retira el testigo",
          arguments: ["private func evaluate() async {", "private func evaluateInvite() {"])
    func proceedClearsTheWitness(marker: String) throws {
        let body = try #require(Self.bodyOf(marker, in: try Self.code(Self.gateView)))
        #expect(Self.lines(of: body).joined(separator: " ")
            .contains("case .proceed: GroupsGateWipeFailureMarker.clear() onProceed()"))
    }
}

/// «Vaciar datos» retira el testigo en cualquier scope, como su marca hermana del aviso tardío: con las filas fuera, la
/// puerta que venga después no tiene nada que no pudiera borrar (review adversarial).
@Suite("La puerta de Grupos tras un borrado que no pudo · «Vaciar datos» retira el testigo",
       .serialized, .wipeAppGroupMirrorIsolated)
@MainActor
struct GroupsGateWipeFailureDataWipeTests {

    @Test(arguments: [true, false])
    func wipeAllUserData_clearsTheWitness(resetsPreferences: Bool) throws {
        let context = try makeTestContext()
        GroupsGateWipeFailureMarker.mark()
        defer { GroupsGateWipeFailureMarker.clear() }
        try DataWipeService.wipeAllUserData(in: context, broadcastSignal: false, resetsPreferences: resetsPreferences)
        #expect(!GroupsGateWipeFailureMarker.isPending(),
                "tras vaciar, la primera puerta diría «no pudimos» sin haber intentado nada")
    }
}
