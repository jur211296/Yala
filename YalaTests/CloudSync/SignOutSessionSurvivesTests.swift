//
//  SignOutSessionSurvivesTests.swift
//  YalaTests / CloudSync
//
//  **Tras «Cerrar sesión» la sesión en la nube no puede quedar viva en el teléfono.** Ticket
//  `sign-out-exits-do-not-verify-the-cloud-session-closed` (2026-09-26).
//
//  Hasta ese día los cierres descartaban lo que devolvía `CloudAuthService.signOut()` y armaban el borrado igual, y el
//  borrado del arranque (`SwiftDataConfiguration.performSignOutWipeIfArmed`) dejaba el llavero de la sesión intacto. Si la
//  sesión sobrevivía —el llavero no la borró, o un refresco del token la repuso—, el teléfono quedaba como recién instalado
//  con la sesión de quien cerró dentro, y la persona siguiente bajaba sus grupos. Dos capas:
//
//   1. **Los cierres comprueban el `signOut()` antes de armar.** Los cuatro voluntarios se paran en
//      `.blocked(.signOutSessionSurvived)`; los dos tras borrar la cuenta siguen y arman el retiro de la sesión. Esa mitad
//      son source-scans por lo mismo que `GroupsDetachSessionSurvivesTests`: el coordinador toca cinco singletons de
//      proceso. El comportamiento en pantalla lo fija el XCUITest
//      `SessionExitsPerCellUITests.test_privateCell_C_signOutWithASurvivingSession_stopsAndSaysSo`.
//   2. **El borrado del arranque purga el llavero**, verificado. Esa mitad es de comportamiento, con un llavero REAL bajo
//      un service de test: una sesión guardada entra, el borrado corre y la sesión ya no está.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Capa 2 · el borrado del arranque retira la sesión

@Suite("Cerrar sesión · el borrado del arranque retira la sesión en la nube")
struct SignOutWipeRetiresTheCloudSessionTests {

    /// Un llavero real con un service propio por test: aísla del de la app y de los demás tests.
    private func makeStorage() -> CloudAuthKeychainStorage {
        CloudAuthKeychainStorage(service: "test.signout.session.\(UUID().uuidString)")
    }

    /// Lo que un teléfono guarda tras un sign-in: la sesión del SDK y el par de SIWA, que `signOut()` conserva a propósito.
    private func seedSurvivingSession(in storage: CloudAuthKeychainStorage) throws {
        try storage.store(key: CloudAuthService.sessionStorageKey, value: Data("sesion-de-quien-cerro".utf8))
        try storage.store(key: "siwa.pair", value: Data("par".utf8))
        try #require(!storage.isEmpty(), "la siembra no dejó nada en el llavero: el caso no mediría nada")
    }

    /// Estado de un teléfono que acaba de cerrar sesión en la nube y va a relanzar.
    private func armedDefaults(prefix: String) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: prefix)
        StorageModePersistence.write(.cloud, defaults: defaults)
        defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey)
        StorageModePersistence.armSignOutWipe(defaults)
        return defaults
    }

    private func runWipe(defaults: UserDefaults, deleteFiles: Bool = true,
                         retireCloudSession: () -> Void = {}) {
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in deleteFiles },
            resetPrefs: {},
            cancelNotifications: {},
            retireCloudSession: retireCloudSession)
    }

    @Test("Borrado armado + sesión superviviente en el llavero → tras el borrado la sesión ya no está")
    func wipe_withASurvivingSession_leavesNoSessionBehind() throws {
        let storage = makeStorage()
        defer { _ = storage.purgeAll() }
        try seedSurvivingSession(in: storage)
        let defaults = armedDefaults(prefix: "signout.survives.wipe")

        runWipe(defaults: defaults, retireCloudSession: {
            CloudSessionRetirement.retireForSignOutWipe(
                defaults: defaults, purgeKeychain: { storage.purgeAll() }, isKeychainEmpty: { storage.isEmpty() })
        })

        #expect(try storage.retrieve(key: CloudAuthService.sessionStorageKey) == nil, """
            El borrado del arranque dejó la sesión en el llavero: el teléfono queda como recién instalado con la sesión de \
            quien cerró dentro, y la persona siguiente arranca en su cuenta.
            """)
        #expect(storage.isEmpty(), "el par de SIWA sobrevivió: la purga ya no se lleva el service entero")
        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey), "el retiro quedó armado con el llavero vacío")
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults), "el borrado no terminó")
    }

    @Test("Control: sin nadie que la retire, la sesión sembrada sigue ahí tras el borrado")
    func wipe_withoutTheRetirement_keepsTheSession() throws {
        let storage = makeStorage()
        defer { _ = storage.purgeAll() }
        try seedSurvivingSession(in: storage)
        let defaults = armedDefaults(prefix: "signout.survives.control")

        runWipe(defaults: defaults)

        #expect(try storage.retrieve(key: CloudAuthService.sessionStorageKey) != nil)
    }

    @Test("El retiro corre con el borrado AÚN armado: un kill a mitad lo repite el arranque siguiente")
    func wipe_retiresBeforeDisarming() throws {
        let defaults = armedDefaults(prefix: "signout.survives.order")
        var armedDuringRetire: Bool?
        runWipe(defaults: defaults, retireCloudSession: {
            armedDuringRetire = StorageModePersistence.isSignOutWipeArmed(defaults)
        })
        #expect(armedDuringRetire == true, """
            El retiro de la sesión corre con el borrado ya desarmado (o no corre): un kill entre el desarme y el retiro \
            dejaría la sesión viva sin nada que lo reintente.
            """)
    }

    @Test("Si el borrado de los archivos falla, el cierre no ocurrió: no se toca la sesión")
    func wipe_abortS3_doesNotRetire() throws {
        let storage = makeStorage()
        defer { _ = storage.purgeAll() }
        try seedSurvivingSession(in: storage)
        let defaults = armedDefaults(prefix: "signout.survives.abort")
        var retired = false

        runWipe(defaults: defaults, deleteFiles: false, retireCloudSession: {
            retired = true
            _ = storage.purgeAll()
        })

        #expect(!retired, "el retiro corre aunque el store sobrevivió: se le cierra la sesión a quien sigue con sus datos")
        #expect(try storage.retrieve(key: CloudAuthService.sessionStorageKey) != nil)
    }

    @Test("Sin borrado armado no se retira nada")
    func wipe_notArmed_doesNotRetire() {
        let defaults = makeIsolatedDefaults(prefix: "signout.survives.noarm")
        var retired = false
        runWipe(defaults: defaults, retireCloudSession: { retired = true })
        #expect(!retired)
    }

    // MARK: - El retiro, verificado

    @Test("El retiro purga el llavero, lo relee vacío y se desarma")
    func retire_purgesAndDisarms() throws {
        let storage = makeStorage()
        defer { _ = storage.purgeAll() }
        try seedSurvivingSession(in: storage)
        let defaults = makeIsolatedDefaults(prefix: "signout.retire.ok")

        let done = CloudSessionRetirement.retireForSignOutWipe(
            defaults: defaults, purgeKeychain: { storage.purgeAll() }, isKeychainEmpty: { storage.isEmpty() })

        #expect(done)
        #expect(storage.isEmpty())
        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey))
    }

    @Test("MUTACIÓN: si un refresco repone la sesión tras la purga, el retiro queda armado para el arranque siguiente")
    func retire_keychainNotEmptyAfterPurge_keepsTheArm() throws {
        let storage = makeStorage()
        defer { _ = storage.purgeAll() }
        let defaults = makeIsolatedDefaults(prefix: "signout.retire.refresh")

        // El SDK vivo (swap sin relanzar) repone la sesión justo después del `SecItemDelete`.
        let done = CloudSessionRetirement.retireForSignOutWipe(
            defaults: defaults,
            purgeKeychain: {
                let purged = storage.purgeAll()
                do {
                    try storage.store(key: CloudAuthService.sessionStorageKey, value: Data("repuesta".utf8))
                } catch {
                    Issue.record("no se pudo reponer la sesión en el llavero de test: \(error)")
                }
                return purged
            },
            isKeychainEmpty: { storage.isEmpty() })

        #expect(!done)
        #expect(defaults.bool(forKey: CloudSessionRetirement.armedKey), """
            El retiro se dio por hecho sin releer el llavero: la sesión repuesta se quedaría para siempre, sin nada que \
            volviera a mirar.
            """)

        // Y el consumidor pre-mount del arranque siguiente, sin SDK que reponga, lo termina.
        #expect(CloudSessionRetirement.purgeIfArmed(defaults: defaults, purgeKeychain: { storage.purgeAll() }))
        #expect(try storage.retrieve(key: CloudAuthService.sessionStorageKey) == nil)
        #expect(!defaults.bool(forKey: CloudSessionRetirement.armedKey))
    }

    @Test("Si el llavero no se deja purgar, el retiro queda armado")
    func retire_purgeFails_keepsTheArm() {
        let defaults = makeIsolatedDefaults(prefix: "signout.retire.fail")
        let done = CloudSessionRetirement.retireForSignOutWipe(
            defaults: defaults, purgeKeychain: { false }, isKeychainEmpty: { true })
        #expect(!done)
        #expect(defaults.bool(forKey: CloudSessionRetirement.armedKey))
    }

    // MARK: - El copy del aviso

    @Test("El aviso dice que la sesión sigue y que no se borró nada, no «cambios sin subir»")
    func blockedCopy_saysTheSessionSurvived() {
        #expect(SignOutBlockedCopy.title(for: .signOutSessionSurvived) == L10n.Settings.signOutBlockedTitle)
        #expect(SignOutBlockedCopy.message(for: .signOutSessionSurvived) == L10n.Settings.signOutSessionSurvived)
        #expect(SignOutBlockedCopy.message(for: .signOutSessionSurvived) != L10n.Settings.signOutBlockedMessage, """
            El aviso cae en el genérico, que habla de cambios sin subir y de revisar la conexión: aquí no es ninguna de \
            las dos.
            """)
    }
}

// MARK: - Capa 1 · los cierres comprueban el `signOut()` antes de armar

@Suite("Cerrar sesión · los cierres comprueban que la sesión se fue antes de armar el borrado")
struct SignOutChecksTheSessionBeforeArmingTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Código SIN líneas de comentario: el porqué de cada pieza se explica ahí nombrándola.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de un método, del `func` hasta la primera llave de cierre a la indentación de un miembro (`    }`).
    private static func body(of signature: String, in path: String) throws -> String {
        let source = try code(path)
        guard let start = source.range(of: signature) else {
            Issue.record("`\(signature)` desapareció o se renombró en \(path)")
            return ""
        }
        let tail = source[start.lowerBound...]
        guard let end = tail.range(of: "\n    }\n") else { return String(tail) }
        return String(tail[..<end.upperBound])
    }

    private static let signOutPath = "Yala/Services/CloudSync/CloudSessionSignOut.swift"
    private static let checkedSignOut = "guard await CloudAuthService.shared.signOut() else {"
    private static let signOutCall = "CloudAuthService.shared.signOut()"

    /// La rama `else` de la comprobación: del `guard` hasta su llave de cierre (indentación de cuerpo, `        }`).
    private static func elseBranch(after check: Range<String.Index>, in body: String) -> String? {
        let tail = body[check.upperBound...]
        guard let close = tail.range(of: "\n        }\n") else { return nil }
        return String(tail[..<close.lowerBound])
    }

    /// Los dos cierres voluntarios que arman el borrado: la comprobación va antes del arm, la rama que se para no arma y
    /// devuelve, y no hay otra llamada sin comprobar.
    @Test("Cierre voluntario", arguments: [
        ("private func finalizeSessionExit(", "await armAfterCredentials(context: context, kind: kind, export: export)"),
        ("private func performCloudSecureSignOut(", "StorageModePersistence.armSignOutWipe()"),
    ])
    func voluntaryExit_checksBeforeArming(signature: String, arm: String) throws {
        let body = try Self.body(of: signature, in: Self.signOutPath)
        guard let check = body.range(of: Self.checkedSignOut), let armAt = body.range(of: arm) else {
            Issue.record("""
                `\(signature)` cambió de forma. Lo que este invariante exige es un cierre de sesión cuyo resultado se \
                comprueba (`\(Self.checkedSignOut)`) DELANTE de `\(arm)`. Relee el ticket antes de reescribir este test.
                """)
            return
        }
        #expect(check.lowerBound < armAt.lowerBound, """
            En `\(signature)` la comprobación del cierre de sesión va DETRÁS del arm: el borrado se arma con la sesión \
            viva, y el teléfono queda recién instalado con ella dentro.
            """)
        #expect(body.components(separatedBy: Self.signOutCall).count - 1 == 1, """
            `\(signature)` llama más de una vez (o ninguna) a `\(Self.signOutCall)`. La que cuenta es la que se comprueba; \
            una segunda sin comprobar es el código de antes del arreglo.
            """)
        guard let branch = Self.elseBranch(after: check, in: body) else {
            Issue.record("no se encuentra el cierre del `else` de la comprobación en `\(signature)`"); return
        }
        #expect(branch.contains("blockBecauseSessionSurvived(") && branch.contains("return"), """
            La rama que se para en `\(signature)` ya no pone el bloqueo con su motivo o no sale: sin él no sale el aviso, \
            y sin el `return` el cierre sigue al arm.
            """)
        for prohibido in ["armSignOutWipe", "armAfterCredentials", "awaitingRelaunch", "attemptSignOutSwap"] {
            #expect(!branch.contains(prohibido), "la rama que se para en `\(signature)` hace `\(prohibido)`")
        }
    }

    @Test("El bloqueo pone el motivo propio y el canario, fuera de `#if DEBUG`")
    func block_setsItsReasonAndTheCanary() throws {
        let body = try Self.body(of: "private func blockBecauseSessionSurvived(", in: Self.signOutPath)
        #expect(body.contains("phase = .blocked(pendingCount: 0, reason: .signOutSessionSurvived)"), """
            El cierre bloqueado ya no deja `.signOutSessionSurvived`. Con `.sessionNotClosed` Ajustes lo silencia (es del \
            desasociar), y con otro motivo el aviso hablaría de cambios sin subir.
            """)
        #expect(body.contains("MetricsService.canary(.signOutSessionSurvived"), "el bloqueo ya no emite su canario")
        #expect(!body.contains("#if DEBUG"), "el canario quedó dentro de un `#if DEBUG`: en producción no se vería")
        let metrics = try Self.code("Yala/Services/Metrics/MetricsService.swift")
        #expect(metrics.contains("case signOutSessionSurvived"), "el canario no está en el inventario de `MetricsCanary`")
    }

    /// Los dos cierres tras BORRAR LA CUENTA no se paran —la cuenta ya no existe—: su resultado arma el retiro durable de
    /// la sesión, ANTES del arm de su borrado.
    @Test("Cierre tras borrar la cuenta", arguments: [
        ("func closeLocalAfterAccountDeletionCloud()", "StorageModePersistence.armSignOutWipe()"),
        ("func closeLocalAfterAccountDeletionGroupsOnly(", "StorageModePersistence.armGroupsOnlyWipe()"),
    ])
    func accountDeletionExit_retiresASurvivingSession(signature: String, arm: String) throws {
        let body = try Self.body(of: signature, in: Self.signOutPath)
        guard let retire = body.range(of: "Self.retireIfSessionSurvived(await \(Self.signOutCall)"),
              let armAt = body.range(of: arm) else {
            Issue.record("""
                `\(signature)` ya no pasa el resultado del cierre de sesión a `retireIfSessionSurvived`: con la sesión \
                superviviente, el teléfono se queda con ella tras el borrado.
                """)
            return
        }
        #expect(retire.lowerBound < armAt.lowerBound, "en `\(signature)` el retiro va detrás del arm")
        #expect(body.components(separatedBy: Self.signOutCall).count - 1 == 1,
                "`\(signature)` tiene otra llamada a `\(Self.signOutCall)` sin comprobar")

        // El cuerpo ENTERO, normalizado: con `contains`, un `return` metido entre las dos líneas o el arm dentro de un
        // `#if DEBUG` dejarían vivo el texto bueno sin que corriera.
        let helper = try Self.body(of: "private static func retireIfSessionSurvived(", in: Self.signOutPath)
        let lines = helper.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        #expect(lines == [
            "private static func retireIfSessionSurvived(_ gone: Bool, path: String) {",
            "guard !gone else { return }",
            "CloudSessionRetirement.arm(defaults: .standard)",
            "MetricsService.canary(.signOutSessionSurvived, detail: \"path=\\(path)\")",
            "}",
        ], "`retireIfSessionSurvived` ya no es «si la sesión sobrevive, arma el retiro y emite el canario»")
    }

    @Test("El borrado de producción cablea el retiro, y el inyectable lo corre tras el guard S3 y antes del desarme")
    func wipeHook_wiresTheRetirement() throws {
        let config = try Self.code("Yala/Utils/SwiftDataConfiguration.swift")
        #expect(config.contains("retireCloudSession: { CloudSessionRetirement.retireForSignOutWipe(defaults: .standard) })"), """
            El `performSignOutWipeIfArmed()` de producción ya no pasa el retiro de la sesión: los tests del inyectable \
            seguirían verdes y el llavero sobreviviría al borrado en todos los teléfonos.
            """)
        let body = try Self.body(of: "static func performSignOutWipeIfArmed(\n        defaults: UserDefaults,",
                                 in: "Yala/Utils/SwiftDataConfiguration.swift")
        guard let call = body.range(of: "        retireCloudSession()\n"),
              let disarm = body.range(of: "StorageModePersistence.clearSignOutWipeArm(defaults)\n        CloudSyncBreadcrumb.signOutWipeExecuted()") else {
            Issue.record("el borrado inyectable ya no llama a `retireCloudSession()` o cambió su desarme final"); return
        }
        #expect(call.lowerBound < disarm.lowerBound)
        #expect(body.components(separatedBy: "retireCloudSession()").count - 1 == 1,
                "`retireCloudSession()` se llama más de una vez: una de ellas puede caer antes del guard S3")
    }

    @Test("La puerta de Grupos del Welcome tiene su rama para el motivo, antes del catch-all que habla de cambios sin subir")
    func welcomeGroupsGate_hasItsOwnBranch() throws {
        let source = try Self.code("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        guard let branch = source.range(of: "case .blocked(_, .signOutSessionSurvived):"),
              let catchAll = source.range(of: "        case .blocked(let pending, let reason):\n") else {
            Issue.record("""
                La puerta de Grupos del Welcome no tiene rama para `.signOutSessionSurvived`: cae en el `case .blocked:` \
                final, que dice «faltan cambios de tus grupos por subir, vuelve a entrar con esa cuenta».
                """)
            return
        }
        #expect(branch.lowerBound < catchAll.lowerBound, "la rama propia va detrás del catch-all y nunca se alcanza")
        let body = source[branch.upperBound..<catchAll.lowerBound]
        #expect(body.contains("body: SignOutBlockedCopy.message(for: .signOutSessionSurvived)"),
                "la rama propia no enseña el mensaje del motivo")
    }

    @Test("Ajustes enseña el aviso del cierre con este motivo, no lo silencia como al desasociar")
    func profile_showsTheBlockedAlert() throws {
        let source = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        guard let reason = source.range(of: ".signOutSessionSurvived") else {
            Issue.record("Ajustes no nombra `.signOutSessionSurvived`: el cierre bloqueado quedaría mudo"); return
        }
        let tail = source[reason.upperBound...]
        let firstLine = tail.prefix { $0 != "\n" }
        let next = tail.dropFirst(firstLine.count + 1).prefix { $0 != "\n" }
        #expect(firstLine.hasSuffix(":") && next.trimmingCharacters(in: .whitespaces) == "showSignOutBlockedAlert = true", """
            `.signOutSessionSurvived` ya no enciende el aviso del cierre en Ajustes: la persona toca «Cerrar sesión» y no \
            pasa nada.
            """)
    }
}
