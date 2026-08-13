//
//  GroupsOrganizerBranchTests.swift
//  YalaTests / Groups
//
//  G3 de Grupos-first · la rama ORGANIZADOR del Welcome.
//
//  Cuatro mitades y ninguna cubre a las otras:
//
//   (A) LA PUERTA. La tabla de `GroupsOrganizerGateLogic`: canal apagado, sesión secundaria, datos de otro
//       humano, y el ORDEN entre los tres términos, que es load-bearing (el copy del canal habla de algo
//       transitorio; los otros dos, de estados del dispositivo, y el de secundaria tiene salida propia).
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
    /// Separado del total porque el CANAL importa: `defaultCurrencyCode` y el nombre son `synced: true`
    /// en `AppPreferences`, y mandarlos por el canal per-device los dejaría fuera del iKV en silencio.
    private(set) var syncedWrites: [String] = []

    init(defaults: UserDefaults) { self.defaults = defaults }

    func setSynced(_ value: String, forKey key: String) {
        writes.append(key)
        syncedWrites.append(key)
        defaults.set(value, forKey: key)
    }

    func setLocal(_ value: Bool, forKey key: String) {
        writes.append(key)
        defaults.set(value, forKey: key)
    }

    /// Se pregunta al MISMO store aislado, nunca a `.standard`: el host de los unit tests es la app, así
    /// que `.standard` es el del simulador y la divisa que dejara ahí otra corrida decidiría este test.
    func hasValue(forKey key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }
}

// MARK: - (A) La puerta

@Suite("G3 · la puerta de la rama organizador")
struct GroupsOrganizerGateTests {

    @Test("la tabla completa: canal × secundaria × datos ajenos")
    func fullTable() {
        #expect(Gate.decide(channelEnabled: true, isSecondarySession: false, hasExistingData: false) == .proceed)
        #expect(Gate.decide(channelEnabled: false, isSecondarySession: false, hasExistingData: false) == .blockedChannelOff)
        #expect(Gate.decide(channelEnabled: true, isSecondarySession: true, hasExistingData: false) == .blockedSecondarySession)
        #expect(Gate.decide(channelEnabled: true, isSecondarySession: false, hasExistingData: true) == .blockedForeignData)
    }

    @Test("con el canal APAGADO gana el canal, aunque además haya datos de otro humano")
    func channelWinsOverForeignData() {
        // El orden no es estético. El canal acaba de re-medirse con `force`, así que su veredicto es el más
        // fresco, y su copy describe algo TRANSITORIO («vuelve a intentarlo en un momento»). El de datos
        // ajenos describe un estado del DISPOSITIVO, que no se arregla esperando: dárselo a alguien cuyo
        // problema real es el canal le manda a buscar una causa que no existe.
        #expect(Gate.decide(channelEnabled: false, isSecondarySession: false, hasExistingData: true) == .blockedChannelOff)
        #expect(Gate.decide(channelEnabled: false, isSecondarySession: true, hasExistingData: true) == .blockedChannelOff)
    }

    /// **C3 · la celda que carga el peso, y la razón por la que no basta con `hasExistingData`.**
    ///
    /// En sesión secundaria el detector de corpus mide el store de la INVITADA (`YalaModel-Secondary`),
    /// que en una sesión recién montada está VACÍO ⇒ `hasExistingData` da `false`. Sin el término propio la
    /// puerta abría justo ahí, y detrás el alta escribe SEIS preferencias que en `.localOnly` caen en el
    /// `UserDefaults.standard` del DUEÑO — incluida `groupsBetaUnlocked`, que **nadie repone al salir**.
    @Test("secundaria con el store de la invitada VACÍO: la celda que `hasExistingData` no ve")
    func secondarySessionBlocksEvenWithAnEmptyGuestStore() {
        #expect(Gate.decide(channelEnabled: true, isSecondarySession: true, hasExistingData: false)
                == .blockedSecondarySession)
        // Y va DELANTE de los datos ajenos: si además hay corpus, el hecho que hay que contarle al usuario
        // sigue siendo «estás de visita» — ese sí tiene salida (cerrar la sesión de invitado), y el copy de
        // datos ajenos («su dueño puede volver a entrar cuando quiera») le mandaría a esperar algo que no
        // va a pasar.
        #expect(Gate.decide(channelEnabled: true, isSecondarySession: true, hasExistingData: true)
                == .blockedSecondarySession)
    }

    @Test("`proceed` exige las TRES condiciones — es la única celda que deja escribir")
    func proceedNeedsAllThreeTerms() {
        for channel in [true, false] {
            for secondary in [true, false] {
                for data in [true, false] {
                    let decision = Gate.decide(
                        channelEnabled: channel, isSecondarySession: secondary, hasExistingData: data)
                    #expect((decision == .proceed) == (channel && !secondary && !data),
                            "canal=\(channel) secundaria=\(secondary) datosAjenos=\(data) ⇒ \(decision)")
                }
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

        let decision = Gate.decide(channelEnabled: false, isSecondarySession: false, hasExistingData: false)
        #expect(decision == .blockedChannelOff)

        // La aserción que carga el peso: `onboardingMode` es never-downgrade cross-device, así que una
        // escritura aquí viaja al iKV del Apple ID y NO VUELVE — el usuario se queda con la shell reducida
        // a Grupos, propagada a sus otros dispositivos, y sin ningún grupo que enseñar.
        #expect(writer.writes.isEmpty, "la puerta no puede escribir: escribió \(writer.writes)")
        #expect(writtenKeysPresent(in: defaults).isEmpty,
                "el store ganó keys del alta con la puerta cerrada: \(writtenKeysPresent(in: defaults))")

        // CONTROL POSITIVO. Sin esto la aserción de arriba se cumpliría igual con un inventario vacío, un
        // writer que no escribe o unas keys renombradas — la familia de «Executed 0 tests».
        GroupsOrganizerOnboarding.writePreferences(displayName: "Ana", writer: writer, isSecondarySession: false)
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

        #expect(Gate.decide(channelEnabled: true, isSecondarySession: false, hasExistingData: true) == .blockedForeignData)
        #expect(writer.writes.isEmpty)
        #expect(writtenKeysPresent(in: defaults).isEmpty)
    }

    /// **C3 · la mitad que el escáner de M1 no cubría, y la más cara de las seis.**
    ///
    /// El guard vivía en UNA key (`onboardingMode`) porque el escáner de M1 buscaba los literales de ESA
    /// key y C2 arregló exactamente lo que el escáner señalaba. Las otras cinco cruzaban igual: el
    /// `local.set(...)` de `PreferenceSyncService.set(string:)` está FUERA del switch de behavior, así que
    /// `.localOnly` no evita la escritura LOCAL — solo la propagación—, y `local` es `.standard`
    /// hardcodeado, que en secundaria es el dominio del DUEÑO.
    ///
    /// La que más pesa no es el modo (irreversible por never-downgrade) sino `groupsBetaUnlocked`, porque
    /// **nadie la repone**: `DataWipeService.removeGroupsDomainPreferenceKeys` tiene un único call-site,
    /// dentro del «empiezo de cero» del Welcome ⇒ cerrar la sesión de la invitada le deja al dueño el
    /// dominio Grupos adoptado para siempre.
    @Test("sesión secundaria ⇒ el alta no escribe NINGUNA de las seis, y lo dice")
    func secondarySession_writesNoneOfTheSixKeys() {
        let defaults = makeIsolatedDefaults(prefix: "c3.alta.secundaria")
        let writer = SpyPreferenceWriter(defaults: defaults)

        let wrote = GroupsOrganizerOnboarding.writePreferences(
            displayName: "Ana", writer: writer, isSecondarySession: true)

        #expect(wrote == false, """
            el alta dijo que había escrito con la frontera M1 puesta. El `Bool` no es cosmético: \
            `completeSetup` lo usa para abortar los seeds y el aterrizaje, y un `true` aquí deja a la \
            invitada en un shell de Grupos que ninguna preferencia sostiene.
            """)
        // Contar ESCRITURAS y no leer el estado final: cinco de las seis podrían re-escribir un valor que
        // ya está y dejar el store idéntico, y el mutante pasaría en verde.
        #expect(writer.writes.isEmpty, "el alta escribió \(writer.writes) en el dominio del DUEÑO")
        #expect(writtenKeysPresent(in: defaults).isEmpty)

        // CONTROL POSITIVO con el MISMO writer y el MISMO store: sin él, «no escribió nada» se cumpliría
        // igual con un inventario vacío, un writer roto o unas keys renombradas.
        let wroteNow = GroupsOrganizerOnboarding.writePreferences(
            displayName: "Ana", writer: writer, isSecondarySession: false)
        #expect(wroteNow)
        #expect(Set(writer.writes) == Set(GroupsOrganizerOnboarding.writtenKeys),
                "el instrumento no detecta las escrituras del alta: \(writer.writes)")
        // Y son SEIS: el conteo es lo que hace que esto envejezca bien. Una séptima escritura nueva rompe
        // el test y obliga a decidir si entra al inventario, en vez de aparecer en silencio.
        #expect(GroupsOrganizerOnboarding.writtenKeys.count == 6)
    }

    @Test("el alta escribe el trío completo, y el nombre vacío cae al nombre por defecto")
    func setupWritesTheTrio() {
        let defaults = makeIsolatedDefaults(prefix: "g3.alta")
        let writer = SpyPreferenceWriter(defaults: defaults)

        GroupsOrganizerOnboarding.writePreferences(displayName: "  ", writer: writer, isSecondarySession: false)

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

        GroupsOrganizerOnboarding.writePreferences(displayName: "  Ana  ", writer: writer, isSecondarySession: false)
        #expect(defaults.string(forKey: AppPreferences.Keys.userName) == "Ana")
    }

    @Test("G4 · la divisa sale de la REGIÓN, no del default global `.pen`")
    func setupWritesRegionCurrency() {
        // Región inyectada (molde de `CurrencyDefaultsTests`): sin ella el test afirmaría lo que diga el
        // simulador y pasaría en verde con un hardcode puesto, siempre que el sim estuviera en esa región.
        // Tres regiones ⇒ tres divisas: PE es la que coincide con el default global, así que sola no
        // distinguiría «lee la región» de «cayó al `.pen` de `AppPreferences`».
        for (region, expected) in [("PE", CurrencyCode.pen), ("US", .usd), ("MX", .mxn)] {
            let defaults = makeIsolatedDefaults(prefix: "g4.alta.divisa.\(region)")
            let writer = SpyPreferenceWriter(defaults: defaults)

            GroupsOrganizerOnboarding.writePreferences(displayName: "Ana", writer: writer, regionCode: region, isSecondarySession: false)

            #expect(defaults.string(forKey: AppPreferences.Keys.defaultCurrencyCode) == expected.rawValue,
                    "región \(region) ⇒ esperaba \(expected.rawValue)")
            // Va por el canal SINCRONIZADO, como el nombre: `defaultCurrencyCode` es `synced: true` en
            // `AppPreferences`, así que mandarla por el canal per-device la dejaría fuera del iKV.
            #expect(writer.syncedWrites.contains(AppPreferences.Keys.defaultCurrencyCode),
                    "la divisa se escribió por el canal per-device: \(writer.syncedWrites)")
        }
    }

    @Test("G4 · una divisa YA escrita no se pisa — el invariante del parque")
    func setupNeverOverwritesAnExistingCurrency() {
        // `defaultCurrencyCode` es `synced: true`: en una instalación nueva de un Apple ID que ya usa Yala,
        // el valor puede haber bajado por iKV ANTES de que el organizador toque nada. Pisarlo le cambiaría
        // la divisa por la de la región donde esté hoy, y esa escritura viaja de vuelta a la CUENTA.
        let defaults = makeIsolatedDefaults(prefix: "g4.alta.divisa.existente")
        defaults.set(CurrencyCode.eur.rawValue, forKey: AppPreferences.Keys.defaultCurrencyCode)
        let writer = SpyPreferenceWriter(defaults: defaults)

        GroupsOrganizerOnboarding.writePreferences(displayName: "Ana", writer: writer, regionCode: "US", isSecondarySession: false)

        #expect(defaults.string(forKey: AppPreferences.Keys.defaultCurrencyCode) == CurrencyCode.eur.rawValue)
        // Contar la escritura, no solo mirar el estado final: re-escribir el MISMO valor dejaría el store
        // idéntico y un mutante sin guard pasaría en verde si el fixture casara con la región.
        #expect(!writer.writes.contains(AppPreferences.Keys.defaultCurrencyCode),
                "el alta escribió la divisa encima de una existente: \(writer.writes)")
        // El resto del alta sí ocurre: el guard es de la divisa, no del alta entera.
        #expect(defaults.string(forKey: OnboardingMode.userDefaultsKey) == OnboardingMode.groupInvite.rawValue)
    }
}

// MARK: - (C) La máquina de pasos

@Suite("G3 · el paso encadenado de la rama organizador")
struct GroupsOrganizerFlowTests {

    @Test("sin sesión ⇒ sign-in, y va ANTES que el consent")
    func noSession_signsInFirst() {
        // El orden es el del INVITADO (`GroupBackendInviteEntryLogic` pone `presentSignIn` antes que
        // `presentConsent`), al revés que el Welcome, donde el consent va antes y en la misma pantalla.
        #expect(Flow.nextStep(hasSeenEducational: true, hasSession: false, isConsented: false, hasCompletedSetup: false) == .presentSignIn)
        #expect(Flow.nextStep(hasSeenEducational: true, hasSession: false, isConsented: true, hasCompletedSetup: true) == .presentSignIn)
    }

    @Test("con sesión y sin consent ⇒ consent")
    func sessionWithoutConsent_asksForIt() {
        #expect(Flow.nextStep(hasSeenEducational: true, hasSession: true, isConsented: false, hasCompletedSetup: false) == .presentConsent)
        #expect(Flow.nextStep(hasSeenEducational: true, hasSession: true, isConsented: false, hasCompletedSetup: true) == .presentConsent)
    }

    @Test("con sesión y consent, sin alta ⇒ el nombre")
    func readyButNoSetup_asksForTheName() {
        #expect(Flow.nextStep(hasSeenEducational: true, hasSession: true, isConsented: true, hasCompletedSetup: false) == .presentName)
    }

    @Test("todo listo ⇒ el formulario, que es el ÚLTIMO paso y no presenta un join")
    func allReady_opensTheForm() {
        #expect(Flow.nextStep(hasSeenEducational: true, hasSession: true, isConsented: true, hasCompletedSetup: true) == .presentGroupForm)
    }

    @Test("la tabla completa: cada paso se RE-DECIDE, nunca se recuerda")
    func fullTable() {
        // Es lo que hace que un sign-in ya hecho, un consent aceptado en otra pantalla o un kill a mitad no
        // desalineen la máquina: el drain vuelve aquí después de cada sheet en vez de avanzar un contador.
        var seen: Set<Flow.Step> = []
        for educational in [true, false] {
            for session in [true, false] {
                for consent in [true, false] {
                    for setup in [true, false] {
                        seen.insert(Flow.nextStep(
                            hasSeenEducational: educational, hasSession: session,
                            isConsented: consent, hasCompletedSetup: setup))
                    }
                }
            }
        }
        // C2 añadió el QUINTO: el educativo, y va PRIMERO. Antes de él la rama pedía identidad sin haber
        // contado nunca qué es un grupo ni dónde viven sus gastos.
        #expect(seen == [.presentEducational, .presentSignIn, .presentConsent, .presentName, .presentGroupForm],
                "los cinco pasos tienen que ser alcanzables desde alguna combinación: \(seen)")
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

    /// Cuerpo balanceado por llaves desde un marcador (molde `SecondaryOwnerDomainWiringTests`). Acotar al
    /// CUERPO importa: sobre el fichero entero, `ContentView.swift` nombra el descriptor en otros seis
    /// sitios y el escáner comprobaría que el símbolo EXISTE, no que esta función lo consulte.
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

    @Test("MUTACIÓN (b): el alta solo se llama desde DETRÁS de la cadena, y nunca desde la puerta")
    func setupIsOnlyCalledFromBehindTheChain() throws {
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
        // C2 · son DOS, y el segundo NO relaja el invariante: la card «Solo grupos» del onboarding entra
        // en la MISMA cadena (educativo → login → consent) y su alta se ejecuta en el caso `.presentName`
        // del router, con identidad y consent ya en mano; lo que cambia es que no vuelve a pedir el nombre
        // porque ya lo tiene en memoria. Antes de C2 esa puerta no llamaba aquí: escribía el trío ella
        // misma, en el paso 8 del onboarding y sin cuenta en ninguna parte.
        #expect(Set(callSites) == Set(["GroupsOrganizerNameView.swift", "ContentView.swift"]), """
            el alta se escribe detrás de la cadena y en ningún otro sitio. Un call-site nuevo es, con casi
            total seguridad, una escritura del trío adelantada. Encontrado: \(callSites)
            """)
    }

    @Test("MUTACIÓN (b'): la puerta no nombra ni el alta ni las keys del trío")
    func gateNeverWrites() throws {
        let code = try Self.code(Self.gateView)
        // `defaultCurrencyCode` entra con G4: es `synced: true`, así que escribirla en la puerta
        // propagaría a la CUENTA una divisa decidida antes de saber si el canal está encendido.
        for forbidden in ["GroupsOrganizerOnboarding", "groupsBetaUnlocked",
                          "hasCompletedOnboarding", "onboardingMode", "defaultCurrencyCode"] {
            #expect(!code.contains(forbidden), """
                la puerta escribió `\(forbidden)`. El paso 2 comprueba y NO escribe: con el canal apagado el
                usuario tiene que volver al chooser con el dispositivo exactamente como lo encontró.
                """)
        }
    }

    /// **Cada razón de la puerta con SU copy, y ninguna prestada.**
    ///
    /// `.blockedForeignData` pintaba `welcome.cloud.blocked*`, el copy del guard cross-cuenta del
    /// sign-in: «Este dispositivo tiene datos de otra cuenta … no podemos conectar una cuenta distinta
    /// aquí». Dicho a la DUEÑA de esos datos, que no está conectando ninguna cuenta sino intentando
    /// crear un grupo, es una acusación falsa por partida doble. El bloqueo es correcto; lo que estaba
    /// mal era lo que se decía al bloquear.
    ///
    /// El escáner es por CONTENIDO y no por conteo de casos: lo que hay que impedir es que dos ramas
    /// compartan key, no que existan tres ramas (eso ya lo cubre la tabla de `Gate.decide`).
    @Test("las TRES razones de la puerta tienen copy propio, sin préstamos entre ellas")
    func eachBlockReasonHasItsOwnCopy() throws {
        let view = try Self.code(Self.gateView)

        // El copy del guard de SIGN-IN no puede volver a esta pantalla: aquí nadie conecta una cuenta.
        #expect(!view.contains("L10n.Welcome.Cloud.blocked"), """
            La puerta del organizador volvió a pedir prestado el copy del guard cross-cuenta del \
            sign-in (`welcome.cloud.blocked*`). A quien llega por «Crear mi primer grupo» le dice que \
            este dispositivo tiene datos de OTRA cuenta y que no puede conectar una cuenta distinta — \
            y esos datos son suyos, y no está conectando nada.
            """)

        // Una key por razón, y cada una distinta de las otras dos.
        let porRazon: [(String, String)] = [
            ("blockedChannelOff", "L10n.Welcome.Groups.channelOff"),
            ("blockedSecondarySession", "L10n.Welcome.Groups.secondary"),
            ("blockedForeignData", "L10n.Welcome.Groups.existingData"),
        ]
        // Una rama de `switch` no abre llaves, así que `bodyOf` no vale aquí: se corta desde el `case`
        // hasta el siguiente `case .`, que es el límite real de lo que pinta cada razón.
        func rama(_ caso: String) -> String? {
            guard let start = view.range(of: "case .\(caso):") else { return nil }
            let resto = view[start.upperBound...]
            guard let next = resto.range(of: "\n                case .") else { return String(resto) }
            return String(resto[..<next.lowerBound])
        }

        for (caso, prefijo) in porRazon {
            let rama = try #require(
                rama(caso), "La puerta dejó de tener la rama `.\(caso)`.")
            #expect(rama.contains(prefijo), """
                La rama `.\(caso)` ya no pinta su propio copy (`\(prefijo)*`). Las tres razones son \
                hechos distintos y con salidas distintas: un copy compartido describe una acción que \
                la persona no está haciendo.
                """)
            for (otro, otroPrefijo) in porRazon where otro != caso {
                #expect(!rama.contains(otroPrefijo), """
                    La rama `.\(caso)` está pintando el copy de `.\(otro)`.
                    """)
            }
        }
    }

    @Test("el alta se cablea a la lógica del alta y aterriza en el tab Grupos")
    func nameViewCompletesTheSetup() throws {
        let code = try Self.code(Self.nameView)
        #expect(code.contains("GroupsOrganizerOnboarding.completeSetup("),
                "el CTA del nombre es lo que escribe el trío")
    }

    /// **C3 · el default del parámetro TIENE que ser el mecanismo real.**
    ///
    /// El guard es inyectable para poder afirmarlo sobre un valor y no sobre el `UserDefaults.standard` del
    /// simulador (el override global de `isActive()` es estado de PROCESO y contaminaría a las suites que
    /// corren en paralelo). El precio es que alguien puede cambiar el default por `false` y **los tres
    /// tests de comportamiento siguen en VERDE**, porque los tres pasan el término explícito. Este escáner
    /// es el que cae.
    @Test("MUTACIÓN (c): el guard del alta lee el descriptor de verdad por default")
    func setupGuardDefaultsToTheRealDescriptor() throws {
        let code = try Self.code("Yala/Services/Groups/GroupsOrganizerOnboarding.swift")
        #expect(code.contains("isSecondarySession: Bool = SecondarySessionStore.isActive()"), """
            el default del guard M1 dejó de ser el descriptor real. Con un `false` ahí, el alta vuelve a \
            escribir sus seis preferencias en el `UserDefaults` del DUEÑO y los tests de comportamiento \
            no lo ven: todos pasan el término a mano.
            """)
        #expect(code.contains("guard !isSecondarySession else { return false }"), """
            el guard dejó de abortar el MÉTODO ENTERO. Proteger una de las seis escrituras y dejar las \
            otras cinco es exactamente el bug que C3 arregla — y `groupsBetaUnlocked`, que es una de las \
            cinco, no la repone nadie al cerrar la sesión.
            """)
        // Y `completeSetup` tiene que RESPETAR el veredicto: sin el `guard`, los seeds y el aterrizaje en
        // el tab corren igual sobre el store del dueño.
        #expect(code.contains("guard writePreferences("), """
            `completeSetup` ignora el resultado del alta: con la frontera M1 puesta seguiría sembrando \
            categorías y aterrizando en el tab Grupos sin ninguna preferencia detrás.
            """)
    }

    /// **C3 · el choke-point de las DOS puertas, que es lo que hace que la respuesta sea honesta.**
    ///
    /// La puerta del Welcome comprueba por su cuenta; la card «Solo grupos» NO pasa por ella
    /// (`startGroupsOnlyBranch` enciende el discriminador y submitea directo), y su camino SÍ existe con
    /// un descriptor vivo. Lo que decide aquí es QUIÉN pregunta y qué hace con el `no`: un `return` mudo
    /// dejaría un botón que no hace nada, y eso es el «camino muerto» que el spec de la rama prohíbe.
    @Test("MUTACIÓN (d): la rama entera se corta en secundaria, y manda a la PUERTA")
    func organizerFlowStopsUnderASecondarySession() throws {
        let content = try Self.code("Yala/App/ContentView.swift")
        let advance = try #require(
            Self.bodyOf("private func advanceGroupsOrganizerFlow() {", in: content),
            "`advanceGroupsOrganizerFlow` desapareció o cambió de firma")

        #expect(advance.contains("SecondarySessionStore.isActive()"), """
            el choke-point de la rama organizador dejó de mirar el descriptor. La card «Solo grupos» no \
            pasa por `WelcomeGroupsGateView`, así que sin esto su camino llega hasta el alta con una \
            sesión secundaria viva.
            """)
        #expect(advance.contains("welcomeFlowInitialStep = .groupsGate"), """
            el corte dejó de mandar a la PUERTA. Un `return` mudo es un botón que no hace nada; el spec de \
            esta rama exige que ningún camino muera sin respuesta, y la puerta es la que sabe pintar este \
            veredicto (`.blockedSecondarySession`).
            """)
        // El payload de la card se descarta al cortar: un payload superviviente haría que el siguiente
        // intento saltara la pantalla del nombre con datos de una sesión abandonada.
        #expect(advance.contains("pendingGroupsOnlyPayload = nil"))
    }

    @Test("la puerta pregunta por el descriptor, no solo por el corpus")
    func gateAsksForTheDescriptor() throws {
        let code = try Self.code(Self.gateView)
        #expect(code.contains("isSecondarySession: SecondarySessionStore.isActive()"), """
            la puerta decide la celda de secundaria con otra cosa que el descriptor. `hasLocalDataNow` \
            mide el store de la INVITADA, que en una sesión recién montada está VACÍO ⇒ daría vía libre.
            """)
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
