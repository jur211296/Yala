//
//  CloudConsentRegistrationTests.swift
//  YalaTests / CloudSync
//
//  CHIP M0 (ola M, §6.3 de MODO-NUBE-SPEC-M1-REVIVAL) — el consent del reentry se registraba ANTES de
//  conocer la ruta, y el destino de esa escritura lo resuelve `PreferenceSyncService` en el INSTANTE de
//  escribir: con el modo persistido del device, que durante el Welcome es el `.icloud` del DUEÑO. Un
//  intento cross-cuenta que terminaba BLOQUEADO —que es lo que pasa HOY, con el flag de secundaria
//  apagado— ya había dejado el epoch GDPR de otra persona en el iKV del dueño, y el paso 5-bis del
//  cutover lo habría subido un día como consent SUYO.
//
//  Tres cosas se prueban aquí y ninguna cubre a las otras:
//   1. La TABLA (`CloudConsentRegistrationLogic.placement`) — qué punto del flujo escribe, por ruta.
//   2. El CONTEO DE ESCRITURAS de las tres rutas sobre un store inyectado, que es el criterio literal
//      del chip: cero en el camino bloqueado (hoy eran 2), una sola vez en las otras dos. Va sobre el
//      seam del registrar porque `PreferenceSyncService` es un singleton con `local` hardcodeado a
//      `.standard` (regla §prefs de `.claude/rules/swiftdata-cloudkit.md`).
//   3. El source-scan del CABLEADO. Lo que decide es QUIÉN llama y en qué ORDEN —el epoch de la
//      secundaria resuelve `.localOnly` solo DESPUÉS del descriptor—, y eso ningún test de
//      comportamiento lo caza (familia `AttestWiringTests` / `GroupInviteChannelRoutingWiringTests`).
//

import Foundation
import Testing

@testable import Yala

// MARK: - Espía de escrituras

/// Cuenta las escrituras Y las materializa en un `UserDefaults` propio: el criterio del chip habla de
/// «cero escrituras de `cloudConsentAcceptedAt`», así que se comprueba en las dos formas (la traza de
/// llamadas y la ausencia de la key en el store).
@MainActor
private final class ConsentWriteSpy {
    let store: UserDefaults
    private(set) var writes: [(value: Int, key: String)] = []

    init() { store = makeIsolatedDefaults(prefix: "m0.consent") }

    func write(_ value: Int, _ key: String) {
        writes.append((value, key))
        store.set(value, forKey: key)
    }

    var acceptedAtWrites: Int {
        writes.filter { $0.key == PrefSyncKey.cloudConsentAcceptedAt.rawValue }.count
    }

    var persistedAcceptedAt: Int? {
        store.object(forKey: PrefSyncKey.cloudConsentAcceptedAt.rawValue) as? Int
    }

    var persistedTextVersion: Int? {
        store.object(forKey: PrefSyncKey.cloudConsentTextVersion.rawValue) as? Int
    }
}

// MARK: - 1) La tabla + 2) el conteo de escrituras

/// `.serialized`: el seam de escritura de `CloudConsentRegistrar` es estado estático compartido.
@Suite("M0 · dónde cae la escritura del consent del reentry", .serialized)
@MainActor
struct CloudConsentRegistrationTests {

    /// Instala el espía como escritor y lo restaura SIEMPRE. `liveWriter` existe justo para esto: un
    /// `defer` que re-tecleara el closure de producción podría divergir y dejar a las suites siguientes
    /// escribiendo en el sitio equivocado.
    private func withSpy(_ body: (ConsentWriteSpy) -> Void) {
        let spy = ConsentWriteSpy()
        CloudConsentRegistrar.writeInt = { spy.write($0, $1) }
        defer { CloudConsentRegistrar.writeInt = CloudConsentRegistrar.liveWriter }
        body(spy)
    }

    // MARK: La tabla

    @Test("la tabla: adopt escribe antes de la máquina, la secundaria tras el descriptor, el bloqueo nunca")
    func placement_isTotalOverTheGuardsThreeOutcomes() {
        #expect(CloudConsentRegistrationLogic.placement(for: .proceed) == .beforeAdopt)
        #expect(CloudConsentRegistrationLogic.placement(for: .proceedSecondarySession)
                == .afterSecondaryDescriptor)
        #expect(CloudConsentRegistrationLogic.placement(for: .blockedForeignData) == .never)
    }

    // MARK: El conteo, ruta por ruta

    /// EL CRITERIO DEL CHIP. Se prueba el camino entero: los TRES puntos posibles, no solo el que la
    /// vista usa hoy — si mañana alguien añade una llamada en la rama bloqueada, esto no la deja pasar.
    @Test("camino BLOQUEADO: cero escrituras, en cualquiera de los tres puntos (hoy eran 2)")
    func blockedRoute_neverWrites() {
        withSpy { spy in
            var pending = true
            for point in [CloudConsentRegistrationLogic.Placement.beforeAdopt,
                          .afterSecondaryDescriptor, .never] {
                CloudConsentRegistrationLogic.persistIfDue(
                    at: point, routedBy: .blockedForeignData,
                    pending: &pending, persist: { CloudConsentRegistrar.register() })
            }
            #expect(spy.writes.isEmpty, """
                El intento cross-cuenta bloqueado descarta la sesión y NO deja registro en este device:
                el consent real de esa cuenta vive en SU backend. Escribir aquí es el bug de M0 — el
                epoch cae en el iKV del Apple ID del DUEÑO y el cutover lo sube un día como suyo.
                """)
            #expect(spy.acceptedAtWrites == 0)
            #expect(spy.persistedAcceptedAt == nil)
            #expect(pending, "sin escritura no se consume el pendiente")
        }
    }

    @Test("ruta ADOPT: escribe UNA vez y solo en `beforeAdopt`")
    func adoptRoute_writesOnceBeforeTheMachineStarts() {
        withSpy { spy in
            var pending = true

            CloudConsentRegistrationLogic.persistIfDue(
                at: .afterSecondaryDescriptor, routedBy: .proceed,
                pending: &pending, persist: { CloudConsentRegistrar.register() })
            #expect(spy.writes.isEmpty, "el punto de la secundaria no es el suyo")

            CloudConsentRegistrationLogic.persistIfDue(
                at: .beforeAdopt, routedBy: .proceed,
                pending: &pending, persist: { CloudConsentRegistrar.register() })
            #expect(spy.acceptedAtWrites == 1)
            #expect(spy.writes.count == 2, "las DOS keys del registro: epoch + versión del contrato")
            #expect(!pending)

            // Un retry tras `.error` vuelve a pasar por el guard: el epoch conserva su T0 en vez de
            // saltar a la hora del reintento.
            CloudConsentRegistrationLogic.persistIfDue(
                at: .beforeAdopt, routedBy: .proceed,
                pending: &pending, persist: { CloudConsentRegistrar.register() })
            #expect(spy.acceptedAtWrites == 1, "append-only y UNA vez: el pendiente ya se consumió")
        }
    }

    /// El orden es el fix: `PrefsSyncBehavior.resolve` pregunta por el descriptor VIVO en cada llamada,
    /// así que escribir un paso antes de `SecondarySessionStore.activate` es escribir en el iKV del dueño.
    @Test("ruta SECUNDARIA: nada antes del descriptor, una escritura después")
    func secondaryRoute_writesOnlyAfterTheDescriptor() {
        withSpy { spy in
            var pending = true

            CloudConsentRegistrationLogic.persistIfDue(
                at: .beforeAdopt, routedBy: .proceedSecondarySession,
                pending: &pending, persist: { CloudConsentRegistrar.register() })
            #expect(spy.writes.isEmpty, """
                Antes del descriptor el behavior de prefs es el del DUEÑO (`.icloudKeyValue`): el epoch
                de la invitada se propagaría a los otros devices de su Apple ID.
                """)
            #expect(pending)

            CloudConsentRegistrationLogic.persistIfDue(
                at: .afterSecondaryDescriptor, routedBy: .proceedSecondarySession,
                pending: &pending, persist: { CloudConsentRegistrar.register() })
            #expect(spy.acceptedAtWrites == 1)
            #expect(spy.writes.count == 2)
            #expect(!pending)
        }
    }

    /// El alta born-cloud escribe en la PANTALLA (su ruta ya se conoce al aceptar y su claim la verifica),
    /// así que llega aquí sin pendiente: la variante A de §f.1 —`existing_stable` reencamina al
    /// returning-user y cae en el guard— no puede acabar escribiendo el epoch dos veces.
    @Test("alta born-cloud: sin pendiente, ningún punto escribe (no hay doble registro)")
    func bornCloud_doesNotWriteASecondTime() {
        withSpy { spy in
            var pending = false
            for decision in [CrossAccountEntryGuardLogic.Decision.proceed,
                             .proceedSecondarySession, .blockedForeignData] {
                for point in [CloudConsentRegistrationLogic.Placement.beforeAdopt,
                              .afterSecondaryDescriptor, .never] {
                    CloudConsentRegistrationLogic.persistIfDue(
                        at: point, routedBy: decision,
                        pending: &pending, persist: { CloudConsentRegistrar.register() })
                }
            }
            #expect(spy.writes.isEmpty)
        }
    }

    /// `.never` es un veredicto, no un sitio. Sin este guard, un call-site colocado en la rama bloqueada
    /// con `at: .never` CASARÍA con la tabla y escribiría — reintroduciendo el bug por la puerta de atrás.
    @Test("`.never` no es un punto de escritura ni cuando la tabla dice `.never`")
    func neverIsAVerdictNotAWriteSite() {
        withSpy { spy in
            var pending = true
            CloudConsentRegistrationLogic.persistIfDue(
                at: .never, routedBy: .blockedForeignData,
                pending: &pending, persist: { CloudConsentRegistrar.register() })
            #expect(spy.writes.isEmpty)
            #expect(pending)
        }
    }

    // MARK: El contenido del registro

    @Test("el registro son las DOS keys: el epoch de la aceptación y la versión del contrato")
    func registrar_writesTheEpochAndTheContractVersion() {
        withSpy { spy in
            CloudConsentRegistrar.register(now: Date(timeIntervalSince1970: 1_760_000_000))
            #expect(spy.writes.count == 2)
            #expect(spy.persistedAcceptedAt == 1_760_000_000, """
                El epoch es T0 —la hora en que el usuario aceptó—: el paso 5-bis del cutover lo RE-EMITE
                tal cual, así que recalcularlo en otro paso falsearía la traza GDPR.
                """)
            #expect(spy.persistedTextVersion == CloudConsentText.version)
        }
    }
}

// MARK: - 3) El cableado (source-scan)

/// Lo que decide este chip es QUIÉN escribe y DÓNDE, y eso no se ve desde el comportamiento: la tabla
/// puede ser perfecta y sus tests verdes mientras la pantalla sigue escribiendo al aceptar. Molde
/// `BornCloudSignUpFlowTests` / `AttestWiringTests`.
@Suite("M0 · el cableado: quién escribe el consent y en qué orden")
struct CloudConsentRegistrationWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Sin los comentarios: los docblocks de estos ficheros NOMBRAN a propósito lo que ya no hacen
    /// («escribía al aceptar»), y un `contains` sobre el fichero crudo se rompería al documentar el
    /// invariante — la trampa que ya cazaron `CloudConsentCopyTests` y `WelcomeHeroReentryTests`.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo balanceado por llaves desde un marcador (molde `BornCloudSignUpFlowTests.body(of:in:)`).
    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker))
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

    private static let welcomePath = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
    private static let consentViewPath = "Yala/App/Views/Settings/CloudConsentView.swift"

    /// LA MUTACIÓN DEL CHIP: devolver el registro al `onAccept` del sheet (pasar `persistsOnAccept: true`,
    /// o quitar el argumento y heredar el default). Ahí la ruta todavía no existe y el camino bloqueado
    /// vuelve a escribir 2.
    @Test("el sheet del Welcome delega el CUÁNDO: pasa la condición, no un `true`")
    func welcomeSheet_defersThePersistenceToTheRoute() throws {
        let src = try Self.code(Self.welcomePath)
        let sheet = try Self.body(of: ".sheet(isPresented: $showConsent) {", in: src)
        #expect(sheet.contains("persistsOnAccept: persistsConsentOnAccept"), """
            El consent se PRESENTA antes del sign-in (eso no se mueve), pero en la re-entrada la ESCRITURA
            no puede ocurrir aquí: `PreferenceSyncService` resuelve el destino en el instante de escribir
            y el único modo que hay todavía es el `.icloud` del DUEÑO.
            """)
        #expect(!sheet.contains("persistsOnAccept: true"))
        #expect(sheet.contains("consentPendingPersistence = !persistsConsentOnAccept"),
                "el pendiente se arma al aceptar: sin él la escritura diferida no llega nunca")

        let flag = try Self.body(of: "private var persistsConsentOnAccept: Bool {", in: src)
        #expect(flag.contains("case .bornCloud: true"), "el alta conoce su ruta al aceptar y su claim la verifica")
        #expect(flag.contains("case .reentry:   false"))
    }

    /// La pantalla tiene que poder NO escribir. Quitar el guard la devuelve a escribir siempre y el
    /// argumento del Welcome pasa a ser decorativo.
    @Test("`CloudConsentView` persiste solo si el caller conoce su ruta; la telemetría, siempre")
    func consentView_persistsBehindTheFlag() throws {
        let src = try Self.code(Self.consentViewPath)
        let register = try Self.body(of: "private func registerConsent() {", in: src)
        #expect(register.contains("if persistsOnAccept { CloudConsentRegistrar.register() }"))
        #expect(register.contains("MetricsService.cloudConsentAccepted(path: path.rawValue)"), """
            La telemetría NO se difiere: el usuario aceptó, y eso ocurrió en esta pantalla. Diferirla
            haría desaparecer del dashboard justo la cohorte que este chip protege (los bloqueados).
            """)
        #expect(!src.contains("PreferenceSyncService"), """
            Un solo escritor de las dos keys (`CloudConsentRegistrar`): con dos, el guard de arriba tapa
            uno y el otro sigue escribiendo al aceptar.
            """)
    }

    /// El adopt es la ruta del PROPIO dueño y su escritura tiene que preceder a la máquina: el paso
    /// 5-bis de `adoptBackendAccount` re-emite el epoch PERSISTIDO y sin él cae al fallback `now()`,
    /// que es la hora de FIN del adopt y no la de la aceptación.
    @Test("en `runSignInFlow` hay UNA sola escritura y va antes de arrancar el adopt")
    func signInFlow_writesOnlyOnTheAdoptBranch_beforeTheMachine() throws {
        let src = try Self.code(Self.welcomePath)
        let flow = try Self.body(of: "private func runSignInFlow() async {", in: src)

        let calls = flow.components(separatedBy: "persistConsentIfDue(").count - 1
        #expect(calls == 1, """
            El guard tiene tres salidas y solo UNA escribe. Una llamada de más en la rama bloqueada o en
            la secundaria es exactamente el bug de M0 (la tabla la haría no-op, pero el call-site miente).
            """)
        let persist = try #require(flow.range(of: "persistConsentIfDue(at: .beforeAdopt"))
        let start = try #require(flow.range(of: "startAdoptWithExistingSession()"))
        #expect(persist.lowerBound < start.lowerBound)
    }

    /// LA OTRA MUTACIÓN: subir la escritura por encima de `SecondaryEntryLogic.begin`. Compila, pasa la
    /// tabla y vuelve a dejar el epoch de la invitada en el iKV del dueño — el descriptor es lo único
    /// que hace que `PrefsSyncBehavior` resuelva `.localOnly`.
    @Test("en la entrada secundaria la escritura va DESPUÉS del descriptor")
    func secondaryEntry_writesAfterTheDescriptor() throws {
        let src = try Self.code(Self.welcomePath)
        let confirm = try Self.body(of: "private func confirmSecondaryEntry() {", in: src)
        let begin = try #require(confirm.range(of: "SecondaryEntryLogic.begin("))
        let persist = try #require(confirm.range(of: "persistConsentIfDue(at: .afterSecondaryDescriptor"))
        #expect(begin.lowerBound < persist.lowerBound, """
            `SecondaryEntryLogic.begin` es quien activa el descriptor, y `PrefsSyncBehavior.resolve` lo
            consulta VIVO en cada llamada: una línea antes, el epoch de la invitada viaja al iKV del
            Apple ID del dueño y se propaga a sus otros devices.
            """)
    }
}
