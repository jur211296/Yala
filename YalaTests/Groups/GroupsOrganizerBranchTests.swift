//
//  GroupsOrganizerBranchTests.swift
//  YalaTests / Groups
//
//  G3 de Grupos-first · la rama ORGANIZADOR del Welcome.
//
//  Cuatro mitades y ninguna cubre a las otras:
//
//   (A) LA PUERTA. La tabla de `GroupsOrganizerGateLogic`: canal apagado, datos de otro humano, y el ORDEN
//       entre los dos términos, que es load-bearing (el copy del canal habla de algo transitorio; el de
//       datos ajenos, de un estado del dispositivo).
//   (B) CERO ESCRITURAS con la puerta cerrada, afirmado sobre un STORE inyectado y no sobre una pantalla —
//       que es lo que el criterio de hecho del chip pide. La aserción negativa va con su CONTROL POSITIVO:
//       sin él, «no se escribió nada» se cumpliría igual con un inventario vacío o un writer roto.
//   (C) LA MÁQUINA de pasos, que espeja la del invitado y respeta su orden (sign-in ANTES que consent).
//   (D) CABLEADO (source-scan): el `force: true` del refresh, y que el alta tenga UN SOLO call-site de
//       producción y NO esté en el fichero de la puerta. La lógica puede ser perfecta y sus tablas verdes
//       mientras el `force` se pierde o mientras alguien adelanta la escritura del trío — familia de
//       `AttestWiringTests`.
//
//  **Lo que estos tests NO pueden declarar verificado** (y va dicho para que nadie lo lea de más): el e2e
//  de la rama contra producción. Un build de Xcode no completa App Attest contra prod por diseño
//  (`.claude/rules/gateway-attest.md`), así que la cadena real sign-in → consent → grupo la ejerce el owner
//  con un build de distribución. Y la celda «canal apagado» tampoco es alcanzable por XCUITest: bajo
//  `-uitest` el flag es SIEMPRE `true` (`CloudRemoteConfig.decide` corta en `isUITestHost` → `absentDefault`,
//  ON bajo `DEV_BUILD`) y no hay launch arg que lo apague. Esa celda vive AQUÍ y en ningún otro sitio.
//

import Foundation
import Testing

@testable import Yala

private typealias Gate = GroupsOrganizerGateLogic
private typealias Flow = GroupsOrganizerFlowLogic

// MARK: - Doble del canal de escritura

/// Writer espía: escribe de verdad en un `UserDefaults` aislado (para poder afirmar sobre el STORE, que es
/// lo que el criterio pide) y además CUENTA, porque re-escribir un valor que ya está deja el store idéntico
/// y una aserción de estado final no vería la diferencia.
@MainActor
private final class SpyPreferenceWriter: GroupsOrganizerPreferenceWriting {
    let defaults: UserDefaults
    private(set) var writes: [String] = []

    init(defaults: UserDefaults) { self.defaults = defaults }

    func setSynced(_ value: String, forKey key: String) {
        writes.append(key)
        defaults.set(value, forKey: key)
    }

    func setLocal(_ value: Bool, forKey key: String) {
        writes.append(key)
        defaults.set(value, forKey: key)
    }
}

// MARK: - (A) La puerta

@Suite("G3 · la puerta de la rama organizador")
struct GroupsOrganizerGateTests {

    @Test("la tabla completa: canal × datos ajenos")
    func fullTable() {
        #expect(Gate.decide(channelEnabled: true, hasExistingData: false) == .proceed)
        #expect(Gate.decide(channelEnabled: false, hasExistingData: false) == .blockedChannelOff)
        #expect(Gate.decide(channelEnabled: true, hasExistingData: true) == .blockedForeignData)
    }

    @Test("con el canal APAGADO gana el canal, aunque además haya datos de otro humano")
    func channelWinsOverForeignData() {
        // El orden no es estético. El canal acaba de re-medirse con `force`, así que su veredicto es el más
        // fresco, y su copy describe algo TRANSITORIO («vuelve a intentarlo en un momento»). El de datos
        // ajenos describe un estado del DISPOSITIVO, que no se arregla esperando: dárselo a alguien cuyo
        // problema real es el canal le manda a buscar una causa que no existe.
        #expect(Gate.decide(channelEnabled: false, hasExistingData: true) == .blockedChannelOff)
    }

    @Test("`proceed` exige las DOS condiciones — es la única celda que deja escribir")
    func proceedNeedsBothTerms() {
        for channel in [true, false] {
            for data in [true, false] {
                let decision = Gate.decide(channelEnabled: channel, hasExistingData: data)
                #expect((decision == .proceed) == (channel && !data),
                        "canal=\(channel) datosAjenos=\(data) ⇒ \(decision)")
            }
        }
    }
}

// MARK: - (B) Cero escrituras con la puerta cerrada

@Suite("G3 · con la puerta cerrada no se escribe NADA", .serialized)
@MainActor
struct GroupsOrganizerNoWriteTests {

    /// Las cinco keys del alta, leídas del INVENTARIO de producción y no de una lista a mano: duplicarla
    /// aquí la dejaría corta en cuanto alguien añadiera una escritura al alta, y la aserción negativa
    /// seguiría pasando sin cubrirla.
    private func writtenKeysPresent(in defaults: UserDefaults) -> [String] {
        GroupsOrganizerOnboarding.writtenKeys.filter { defaults.object(forKey: $0) != nil }
    }

    @Test("canal apagado ⇒ decisión de bloqueo Y el store sigue intacto")
    func channelOff_writesNothing() {
        let defaults = makeIsolatedDefaults(prefix: "g3.gate.off")
        let writer = SpyPreferenceWriter(defaults: defaults)

        let decision = Gate.decide(channelEnabled: false, hasExistingData: false)
        #expect(decision == .blockedChannelOff)

        // La aserción que carga el peso: `onboardingMode` es never-downgrade cross-device, así que una
        // escritura aquí viaja al iKV del Apple ID y NO VUELVE — el usuario se queda con la shell reducida
        // a Grupos, propagada a sus otros dispositivos, y sin ningún grupo que enseñar.
        #expect(writer.writes.isEmpty, "la puerta no puede escribir: escribió \(writer.writes)")
        #expect(writtenKeysPresent(in: defaults).isEmpty,
                "el store ganó keys del alta con la puerta cerrada: \(writtenKeysPresent(in: defaults))")

        // CONTROL POSITIVO. Sin esto la aserción de arriba se cumpliría igual con un inventario vacío, un
        // writer que no escribe o unas keys renombradas — la familia de «Executed 0 tests».
        GroupsOrganizerOnboarding.writePreferences(displayName: "Ana", writer: writer)
        #expect(Set(writer.writes) == Set(GroupsOrganizerOnboarding.writtenKeys),
                "el instrumento no detecta las escrituras del alta: \(writer.writes)")
        #expect(writtenKeysPresent(in: defaults).count == GroupsOrganizerOnboarding.writtenKeys.count)
    }

    @Test("datos de otro humano ⇒ decisión de bloqueo Y el store sigue intacto (la ENMIENDA del punto de control)")
    func foreignData_writesNothing() {
        // La ventana M1: Welcome visible tras un `.privateReset` con el corpus del dueño vivo. La rama reusa
        // `GroupsSignInView`, que NO consulta el guard cross-cuenta (regla dura de su docblock) ⇒ sin esta
        // celda, la invitada firmaría SOBRE el store personal del dueño: su bridge metería los gastos de
        // ella en el Panel de él, y el trío viajaría al iKV del Apple ID del dueño.
        let defaults = makeIsolatedDefaults(prefix: "g3.gate.foreign")
        let writer = SpyPreferenceWriter(defaults: defaults)

        #expect(Gate.decide(channelEnabled: true, hasExistingData: true) == .blockedForeignData)
        #expect(writer.writes.isEmpty)
        #expect(writtenKeysPresent(in: defaults).isEmpty)
    }

    @Test("el alta escribe el trío completo, y el nombre vacío cae al nombre por defecto")
    func setupWritesTheTrio() {
        let defaults = makeIsolatedDefaults(prefix: "g3.alta")
        let writer = SpyPreferenceWriter(defaults: defaults)

        GroupsOrganizerOnboarding.writePreferences(displayName: "  ", writer: writer)

        // El trío que hace la shell.
        #expect(defaults.string(forKey: OnboardingMode.userDefaultsKey) == OnboardingMode.groupInvite.rawValue)
        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsBetaUnlocked))
        #expect(defaults.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding))
        // Nombre vacío ⇒ el default, igual que hacen las otras dos altas. Un botón deshabilitado aquí sería
        // la regresión del «botón muerto» de 2.0.5.
        #expect(defaults.string(forKey: AppPreferences.Keys.userName) == L10n.Profile.defaultName)
        #expect(defaults.string(forKey: AppPreferences.Keys.defaultPeriod) == DetailPeriod.thisMonth.rawValue)
    }

    @Test("el nombre se trimea y el tecleado gana al default")
    func setupTrimsTheName() {
        let defaults = makeIsolatedDefaults(prefix: "g3.alta.nombre")
        let writer = SpyPreferenceWriter(defaults: defaults)

        GroupsOrganizerOnboarding.writePreferences(displayName: "  Ana  ", writer: writer)
        #expect(defaults.string(forKey: AppPreferences.Keys.userName) == "Ana")
    }

    @Test("la DIVISA no se escribe: es del chip G4")
    func setupDoesNotWriteCurrency() {
        // Anotado como aserción y no solo como comentario porque es una frontera de alcance: G4 añade
        // `defaultCurrencyCode = CurrencyDefaults.detectCurrencyFromRegion()` a este mismo alta, y hasta
        // entonces la key tiene que quedar AUSENTE (`AppPreferences` cae a su default). Si alguien la
        // adelanta aquí sin el resto de G4, este test lo dice.
        let defaults = makeIsolatedDefaults(prefix: "g3.alta.divisa")
        let writer = SpyPreferenceWriter(defaults: defaults)

        GroupsOrganizerOnboarding.writePreferences(displayName: "Ana", writer: writer)
        #expect(defaults.object(forKey: AppPreferences.Keys.defaultCurrencyCode) == nil)
    }
}

// MARK: - (C) La máquina de pasos

@Suite("G3 · el paso encadenado de la rama organizador")
struct GroupsOrganizerFlowTests {

    @Test("sin sesión ⇒ sign-in, y va ANTES que el consent")
    func noSession_signsInFirst() {
        // El orden es el del INVITADO (`GroupBackendInviteEntryLogic` pone `presentSignIn` antes que
        // `presentConsent`), al revés que el Welcome, donde el consent va antes y en la misma pantalla.
        #expect(Flow.nextStep(hasSession: false, isConsented: false, hasCompletedSetup: false) == .presentSignIn)
        #expect(Flow.nextStep(hasSession: false, isConsented: true, hasCompletedSetup: true) == .presentSignIn)
    }

    @Test("con sesión y sin consent ⇒ consent")
    func sessionWithoutConsent_asksForIt() {
        #expect(Flow.nextStep(hasSession: true, isConsented: false, hasCompletedSetup: false) == .presentConsent)
        #expect(Flow.nextStep(hasSession: true, isConsented: false, hasCompletedSetup: true) == .presentConsent)
    }

    @Test("con sesión y consent, sin alta ⇒ el nombre")
    func readyButNoSetup_asksForTheName() {
        #expect(Flow.nextStep(hasSession: true, isConsented: true, hasCompletedSetup: false) == .presentName)
    }

    @Test("todo listo ⇒ el formulario, que es el ÚLTIMO paso y no presenta un join")
    func allReady_opensTheForm() {
        #expect(Flow.nextStep(hasSession: true, isConsented: true, hasCompletedSetup: true) == .presentGroupForm)
    }

    @Test("la tabla completa: cada paso se RE-DECIDE, nunca se recuerda")
    func fullTable() {
        // Es lo que hace que un sign-in ya hecho, un consent aceptado en otra pantalla o un kill a mitad no
        // desalineen la máquina: el drain vuelve aquí después de cada sheet en vez de avanzar un contador.
        var seen: Set<Flow.Step> = []
        for session in [true, false] {
            for consent in [true, false] {
                for setup in [true, false] {
                    seen.insert(Flow.nextStep(hasSession: session, isConsented: consent, hasCompletedSetup: setup))
                }
            }
        }
        #expect(seen == [.presentSignIn, .presentConsent, .presentName, .presentGroupForm],
                "los cuatro pasos tienen que ser alcanzables desde alguna combinación: \(seen)")
    }
}

// MARK: - (D) Cableado (source-scan)

/// Por qué además de las tablas: las dos lógicas puras pueden estar perfectas y sus tests verdes mientras el
/// `force` del refresh se pierde (y entonces la puerta mide el flag STALE, que es el caso exacto del bug) o
/// mientras alguien adelanta la escritura del trío por delante de la puerta. Lo que decide aquí es QUIÉN
/// llama, con qué y en qué orden, y eso solo lo ve un escáner.
@Suite("G3 · cableado de la rama organizador (source-scan)")
struct GroupsOrganizerWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Groups
            .deletingLastPathComponent()   // YalaTests
            .deletingLastPathComponent()   // repo
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Código SIN líneas de comentario: los docblocks de esta rama nombran a propósito lo que prohíben, y
    /// contar la prosa haría que documentar el invariante lo «cumpliera».
    private static func code(_ path: String) throws -> String {
        try source(path)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static let gateView = "Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift"
    private static let nameView = "Yala/App/Views/Groups/GroupsOrganizerNameView.swift"

    @Test("MUTACIÓN (a): la puerta refresca el remote-config con `force: true`")
    func gateRefreshesWithForce() throws {
        let code = try Self.code(Self.gateView)
        #expect(code.contains("refreshIfDue(force: true)"), """
            sin el `force`, `refreshIfDue` es un NO-OP en el caso exacto del bug: el min-interval es de 6 h y
            el arranque ya gastó la ventana con su propio refresh fire-and-forget. La puerta mediría el flag
            stale y el organizador acabaría con un grupo local huérfano irrecuperable.
            """)
        #expect(!code.contains("refreshIfDue()"),
                "un `refreshIfDue()` sin argumentos aquí es el no-op que el chip prohíbe")
    }

    @Test("la puerta decide con la lógica pura y lee el flag DESPUÉS del refresh")
    func gateUsesPureLogicAfterTheRefresh() throws {
        let code = try Self.code(Self.gateView)
        #expect(code.contains("GroupsOrganizerGateLogic.decide("),
                "la decisión vive en la lógica pura, no escrita a mano en la vista")

        let refresh = try #require(code.range(of: "refreshIfDue(force: true)"))
        let decide = try #require(code.range(of: "GroupsOrganizerGateLogic.decide("))
        #expect(refresh.upperBound < decide.lowerBound, """
            leer `groupsBackendEnabled` ANTES del refresh mide el snapshot viejo, que es justamente lo que el
            `force` existe para invalidar.
            """)
    }

    @Test("MUTACIÓN (b): el alta tiene UN SOLO call-site de producción, y NO está en la puerta")
    func setupHasExactlyOneProductionCallSite() throws {
        // `onboardingMode = .groupInvite` es never-downgrade cross-device: adelantar esta llamada por delante
        // de la puerta la manda al iKV del Apple ID sin vuelta atrás. El conteo esperado es lo que impide
        // que un escáner roto —o un fichero renombrado— pase en verde sin comprobar nada.
        let root = Self.repoRoot.appendingPathComponent("Yala")
        var callSites: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let stripped = body
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            // La definición vive en `GroupsOrganizerOnboarding.swift` y no es un call-site.
            guard url.lastPathComponent != "GroupsOrganizerOnboarding.swift" else { continue }
            if stripped.contains("GroupsOrganizerOnboarding.completeSetup(")
                || stripped.contains("GroupsOrganizerOnboarding.writePreferences(") {
                callSites.append(url.lastPathComponent)
            }
        }
        #expect(callSites == ["GroupsOrganizerNameView.swift"], """
            el alta se escribe en el paso 6 y en ningún otro sitio. Encontrado: \(callSites)
            """)
    }

    @Test("MUTACIÓN (b'): la puerta no nombra ni el alta ni las keys del trío")
    func gateNeverWrites() throws {
        let code = try Self.code(Self.gateView)
        for forbidden in ["GroupsOrganizerOnboarding", "groupsBetaUnlocked",
                          "hasCompletedOnboarding", "onboardingMode"] {
            #expect(!code.contains(forbidden), """
                la puerta escribió `\(forbidden)`. El paso 2 comprueba y NO escribe: con el canal apagado el
                usuario tiene que volver al chooser con el dispositivo exactamente como lo encontró.
                """)
        }
    }

    @Test("el alta se cablea a la lógica del alta y aterriza en el tab Grupos")
    func nameViewCompletesTheSetup() throws {
        let code = try Self.code(Self.nameView)
        #expect(code.contains("GroupsOrganizerOnboarding.completeSetup("),
                "el CTA del nombre es lo que escribe el trío")
    }

    @Test("la puerta no monta un `.alert(` — el pin de W1 lo prohíbe en el container")
    func gateIsAScreenAndNeverAnAlert() throws {
        let container = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        #expect(!container.contains(".alert("), """
            `WelcomeHeroReentryTests` prohíbe `.alert(` en este fichero por source-scan, y además un alert
            para la puerta cerrada sería un camino muerto en un flujo que el spec exige que no los tenga.
            """)
        #expect(container.contains("case .groupsGate:"),
                "la puerta es un STEP del container, no una presentación del anchor de ContentView")
    }
}
