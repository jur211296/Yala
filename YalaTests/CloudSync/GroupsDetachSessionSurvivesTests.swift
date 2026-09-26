//
//  GroupsDetachSessionSurvivesTests.swift
//  YalaTests / CloudSync
//
//  **Si la sesión en la nube sobrevive a su cierre, el desasociar no cruza el punto de no retorno.** Ticket
//  `detach-does-not-verify-the-cloud-session-actually-closed`.
//
//  Hasta el 2026-09-26 el desasociar llamaba a `CloudAuthService.signOut()` DESPUÉS de soltar el puente, sin mirar si
//  la sesión se había ido, y seguía al borrado y a `finishDetach`. Con la sesión viva, en el siguiente primer plano el
//  loop de Grupos arrancaba, el cursor ya estaba borrado y bajaba el corpus entero; con la asociación limpia el libro de
//  conservados no casaba y todo se re-puenteaba al lado de lo que la persona eligió conservar. Medido en supabase-swift
//  2.50.0: la sesión sobrevive si el llavero no la borra (el SDK traga ese error) o si un refresco en vuelo la repone.
//
//  ## Por qué son source-scans
//
//  `detachGroupsAccount` toca cinco singletons de proceso (ver la cabecera de `GroupsDetachPurgeFailureTests`), así que
//  invocarlo aquí no mide el invariante. Lo que el bug podía violar es el ORDEN dentro del cuerpo —la comprobación
//  delante del puente y del borrado— y qué hace la rama que se para. El comportamiento en pantalla lo fija el XCUITest
//  `GroupsAssociationRowUITests.test_detachWhenTheSessionSurvivesSignOut_stopsAndSaysSo`, con su seam.
//

import Auth
import Foundation
import Testing

@testable import Yala

@Suite("Grupos · el desasociar se para si la sesión sobrevive a su cierre")
struct GroupsDetachSessionSurvivesTests {

    // MARK: - El testigo, como tabla

    private struct KeychainLocked: Error {}

    @Test("Sin nada en el llavero y sin sesión en el SDK, la sesión se fue")
    func witness_nothingStored_isGone() {
        #expect(CloudAuthService.sessionIsGone(sdkSeesSession: false, read: { nil }))
    }

    /// **Lo que se lee es lo que el SDK ESCRIBE**, no un JSON de red: el `AuthClient` real guarda la sesión en el almacén
    /// con un `JSONEncoder()` por defecto (fechas como número), y un fixture escrito a mano en el formato de la respuesta
    /// del servidor (fechas ISO) no decodifica — medido, así cayó la primera versión de este caso.
    @Test("Una sesión que el SDK guardó SIGUE para el testigo, aunque el SDK no la vea")
    func witness_sessionStoredByTheSDK_isAlive() async throws {
        let server = SupabaseSessionRenewalContractTests.AuthServer()
        let storage = SupabaseSessionRenewalContractTests.MemoryStorage()
        let url = try #require(URL(string: "https://auth.invalid/auth/v1"))
        let client = AuthClient(configuration: AuthClient.Configuration(
            url: url,
            storageKey: CloudAuthService.sessionStorageKey,
            localStorage: storage,
            fetch: { try server.respond(to: $0) },
            autoRefreshToken: false))
        _ = try await client.refreshSession(refreshToken: "rt-alta")
        try #require(client.currentSession != nil, "el alta no dejó la sesión guardada: el caso no mediría nada")

        #expect(!CloudAuthService.sessionIsGone(
            sdkSeesSession: false, read: { try storage.retrieve(key: CloudAuthService.sessionStorageKey) }), """
            El testigo no reconoce como sesión lo que el SDK guarda: diría «se fue» con la sesión en el llavero, y el \
            desasociar cruzaría el punto de no retorno con ella.
            """)
    }

    @Test("MUTACIÓN: un llavero que no se deja leer NO es un llavero vacío")
    func witness_unreadableKeychain_isAlive() {
        #expect(!CloudAuthService.sessionIsGone(sdkSeesSession: false, read: { throw KeychainLocked() }), """
            Un fallo al leer el llavero se lee como «se fue». Es lo que hace el SDK con `currentSession`, y es justo el \
            momento en que el borrado tampoco entró: el testigo fallaría abierto.
            """)
    }

    @Test("Si el SDK ve la sesión, sigue, lea lo que lea el llavero")
    func witness_sdkSeesSession_isAlive() {
        #expect(!CloudAuthService.sessionIsGone(sdkSeesSession: true, read: { nil }))
    }

    @Test("Algo que no decodifica como sesión cuenta como ido: bloquear por ello no tendría salida")
    func witness_undecodableData_isGone() {
        #expect(CloudAuthService.sessionIsGone(sdkSeesSession: false, read: { Data("no-es-una-sesion".utf8) }), """
            Un residuo que el SDK no puede usar bloquea el desasociar. Su `signOut` sale sin borrar cuando no ve sesión, así \
            que ningún reintento lo quitaría: el gesto quedaría imposible para siempre.
            """)
    }

    // MARK: - El cableado

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
    private static let authPath = "Yala/Services/CloudSync/CloudAuthService.swift"
    private static let checkedSignOut = "guard await CloudAuthService.shared.signOut() else {"

    @Test("El cierre de sesión se COMPRUEBA, y antes del puente y del borrado")
    func detach_checksTheSignOutBeforeThePointOfNoReturn() throws {
        let body = try Self.body(of: "func detachGroupsAccount(", in: Self.signOutPath)

        guard let teardown = body.range(of: "GroupsSyncClient.shared.teardownForSignOut()"),
              let residual = body.range(of: "reason: .permanent)"),
              let check = body.range(of: Self.checkedSignOut),
              let bridge = body.range(of: "GroupsAssociationDetach.detachBridge("),
              let purge = body.range(of: "try Self.purgeGroupsDomainForDetach(context: context)"),
              let finish = body.range(of: "finishDetach(context: context)") else {
            Issue.record("""
                El desasociar cambió de forma. Lo que este invariante exige es un cierre de sesión cuyo resultado se \
                comprueba (`\(Self.checkedSignOut)`) DELANTE del puente y del borrado. Si el método se reescribió, relee \
                el ticket antes de reescribir este test.
                """)
            return
        }

        #expect(teardown.lowerBound < check.lowerBound && residual.lowerBound < check.lowerBound, """
            El cierre de sesión se adelantó al teardown o al recuento de lo que quedó sin subir. Sin sesión, una fila \
            pendiente ya no sube hasta volver a entrar; con ella viva, la sube el loop del siguiente primer plano.
            """)
        #expect(check.lowerBound < bridge.lowerBound, """
            La comprobación del cierre de sesión ya no va delante del puente. Si la sesión sobrevive, el puente queda \
            soltado con la asociación en pie, y el reintento vuelve a ofrecer las dos salidas cuando la segunda ya no \
            puede aplicarse.
            """)
        #expect(bridge.lowerBound < purge.lowerBound && purge.lowerBound < finish.lowerBound,
                "el puente, el borrado y el remate cambiaron de orden")

        // Una sola llamada: con otra suelta, el gesto podría seguir con una sesión que la segunda no verificó.
        #expect(body.components(separatedBy: "CloudAuthService.shared.signOut()").count - 1 == 1, """
            El desasociar llama más de una vez (o ninguna) a `CloudAuthService.shared.signOut()`. La que cuenta es la \
            que se comprueba; una segunda sin comprobar es el código de antes del arreglo.
            """)
    }

    @Test("Con la sesión viva, el gesto se para sin escribir nada y lo dice")
    func detach_stopsWithItsOwnReasonWhenTheSessionSurvives() throws {
        let body = try Self.body(of: "func detachGroupsAccount(", in: Self.signOutPath)
        guard let check = body.range(of: Self.checkedSignOut) else {
            Issue.record("la comprobación del cierre de sesión desapareció"); return
        }
        let tail = body[check.upperBound...]
        guard let close = tail.range(of: "\n        }\n") else {
            Issue.record("no se encuentra el cierre del `else` de la comprobación"); return
        }
        let branch = String(tail[..<close.lowerBound])

        #expect(branch.contains("phase = .blocked(pendingCount: 0, reason: .sessionNotClosed)"), """
            La rama que se para ya no deja la fase en `.blocked` con `.sessionNotClosed`. La pantalla lee el motivo de \
            ahí: sin él no sale el aviso, o sale el de otro bloqueo, que habla de cambios sin subir o de movimientos.
            """)
        #expect(branch.contains("return .blockedBeforeWriting"), """
            La rama que se para ya no devuelve `.blockedBeforeWriting`: la pantalla no enseña el aviso del bloqueo.
            """)
        #expect(branch.contains(".groupsDetachSessionSurvived"), """
            La rama que se para ya no emite `groupsDetachSessionSurvived`. Es la única medición de si esto pasa en la \
            flota, que el ticket no pudo hacer.
            """)
        for prohibido in ["detachBridge", "purgeGroupsDomainForDetach", "finishDetach", "GroupsDetachPendingPurge.arm",
                          "GroupsAccountAssociation.shared.clear()"] {
            #expect(!branch.contains(prohibido), """
                La rama que se para hace `\(prohibido)`: el gesto escribe algo del dominio Grupos con la sesión viva, \
                que es el daño que esta comprobación existe para impedir.
                """)
        }
        // El canario fuera de `#if DEBUG`: en producción es donde importa.
        let before = body[..<check.lowerBound]
        #expect(before.components(separatedBy: "#if DEBUG").count == before.components(separatedBy: "#endif").count
                && !branch.contains("#if DEBUG"),
                "el canario de la sesión superviviente quedó dentro de un `#if DEBUG`")

        let metrics = try Self.code("Yala/Services/Metrics/MetricsService.swift")
        #expect(metrics.contains("case groupsDetachSessionSurvived"),
                "el canario no está en el inventario de `MetricsCanary`")
    }

    @Test("`signOut()` devuelve el almacén del SDK releído, en sus DOS salidas, y no `hasSession`")
    func signOut_returnsTheStoredSessionWitness() throws {
        let body = try Self.body(of: "func signOut() async -> Bool {", in: Self.authPath)
        #expect(body.contains("guard let client else { return storedSessionIsGone }"), """
            La salida sin backend configurado ya no devuelve el testigo. Sin ella, el seam del XCUITest (que corre sin \
            cliente) no llega al desasociar.
            """)
        guard let call = body.range(of: "try await client.signOut(scope: .local)"),
              let witness = body.range(of: "let gone = storedSessionIsGone") else {
            Issue.record("`signOut()` ya no relee el testigo tras la llamada del SDK"); return
        }
        #expect(call.lowerBound < witness.lowerBound, """
            El testigo se lee ANTES de la llamada del SDK: diría que la sesión sigue en todos los cierres.
            """)
        #expect(body.contains("return gone"), "`signOut()` ya no devuelve lo que leyó")

        // El perfil y el proveedor se borran SOLO con la sesión ida: borrados antes, una sesión superviviente dejaba al
        // registrador de Grupos reescribiendo la asociación sin nombre, también en el iCloud-KV.
        guard let gated = body.range(of: "if gone {") else {
            Issue.record("`signOut()` ya no condiciona nada al testigo"); return
        }
        for clear in ["clearCapturedProfile()", "clearStoredProvider()"] {
            let hits = body.components(separatedBy: clear).count - 1
            let at = body.range(of: clear)
            #expect(hits == 1 && at.map { witness.lowerBound < $0.lowerBound && gated.lowerBound < $0.lowerBound } == true, """
                `\(clear)` ya no corre solo dentro de `if gone {`, tras el testigo. Con la sesión superviviente se borraría el \
                perfil de una sesión que sigue viva, y el registrador de Grupos reescribiría la asociación sin él.
                """)
        }

        let source = try Self.code(Self.authPath)
        guard let start = source.range(of: "private var storedSessionIsGone: Bool {") else {
            Issue.record("`storedSessionIsGone` desapareció"); return
        }
        let tail = source[start.lowerBound...]
        let witnessBody = tail.range(of: "\n    }\n").map { String(tail[..<$0.upperBound]) } ?? String(tail)
        // El cuerpo ENTERO, normalizado: con `contains`, un `return client.currentSession == nil` antepuesto dejaba vivo el
        // texto de la llamada buena, muerto detrás del `return` (mutante M6, superviviente de la primera versión).
        let normalized = witnessBody
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        #expect(normalized == [
            "private var storedSessionIsGone: Bool {",
            "#if DEBUG",
            "if UITestHooks.signOutKeepsSession { return false }",
            "#endif",
            "guard let client else { return true }",
            "return Self.sessionIsGone(",
            "sdkSeesSession: client.currentSession != nil,",
            "read: { try CloudAuthKeychainStorage().retrieve(key: Self.sessionStorageKey) })",
            "}",
        ], """
            El testigo ya no es «pregunta al SDK Y lee el llavero directamente». `currentSession` convierte un fallo al leer \
            el llavero en `nil`: leído solo de ahí, diría «se fue» justo cuando el llavero falla, que es cuando el borrado \
            tampoco entró. (Y `hasSession` lleva el seam de la sesión fingida: bloquearía todo XCUITest que lo use.)
            """)
        #expect(source.contains("storageKey: Self.sessionStorageKey,"), """
            La configuración del cliente ya no guarda la sesión bajo `sessionStorageKey`: el testigo leería una clave \
            vacía y diría siempre «se fue».
            """)
        #expect(!witnessBody.contains("hasSession"), """
            El testigo lee `hasSession`, que lleva el seam `-uitest-fake-cloud-session`: en todo XCUITest que lo use el \
            desasociar se pararía siempre.
            """)
    }

    @Test("El motivo del desasociar no enciende el aviso del cierre de sesión en Perfil")
    func profile_doesNotStackTheSignOutAlertOverTheDetachOne() throws {
        let profile = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains("case .bridgeUnreadable, .detachBusy, .sessionNotClosed: break"), """
            `ProfileView` ya no deja pasar `.sessionNotClosed` sin hacer nada. Perfil escucha la fase del coordinador y \
            sigue montado debajo de Almacenamiento: apilaría «No pudimos cerrar tu sesión» encima del aviso de la \
            sección, dos presentaciones en el mismo anchor.
            """)
    }

    @Test("El seam de XCUITest y el argumento que lanza el test se llaman igual")
    func uiTestSeam_parity() throws {
        let hooks = try Self.code("Yala/App/UITestHooks.swift")
        let launcher = try Self.code("YalaUITests/Support/XCUIApplication+Yala.swift")
        #expect(hooks.contains("hasArg(\"-uitest-sign-out-keeps-session\")"))
        #expect(launcher.contains("args.append(\"-uitest-sign-out-keeps-session\")"), """
            El lanzador de XCUITest ya no pasa el mismo argumento que lee `UITestHooks`: el caso del desasociar parado \
            correría sin el seam y caería culpando al aviso.
            """)
    }
}
