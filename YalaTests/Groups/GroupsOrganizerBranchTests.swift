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

    @Test("la tabla completa: canal × estado del store")
    func fullTable() {
        #expect(Gate.decide(channelEnabled: true, hasExistingData: false, mountAttachesMirror: false) == .proceed)
        #expect(Gate.decide(channelEnabled: false, hasExistingData: false, mountAttachesMirror: false) == .blockedChannelOff)
        #expect(Gate.decide(channelEnabled: true, hasExistingData: true, mountAttachesMirror: false) == .returnsToNeutral)
    }

    @Test("con el canal APAGADO gana el canal, aunque además haya que volver al neutro")
    func channelWinsOverNeutralReturn() {
        // El orden no es estético. El canal acaba de re-medirse con `force`, así que su veredicto es el más
        // fresco, y su copy describe algo TRANSITORIO («vuelve a intentarlo en un momento»). Y la vuelta al
        // neutro BORRA: ofrecérsela a quien no va a poder crear el grupo de todas formas sería cobrarle un
        // borrado por nada.
        #expect(Gate.decide(channelEnabled: false, hasExistingData: true, mountAttachesMirror: true) == .blockedChannelOff)
    }

    /// **El medio bug que el detector de filas NO puede ver (2026-09-11).**
    ///
    /// Un store personal VACÍO pero montado CON espejo dejaba pasar: no hay filas que contar. Y detrás de
    /// la puerta, todo lo que el recién llegado escriba —el bridge de sus gastos de grupo incluido— se
    /// exporta al iCloud del Apple ID de este teléfono, que es el del dueño. El eje ancho
    /// (`attachesCloudKitMirror`) es el único término que ve esa celda, y es `true` también para
    /// `.localNoMirror`, cuyo `.automatic` adjunta el espejo aunque no haya cuenta.
    @Test("store VACÍO pero con ESPEJO: también vuelve al neutro")
    func emptyStoreWithMirrorStillReturnsToNeutral() {
        #expect(Gate.decide(channelEnabled: true,
                            hasExistingData: false, mountAttachesMirror: true) == .returnsToNeutral)
        // Control negativo, que es lo que impide que el término se convierta en un «siempre borra»: sin
        // espejo y sin datos —el mount neutro de toda instalación fresca— se pasa sin tocar nada.
        #expect(Gate.decide(channelEnabled: true,
                            hasExistingData: false, mountAttachesMirror: false) == .proceed)
    }

    /// **D2 se INVIRTIÓ el 2026-09-11, y conviene saber por qué no es una regresión.**
    ///
    /// Hasta hoy `restoreInProgress` era un término de esta tabla: con una restauración en curso el corpus
    /// no contaba como ajeno y la puerta ABRÍA, porque el veredicto alternativo era un bloqueo con una
    /// salida imposible de seguir. Ya no hay bloqueo que corregir: restaure o no, el estado del store es el
    /// mismo y la respuesta también —volver al neutro—, así que el término salió de la firma. El criterio
    /// nº 3 del ticket lo pide con esas palabras, y lo que protege a la dueña es que su iCloud queda
    /// intacto: puede volver a restaurar cuando quiera. La cancelación de la señal es un EFECTO de la
    /// vuelta al neutro (`WelcomeGroupsGateView.returnToNeutral`), no un término de aquí.
    @Test("D2 · restaurar ya no abre la puerta: el estado del store manda igual")
    func restoreNoLongerOpensTheGate() {
        // Un restore en curso implica espejo adjunto, así que la celda real es ésta.
        #expect(Gate.decide(channelEnabled: true,
                            hasExistingData: true, mountAttachesMirror: true) == .returnsToNeutral)
        // Y el canal sigue mandando por encima, igual que antes.
        #expect(Gate.decide(channelEnabled: false,
                            hasExistingData: true, mountAttachesMirror: true) == .blockedChannelOff)
    }

    @Test("`proceed` exige las TRES condiciones — es la única celda que deja escribir")
    func proceedNeedsAllThreeTerms() {
        for channel in [true, false] {
            for data in [true, false] {
                for mirror in [true, false] {
                    let decision = Gate.decide(
                        channelEnabled: channel,
                        hasExistingData: data, mountAttachesMirror: mirror)
                    // El store está limpio solo si no hay filas Y no hay espejo que exporte.
                    let storeIsNeutral = !data && !mirror
                    #expect((decision == .proceed) == (channel && storeIsNeutral),
                            "canal=\(channel) datos=\(data) espejo=\(mirror) ⇒ \(decision)")
                    // Y la otra mitad de la tabla, que es la que este ticket añade: con el canal
                    // encendido, todo store no-neutro vuelve al neutro. Sin esta línea el mutante que
                    // devuelve `.blockedChannelOff` en la última rama seguiría verde.
                    if channel {
                        #expect((decision == .returnsToNeutral) == !storeIsNeutral,
                                "canal=\(channel) datos=\(data) espejo=\(mirror) ⇒ \(decision)")
                    }
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

        let decision = Gate.decide(channelEnabled: false, hasExistingData: false, mountAttachesMirror: false)
        #expect(decision == .blockedChannelOff)

        // La aserción que carga el peso: `groupsBetaUnlocked` es per-device y permanente, y NADIE la
        // repone — escribirla con la puerta cerrada deja el dominio Grupos adoptado para siempre en un
        // teléfono que no llegó a crear ningún grupo.
        #expect(writer.writes.isEmpty, "la puerta no puede escribir: escribió \(writer.writes)")
        #expect(writtenKeysPresent(in: defaults).isEmpty,
                "el store ganó keys del alta con la puerta cerrada: \(writtenKeysPresent(in: defaults))")

        // CONTROL POSITIVO. Sin esto la aserción de arriba se cumpliría igual con un inventario vacío, un
        // writer que no escribe o unas keys renombradas — la familia de «Executed 0 tests».
        GroupsOrganizerOnboarding.writePreferences(displayName: "Ana", writer: writer, defaults: defaults)
        #expect(Set(writer.writes) == Set(GroupsOrganizerOnboarding.writtenPreferenceKeys),
                "el instrumento no detecta las escrituras del alta: \(writer.writes)")
        #expect(writtenKeysPresent(in: defaults).count == GroupsOrganizerOnboarding.writtenKeys.count)
    }

    @Test("store no-neutro ⇒ vuelta al neutro Y ninguna preferencia del alta escrita")
    func neutralReturn_writesNothing() {
        // La decisión dejó de ser un bloqueo el 2026-09-11, pero **lo que no puede pasar sigue siendo lo
        // mismo**: que el alta escriba antes de que el dispositivo esté listo. Lo que escribe el alta
        // incluye `groupsBetaUnlocked`, per-device y permanente: si se escribiera aquí, el dominio Grupos
        // quedaría adoptado en un teléfono que todavía es de otra persona, y nadie la repone. La vuelta al
        // neutro sí escribe, pero lo suyo (el arm del borrado) y por otra vía; esta tabla no toca nada.
        let defaults = makeIsolatedDefaults(prefix: "g3.gate.neutral")
        let writer = SpyPreferenceWriter(defaults: defaults)

        #expect(Gate.decide(channelEnabled: true, hasExistingData: true, mountAttachesMirror: true) == .returnsToNeutral)
        #expect(writer.writes.isEmpty)
        #expect(writtenKeysPresent(in: defaults).isEmpty)
    }

    /// El neutro de solo-grupos es una decisión de MOUNT del device, y el alta es quien la arma: sin ella
    /// el arranque siguiente adjunta el espejo sobre el store personal y baja el contenedor privado del
    /// Apple ID del teléfono, que es el bug del ticket.
    @Test("el alta arma el neutro de solo-grupos, y escribe su inventario entero")
    func setupArmsTheGroupsOnlyNeutralMount() {
        let defaults = makeIsolatedDefaults(prefix: "g3.alta.neutro")
        let writer = SpyPreferenceWriter(defaults: defaults)

        #expect(GroupsOrganizerOnboarding.writePreferences(
            displayName: "Ana", writer: writer, defaults: defaults))
        #expect(StorageModePersistence.isGroupsOnlyNeutralMountArmed(defaults), """
            el alta TIENE que armar el neutro de solo-grupos: es lo que impide que el arranque siguiente \
            adjunte el espejo y baje datos ajenos.
            """)
        // Contar ESCRITURAS y no leer el estado final: podrían re-escribir un valor que ya está y dejar el
        // store idéntico, y el mutante pasaría en verde.
        #expect(Set(writer.writes) == Set(GroupsOrganizerOnboarding.writtenPreferenceKeys),
                "el instrumento no detecta las escrituras del alta: \(writer.writes)")
    }

    @Test("el alta escribe su inventario, y el nombre vacío cae al nombre por defecto")
    func setupWritesTheTrio() {
        let defaults = makeIsolatedDefaults(prefix: "g3.alta")
        let writer = SpyPreferenceWriter(defaults: defaults)

        GroupsOrganizerOnboarding.writePreferences(displayName: "  ", writer: writer, defaults: defaults)

        // El par que hace la shell.
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

        GroupsOrganizerOnboarding.writePreferences(displayName: "  Ana  ", writer: writer, defaults: defaults)
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

            GroupsOrganizerOnboarding.writePreferences(displayName: "Ana", writer: writer, regionCode: region, defaults: defaults)

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

        GroupsOrganizerOnboarding.writePreferences(displayName: "Ana", writer: writer, regionCode: "US", defaults: defaults)

        #expect(defaults.string(forKey: AppPreferences.Keys.defaultCurrencyCode) == CurrencyCode.eur.rawValue)
        // Contar la escritura, no solo mirar el estado final: re-escribir el MISMO valor dejaría el store
        // idéntico y un mutante sin guard pasaría en verde si el fixture casara con la región.
        #expect(!writer.writes.contains(AppPreferences.Keys.defaultCurrencyCode),
                "el alta escribió la divisa encima de una existente: \(writer.writes)")
        // El resto del alta sí ocurre: el guard es de la divisa, no del alta entera.
        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsBetaUnlocked))
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
    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private static let contentView = "Yala/App/ContentView.swift"
    private static let container = "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"

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

    // MARK: - La vuelta al neutro (mitad 2 del paso 5, 2026-09-11)

    /// **La lección del 2026-09-10, hecha red.**
    ///
    /// Aquella sesión intentó volver al neutro llamando a `StorageModePersistence.armSignOutWipe()` por su
    /// cuenta, y tres lentes midieron que el boot-wipe declara precondiciones («el coordinador de sign-out
    /// ya subió TODO el outbox, cerró la sesión y armó») que un call-site suelto **no cumple**: se llevaba
    /// el canal de Grupos y las colas de Apple Pay/Siri, y no había desarme si abortaba. Consumir el
    /// coordinador entero las cumple las tres por construcción.
    ///
    /// Este escáner es lo único que impide que alguien «simplifique» el camino saltándose el coordinador:
    /// un `armSignOutWipe()` aquí compila, pasa la tabla de `decide` y vuelve a abrir los tres agujeros.
    @Test("MUTACIÓN: la vuelta al neutro CONSUME el cierre de sesión, no arma el wipe por su cuenta")
    func neutralReturnConsumesTheSignOutVerb() throws {
        let code = try Self.code(Self.gateView)
        #expect(code.contains("CloudSessionSignOut.shared.signOut("), """
            la vuelta al neutro tiene que entrar por el coordinador del cierre privado: es lo único que
            cumple las tres precondiciones del boot-wipe (outbox subido y verificado, sesión cerrada, arm).
            """)
        // **Los literales van SIN el paréntesis a propósito.** `SharedStateIsolationTests` escanea todo
        // `YalaTests/` buscando `wipeAllUserData(` para exigir el trait de aislamiento del App Group a quien
        // lo EJECUTA, y filtra comentarios pero no cadenas: con el paréntesis, este test se declaraba a sí
        // mismo ejecutor del wipe y ponía en rojo a aquel. Sin él, la aserción de aquí mide lo mismo.
        for prohibido in ["armSignOutWipe", "performSignOutWipeIfArmed", "wipeAllUserData",
                          "markSignOutWipeIncludesGroups", "deleteStoreFiles"] {
            #expect(!code.contains(prohibido), """
                la puerta está borrando por su cuenta (`\(prohibido)`). Ese es exactamente el camino que
                la review del 2026-09-10 tumbó: el mecanismo hace cosas que solo tienen sentido cuando sus
                precondiciones son ciertas, y aquí no lo son si no ha corrido el coordinador.
                """)
        }
    }

    /// **Se informa, no se pregunta — salvo sin copia, y eso exige PRUEBA.**
    ///
    /// El segundo gesto tiene que colgar de `privateCopyChannel()`, que es quien sabe distinguir «no hay
    /// copia» de «no lo sabemos»: con iCloud Drive apagado y CloudKit vivo el canal sigue siendo `.iCloud`
    /// (hallazgo nº 7 de la review del paso 9). Un predicado escrito a mano aquí —por ejemplo
    /// `!personalMountAttachesMirror`— le diría «no hay copia» a quien sí la tiene, y le pediría confirmar
    /// una pérdida que no existe; o peor, al revés.
    @Test("MUTACIÓN: el segundo gesto cuelga del canal de copia, no de un predicado propio")
    func secondGestureHangsFromTheCopyChannel() throws {
        let code = try Self.code(Self.gateView)
        #expect(code.contains("CloudSessionSignOut.privateCopyChannel()"), """
            quién tiene copia en iCloud lo contesta el canal del paso 9, que exige prueba para decir que no.
            """)
        // Y el segundo gesto viaja como la bandera que el coordinador entiende, no como un salto de fase
        // que se salte la espera por su cuenta.
        #expect(code.contains("confirmedWithoutICloudCopy: withoutICloudCopy"), """
            saltarse la espera del export tiene que ser una DECISIÓN de la persona que viaja hasta el
            coordinador, no un atajo del call-site.
            """)
    }

    /// **El destino se persiste DESPUÉS del arm, y el orden es lo que evita un `exit(0)` espurio.**
    ///
    /// `RelaunchNetLogic.shouldExitOnBackground` lee «hay destino pendiente» como «este proceso tiene que
    /// morir al pasar a segundo plano». Escribirlo antes de empezar haría que la app se cerrara sola
    /// aunque la vuelta al neutro se hubiera bloqueado o abortado — y en ese caso no hay nada armado, así
    /// que al reabrir no habría pasado nada y la persona no entendería el cierre.
    @Test("MUTACIÓN: el destino durable se escribe al ARMAR, no al empezar")
    func pendingDestinationIsWrittenOnArmOnly() throws {
        let view = try Self.code(Self.gateView)
        #expect(!view.contains("WelcomePendingDestinationStore"), """
            la vista no persiste destinos: eso es de `ContentView`, que es quien tiene el flag del cover.
            """)
        #expect(view.contains("if new == .awaitingRelaunch { onNeutralReturnArmed() }"), """
            el aviso cuelga de la fase terminal del coordinador, que es la que va pegada al arm sin ningún
            `await` en medio.
            """)

        let content = try Self.code(Self.contentView)
        let armed = try #require(Self.bodyOf("onGroupsGateNeutralReturnArmed: {", in: content), """
            `ContentView` dejó de cablear el aviso de la vuelta al neutro.
            """)
        #expect(armed.contains("WelcomePendingDestinationStore.set(.groupsOrganizer)"), """
            sin persistir el destino, quien vuelve a abrir la app aterriza en el chooser y tiene que volver
            a elegir «Vengo por un grupo» — el camino muerto, movido un paso más adelante.
            """)
        #expect(armed.contains("showWelcomeFlow = false"), """
            el cover del Welcome y el terminal del cierre cuelgan del MISMO body: sin cerrar éste, UIKit no
            presenta el otro y la persona se queda en un progreso que ya no avanza.
            """)
    }

    /// **Y el destino tiene que tener quién lo consuma.** `.groupsOrganizer` caía hasta hoy en la rama de
    /// «inalcanzables» del consumidor, que aterriza en el chooser: persistirlo sin esta rama habría dejado
    /// a la persona eligiendo otra vez lo que ya eligió.
    @Test("MUTACIÓN: el arranque retoma `.groupsOrganizer` en la PUERTA, no en el chooser ni en el alta")
    func bootResumesTheGate() throws {
        let content = try Self.code(Self.contentView)
        let resume = try #require(Self.bodyOf("if let pending = WelcomePendingDestinationStore.consume() {", in: content))
        let rama = try #require(resume.range(of: "case .groupsOrganizer:"), """
            `.groupsOrganizer` volvió a caer en la rama de destinos inalcanzables: el arranque siguiente
            aterriza en el chooser y la vuelta al neutro pierde su razón de ser.
            """)
        let resto = resume[rama.upperBound...]
        let siguiente = resto.range(of: "case .")?.lowerBound ?? resto.endIndex
        let cuerpo = String(resto[..<siguiente])
        #expect(cuerpo.contains("welcomeFlowInitialStep = .groupsGate"), """
            se retoma en la PUERTA y no en el alta: el proceso nuevo no ha visto esa puerta, y volver a
            medirla es lo que confirma que el dispositivo quedó de verdad en neutro.
            """)
        #expect(!cuerpo.contains(".chooser"), "retomar en el chooser es no retomar nada")
    }

    /// **Salir de un bloqueo tiene que devolver el coordinador a `.idle`, o el siguiente intento es MUDO.**
    ///
    /// `signOut` empieza con `guard phase == .idle`: un `.blocked` que sobrevive a esta pantalla hace que
    /// la vuelta al neutro siguiente vuelva sin hacer nada y sin decirlo, con la persona mirando un
    /// progreso que no avanza. No lo caza ningún test de comportamiento —la vista se desmonta igual— así
    /// que el escáner es la única red.
    @Test("MUTACIÓN: salir de un bloqueo reconoce la fase antes de volver")
    func leavingABlockAcknowledgesThePhase() throws {
        let view = try Self.code(Self.gateView)
        let cuerpo = try #require(Self.bodyOf("private func leaveAfterBlock() {", in: view), """
            la puerta dejó de tener salida propia para los bloqueos del cierre.
            """)
        #expect(cuerpo.contains("CloudSessionSignOut.shared.acknowledgeBlocked()"), """
            sin reconocer la fase, el coordinador se queda en `.blocked` y el `guard phase == .idle` de
            `signOut` deja mudo cualquier intento posterior.
            """)
        #expect(cuerpo.contains("onBack()"), "y hay que volver: quedarse aquí es el camino muerto")
    }

    /// **Todo bloqueo del cierre tiene que tener pantalla.** El único alcanzable en esta celda además del
    /// export es `blockIfGroupsCannotUpload` (`.sessionExpired`): quedaron cambios de grupos sin subir de
    /// una sesión que caducó, y el criterio del paso 9 es «nunca descarta». Sin su rama, la vista se queda
    /// en el progreso para siempre — un spinner eterno, que es la definición de camino muerto.
    @Test("MUTACIÓN: el bloqueo por grupos sin subir tiene su pantalla y su salida")
    func groupsBlockHasItsOwnScreen() throws {
        let view = try Self.code(Self.gateView)
        #expect(view.contains("welcome_groups_gate_neutral_blocked"), """
            desapareció la pantalla del bloqueo por grupos pendientes: ese cierre no descarta nunca, así
            que sin pantalla la persona se queda mirando un progreso que ya no va a terminar.
            """)
        #expect(view.contains("L10n.Welcome.Groups.neutralBlockedBody"),
                "y tiene que decir CÓMO se desbloquea (volver a entrar con esa cuenta)")
    }

    /// El container solo REENVÍA: si empezara a decidir, habría dos sitios donde escribir la condición.
    @Test("el container reenvía el aviso de la vuelta al neutro sin decidir nada")
    func containerOnlyForwardsTheNeutralReturn() throws {
        let code = try Self.code(Self.container)
        // 2026-09-11: el callback pasó a llevar el PROPÓSITO del step, porque desde la puerta del
        // invitado el mismo aviso significa dos destinos distintos. El envoltorio reenvía un DATO que el
        // container ya tiene delante —el `let purpose` del propio `case`—, no una decisión: sigue sin
        // haber aquí ni un `if`, ni una lectura de `UserDefaults`, ni nada que `ContentView` tenga que
        // volver a comprobar.
        #expect(code.contains("onNeutralReturnArmed: { onGroupsGateNeutralReturnArmed(purpose) }"), """
            el step tiene que reenviar el callback con el propósito y nada más. Meter aquí una condición
            sería un segundo sitio donde decidir qué pasa al armar.
            """)
        #expect(!code.contains("WelcomePendingDestinationStore.set(.groupsOrganizer)"), """
            el container no toca `UserDefaults` — es el contrato que su propio docblock declara para el
            callback hermano del relanzamiento.
            """)
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

    /// **El escáner que caza el mutante que la tabla NO ve.**
    ///
    /// La tabla de arriba prueba que `decide` clasifica bien las ocho celdas, pero pasaría igual de verde
    /// si el call-site le pasara `mountAttachesMirror: false` a pelo, o midiera el eje ESTRECHO. Ese es
    /// exactamente el mutante que en la pieza 1 de este ticket cayó SOLO en el source-scan, con los ocho
    /// tests del guard en verde. El parámetro sin default obliga a poner ALGO; esto obliga a poner lo
    /// correcto.
    ///
    /// **Por qué el testigo tiene que ser el ancho:** `personalStoreMountedDecision == .iCloudMirror` deja
    /// fuera a `.localNoMirror`, cuyo `cloudKitDatabase` cae en `.automatic` y **adjunta el espejo igual**
    /// (auditoría R1(c), escrito en `PersonalStoreDecision.attachesCloudKitMirror`). Con el eje estrecho,
    /// a quien tiene iCloud Drive apagado y CloudKit vivo se le abre la puerta con el espejo puesto y sus
    /// gastos de grupo acaban en el iCloud del dueño del teléfono.
    @Test("MUTACIÓN: el call-site mide el EJE ANCHO del mount, no un literal ni el estrecho")
    func gateReadsTheWideMountAxis() throws {
        let code = try Self.code(Self.gateView)
        #expect(code.contains("mountAttachesMirror: Self.mountAttachesMirrorNow"),
                "el término del mount tiene que salir del seam, que es quien conoce la mentira del host de test")
        let seam = try #require(Self.bodyOf("private static var mountAttachesMirrorNow: Bool {", in: code))
        #expect(seam.contains("return CloudSessionSignOut.personalMountAttachesMirror"), """
            en producción tiene que ser el eje ANCHO, y por el MISMO testigo que usa el cierre de sesión para
            decidir si espera al export. Dos testigos distintos para el mismo hecho es como divergen la
            decisión de borrar y la de esperar.
            """)
        #expect(!code.contains("mountAttachesMirror: false"),
                "un literal aquí es el bug de vuelta, y el compilador no puede cazarlo: el tipo casa")
        #expect(!code.contains("== .iCloudMirror"), """
            el eje ESTRECHO deja fuera a `.localNoMirror`, que adjunta el espejo igual: es el predicado que
            falla ABIERTO justo sobre la población que este término existe para proteger.
            """)
    }

    /// **El seam del host de test, y por qué su default tiene que ser `false`.**
    ///
    /// Medido: bajo `-uitest`, `SwiftDataConfiguration.personalConfiguration` sale por su rama
    /// `YalaModel-UITest` —`cloudKitDatabase: .none`— ANTES de `capturePersonalStoreMountedDecisionOnce`, así
    /// que `personalStoreMountedDecision` se queda en el default de su declaración, `.iCloudMirror`, y el eje
    /// ancho da `true` en toda corrida. Sin este seam la puerta volvería SIEMPRE al neutro en XCUITest:
    /// `.proceed` sería inalcanzable, `WelcomeChooserUITests` se caería, y cada corrida armaría un boot-wipe
    /// real cuya key sobrevive a `-uitest-reset`.
    ///
    /// El default es la VERDAD de ese host (`false`), no una inversión. El hook solo lo enciende para quien
    /// quiera recorrer la vuelta al neutro en simulador.
    @Test("MUTACIÓN: el seam del mount vale `false` por defecto bajo uitest, y su hook existe")
    func mountSeamDefaultsToFalseUnderUITest() throws {
        let code = try Self.code(Self.gateView)
        let seam = try #require(Self.bodyOf("private static var mountAttachesMirrorNow: Bool {", in: code))
        #expect(seam.contains("if SwiftDataConfiguration.isUITesting { return UITestHooks.groupsGateMirrorLive }"), """
            sin este corte el testigo del mount miente en TODA corrida y la rama buena de la puerta deja de
            ser recorrible.
            """)
        #expect(!seam.contains("!UITestHooks.groupsGateMirrorLive"),
                "invertir el hook haría que el default fuera `true`, que es justo la mentira que este seam quita")

        let hooks = try Self.code("Yala/App/UITestHooks.swift")
        #expect(hooks.contains("-uitest-groups-gate-mirror-live"),
                "desapareció el hook: la vuelta al neutro deja de ser alcanzable desde XCUITest")
    }

    /// **La puerta NO apaga el latch de restauración, y la aserción va en negativo a propósito.**
    ///
    /// La primera versión lo apagaba como primera línea de la vuelta al neutro, leyendo el criterio nº 3 del
    /// ticket al pie de la letra. Dos lentes independientes midieron el precio: si el cierre luego se
    /// bloquea —espera agotada, grupos sin subir— y la persona sale, el import SIGUE bajando con el latch
    /// apagado, y **nadie lo vuelve a encender**: su único encendedor de producción es `WelcomeRestoreView`,
    /// pinneado a un solo sitio por `ICloudRestoreSignalTests`. A partir de ahí el guard cross-cuenta del
    /// sign-in vuelve a clasificar el corpus propio de la dueña como ajeno — la enmienda D2, deshecha, en la
    /// misma sesión.
    ///
    /// El criterio se cumple igual por el camino de siempre: el latch vive en MEMORIA y muere con el
    /// proceso, que es exactamente lo que hace el relanzamiento de este flujo.
    @Test("MUTACIÓN: la puerta no apaga el latch de restauración")
    func neutralReturnDoesNotCancelTheRestoreSignal() throws {
        let code = try Self.code(Self.gateView)
        // Con paréntesis abierto y sin cerrar: desde el 2026-09-21 el apagado lleva el token del flujo
        // (`noteRestoreFinished(flowToken)`), así que anclar al literal sin argumento dejaba pasar en
        // verde exactamente lo que este test prohíbe.
        #expect(!code.contains("ICloudRestoreSessionSignal.noteRestoreFinished("), """
            apagar el latch aquí lo deja apagado también cuando el cierre se aborta, y su único encendedor
            vive en otra pantalla. El relanzamiento ya lo apaga, porque vive en memoria.
            """)
        // **Y el segundo verbo que apaga, desde `restore-session-window-has-no-reachable-ceiling`
        // (2026-09-21).** Este test se escribió cuando solo había uno; `noteRestoreDiscardRequested`
        // pone `restoreStartedAt` y `currentFlow` a `nil` exactamente igual, así que produce el daño de
        // arriba entero — y encima deja un reloj aparcado que la entrada siguiente heredaría. Lo cazaron
        // dos lentes de la review de aquel ticket, con este test en verde.
        #expect(!code.contains("ICloudRestoreSessionSignal.noteRestoreDiscardRequested("), """
            el verbo del descarte apaga el latch igual que su hermano, así que aquí hace el mismo daño:
            con el cierre abortado, el import sigue bajando sin latch y nadie lo vuelve a encender.
            Además aparca el reloj, y la próxima entrada a Restaurar nacería con un tope duro gastado.
            """)
    }

    /// **La celda se mide ANTES de arrancar, y ésa es la red contra los tres `return` mudos de `signOut`.**
    ///
    /// `signOut` vuelve sin tocar su fase en tres casos —fase no `.idle`, celda distinta de la confirmada,
    /// plan nulo— y la vista observa esa fase para pintar. Arrancar a ciegas dejaba un progreso eterno SIN
    /// botón de volver, que es el camino muerto que este ticket existe para retirar.
    @Test("MUTACIÓN: la puerta mide la celda antes de arrancar y tiene pantalla para la que no sirve")
    func gateMeasuresTheExitCellBeforeStarting() throws {
        let code = try Self.code(Self.gateView)
        let entry = try #require(Self.bodyOf("private func neutralReturnEntryPhase() -> Phase {", in: code), """
            desapareció la comprobación previa: la puerta vuelve a arrancar el cierre a ciegas.
            """)
        #expect(entry.contains("guard CloudSessionSignOut.shared.phase == .idle else { return .unavailable }"), """
            con el coordinador ocupado, `signOut` vuelve mudo por su primer guard.
            """)
        #expect(entry.contains("case .cloudSecureSignOut:"), """
            las dos celdas que NO borran por archivos tienen que salir por una pantalla con salida: el cierre
            de la nube haría un borrado distinto del que esta pantalla promete.
            """)
        #expect(code.contains("welcome_groups_gate_neutral_unavailable"),
                "y esa pantalla tiene que existir, con su identifier")

        // El cinturón del cinturón, para lo que cambie entre la medida y la ejecución.
        let run = try #require(Self.bodyOf("private func returnToNeutral(withoutICloudCopy: Bool) async {", in: code))
        #expect(run.contains("if CloudSessionSignOut.shared.phase == .idle { phase = .unavailable }"), """
            si el coordinador volvió sin tocar su fase, no arrancó nada: sin esta línea la pantalla se queda
            en un progreso que no avanza.
            """)
        #expect(run.contains("confirmedPath: celda"),
                "la celda medida viaja como cinturón, para que un cambio entre medias no ejecute otro borrado")
    }

    /// **El espejo del dispatch tiene que llevar los mismos términos.** Es el duplicado deliberado que ya
    /// tiene `ProfileView.signOutRowPath`: si divergieran, la puerta prometería un borrado que el
    /// coordinador no va a hacer, y el `confirmedPath` lo convertiría en un `return` mudo.
    @Test("MUTACIÓN: el espejo de la celda usa los mismos términos que el dispatch")
    func exitCellMirrorsTheDispatch() throws {
        let code = try Self.code(Self.gateView)
        let cell = try #require(Self.bodyOf("private static func exitCell() -> CloudSignOutFlowLogic.Path {", in: code))
        for termino in ["for: CloudSyncFlags.storageMode",
                        "hasLiveSession: CloudAuthService.shared.hasSession",
                        "groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability",
                        "hasPrivateSession: PrivateSessionMark.hasPrivateSession()"] {
            #expect(cell.contains(termino), "al espejo de la celda le falta `\(termino)`")
        }
    }

    /// **Los botones del aviso se pueden tocar dos veces.** `.task(id:)` solo re-arranca cuando el id
    /// CAMBIA, y el cierre vuelve a bloquear si la espera se agota otra vez: sin un nonce, el segundo tap
    /// del mismo botón asigna el mismo valor y no pasa nada. El primero en morir era «Esperar», que es el
    /// que NO destruye — o sea que la pantalla empujaba hacia el botón que borra.
    @Test("MUTACIÓN: las fases de trabajo llevan nonce, o el segundo tap es un no-op")
    func workPhasesCarryANonce() throws {
        let code = try Self.code(Self.gateView)
        for caso in ["case returningToNeutral(withoutICloudCopy: Bool, intento: Int)",
                     "case discardingUnconfirmed(intento: Int)",
                     "case resumingExportWait(intento: Int)"] {
            #expect(code.contains(caso), "la fase perdió su nonce: `\(caso)`")
        }
        #expect(Self.count("intento += 1", in: code) >= 4, """
            cada sitio que lanza trabajo tiene que avanzar el nonce (los tres botones y la entrada).
            """)
    }

    /// `initial: true` **no es cinturón**: sin él, un step que se montara con el coordinador YA en su fase
    /// terminal no avisaría nunca, el Welcome no se cerraría y el cover que cuenta el relanzamiento no
    /// podría presentarse — un solo cover por body.
    @Test("MUTACIÓN: el aviso del arm se evalúa también al montar")
    func armNoticeFiresOnAppearToo() throws {
        let code = try Self.code(Self.gateView)
        #expect(code.contains(".onChange(of: exitPhase, initial: true)"), """
            sin `initial: true`, montar el step con la fase terminal ya puesta deja el Welcome delante del
            cover terminal para siempre.
            """)
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
        // UNO desde el 2026-09-10. Hubo un segundo —el caso `.presentName` del router, por donde entraba la
        // card «Solo grupos» del onboarding (C2)— y se retiró con la card (ADR 2026-09-09 §7): solo-grupos se
        // abre desde el Welcome, así que el alta solo se escribe detrás de su pantalla del nombre.
        #expect(Set(callSites) == Set(["GroupsOrganizerNameView.swift"]), """
            el alta se escribe detrás de la cadena y en ningún otro sitio. Un call-site nuevo es, con casi
            total seguridad, una escritura del trío adelantada. Que la cadena tenga una sola ENTRADA lo fija
            `GroupsGateWiringTests.organizerBranchHasOneEntry`. Encontrado: \(callSites)
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

    /// **Cada pantalla de la puerta con SU copy, y ninguna prestada.**
    ///
    /// Hasta el 2026-08-12 la rama de datos existentes pintaba `welcome.cloud.blocked*`, el copy del guard
    /// cross-cuenta del sign-in: «Este dispositivo tiene datos de otra cuenta … no podemos conectar una
    /// cuenta distinta aquí». Dicho a la DUEÑA de esos datos, que no está conectando ninguna cuenta sino
    /// intentando crear un grupo, era una acusación falsa por partida doble. **Y desde el 2026-09-11 esa
    /// rama ya no bloquea**: vuelve al neutro, así que su copy propio (`existingData*`) también se retiró —
    /// describía una puerta cerrada que ya no existe.
    ///
    /// El escáner es por CONTENIDO y no por conteo de casos: lo que hay que impedir es que dos pantallas
    /// compartan key, no que existan N ramas (eso ya lo cubre la tabla de `Gate.decide`).
    @Test("cada pantalla de la puerta tiene copy propio, sin préstamos entre ellas")
    func eachGateScreenHasItsOwnCopy() throws {
        let view = try Self.code(Self.gateView)

        // El copy del guard de SIGN-IN no puede volver a esta pantalla: aquí nadie conecta una cuenta.
        #expect(!view.contains("L10n.Welcome.Cloud.blocked"), """
            La puerta del organizador volvió a pedir prestado el copy del guard cross-cuenta del \
            sign-in (`welcome.cloud.blocked*`). A quien llega por «Crear mi primer grupo» le dice que \
            este dispositivo tiene datos de OTRA cuenta y que no puede conectar una cuenta distinta — \
            y esos datos son suyos, y no está conectando nada.
            """)

        // Y tampoco el de la puerta que se retiró: si vuelve, es que alguien repuso el bloqueo.
        #expect(!view.contains("L10n.Welcome.Groups.existingData"), """
            `existingData*` es el copy del BLOQUEO que este ticket retiró («Aquí ya hay datos guardados … \
            crea el grupo desde la app que ya usas» — que es ésta). Sus keys ya no existen en los .strings.
            """)

        // Ni el del cierre de sesión de Ajustes: allí el verbo es «cerrar sesión» y aquí «empezar tu grupo».
        #expect(!view.contains("L10n.Settings.signOutExportPending"), """
            el aviso de Ajustes habla de cerrar sesión, y quien lee esta pantalla no ha pedido cerrar nada.
            """)

        // Una familia de keys por pantalla, y cada una distinta de las demás.
        let porPantalla: [(String, String)] = [
            ("blockedChannelOff", "L10n.Welcome.Groups.channelOff"),
            ("confirmingNoBackup", "L10n.Welcome.Groups.neutralNoBackup"),
        ]
        // Una rama de `switch` no abre llaves, así que `bodyOf` no vale aquí: se corta desde el `case`
        // hasta el siguiente `case .` con la MISMA indentación, que es el límite real de cada rama.
        func rama(_ caso: String, sangria: String) -> String? {
            guard let start = view.range(of: "\(sangria)case .\(caso):") else { return nil }
            let resto = view[start.upperBound...]
            guard let next = resto.range(of: "\n\(sangria)case ") else { return String(resto) }
            return String(resto[..<next.lowerBound])
        }

        for (caso, prefijo) in porPantalla {
            let cuerpo = try #require(
                rama(caso, sangria: "        "), "La puerta dejó de tener la rama `.\(caso)`.")
            #expect(cuerpo.contains(prefijo), """
                La rama `.\(caso)` ya no pinta su propio copy (`\(prefijo)*`). Son hechos distintos y con \
                salidas distintas: un copy compartido describe una acción que la persona no está haciendo.
                """)
            for (otro, otroPrefijo) in porPantalla where otro != caso {
                #expect(!cuerpo.contains(otroPrefijo), """
                    La rama `.\(caso)` está pintando el copy de `.\(otro)`.
                    """)
            }
        }

        // Las tres pantallas de la vuelta al neutro, que viven en el SUB-switch de la fase del cierre y
        // por eso no se pueden cortar con la misma sangría. Se comprueban por presencia: son tres hechos
        // distintos (trabajando · la espera se agotó · quedan grupos sin subir) y cada uno tiene su familia.
        for key in ["L10n.Welcome.Groups.neutralWorking",
                    "L10n.Welcome.Groups.neutralStalledTitle",
                    "L10n.Welcome.Groups.neutralStalledBodyUnknown",
                    "L10n.Welcome.Groups.neutralBlockedTitle"] {
            #expect(view.contains(key), "la vuelta al neutro perdió su copy `\(key)`")
        }
    }

    @Test("el alta se cablea a la lógica del alta y aterriza en el tab Grupos")
    func nameViewCompletesTheSetup() throws {
        let code = try Self.code(Self.nameView)
        #expect(code.contains("GroupsOrganizerOnboarding.completeSetup("),
                "el CTA del nombre es lo que escribe el trío")
    }

    /// **C3 · `completeSetup` tiene que RESPETAR el veredicto del alta.** Sin el `guard`, los seeds y el
    /// aterrizaje en el tab corren igual aunque las preferencias no se hayan escrito, y quien llega se
    /// queda dentro de un shell de Grupos que ninguna preferencia sostiene.
    @Test("MUTACIÓN (c): `completeSetup` aborta si el alta no escribió")
    func completeSetupHonoursTheWriteVerdict() throws {
        let code = try Self.code("Yala/Services/Groups/GroupsOrganizerOnboarding.swift")
        #expect(code.contains("guard writePreferences("), """
            `completeSetup` ignora el resultado del alta: seguiría sembrando categorías y aterrizando en \
            el tab Grupos sin ninguna preferencia detrás.
            """)
    }

    @Test("la puerta no monta un `.alert(` — el pin de W1 lo prohíbe en el container")
    func gateIsAScreenAndNeverAnAlert() throws {
        let container = try Self.code("Yala/App/Views/Onboarding/WelcomeFlowContainer.swift")
        #expect(!container.contains(".alert("), """
            `WelcomeHeroReentryTests` prohíbe `.alert(` en este fichero por source-scan, y además un alert
            para la puerta cerrada sería un camino muerto en un flujo que el spec exige que no los tenga.
            """)
        // El `case` lleva payload desde 2026-09-11: el propósito viaja DENTRO del step para que ningún
        // productor pueda heredar el del uso anterior.
        #expect(container.contains("case .groupsGate(let purpose):"),
                "la puerta es un STEP del container, no una presentación del anchor de ContentView")
    }
}

/// **El «Atrás» de cada sub-flow del Welcome vuelve al step del que SALIÓ.**
///
/// `InviteRecoveryView` (pegar el enlace) usaba el helper compartido con `WelcomeRestoreView`, que
/// fuerza `.chooser` — el chooser de nivel 1, «¿qué quieres hacer en Yala?». Para `WelcomeRestoreView`
/// es correcto (de ahí viene); para quien llegó con un enlace es un nivel de más: al volver tenía que
/// re-elegir «Vengo por un grupo» antes de poder reintentar. Su hermano `returnToGroupsChooser` ya
/// resolvía lo mismo bien, y su comentario explica por qué importa.
///
/// El pin es un source-scan porque los dos lados son callbacks de vistas SwiftUI: lo que decide es qué
/// step se pasa en cada callback, y eso no se puede afirmar desde un unit test de otra forma.
@Suite("Welcome · el «Atrás» de cada sub-flow vuelve a su sitio (source-scan)")
struct WelcomeBackDestinationTests {

    private static func contentView() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/Groups/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(
            contentsOf: root.appendingPathComponent("Yala/App/ContentView.swift"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo entre llaves balanceadas desde un marcador. Copia del helper de la suite de arriba —son
    /// `private static` de otro tipo— y hace falta desde el 2026-09-14: `welcomeRestoreCover` pasó a
    /// tener DOS llamadas a `returnToWelcomeChooser` con el mismo binding, así que un `contains` sobre el
    /// fichero ya no identifica cuál de las dos lo cumple.
    private static func bodyOf(_ marker: String, in source: String) -> String? {
        guard let start = source.range(of: marker) else { return nil }
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

    @Test("el helper exige el step y no lo asume")
    func helperTakesAnExplicitStep() throws {
        let src = try Self.contentView()
        #expect(src.contains("returnToWelcomeChooser(dismissing flag: Binding<Bool>, step: WelcomeFlowStep)"), """
            El helper volvió a decidir el destino por su cuenta. Sus dos llamadores vienen de sitios \
            distintos: un default los iguala otra vez en silencio.
            """)
        #expect(!src.contains("step: WelcomeFlowStep = "), """
            Un valor por defecto en el `step` reintroduce el bug: el llamador que no lo piense vuelve \
            a mandar al invitado un nivel por encima de donde estaba.
            """)
    }

    @Test("pegar-el-enlace vuelve al sub-step de Grupos; restaurar vuelve al chooser")
    func eachCallerReturnsWhereItCameFrom() throws {
        let src = try Self.contentView()
        #expect(src.contains("returnToWelcomeChooser(dismissing: $showInviteRecovery, step: .groupsChooser)"), """
            El «Atrás» de `InviteRecoveryView` volvió a subir al chooser de nivel 1.
            """)
        // **Acotado al `onBack:`, y desde el 2026-09-14 hace falta.** `WelcomeRestoreView` tiene ahora DOS
        // llamadas a este helper con el mismo binding: el «Atrás» (aquí) y el «Empezar desde cero», que
        // desde ese día entra a `.privateICloudGate`. Un `contains` sobre el fichero entero deja de
        // identificar CUÁL de los dos lo cumple: con los destinos intercambiados —el «Atrás» a la puerta
        // y «Empezar desde cero» al chooser— el literal sigue apareciendo y el swap pasa. Es el molde de
        // `expectAction` de `WelcomePrivateICloudGateWiringTests`, por el mismo motivo.
        // Se acota primero al cover —`onBack: {` aparece en casi todas las vistas del Welcome y
        // `range(of:)` se queda con la primera— y solo dentro de él se busca el callback.
        let cover = try #require(Self.bodyOf("private var welcomeRestoreCover: some View {", in: src),
                                 "no está `welcomeRestoreCover`")
        let back = try #require(Self.bodyOf("onBack: {", in: cover), "no está el `onBack:` del restore")
        #expect(back.contains("returnToWelcomeChooser(dismissing: $showWelcomeRestore, step: .chooser)"), """
            `WelcomeRestoreView` sí viene del chooser de nivel 1 — su destino no cambia.
            Cuerpo leído: \(back)
            """)
    }
}
