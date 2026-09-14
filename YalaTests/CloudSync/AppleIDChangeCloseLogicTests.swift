//
//  AppleIDChangeCloseLogicTests.swift
//  YalaTests
//
//  El predicado del cierre de la sesión privada por cambio de Apple ID
//  (`apple-id-change-should-close-the-private-session`, ADR 2026-09-09 §1).
//
//  **Qué mide esta suite, y por qué la mayoría de los casos son NEGATIVOS.** El error caro de este
//  predicado es el `true`: cierra una sesión y borra la copia local del store personal. Un test que
//  solo comprobara «cuando la identidad cambia, cierra» dejaría sin red las cinco formas de cerrar
//  cuando no tocaba, que son las que destruyen datos. Cada caso negativo invierte UN término y deja
//  los demás en la celda que SÍ cerraría, para que el rojo señale al término y no al escenario.
//

import Foundation
import Testing

@testable import Yala

@Suite("Apple ID cambiado · cierre de la sesión privada")
struct AppleIDChangeCloseLogicTests {

    /// La celda que SÍ cierra, para que cada caso negativo se escriba como «ésta, con un término
    /// cambiado». Sin este helper cada test elegiría sus propios valores y un negativo podría estar
    /// pasando por un término distinto del que dice medir.
    private func decide(confirmedPrivateSession: Bool = true,
                        groupsOnlySessionArmed: Bool = false,
                        storageMode: StorageMode = .icloud,
                        witness: String? = "_cuenta-vieja",
                        currentIdentity: String? = "_cuenta-nueva") -> AppleIDChangeCloseLogic.Verdict {
        AppleIDChangeCloseLogic.decide(confirmedPrivateSession: confirmedPrivateSession,
                                       groupsOnlySessionArmed: groupsOnlySessionArmed,
                                       storageMode: storageMode,
                                       witness: witness,
                                       currentIdentity: currentIdentity)
    }

    // MARK: - El caso que cierra

    @Test("Sesión privada confirmada + identidad distinta ⇒ se ofrece cerrar")
    func identidadDistinta_ofreceCerrar() {
        #expect(decide() == .offerClose)
    }

    @Test("La misma identidad NO cierra")
    func mismaIdentidad_noCierra() {
        #expect(decide(witness: "_misma", currentIdentity: "_misma") == .ignore)
    }

    // MARK: - Los cinco negativos, un término cada uno

    @Test("Sin sesión privada CONFIRMADA no cierra — la lectura es la estricta, no la ancha")
    func sinSesionPrivadaConfirmada_noCierra() {
        // `PrivateSessionMark.confirmedPrivateSession` devuelve `false` cuando la marca está AUSENTE,
        // que es el estado de todo el parque el día que este código se estrena. Con la lectura ancha
        // (`hasPrivateSession`, ausente ⇒ `true`) esos teléfonos se borrarían solos.
        #expect(decide(confirmedPrivateSession: false) == .ignore)
    }

    @Test("Una sesión solo-grupos NO recibe ni el aviso ni el cierre")
    func soloGrupos_noCierra() {
        // Criterio explícito del ticket. Su store personal está vacío a propósito y su vida vive en la
        // cuenta de Yala, que no es del Apple ID del teléfono: el aviso le propondría borrar algo que
        // no es suyo.
        #expect(decide(groupsOnlySessionArmed: true) == .ignore)
    }

    @Test("En modo nube lo personal no es del Apple ID: no cierra")
    func modoNube_noCierra() {
        #expect(decide(storageMode: .cloud) == .ignore)
    }

    @Test("Si CloudKit no contesta, NO se concluye que cambió")
    func sinRespuestaDeCloudKit_noCierra() {
        // `nil` = sin red, sin cuenta, `notAuthenticated`, `managedAccountRestricted`. No saber quién
        // es la cuenta de ahora no es saber que es otra. Falla CERRADO.
        #expect(decide(currentIdentity: nil) == .ignore)
        // Y una respuesta vacía es lo mismo que ninguna: un `recordName` en blanco no identifica a nadie.
        #expect(decide(currentIdentity: "") == .ignore)
    }

    @Test("Sin testigo previo se SIEMBRA, nunca se cierra")
    func sinTestigo_siembra() {
        // Es el estado del parque entero en el primer arranque con este código, y de toda instalación
        // nueva. Una marca ausente no es prueba de un cambio.
        #expect(decide(witness: nil) == .seedWitness)
        #expect(decide(witness: "") == .seedWitness)
    }

    @Test("Sin testigo Y sin respuesta de CloudKit no se siembra nada")
    func sinTestigoNiRespuesta_ignora() {
        // El orden de los dos guards importa: si `.seedWitness` se decidiera antes de comprobar la
        // respuesta, este caso escribiría un testigo vacío que después se leería como «nunca sembrado»
        // — o peor, si el llamador no filtrara el `nil`, un testigo en blanco permanente.
        #expect(decide(witness: nil, currentIdentity: nil) == .ignore)
    }

    @Test("Una celda que NO participa tampoco siembra testigo")
    func celdaQueNoParticipa_noSiembra() {
        // El orden de los guards es load-bearing en las DOS direcciones, y el caso de arriba solo fija
        // una: si el guard del testigo subiera por encima de `participates`, una sesión solo-grupos —o
        // una en la nube— sembraría un testigo que describe a nadie, y a partir de ahí participaría con
        // un testigo que no se corresponde con su vida.
        #expect(decide(confirmedPrivateSession: false, witness: nil) == .ignore)
        #expect(decide(groupsOnlySessionArmed: true, witness: nil) == .ignore)
        #expect(decide(storageMode: .cloud, witness: nil) == .ignore)
    }

    // MARK: - La mitad local, que es la que evita la ida a la red

    @Test("`participates` es la mitad local del MISMO predicado, no una copia")
    func participatesEsElMismoCriterio() {
        // Lo que este caso protege es el modo de fallo de un pre-filtro duplicado: si `participates`
        // tuviera su propia copia de la condición, invertir un término en `decide` dejaría el filtro
        // intacto y el mutante saldría VERDE. Aquí se comprueba que las dos caras contestan lo mismo
        // en las cuatro celdas que deciden si hay viaje a CloudKit.
        for confirmed in [true, false] {
            for groupsOnly in [true, false] {
                for mode in StorageMode.allCases {
                    let participa = AppleIDChangeCloseLogic.participates(
                        confirmedPrivateSession: confirmed,
                        groupsOnlySessionArmed: groupsOnly,
                        storageMode: mode)
                    let veredicto = decide(confirmedPrivateSession: confirmed,
                                           groupsOnlySessionArmed: groupsOnly,
                                           storageMode: mode)
                    // Con una identidad válida y distinta del testigo, «participa» y «cierra» tienen
                    // que coincidir: no hay ninguna celda que participe y no llegue a decidir.
                    #expect(participa == (veredicto == .offerClose),
                            "confirmed=\(confirmed) groupsOnly=\(groupsOnly) mode=\(mode)")
                }
            }
        }
    }

    @Test("La celda que participa es exactamente UNA de las ocho")
    func soloUnaCeldaParticipa() {
        var participan = 0
        for confirmed in [true, false] {
            for groupsOnly in [true, false] {
                for mode in StorageMode.allCases where AppleIDChangeCloseLogic.participates(
                    confirmedPrivateSession: confirmed,
                    groupsOnlySessionArmed: groupsOnly,
                    storageMode: mode) {
                    participan += 1
                }
            }
        }
        // Un término que se relaje —quitar el guard de solo-grupos, aceptar `.cloud`— sube este número.
        // El conteo es la red que un `#expect` por celda no da: caza el término que alguien AÑADA a la
        // celda equivocada tanto como el que quite. Recorre `allCases` y no un array a mano: con la
        // lista escrita, un modo de almacenamiento nuevo quedaría sin cubrir y la frase «de las ocho»
        // sería falsa sin que nada lo dijera.
        #expect(participan == 1)
        #expect(StorageMode.allCases.count == 2, "si aparece un modo nuevo, decide qué hace aquí")
    }
}

// `.serialized` NO es decorado: los casos de abajo escriben `identityFetcher`, que es una global
// estática (`nonisolated(unsafe)`), y en paralelo se pisan entre sí. Es la regla de `.claude/rules/
// testing.md`: nunca tocar un singleton sin serializar y sin reponerlo.
@Suite("Testigo del Apple ID de la sesión privada", .serialized)
struct PrivateSessionAppleIDWitnessTests {

    /// `UUID` y no `#function`: es lo que prescribe `.claude/rules/testing.md`. Con un nombre
    /// determinista el dominio queda escrito en disco entre corridas, y los dos hosts del scheme
    /// comparten prefs.
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test("Ausente ⇒ nil; adoptado ⇒ se lee; limpiado ⇒ vuelve a nil")
    func cicloDeVida() {
        let d = makeDefaults()
        #expect(PrivateSessionAppleIDWitness.witness(d) == nil)
        PrivateSessionAppleIDWitness.adopt("_abc123", d)
        #expect(PrivateSessionAppleIDWitness.witness(d) == "_abc123")
        PrivateSessionAppleIDWitness.clear(d)
        #expect(PrivateSessionAppleIDWitness.witness(d) == nil)
    }

    @Test("Un testigo VACÍO no se escribe")
    func vacioNoSeEscribe() {
        // Escribirlo dejaría una key presente que miente sobre lo que se hizo: `witness()` la leería
        // como ausente (y volvería a sembrar), pero cualquier inspección de las prefs vería la key.
        let d = makeDefaults()
        PrivateSessionAppleIDWitness.adopt("", d)
        #expect(d.object(forKey: PrivateSessionAppleIDWitness.userDefaultsKey) == nil)
    }

    @Test("La key lleva el prefijo que el barrido de preferencias excluye")
    func prefijoCloudSync() {
        // «Vaciar datos» no cambia de quién es el teléfono, así que el testigo tiene que sobrevivirle
        // — igual que el eje 1. `DataWipeService.removeUserPreferenceKeys` excluye `cloudSync.*`, y
        // por eso el único borrador es `performSignOutWipeIfArmed`. Si alguien renombra la key sin ese
        // prefijo, el testigo moriría en cada vaciado y el arranque siguiente volvería a sembrar,
        // dejando ciega la detección para siempre.
        #expect(PrivateSessionAppleIDWitness.userDefaultsKey.hasPrefix("cloudSync."))
    }

    @Test("Un fetch que CONTESTA devuelve su identidad tal cual")
    func fetchQueContesta() async {
        // El control positivo, y sin él los dos casos de abajo no distinguen nada: los dos esperan
        // `nil`, así que cada uno pasaría con el fetcher del otro — y también con un `currentIdentity`
        // que devolviera `nil` siempre, que es el mutante que de verdad importa.
        PrivateSessionAppleIDWitness.identityFetcher = { "_cuenta-real" }
        defer { PrivateSessionAppleIDWitness._testReset() }
        #expect(await PrivateSessionAppleIDWitness.currentIdentity() == "_cuenta-real")
    }

    @Test("Un fetch que lanza devuelve nil, no un identificador inventado")
    func fetchQueLanza() async {
        struct Boom: Error {}
        PrivateSessionAppleIDWitness.identityFetcher = { throw Boom() }
        defer { PrivateSessionAppleIDWitness._testReset() }
        #expect(await PrivateSessionAppleIDWitness.currentIdentity() == nil)
    }

    @Test("Un fetch que devuelve vacío se trata como «no se pudo preguntar»")
    func fetchVacio() async {
        PrivateSessionAppleIDWitness.identityFetcher = { "" }
        defer { PrivateSessionAppleIDWitness._testReset() }
        #expect(await PrivateSessionAppleIDWitness.currentIdentity() == nil)
    }

    @Test("`_testReset` devuelve el seam a producción")
    func testResetRepone() async {
        // Si `_testReset` no repusiera el fetcher, el caso de arriba dejaría una identidad falsa puesta
        // para todo el resto de la corrida — y con la suite serializada eso contamina en orden, que es
        // la peor forma de contaminar: parece determinista.
        PrivateSessionAppleIDWitness.identityFetcher = { "_pegado" }
        PrivateSessionAppleIDWitness._testReset()
        // En el simulador no hay cuenta de iCloud, así que el fetcher de producción falla y contesta
        // `nil`. Lo que se mide es que YA NO devuelve `_pegado`.
        #expect(await PrivateSessionAppleIDWitness.currentIdentity() != "_pegado")
    }
}

// MARK: - Cableado (source-scan)

/// **Las cuatro líneas que no tiene ningún test de comportamiento, y las cuatro destruyen o ciegan.**
///
/// El cableado del cierre vive tras `guard !SwiftDataConfiguration.isRunningTests, !UITestHooks.isActive`
/// —y tiene que vivir ahí: un host de test no debe salir a CloudKit ni armar un boot-wipe real— así que
/// es **inalcanzable desde cualquier suite**. Cuando el source-scan es la única red posible, la regla del
/// repo es fijar el cuerpo entero y no dos literales sueltos (`.claude/rules/testing.md`). Aquí se fija
/// cada decisión por separado, con el mensaje diciendo qué se rompe si cae.
@Suite("Apple ID cambiado · cableado")
struct AppleIDChangeWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Sin comentarios de línea: documentar el invariante que el scan mide no puede romperlo.
    private static func code(_ path: String) throws -> String {
        let raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        return raw.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El cuerpo de una función, contando llaves. Molde de `PersonalMountWitnessTests`.
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

    @Test("MUTACIÓN: el cableado lee la lectura ESTRICTA del eje, en los DOS instantes")
    func elCableadoLeeLaEstricta() throws {
        let src = try Self.code("Yala/App/AppBootstrapper.swift")
        let fn = try Self.body(of: "func checkForAppleIDChange(trigger: String) {", in: src)

        // Dos: el pre-filtro y la re-lectura tras el `await`. Las dos tienen que ser la estricta.
        #expect(fn.components(separatedBy: "PrivateSessionMark.confirmedPrivateSession()").count - 1 == 2, """
            el cierre por cambio de Apple ID dejó de leer `confirmedPrivateSession` en sus dos
            instantes. Con `hasPrivateSession` —ausente ⇒ `true`— un dispositivo cuya marca aún no se ha
            escrito se ofrece a sí mismo cerrar la sesión y borrar su copia local.
            """)
        #expect(!fn.contains("PrivateSessionMark.hasPrivateSession()"), """
            alguien cambió la lectura del eje a la ANCHA en el camino que BORRA. Es el mutante literal
            que `PrivateSessionMark` describe en su docblock: hacia `true` se destruye.
            """)
    }

    @Test("MUTACIÓN: los términos se RE-LEEN después del `await`, no se capturan antes")
    func losTerminosSeReleenTrasElAwait() throws {
        let src = try Self.code("Yala/App/AppBootstrapper.swift")
        let fn = try Self.body(of: "func checkForAppleIDChange(trigger: String) {", in: src)
        let awaitIdx = try #require(fn.range(of: "await PrivateSessionAppleIDWitness.currentIdentity()"))
        let despues = String(fn[awaitIdx.upperBound...])

        // Entre el disparo y la respuesta de CloudKit cabe un cierre de sesión entero: decidir un
        // borrado con el snapshot de antes del `await` es exactamente el bug que esta re-lectura evita.
        #expect(despues.contains("PrivateSessionMark.confirmedPrivateSession()"), "el eje")
        #expect(despues.contains("StorageModePersistence.isGroupsOnlyNeutralMountArmed()"), "solo-grupos")
        #expect(despues.contains("CloudSyncFlags.storageMode"), "el modo")
        #expect(despues.contains("PrivateSessionAppleIDWitness.witness()"), "el testigo")
    }

    @Test("MUTACIÓN: `.seedWitness` SIEMBRA — sin eso la detección queda ciega para siempre")
    func elSeedSiembra() throws {
        let src = try Self.code("Yala/App/AppBootstrapper.swift")
        let fn = try Self.body(of: "func checkForAppleIDChange(trigger: String) {", in: src)
        #expect(fn.contains("case .seedWitness:"), "la rama de siembra desapareció")
        #expect(fn.contains("PrivateSessionAppleIDWitness.adopt(identity)"), """
            el veredicto `.seedWitness` dejó de escribir el testigo. Sin testigo, `decide` devuelve
            `.seedWitness` en cada arranque y `.offerClose` no es alcanzable NUNCA: el cierre por cambio
            de Apple ID deja de existir, en silencio y sin un solo rojo de comportamiento.
            """)
    }

    @Test("MUTACIÓN: el aviso NO cuelga de `handleBecameActive`")
    func noCuelgaDelForeground() throws {
        let src = try Self.code("Yala/App/AppBootstrapper.swift")
        let fn = try Self.body(of: "func handleBecameActive(context: ModelContext) {", in: src)
        // Es el tercer criterio del ticket, y aquí se cumple por CONSTRUCCIÓN y no por un guard: si
        // alguien lo cuelga del foreground, vuelven la ida a CloudKit por cada vuelta a primer plano y
        // el riesgo de aviso repetido que el ticket pide evitar.
        #expect(!fn.contains("checkForAppleIDChange"), """
            la comprobación del Apple ID se colgó de la vuelta a primer plano. El ticket pide
            explícitamente que `handleBecameActive` no dispare el cierre repetidamente.
            """)
    }

    @Test("MUTACIÓN: el aviso del espejo tardío se calla mientras el del Apple ID decide")
    func elMismatchSeCallaMientrasSeDecide() throws {
        let src = try Self.code("Yala/App/AppBootstrapper.swift")
        let fn = try Self.body(of: "private func checkForICloudMismatch() {", in: src)
        #expect(fn.contains("guard !appleIDChangeOffered, !appleIDChangeCheckInFlight else { return }"), """
            `checkForICloudMismatch` volvió a emitir durante la ventana del cambio de Apple ID. Es la
            mitad que la regla de supersesión NO puede cubrir —solo mira la cola—, y su consecuencia no
            es solo estética: su copy dice «cierra y vuelve a abrir la app para sincronizar tus datos»,
            que con la cuenta cambiada sincronizaría el corpus del Apple ID anterior contra el NUEVO.
            """)
    }

    @Test("MUTACIÓN: el testigo muere DENTRO del escritor del eje, no en sus call-sites")
    func elTestigoMuereConLaMarca() throws {
        let src = try Self.code("Yala/Services/CloudSync/PrivateSessionMark.swift")
        let clear = try Self.body(of: "static func clear(_ defaults: UserDefaults = .standard) {", in: src)
        let set = try Self.body(of: "static func set(_ value: Bool, _ defaults: UserDefaults = .standard) {", in: src)
        #expect(clear.contains("PrivateSessionAppleIDWitness.clear(defaults)"), """
            `PrivateSessionMark.clear` dejó de llevarse el testigo del Apple ID. El eje muere en DOS
            sitios —el boot-wipe y el relevo de humano de «Empiezo de cero»— y colgar el borrado de los
            call-sites deja el testigo del dueño ANTERIOR vivo: la persona siguiente termina su
            onboarding y la app le ofrece cerrar la sesión y borrarle SUS datos.
            """)
        #expect(set.contains("if !value { PrivateSessionAppleIDWitness.clear(defaults) }"), """
            apagar la marca dejó de llevarse el testigo. Las dos puertas de entrada por grupo la apagan,
            y tras activar Yala completo la marca vuelve a `true` con el testigo viejo puesto.
            """)
    }
}
