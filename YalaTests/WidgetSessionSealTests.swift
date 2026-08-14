//
//  WidgetSessionSealTests.swift
//  YalaTests
//
//  El sello de identidad del snapshot del widget, la puerta de `updateCache` y el ORDEN de la frontera
//  de salida.
//
//  ## Por qué hay comportamiento Y source-scan, y cuál carga el peso en cada mitad
//
//  El lector real (`WidgetDataService.loadSnapshot`) vive SOLO en `YalaWidgetsExtension` ⇒ `@testable
//  import Yala` no lo alcanza (lo dice por escrito `WidgetDataServiceIntervalTests`, que por eso replica
//  su lógica). Aquí NO se replica nada: `WidgetSessionSeal` es un fichero de `Yala/` añadido al target del
//  widget por el exception set del `.pbxproj`, así que estos tests ejercitan **el mismo símbolo** que
//  corre en la extensión. Lo que el test no puede ver es si el lector lo LLAMA — eso va por escáner, y es
//  la mitad que caza la regresión de cableado.
//
//  ## Lo que se midió antes de escribir esto (2026-08-14, árbol `9abdbbe2`)
//
//  El ticket lo pedía como fix de un bug SERIO y la medición lo dejó en endurecimiento más un hueco de
//  segundos. Queda aquí para que nadie repita el diagnóstico:
//   · la SALIDA ya limpiaba in-session (`CloudSessionSignOut.clearLocalSurfacesForArmedWipe`), y es la
//     única salida posible desde secundaria — la precedencia de `CloudSignOutFlowLogic` es CONGELADA y el
//     borrado de cuenta está bloqueado ahí (`AccountDeletionService.canDelete`);
//   · la ventana post-clear NO es alcanzable por BGTask: `RelaunchNetLogic.shouldExitOnBackground` mata el
//     proceso al ir a background en `.awaitingRelaunch`;
//   · el hueco REAL era la ENTRADA, cuya purga es un hook PRE-MOUNT ⇒ entre `confirmSecondaryEntry` y el
//     arranque siguiente el widget seguía con los saldos del DUEÑO, con el teléfono en manos de la visita.
//   · y el conteo de escritores del snapshot son **48**, no ~13 como decía el ticket.
//
//  ## Mutantes verificados a exit 65 (medidos, no inferidos)
//
//   1. quitar la comparación del LECTOR (`loadSnapshot`)            → 4 rojos
//   2. cortocircuitar el SELLADO a `sessionSeal: nil`               → 5 rojos
//   3. mover el republish ANTES de `SecondarySessionStore.clear`    → 3 rojos
//   4. quitar la PUERTA de `updateCache`                            → 3 rojos
//   5. quitar el `clearCache()` in-session de la ENTRADA            → 3 rojos
//   6. el default del seam a `{ _ in }`                             → 1 rojo, **solo el escáner**
//
//  El (2) es la razón de que exista `elEscritor_sellaDesdeElDescriptorVivo`: en la primera versión de este
//  fichero SOBREVIVÍA en verde con las otras 18 aserciones pasando — el snapshot de la invitada habría
//  quedado marcado como del dueño y el lector lo habría servido para siempre. Y el (6) es la razón de que
//  exista el escáner de cableado: cae él solo, con los CINCO tests de comportamiento en VERDE (medido),
//  porque cada uno inyecta su propia closure y ninguno ve el default de producción.
//

import Foundation
import Testing

@testable import Yala

// MARK: - El sello (símbolo compartido con el lector real)

@Suite("Widget · sello de sesión")
struct WidgetSessionSealTests {

    /// EL GATE DEL TICKET: escribir el snapshot con la identidad de la INVITADA y leerlo con la del
    /// DUEÑO no devuelve datos. Es la aserción que carga el peso de todo el fichero.
    @Test func selloDeLaInvitada_leidoPorElDueno_noCasa() {
        let deLaInvitada = WidgetSessionSeal.seal(forUserID: "sub-de-la-invitada")
        let delDueno = WidgetSessionSeal.seal(forUserID: nil)

        #expect(deLaInvitada != nil, "la sesión secundaria tiene que producir sello")
        #expect(delDueno == nil, "la sesión del dueño es la AUSENCIA de sello")
        #expect(!WidgetSessionSeal.isFresh(snapshotSeal: deLaInvitada, activeSeal: delDueno))
    }

    /// La otra dirección, que también importa: el dueño no debe ver el widget del que ya no está, pero
    /// tampoco puede perder el suyo. Sin esta mitad, «devolver siempre nil» pasaría el test de arriba.
    @Test func selloDelDueno_conSesionDelDueno_casa() {
        #expect(WidgetSessionSeal.isFresh(snapshotSeal: nil, activeSeal: nil))
    }

    /// Y la simétrica: la INVITADA tiene que seguir viendo lo suyo mientras dura la visita — es la
    /// decisión del owner (2026-08-13), no un efecto lateral.
    @Test func selloDeLaInvitada_conSuPropiaSesion_casa() {
        let suyo = WidgetSessionSeal.seal(forUserID: "sub-de-la-invitada")
        #expect(WidgetSessionSeal.isFresh(snapshotSeal: suyo, activeSeal: suyo))
    }

    /// Dos visitas distintas no se heredan el widget. El slot M1 es de una cuenta a la vez, pero el
    /// snapshot de la anterior puede seguir en disco cuando entra la siguiente.
    @Test func dosInvitadasDistintas_noCasanEntreSi() {
        let a = WidgetSessionSeal.seal(forUserID: "sub-a")
        let b = WidgetSessionSeal.seal(forUserID: "sub-b")
        #expect(a != b)
        #expect(!WidgetSessionSeal.isFresh(snapshotSeal: a, activeSeal: b))
    }

    /// Un string de cero bytes NO es una identidad. Es la trampa de `KeychainService.getString`, que
    /// devuelve `""` y no `nil`: sin el `!isEmpty`, un `""` colaría como sello distinto de `nil` y el
    /// DUEÑO dejaría de ver sus propios datos.
    @Test func stringVacio_esSesionDelDueno() {
        #expect(WidgetSessionSeal.seal(forUserID: "") == nil)

        let store = makeIsolatedDefaults(prefix: "test.widgetseal.vacio")
        store.set("", forKey: WidgetSessionSeal.activeSealKey)
        #expect(WidgetSessionSeal.activeSeal(in: store) == nil)
    }

    /// El sello es DETERMINISTA (si no, ni el propio snapshot de la visita casaría con su sesión) y no
    /// lleva el `sub` dentro: el App Group persiste en el disco del dueño hasta la purga.
    @Test func selloEsEstable_yNoContieneElSubEnClaro() {
        let sub = "3f2a1c88-0000-4444-9999-abcdefabcdef"
        let primero = WidgetSessionSeal.seal(forUserID: sub)
        let segundo = WidgetSessionSeal.seal(forUserID: sub)

        #expect(primero == segundo)
        #expect(primero?.contains(sub) == false)
        #expect(primero?.count == 16)
    }

    /// Publicar y RETIRAR, que es la operación de la frontera de salida.
    @Test func publish_escribeYRetira() {
        let store = makeIsolatedDefaults(prefix: "test.widgetseal.publish")

        WidgetSessionSeal.publish(WidgetSessionSeal.seal(forUserID: "sub-x"), in: store)
        #expect(WidgetSessionSeal.activeSeal(in: store) != nil)

        WidgetSessionSeal.publish(nil, in: store)
        #expect(store.object(forKey: WidgetSessionSeal.activeSealKey) == nil,
                "retirar tiene que dejar la key AUSENTE, no vacía")
    }

    /// El escenario COMPLETO de la salida, contado como lo vive el usuario: la visita escribió su
    /// snapshot, se fue, y su sello se retiró con el descriptor. El snapshot sigue en disco —nadie lo
    /// limpió— y aun así no se sirve. Es la propiedad que un `clearCache()` best-effort no puede dar.
    @Test func snapshotDeLaVisitaSobrevive_peroDejaDeServirse() {
        let store = makeIsolatedDefaults(prefix: "test.widgetseal.salida")
        let snapshotSeal = WidgetSessionSeal.seal(forUserID: "sub-de-la-invitada")
        WidgetSessionSeal.publish(snapshotSeal, in: store)

        // Durante la visita se sirve.
        #expect(WidgetSessionSeal.isFresh(
            snapshotSeal: snapshotSeal, activeSeal: WidgetSessionSeal.activeSeal(in: store)))

        // La frontera de salida retira el sello con el descriptor. El snapshot NO se toca.
        WidgetSessionSeal.publish(nil, in: store)

        #expect(!WidgetSessionSeal.isFresh(
            snapshotSeal: snapshotSeal, activeSeal: WidgetSessionSeal.activeSeal(in: store)))
    }

    /// Compatibilidad hacia atrás: un snapshot escrito ANTES de que el campo existiera decodifica con
    /// `sessionSeal == nil` ⇒ cuenta como del dueño, que es de quien era. Sin esto, la primera
    /// actualización dejaría a todo el parque con el widget vacío hasta reabrir la app.
    @Test func snapshotLegacySinElCampo_decodificaComoDelDueno() throws {
        // Un JSON con los campos mínimos y SIN `sessionSeal` — la forma exacta que hay hoy en los discos.
        let legacy = """
        {"lastUpdated":0,"preferredCurrencyCode":"PEN","currencyDisplayFormat":"symbol",
         "accountBalances":[],"totalBalance":0,"transactions":[],"budgets":[],"scheduledPayments":[],
         "trendData":{"dailyPoints":[],"weeklyPoints":[],"monthlyPoints":[]},
         "thisMonthSummary":{"totalIncome":0,"totalExpense":0,"netCashFlow":0,"topCategories":[],
           "topSubcategories":[],"cashFlowPoints":[]},
         "allTimeSummary":{"totalIncome":0,"totalExpense":0,"netCashFlow":0,"topCategories":[],
           "topSubcategories":[],"cashFlowPoints":[]},
         "periodSummaries":{}}
        """
        let decoded = try JSONDecoder().decode(WidgetDataSnapshot.self, from: Data(legacy.utf8))

        #expect(decoded.sessionSeal == nil)
        #expect(WidgetSessionSeal.isFresh(snapshotSeal: decoded.sessionSeal, activeSeal: nil))
    }
}

// MARK: - El ORDEN de la frontera de salida (comportamiento, vía el seam)

@Suite("Widget · sello · frontera de salida", .serialized)
struct WidgetSealBoundaryOrderTests {

    /// LA ASERCIÓN QUE CARGA EL PESO DEL ORDEN, y se puede hacer por comportamiento porque el seam
    /// recibe el `defaults`: cuando el hook llama a `republishWidgetSeal`, el DESCRIPTOR ya tiene que
    /// estar limpio. Si alguien mueve la línea por encima de `SecondarySessionStore.clear`, el republish
    /// resolvería el `sub` de la invitada y RE-PUBLICARÍA su sello sobre una sesión que ya no existe —
    /// dejando válido cualquier snapshot suyo que quedara en disco, que es exactamente lo que el lector
    /// tiene que poder rechazar.
    @Test func republish_correConElDescriptorYaLimpio() {
        let defaults = makeIsolatedDefaults(prefix: "test.widgetseal.orden")
        SecondarySessionStore.activate(userID: "sub-de-la-invitada", defaults)
        SecondarySessionStore.armWipe(defaults)

        var descriptorAlRepublicar: String?? = .none
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            purge: {},
            destroySessionDomain: { _ in },
            republishWidgetSeal: { store in
                descriptorAlRepublicar = .some(SecondarySessionStore.activeUserID(store))
            })

        #expect(descriptorAlRepublicar != .none, "el hook no llamó al republish del sello")
        #expect(descriptorAlRepublicar == .some(nil),
                "el republish corrió con el descriptor TODAVÍA vivo ⇒ re-publicaría el sello de la visita")
    }

    /// El wipe que ABORTA (el archivo base no se pudo borrar) conserva la sesión: el descriptor sigue
    /// vivo y el widget de la invitada tiene que seguir sirviéndose. Republicar ahí sería inofensivo,
    /// pero retirar el sello la dejaría sin widget con su sesión intacta.
    @Test func wipeQueAborta_noTocaElSello() {
        let defaults = makeIsolatedDefaults(prefix: "test.widgetseal.abort")
        SecondarySessionStore.activate(userID: "sub-de-la-invitada", defaults)
        SecondarySessionStore.armWipe(defaults)

        var republicado = false
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in false },
            purge: {},
            destroySessionDomain: { _ in },
            republishWidgetSeal: { _ in republicado = true })

        #expect(!republicado)
        #expect(SecondarySessionStore.activeUserID(defaults) == "sub-de-la-invitada")
    }

    /// La ENTRADA publica el sello, y FUERA del guard one-shot: la key vive en el App Group, que otras
    /// limpiezas barren, así que se re-publica en CADA arranque de la sesión. Colgarla del marker
    /// dejaría a la invitada sin widget propio en cuanto algo se llevara la key una vez.
    @Test func entrada_republicaElSelloAunConLaPurgaYaHecha() {
        let defaults = makeIsolatedDefaults(prefix: "test.widgetseal.entrada")
        SecondarySessionStore.activate(userID: "sub-de-la-invitada", defaults)
        SecondarySessionStore.markEntryPurgeDone(defaults)

        var purgado = false
        var selloDeLaSesion: String??  = .none
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults,
            purge: { purgado = true },
            cancelNotifications: {},
            seedSessionDomain: { _, _ in },
            republishWidgetSeal: { store in
                selloDeLaSesion = .some(SecondarySessionStore.activeUserID(store))
            })

        #expect(!purgado, "el one-shot ya estaba marcado — la purga no debe repetirse")
        #expect(selloDeLaSesion == .some("sub-de-la-invitada"),
                "el republish tiene que correr igualmente: va FUERA del guard one-shot")
    }

    /// Sin sesión secundaria el hook de entrada no toca nada: el dueño no tiene sello que publicar.
    @Test func entrada_sinSesionSecundaria_noPublicaNada() {
        let defaults = makeIsolatedDefaults(prefix: "test.widgetseal.sinsesion")

        var republicado = false
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults,
            purge: {},
            cancelNotifications: {},
            seedSessionDomain: { _, _ in },
            republishWidgetSeal: { _ in republicado = true })

        #expect(!republicado)
    }
}

// MARK: - Cableado (source-scan)

@Suite("Widget · sello · cableado de producción (source-scan)")
struct WidgetSessionSealWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El fuente SIN las líneas que son comentario entero. Molde `AttestWiringTests`, y aquí NO es
    /// cosmética: los scans de abajo CUENTAN ocurrencias de símbolos que los docblocks de este mismo
    /// trabajo nombran a propósito — documentar el invariante lo pondría en rojo sin que producción
    /// cambiara. Los comentarios de final de línea se conservan (recortar desde el primer `//` destrozaría
    /// cualquier URL).
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// LA MITAD QUE NINGÚN TEST DE COMPORTAMIENTO PUEDE CUBRIR: que el LECTOR real llame al sello.
    /// `WidgetDataService` vive solo en `YalaWidgetsExtension` ⇒ inalcanzable desde este target. Sin este
    /// escáner, borrar el guard de `loadSnapshot` deja los diez tests de arriba en VERDE y el widget
    /// vuelve a servir el snapshot de la visita.
    @Test func lectorDelWidget_comparaElSello() throws {
        let src = Self.codeOnly(try Self.source("YalaWidgets/Services/WidgetDataService.swift"))

        #expect(src.contains("WidgetSessionSeal.isFresh("),
                "`loadSnapshot` dejó de comparar el sello — el widget sirve snapshots de otra sesión")
        #expect(src.contains("WidgetSessionSeal.activeSeal(in: defaults)"))
        #expect(src.contains("let sessionSeal: String?"),
                "el campo del snapshot desapareció del lector")
    }

    /// LA TERCERA PATA, y la que faltaba: que el ESCRITOR selle de verdad. Se descubrió mutando —
    /// sustituir el sellado por `sessionSeal: nil` dejaba las otras 18 aserciones en VERDE, y con eso el
    /// snapshot de la invitada quedaría marcado como del DUEÑO y el lector lo serviría para siempre. Es el
    /// mutante exacto que el criterio de hecho del ticket exige en exit 65.
    ///
    /// Va por escáner y no por comportamiento porque `buildSnapshot` es privada y resuelve el descriptor
    /// por el default `.standard` de `activeUserID()`: ejercitarla de verdad exigiría contaminar el
    /// `UserDefaults` del host o abrir un seam de producción que solo existiría para esto. Lo que se fija
    /// es que el sellado use la MISMA expresión que `republishActiveSeal`, que sí está probada por
    /// comportamiento en la suite de fronteras — si las dos divergen, el sello escrito y el publicado
    /// dejan de compararse entre sí.
    @Test func elEscritor_sellaDesdeElDescriptorVivo() throws {
        let src = Self.codeOnly(try Self.source("Yala/Services/WidgetDataCache.swift"))
        let expresion = "WidgetSessionSeal.seal(forUserID: SecondarySessionStore.activeUserID())"

        #expect(src.contains("sessionSeal: \(expresion)"),
                "`buildSnapshot` dejó de sellar desde el descriptor vivo")
        #expect(!src.contains("sessionSeal: nil"),
                "el sellado se cortocircuitó a nil — todo snapshot pasaría por el del dueño")
        // El sellado y el publicado tienen que salir de la misma expresión: uno escribe el sello DENTRO
        // del snapshot y el otro el ACTIVO del App Group, y el lector los compara. Dos formas distintas de
        // resolver la identidad harían que no casaran nunca, o que casaran cuando no deben.
        #expect(src.components(separatedBy: expresion).count - 1 == 1)
        #expect(src.contains("WidgetSessionSeal.seal(forUserID: SecondarySessionStore.activeUserID(defaults))"),
                "`republishActiveSeal` dejó de resolver el sello por la misma vía que el escritor")
    }

    /// Las DOS structs son copias manuales una de otra (el target del widget no comparte el fichero) y
    /// divergen ya en dos campos por compat. El sello tiene que estar en las dos o el decode del lector
    /// ignora lo que la app escribe, en silencio y sin romper nada visible.
    @Test func lasDosCopiasDelSnapshot_declaranElSello() throws {
        let app = Self.codeOnly(try Self.source("Yala/Services/WidgetDataCache.swift"))
        let widget = Self.codeOnly(try Self.source("YalaWidgets/Services/WidgetDataService.swift"))

        #expect(app.contains("let sessionSeal: String?"))
        #expect(widget.contains("let sessionSeal: String?"))
    }

    /// LA PUERTA, y su CONTEO. `updateCache` es un choke-point con 48 call-sites de producción en 18
    /// ficheros: el guard vive en la puerta justamente porque gatear 48 sitios es una lista que envejece.
    /// El conteo es el anti-drift que pide el ticket — si alguien añade un escritor, este test le obliga a
    /// leer por qué el gate está donde está en vez de copiar un guard local.
    ///
    /// Si el número cambia por una razón legítima, ajústalo a conciencia.
    @Test func laPuerta_gateaLos48Escritores() throws {
        let cache = Self.codeOnly(try Self.source("Yala/Services/WidgetDataCache.swift"))

        #expect(cache.contains("guard !isWipeArmed else {"),
                "la puerta de `updateCache` desapareció")
        #expect(cache.contains(
            "StorageModePersistence.isSignOutWipeArmed() || SecondarySessionStore.isWipeArmed()"),
            "el predicado dejó de ser el espejo de `NotificationService.isPersonalWipeArmed`")

        let sources = FileManager.default.enumerator(
            at: Self.repoRoot.appendingPathComponent("Yala"), includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        var callSites = 0
        for url in sources where url.lastPathComponent != "WidgetDataCache.swift" {
            // `try` y no `try?`: un fichero ilegible bajaría el conteo y el mensaje diría «pasaron de 48 a
            // N», mandando a buscar un call-site retirado que nadie retiró. Que reviente por donde duele.
            let src = Self.codeOnly(try String(contentsOf: url, encoding: .utf8))
            callSites += src.components(separatedBy: "WidgetDataCache.updateCache(").count - 1
        }

        #expect(callSites == 48, "los escritores del snapshot pasaron de 48 a \(callSites)")
    }

    /// El predicado de la puerta es el MISMO que el del gemelo de notificaciones, literalmente. Si uno de
    /// los dos se mueve sin el otro, vuelven a existir dos respuestas para la misma pregunta — el
    /// anti-patrón que este repo lleva media docena de fixes persiguiendo.
    @Test func laPuerta_espejaAlGemeloDeNotificaciones() throws {
        let predicado = "StorageModePersistence.isSignOutWipeArmed() || SecondarySessionStore.isWipeArmed()"
        let notifs = Self.codeOnly(try Self.source("Yala/Services/NotificationService.swift"))

        #expect(notifs.contains(predicado),
                "el gemelo cambió de predicado — decide si el widget lo sigue")
    }

    /// La ENTRADA limpia in-session, que era el único hueco VIVO del ticket. No es cubrible por
    /// comportamiento: `confirmSecondaryEntry` es un método privado de una `View`.
    ///
    /// El ORDEN respecto de `activate` es lo que importa y por eso se comprueba por posición: republicar
    /// ANTES del descriptor publicaría `nil` y el primer snapshot de la invitada se serviría como si
    /// fuera del dueño.
    @Test func entradaInSession_limpiaElWidgetYPublicaTrasElDescriptor() throws {
        let src = Self.codeOnly(try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"))

        let activate = try #require(src.range(of: "activateDescriptor: { SecondarySessionStore.activate"))
        let clear = try #require(src.range(of: "WidgetDataCache.clearCache()"),
                                 "la entrada dejó de limpiar el widget in-session")
        let republish = try #require(src.range(of: "WidgetDataCache.republishActiveSeal()"))

        #expect(clear.lowerBound > activate.upperBound)
        #expect(republish.lowerBound > activate.upperBound,
                "el republish tiene que ir DESPUÉS de `activate` o publica el sello del dueño")
    }

    /// Los DOS hooks de frontera cablean el republish, y el de SALIDA va detrás del `clear`. La aserción
    /// de comportamiento de arriba ya lo prueba para la salida; esto fija que ninguno de los dos
    /// call-sites desaparezca —el de entrada no tiene guard one-shot que lo delate— y que el default del
    /// seam siga siendo el mecanismo REAL: cambiarlo por un `{ _ in }` dejaría los cinco tests de
    /// comportamiento en verde y el sello sin publicar en producción.
    @Test func losDosHooksDeFrontera_cablanElRepublish() throws {
        let src = Self.codeOnly(try Self.source("Yala/Utils/SwiftDataConfiguration.swift"))

        #expect(src.components(separatedBy: "WidgetDataCache.republishActiveSeal($0)").count - 1 == 2,
                "uno de los dos hooks M1 perdió el default REAL del seam del sello")
        #expect(src.components(separatedBy: "republishWidgetSeal(defaults)").count - 1 == 2)

        let clear = try #require(src.range(of: "SecondarySessionStore.clear(defaults)"))
        let republishSalida = try #require(src.range(of: "republishWidgetSeal(defaults)", range: clear.upperBound..<src.endIndex))
        #expect(republishSalida.lowerBound > clear.upperBound)
    }
}
