//
//  PrivateSessionMarkTests.swift
//  YalaTests / CloudSync
//
//  EL EJE 1 («¿hay sesión privada en este dispositivo?») sobre fixtures de `UserDefaults`.
//
//  **Lo que carga el peso aquí es la ASIMETRÍA de las dos lecturas ante la ausencia**, no el
//  guardar y leer. Guardar un `Bool` no se rompe solo; lo que se rompe —y en silencio— es el
//  default que alguien unifica «para simplificar». `hasPrivateSession` y `confirmedPrivateSession`
//  existen porque no hay un default que sirva para las dos preguntas: fallar a `true` conserva de
//  más (barato), y fallar a `true` en la señal de vaciado ORDENA a los demás dispositivos del Apple
//  ID vaciarse (el daño que la review del paso 9 cazó). Un test que solo mirase la marca PUESTA
//  pasaría verde con las dos lecturas colapsadas en una, que es justo la mutación que importa.
//

import Foundation
import Testing

@testable import Yala

@Suite("El eje 1: la marca de sesión privada")
struct PrivateSessionMarkTests {

    /// Suite propio por test: la marca vive en `UserDefaults` y dos tests compartiendo dominio se
    /// pisan el estado. `removePersistentDomain` se llama sobre la instancia del PROPIO suite —
    /// hacerlo desde otro dominio deja residuos (medido en este repo).
    private final class Fixture {
        let name: String
        let defaults: UserDefaults

        init() {
            name = "test.privateSessionMark.\(UUID().uuidString)"
            defaults = UserDefaults(suiteName: name)!
        }

        deinit {
            defaults.removePersistentDomain(forName: name)
        }
    }

    // MARK: - La ausencia, que es el caso que justifica el diseño

    @Test("MUTACIÓN: ante la marca AUSENTE las dos lecturas responden distinto")
    func absentMarkSplitsTheTwoReads() {
        let f = Fixture()
        let d = f.defaults

        // El control NEGATIVO va primero: si la marca ya estuviera puesta, lo de abajo no mediría
        // la ausencia sino un valor, y pasaría verde sin comprobar ningún default.
        #expect(PrivateSessionMark.raw(d) == nil, "el fixture no arranca limpio: el test no mide nada")

        #expect(PrivateSessionMark.hasPrivateSession(d) == true, """
            «¿hay vida personal que PROTEGER?» falla hacia SÍ: conservar y esperar de más es el lado
            barato. Con `false` aquí, un cierre de sesión borraría sin esperar al export de iCloud.
            """)
        #expect(PrivateSessionMark.confirmedPrivateSession(d) == false, """
            «¿puedo AFIRMAR que es privada?» falla hacia NO. Con `true` aquí, «Vaciar datos» ordenaría
            a los demás dispositivos del Apple ID vaciarse — el iPad del dueño incluido.
            """)
        #expect(PrivateSessionMark.hasPrivateSession(d) != PrivateSessionMark.confirmedPrivateSession(d),
                "las dos lecturas colapsaron en una: una de las dos direcciones de fallo se perdió")
    }

    @Test("MUTACIÓN: `raw` distingue AUSENTE de `false`")
    func rawDistinguishesAbsentFromFalse() {
        let f = Fixture()
        let d = f.defaults

        #expect(PrivateSessionMark.raw(d) == nil)
        PrivateSessionMark.set(false, d)
        #expect(PrivateSessionMark.raw(d) == false, """
            sin el guard de `object(forKey:)`, `defaults.bool` devuelve `false` para una key ausente y
            `raw` no podría distinguirlos — y con eso el backfill se creería ya hecho para siempre.
            """)
    }

    // MARK: - Con la marca puesta, las dos lecturas coinciden

    @Test("con la marca PUESTA las dos lecturas dicen lo mismo", arguments: [true, false])
    func presentMarkAgreesOnBothReads(_ value: Bool) {
        let f = Fixture()
        let d = f.defaults

        PrivateSessionMark.set(value, d)
        #expect(PrivateSessionMark.hasPrivateSession(d) == value)
        #expect(PrivateSessionMark.confirmedPrivateSession(d) == value)
    }

    @Test("`clear` devuelve el dispositivo a la ausencia, con sus dos defaults")
    func clearRestoresTheAbsence() {
        let f = Fixture()
        let d = f.defaults

        PrivateSessionMark.set(false, d)
        #expect(PrivateSessionMark.raw(d) == false)   // control positivo: había algo que borrar

        PrivateSessionMark.clear(d)
        #expect(PrivateSessionMark.raw(d) == nil)
        #expect(PrivateSessionMark.hasPrivateSession(d) == true)
        #expect(PrivateSessionMark.confirmedPrivateSession(d) == false)
    }

    // MARK: - El backfill de un arranque

    @Test("el backfill escribe la celda del parque existente")
    func backfillWritesTheLegacyCell() {
        let f = Fixture()
        let d = f.defaults

        let escribio = PrivateSessionMark.backfillIfNeeded(hasGroupsOnlyNeutralMount: false, hasCompletedOnboarding: true, d)
        #expect(escribio == true)
        #expect(PrivateSessionMark.raw(d) == true, """
            todo dispositivo con el alta completada despierta CON sesión privada: es la celda normal,
            que es casi todo el parque.
            """)
    }

    /// **La celda que el backfill NO puede confundir, y que costó un hallazgo de review.**
    ///
    /// La primera versión escribía `true` sin preguntar nada, apoyada en que «no hay usuarios
    /// solo-grupos». La medición lo refutó: Grupos está compilado en `true` y su percent de producción
    /// en 100, y un alta solo-grupos deja `hasCompletedOnboarding = true` ⇒ cumplía el gate. A ese
    /// teléfono se le habría escrito «tiene vida personal» de forma permanente: app entera sobre un
    /// store vacío, el cierre de sesión esperando un export de iCloud que no existe, y «Vaciar datos»
    /// ordenando el vaciado a los demás dispositivos del Apple ID.
    @Test("MUTACIÓN: un teléfono solo-grupos NO estrena la marca en `true`")
    func backfillDoesNotClaimPrivateLifeOnAGroupsOnlyDevice() {
        let f = Fixture()
        let d = f.defaults

        let escribio = PrivateSessionMark.backfillIfNeeded(
            hasGroupsOnlyNeutralMount: true, hasCompletedOnboarding: true, d)

        #expect(escribio == true, "el backfill tiene que pronunciarse también sobre esta celda")
        #expect(PrivateSessionMark.raw(d) == false, """
            se le escribió «tiene sesión privada» a un teléfono que solo usa Grupos. Con eso, «Vaciar
            datos» ordena el vaciado a los demás dispositivos de su Apple ID.
            """)
    }

    @Test("MUTACIÓN: el backfill es idempotente por PRESENCIA, no por valor")
    func backfillIsIdempotentByPresenceNotValue() {
        let f = Fixture()
        let d = f.defaults

        // Un solo-grupos que ya tiene su marca escrita a `false`.
        PrivateSessionMark.set(false, d)

        // Un arranque posterior: el backfill escribe SIEMPRE `true`, así que sin el guard por
        // presencia le daría la vuelta a una marca que ya dice lo contrario.
        let escribio = PrivateSessionMark.backfillIfNeeded(hasGroupsOnlyNeutralMount: false, hasCompletedOnboarding: true, d)

        #expect(escribio == false, "el backfill volvió a escribir sobre una marca que ya existía")
        #expect(PrivateSessionMark.raw(d) == false, """
            con el guard por VALOR (`raw != true`) en vez de por PRESENCIA, este backfill habría
            pisado la marca de una entrada solo-grupos. La marca es local y no se re-deriva.
            """)
    }

    @Test("MUTACIÓN: tras un cierre de sesión el backfill NO resucita la marca")
    func backfillDoesNotResurrectTheMarkAfterSignOut() {
        let f = Fixture()
        let d = f.defaults

        // Lo que hace el boot real, en su orden medido: `performSignOutWipeIfArmed` corre pre-mount
        // y llama a `clear()`, y su `resetPrefs()` borra además `hasCompletedOnboarding`.
        PrivateSessionMark.set(false, d)
        PrivateSessionMark.clear(d)

        // El arranque siguiente. Sin el gate, aquí se escribía `true` y la marca revivía en el mismo
        // lanzamiento.
        let escribio = PrivateSessionMark.backfillIfNeeded(hasGroupsOnlyNeutralMount: false, hasCompletedOnboarding: false, d)

        #expect(escribio == false)
        #expect(PrivateSessionMark.raw(d) == nil, """
            el backfill resucitó la marca que el cierre de sesión acababa de borrar. Con eso la
            AUSENCIA no existe nunca en producción y el default estricto de `confirmedPrivateSession`
            deja de proteger nada: «Vaciar datos» podría ordenar a los demás dispositivos del Apple ID
            vaciarse en un teléfono que acaba de volver a «recién instalado».
            """)
        #expect(PrivateSessionMark.confirmedPrivateSession(d) == false)
    }

    @Test("MUTACIÓN: en instalación fresca el backfill no se inventa una sesión privada")
    func backfillDoesNotInventASessionOnAFreshInstall() {
        let f = Fixture()
        let d = f.defaults

        // Celda A: nadie se ha dado de alta todavía. Sin el gate el backfill se convertía en el PRIMER
        // escritor de la marca — contradiciendo el invariante del tipo, que dice que se escribe cuando
        // la sesión privada NACE.
        #expect(PrivateSessionMark.backfillIfNeeded(hasGroupsOnlyNeutralMount: false, hasCompletedOnboarding: false, d) == false)
        #expect(PrivateSessionMark.raw(d) == nil)
        // Y quien lea mientras tanto sigue protegido por el default conservador.
        #expect(PrivateSessionMark.hasPrivateSession(d) == true)
    }

    @Test("el backfill SÍ escribe en el parque existente (control positivo del gate)")
    func backfillStillWritesForTheExistingFleet() {
        let f = Fixture()
        let d = f.defaults

        #expect(PrivateSessionMark.backfillIfNeeded(hasGroupsOnlyNeutralMount: false, hasCompletedOnboarding: true, d) == true)
        #expect(PrivateSessionMark.raw(d) == true, """
            el gate de `hasCompletedOnboarding` se comió también el caso que el backfill existe para
            cubrir. Sin esta aserción, poner `guard false` arriba dejaría los otros dos tests verdes.
            """)
    }
}

// MARK: - El cableado: quién lee cuál, y por qué no se pueden aplanar

@Suite("El eje 1: el reparto de las dos lecturas en producción")
struct PrivateSessionMarkWiringTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // …/YalaTests/CloudSync
        .deletingLastPathComponent()   // …/YalaTests
        .deletingLastPathComponent()   // raíz

    /// Sin comentarios de línea: el reparto se explica en prosa en los dos ficheros, y contar la
    /// prosa haría que documentar el invariante lo rompiera (ya pasó en este repo).
    private static func code(_ path: String) throws -> String {
        let raw = try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
        return raw.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// **La aserción que importa de todo este ticket.** Las tres decisiones de «Vaciar datos» salen del
    /// mismo eje, y dos de ellas fallan bien hacia `true`; la tercera —la que ORDENA a los demás
    /// dispositivos del Apple ID vaciarse— falla mal. Un refactor que las unifique «porque son la misma
    /// pregunta» no rompe ningún test de comportamiento: con la marca PUESTA las dos lecturas coinciden,
    /// así que toda la suite de `DestructiveScopeLogic` sigue verde. Lo único que lo caza es esto.
    @Test("MUTACIÓN: el reparto de las dos lecturas del eje 1 en producción")
    func onlyTheAppleIDSignalReadsTheConfirmedFlavour() throws {
        let vista = try Self.code("Yala/App/Views/Settings/UserDataResetView.swift")

        #expect(vista.contains("confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession()"), """
            la señal a los otros dispositivos del Apple ID dejó de leer la lectura estricta. Con
            `hasPrivateSession`, una marca ausente vacía el iPad privado del dueño de un móvil prestado.
            """)
        #expect(vista.contains("wipeOperation(\n            hasPrivateSession: PrivateSessionMark.hasPrivateSession()"), """
            el alcance de la hoja tiene que leer la lectura conservadora: barrer de más es el lado barato,
            y la hoja nombra todo lo que va a borrar antes de que nadie confirme.
            """)
        #expect(vista.contains("wipeLanding(\n            hasPrivateSession: PrivateSessionMark.hasPrivateSession()"))

        // El conteo va sobre TODO `Yala/`, no sobre esta vista: un consumidor nuevo en
        // `ProfileView`, `CloudSessionSignOut` o `AccountDeletionService` es exactamente donde el
        // fallo alcanza datos de fuera, y medirlo aquí dentro lo habría dejado pasar en verde.
        //
        // **El needle abre paréntesis y no dice `()`**, y eso cambió el 2026-09-14. Con `()` literal,
        // un consumidor que pasara su propio `UserDefaults` —que es lo que hace el servicio de
        // preferencias— no lo contaba nadie: se colaba un lector de la estricta sin pasar por esta
        // decisión. El prefijo `PrivateSessionMark.` deja fuera la declaración del propio tipo.
        #expect(Self.countInProduction("PrivateSessionMark.confirmedPrivateSession(") == 8, """
            `confirmedPrivateSession` tiene OCHO lecturas en toda la app, y todas comparten el SIGNO
            de su error: hacia `true` se DAÑA —se borra, o se afirma un hecho falso sobre datos
            ajenos—, hacia `false` solo se conserva de más o se calla. Si aparece una más, decide a
            conciencia de qué lado cae — si equivocarse hacia `true` no destruye nada ni miente, la
            lectura que le toca es `hasPrivateSession`, que falla conservando.

            Era UNO hasta el 2026-09-14 (`UserDataResetView`: ¿esta sesión EMITE la señal de vaciado a
            los demás dispositivos del Apple ID?). Los dos nuevos son el otro extremo de esa misma
            señal —¿esta sesión la OBEDECE?—, uno en cada punto donde se decide: la detección
            (`PreferenceSyncService.checkForRemoteWipeSignal`, que es quien pone el intent en la cola)
            y el drenaje (`ContentView.handleRemoteWipeSignal`, que es quien borra las filas). Obedecer
            de más en una sesión de la nube sube esos borrados a SU cuenta; en solo grupos borra el
            perfil de quien tiene el teléfono prestado.

            La sexta entró el mismo 2026-09-14 y es la única que NO borra: el aviso de la gracia de
            5 s en `ContentView` («Tus datos fueron eliminados de iCloud»), que se enciende cuando las
            filas desaparecen del store. Quien las baja es el espejo de CloudKit, no la señal, y el
            espejo está montado también en el teléfono prestado — así que sin este eje el aviso le
            salta a quien no tiene ningún iCloud en juego, con un botón que lo expulsa al onboarding.
            Su `true` de más no destruye datos, pero afirma un hecho falso sobre los de otra persona y
            le ofrece el camino genérico de degradación: mismo signo, misma lectura.

            La SÉPTIMA es la pareja de esa sexta, y este número se quedó en 6 cuando entró: desde que
            el aviso viaja por la cola del router, el DRENAJE lo re-mide antes de presentarlo
            (`ContentView.presentRemoteWipeNoticeIfStillTrue`). No es una duplicación por si acaso —
            entre que el aviso se PIDE y la pantalla queda libre puede pasar un background entero y un
            cambio de sesión, y el intent no es transitorio: afirma un hecho sobre AHORA. O sea que las
            dos superficies del aviso aportan DOS lecturas, igual que el borrado (detección + drenaje)
            y que el cierre por cambio de Apple ID (pre-filtro + re-lectura tras el `await`): cada vez
            que este eje gobierna algo asíncrono, se lee en los dos extremos de la espera.

            Y desde el 2026-09-14 hay un consumidor más —el cierre de la sesión privada cuando cambia
            el Apple ID del teléfono (`AppleIDChangeCloseLogic`)— que aporta **DOS** lecturas, no una,
            y por eso aporta dos de los seis. Son dos instantes distintos del mismo cableado en
            `AppBootstrapper.checkForAppleIDChange`: el pre-filtro que decide si merece la pena salir a
            CloudKit, y la re-lectura DESPUÉS del `await`, que es la que decide de verdad. Contarlas
            como una sola escondería justo la que importa: entre las dos cabe un cierre de sesión
            entero, y decidir un borrado con el snapshot de antes del `await` es el bug que la segunda
            existe para evitar. Su signo es el de la familia: `true` de más cierra la sesión de alguien
            y le borra la copia local.

            La OCTAVA (2026-09-14) no borra ni avisa: decide si el iCloud-KV del Apple ID está abierto
            para esta sesión (`OwnerKeyValueGate.current`). Resuelve la marca AUSENTE junto a la marca
            del neutro solo-grupos, y su signo es el de la familia: afirmar de más que la sesión es
            privada le abre el store del dueño a quien usa su móvil prestado, que le pisa las
            preferencias en todos sus dispositivos. Hacia `false` solo cierra si además hay un alta
            solo-grupos empezada. La permisiva sola no servía: la puerta del organizador escribe nombre
            y periodo con la marca todavía ausente.
            """)
    }

    /// **Las dos muertes de la marca, pinneadas.** Sus vecinas literales en los dos ficheros ya lo
    /// están (`clearGroupsOnlyNeutralMount`, `clearPrivateChoseWithoutICloud`); sin esto, un mutante
    /// que borrara cualquiera de las dos líneas salía verde y la persona siguiente heredaba el eje del
    /// humano anterior.
    @Test("MUTACIÓN: la marca muere en los dos sitios que devuelven el teléfono a recién instalado")
    func theMarkDiesInBothHandoverPaths() throws {
        let boot = try Self.code("Yala/Utils/SwiftDataConfiguration.swift")
        #expect(boot.contains("PrivateSessionMark.clear(defaults)"), """
            el boot-wipe del cierre de sesión dejó de limpiar el eje: quien restaure su iCloud en este
            teléfono hereda el de quien se fue.
            """)

        let wipe = try Self.code("Yala/Utils/DataWipeService.swift")
        #expect(wipe.contains("PrivateSessionMark.clear(defaults)"), "el relevo de humano dejó de limpiar el eje")
    }

    /// La pantalla de vaciar decide el TEXTO y el ALCANCE con el mismo eje, o promete un borrado
    /// distinto del que ejecuta — que es el daño que `wipeOperation` existe para cerrar.
    @Test("MUTACIÓN: la copy de «Vaciar datos» sale del mismo eje que su alcance")
    func theWipeCopyReadsTheSameAxisAsItsScope() throws {
        let vista = try Self.code("Yala/App/Views/Settings/UserDataResetView.swift")
        #expect(vista.contains("PrivateSessionMark.hasPrivateSession()\n                                        ? L10n.Settings.resetDataDescription"), """
            la descripción de la pantalla volvió a leer otra cosa mientras el alcance lee la marca.
            Divergen justo en el caso del eje: una sesión solo-grupos leía «solo tu perfil y tus
            preferencias» sobre un `.wipeDataFull`.
            """)
    }

    /// El contrato del propio tipo: si alguien colapsa los dos defaults, el eje pierde una de sus dos
    /// direcciones de fallo y ningún test de comportamiento lo nota.
    @Test("MUTACIÓN: los dos defaults del tipo siguen siendo opuestos")
    func theTwoDefaultsStayOpposite() throws {
        let marca = try Self.code("Yala/Services/CloudSync/PrivateSessionMark.swift")
        #expect(marca.contains("raw(defaults) ?? true"), "`hasPrivateSession` perdió su default conservador")
        #expect(marca.contains("raw(defaults) ?? false"), "`confirmedPrivateSession` perdió su default estricto")
    }

    /// El backfill es lo único que escribe la marca del parque existente, y su entrada —el alta
    /// completada— tiene que leerse LOCAL. Correrlo tras `PreferenceSyncService.bootstrap()` lo dejaría
    /// decidiendo con un valor mergeado del iCloud-KV del Apple ID, o sea con el estado de OTRO
    /// dispositivo.
    @Test("MUTACIÓN: el backfill corre ANTES del merge del iCloud-KV")
    func backfillRunsBeforeTheKeyValueMerge() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let backfill = try #require(boot.range(of: "PrivateSessionMark.backfillIfNeeded("))
        let merge = try #require(boot.range(of: "PreferenceSyncService.shared.bootstrap()"))
        #expect(backfill.lowerBound < merge.lowerBound, """
            el backfill quedó DESPUÉS del merge del iCloud-KV: a partir de ahí decide con lo que traiga
            otro dispositivo del mismo Apple ID, y la marca —que es LOCAL por diseño— nacería
            describiendo un teléfono que no es éste.
            """)
    }

    /// **El seam que envenena el simulador.** El seam `-uitest-group-invite` apaga el eje en el dominio
    /// PERSISTENTE, y el prefijo `cloudSync.` —elegido para que la marca sobreviva a «Vaciar datos»— la
    /// deja fuera de `removeUserPreferenceKeys`, así que nada más en el árbol la borra. Sin la purga del
    /// bloque de `-uitest-reset`, la corrida siguiente arranca creyendo que no hay sesión privada, y el
    /// arranque MANUAL de Yala Dev en ese simulador queda igual — que es la víctima que nadie mira.
    @Test("MUTACIÓN: el bloque de `-uitest-reset` purga la marca, y ANTES de que el seam la escriba")
    func theUITestResetPurgesTheMark() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let purga = try #require(boot.range(of: "PrivateSessionMark.clear()"), """
            el bloque de `-uitest-reset` no purga el eje 1, y el barrido de preferencias excluye
            `cloudSync.*` a propósito: sin esta línea, nada en el árbol la borra.
            """)
        let seam = try #require(boot.range(of: "SessionState.shared.hasPrivateSession = false"))
        #expect(purga.lowerBound < seam.lowerBound, """
            la purga quedó DESPUÉS del seam: borraría la marca que el propio `-uitest-group-invite`
            acaba de sembrar y esa corrida arrancaría sin la celda que pidió.
            """)
    }

    /// **La PAREJA de la purga de arriba.**
    /// El backfill del arranque no escribe el eje de la nada: lo DERIVA de
    /// `cloudSync.groupsOnlyNeutralMount`. Esa marca la arman «Activar Yala completo» y las dos altas
    /// solo-grupos, lleva el mismo prefijo `cloudSync.` que la excluye del barrido de preferencias, y
    /// hasta este arreglo **no la borraba nadie**: una corrida que la armara dejaba a todas las
    /// siguientes —y al arranque manual del simulador— con la shell reducida a Grupos.
    ///
    /// Medido con una sonda en el arranque: `BACKFILL entrada raw=nil neutral=true` ⇒ escribe `false`.
    /// Esa es exactamente la contaminación que tumbó ocho XCUITest de tres suites el 2026-09-13 y costó
    /// un día: la copia que los tumbaba vivía en un rincón del simulador que ni `removeObject` ni
    /// `simctl uninstall` alcanzan (lo zanjó `simctl erase`), pero la que SÍ se puede cerrar desde el
    /// código es ésta, y hasta ese día no la borraba nadie.
    @Test("MUTACIÓN: el bloque de `-uitest-reset` purga también la marca del mount neutro")
    func theUITestResetPurgesTheNeutralMountMark() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let purga = try #require(boot.range(of: "StorageModePersistence.clearGroupsOnlyNeutralMount()"), """
            el bloque de `-uitest-reset` no purga el mount neutro. Limpiar el eje sin limpiar su FUENTE
            es peor que no limpiar ninguno: el backfill lo vuelve a derivar en el arranque siguiente.
            """)
        // Acotada al bloque: entre la purga del eje y la del desasociar a medias, que son sus vecinas.
        // Un `contains` a secas dejaría pasar la línea puesta en cualquier otra función del fichero, y
        // fuera del `if UITestHooks.shouldReset` no purga nada.
        let reset = try #require(boot.range(of: "if UITestHooks.shouldReset {"))
        let eje = try #require(boot.range(of: "PrivateSessionMark.clear()"))
        let detach = try #require(boot.range(of: "GroupsDetachPendingPurge.clear()"))
        #expect(reset.upperBound < purga.lowerBound, "la purga quedó FUERA del bloque de `-uitest-reset`")
        #expect(eje.upperBound < purga.lowerBound && purga.upperBound < detach.lowerBound, """
            la purga del mount neutro salió de entre sus dos vecinas del bloque de reset. Van juntas
            porque son la misma familia: keys `cloudSync.*` que ningún barrido toca.
            """)
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// El mismo conteo pero sobre TODO el target de producción, que es el alcance que la aserción
    /// declara. Sin comentarios, por la misma razón que `code(_:)`.
    private static func countInProduction(_ needle: String) -> Int {
        let base = repoRoot.appendingPathComponent("Yala")
        guard let e = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return 0 }
        var total = 0
        for case let url as URL in e where url.pathExtension == "swift" {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let sinComentarios = raw.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            total += count(needle, in: sinComentarios)
        }
        return total
    }

    /// **La premisa que mantiene en CERO la población del backfill mal derivado.**
    ///
    /// El hueco de `backfillIfNeeded` es real: si un dispositivo llega a un arranque con la marca del eje
    /// AUSENTE, `hasCompletedOnboarding == true` y el mount neutro sin armar, se le escribe «tiene sesión
    /// privada» y con eso OBEDECE la señal de vaciado remoto del Apple ID — el teléfono prestado se vacía
    /// por orden de otro. Lo que hace inalcanzable esa celda hoy no es el backfill: es que las DOS altas
    /// solo-grupos escriben el eje EN EL ACTO, así que la marca nunca está ausente en un teléfono que entró
    /// por un grupo. El mount neutro es la segunda mitad, para el arranque siguiente.
    ///
    /// El ticket `remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark` se cerró el
    /// 2026-09-14 midiendo que esa población es cero (telemetría de producción y backend de Grupos, los dos
    /// en 0; el camino solo viajó en tres builds de TestFlight con 3 testers). **Este test es lo que
    /// convierte ese cierre en algo que caduca con aviso**: un alta solo-grupos nueva que se olvide de
    /// cualquiera de las dos escrituras vuelve a crear población, y ahí ya no habría número que valga.
    ///
    /// Mutantes que mata: borrar `armGroupsOnlyNeutralMount` de cualquiera de las dos altas; borrar el
    /// apagado del eje; y —el que no se ve— añadir una TERCERA alta solo-grupos sin ninguna de las dos,
    /// que el conteo obliga a mirar.
    @Test("MUTACIÓN: las dos altas solo-grupos escriben el eje Y arman el mount neutro")
    func bothGroupsOnlySignUpsWriteTheAxisAndArmTheNeutralMount() throws {
        let organizador = try Self.code("Yala/Services/Groups/GroupsOrganizerOnboarding.swift")
        let arma = try #require(organizador.range(of: "StorageModePersistence.armGroupsOnlyNeutralMount(defaults)"), """
            el alta del organizador dejó de armar el mount neutro. En el arranque siguiente el backfill
            deriva «tiene sesión privada» de su ausencia y ese teléfono obedece la señal de vaciado.
            """)
        let eje = try #require(organizador.range(of: "sessionState.hasPrivateSession = false"), """
            el alta del organizador dejó de apagar el eje. Con la marca AUSENTE y el alta completada, el
            backfill del arranque siguiente la escribe en `true`: es la celda del ticket, repoblada.
            """)
        #expect(arma.lowerBound < eje.lowerBound, """
            el orden se invirtió. El arm vive en `writePreferences`, que es lo que el `guard` de
            `completeSetup` exige antes de tocar el eje y los seeds: si el alta aborta ahí, no puede haber
            dejado el eje apagado sin su mount.
            """)

        let invitacion = try Self.code("Yala/App/Views/Groups/GroupInviteOnboardingView.swift")
        let armaInvite = try #require(invitacion.range(of: "StorageModePersistence.armGroupsOnlyNeutralMount()"),
                                      "el alta por invitación dejó de armar el mount neutro")
        let ejeInvite = try #require(invitacion.range(of: "sessionState.hasPrivateSession = false"),
                                     "el alta por invitación dejó de apagar el eje")
        #expect(armaInvite.lowerBound < ejeInvite.lowerBound, """
            las dos escrituras del alta por invitación se separaron de orden. Van juntas y en este orden
            en `performSilentSetup`, que es el único camino por el que un teléfono sin onboarding previo
            entra a un grupo.
            """)

        // El conteo es la parte que no se ve: los dos `#require` de arriba siguen verdes si alguien añade
        // una TERCERA alta solo-grupos que no arme nada. Los dos armadores restantes son de la reposición
        // —activar Yala completo y su vuelta atrás—, no altas.
        #expect(Self.countInProduction("StorageModePersistence.armGroupsOnlyNeutralMount(") == 3, """
            cambió el censo de quien ARMA el mount neutro. Hoy son TRES: las dos altas solo-grupos
            (`GroupsOrganizerOnboarding`, `GroupInviteOnboardingView`) y el rearme de
            `FullModeActivationView`, que repone la sesión solo-grupos cuando la activación de Yala
            completo se deshace.

            Si el nuevo es un ALTA solo-grupos, tiene que armar el mount Y apagar el eje, o repuebla la
            celda de `PrivateSessionMark.backfillIfNeeded` —marca ausente + alta completada ⇒ «tiene
            sesión privada»— que el ticket
            `remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark` cerró midiendo que estaba
            vacía. Ese cierre vale mientras esta lista no crezca por el lado de las altas.
            """)
    }

    /// Control del instrumento: si el recorrido del árbol se rompe, `countInProduction` devolvería 0
    /// y la aserción de arriba pasaría verde sin medir nada — la familia de «Executed 0 tests».
    @Test("control: el escáner de producción encuentra algo")
    func theProductionScannerActuallyFindsThings() {
        #expect(Self.countInProduction("PrivateSessionMark.hasPrivateSession(") == 18, """
            el eje 1 tiene DIECIOCHO consumidores de la lectura conservadora. Si este número cambia, hay un
            constructor nuevo y hay que decidir con qué lectura contesta — y si el consumidor nuevo
            alcanza datos de FUERA de este teléfono, la lectura que le toca es la otra.

            Eran nueve hasta el 2026-09-13: el barrido del paso 12 tradujo a este eje los consumidores
            que preguntaban por el flag de onboarding, y la review añadió el decimosexto
            (`SessionState.refreshPrivateSessionMirror`, que relee la marca para poner el espejo al día).
            Ninguno de los siete nuevos alcanza datos fuera del teléfono — son routing, copy, alcance de
            borrado y el propio refresco, todos del lado que conserva de más.

            El decimoséptimo llegó el 2026-09-14 con el cierre por cambio de Apple ID: el aviso resuelve
            la celda EN EL TAP (`AppleIDCloseNoticeView.requestClose`, `CloudSignOutFlowLogic.path`; hasta
            el 2026-09-15 vivía en el alert de `ShellDataAlertsModifier`) para pasarla
            como `confirmedPath`, y ahí la lectura que toca es la ANCHA, igual que en los otros dos
            call-sites de `path` — su `true` de más resuelve `.privateSignOut` y su `false` de más
            resolvería `.groupsOnlySignOut`, que es el camino que además borra el store de GRUPOS. O
            sea: aquí es el `false` el que destruye de más, que es la dirección contraria a la familia
            de la lectura estricta. Ese mismo cierre aporta además DOS lecturas de la estricta, en el
            cableado de `AppBootstrapper`; están contadas en el test de arriba y su signo es el opuesto.

            El decimoctavo (2026-09-14) es `OwnerKeyValueGate.current`, que abre o cierra el iCloud-KV
            del Apple ID. Lee las DOS lecturas porque ninguna basta sola: con la marca en `false` la
            puerta se cierra aunque ya no esté la marca del neutro solo-grupos —«Activar Yala completo»
            la levanta al relanzar—, y la permisiva es la única que distingue `false` de ausente.
            """)
    }

    /// **El eje se escribe por UN solo sitio, y eso es el invariante — no el número.**
    ///
    /// `PrivateSessionMark.set(` aparece exactamente una vez en producción: dentro del `didSet` de
    /// `SessionState.hasPrivateSession`. Los OCHO puntos donde la sesión privada nace o muere asignan a
    /// esa propiedad, que persiste Y refresca la shell en el mismo render.
    ///
    /// **Un `set` directo sería el bug**: persiste el dato y no mueve la interfaz, así que la pestaña
    /// reducida a Grupos se quedaría puesta hasta el arranque siguiente. Hubo dos hasta el 2026-09-13 y
    /// se unificaron al medir esto.
    @Test("MUTACIÓN: un solo escritor de la marca, y ocho gestos que pasan por el espejo")
    func theMarkHasExactlyOneWriter() {
        #expect(Self.countInProduction("PrivateSessionMark.set(") == 1, """
            apareció un segundo escritor directo de la marca. Si es un alta o una baja nueva, va por
            `SessionState.hasPrivateSession` — si no, persiste el eje sin refrescar la shell.
            """)
        #expect(Self.countInProduction(".hasPrivateSession = ") == 8, """
            el eje se enciende o se apaga en OCHO sitios. Un noveno gesto es un alta o una baja nueva:
            decide de qué lado va y corrige el conteo de la cabecera de `PrivateSessionMark`.

            El punto del literal NO es cosmético: sin él, `let hasPrivateSession = …` de un lector local
            entraría en el conteo y este número mediría dos cosas distintas a la vez.
            """)
    }
}

// MARK: - El espejo observable del eje

/// **El espejo (`SessionState.hasPrivateSession`) y la marca pueden divergir, y estos casos son lo único
/// que lo impide.** El espejo se inicializa UNA vez, en el init del singleton, que corre en el prólogo de
/// `YalaApp` — antes de los hooks pre-mount. Y la marca tiene tres MUERTES que no pasan por el embudo
/// (`PrivateSessionMark.clear`): el boot-wipe de todo cierre de sesión, su gemelo del swap in-session y el
/// relevo de humano de «Empiezo de cero».
///
/// Lo cazó una review adversarial el 2026-09-13, no un síntoma: sin el refresco, el espejo se queda con el
/// valor de la persona ANTERIOR durante todo el proceso, y la app queda con dos fuentes que se contradicen
/// —la shell diciendo «solo grupos» y las dieciséis lecturas conservadoras diciendo «hay sesión privada»—.
/// En el relevo de humano eso neutraliza el sello que ese mismo camino acaba de escribir.
@Suite("El eje 1 · el espejo observable", .serialized)
@MainActor
struct PrivateSessionMirrorTests {

    @Test("refrescar pone el espejo al día cuando la marca cambió por fuera")
    func refreshPicksUpAnExternalChange() {
        let estado = SessionState.shared
        let previo = estado.hasPrivateSession
        defer {
            PrivateSessionMark.set(previo)
            estado.refreshPrivateSessionMirror()
        }

        estado.hasPrivateSession = true
        PrivateSessionMark.set(false)   // una muerte/escritura por fuera del embudo
        #expect(estado.hasPrivateSession == true, "premisa: el espejo todavía no se ha enterado")

        estado.refreshPrivateSessionMirror()
        #expect(estado.hasPrivateSession == false)
    }

    /// **LA ASERCIÓN QUE CARGA EL PESO.** Refrescar NO puede persistir: el `didSet` es el único escritor
    /// de la marca, así que sin la bandera de reentrada el refresco volvería a escribir justo lo que el
    /// `clear()` acaba de borrar. Y la AUSENCIA es lo que hace estricto a `confirmedPrivateSession` — con
    /// ella resucitada, «Vaciar datos» puede ordenar el vaciado a los demás dispositivos del Apple ID en
    /// un teléfono que acaba de volver a «recién instalado».
    @Test("MUTACIÓN: refrescar tras un `clear` NO resucita la marca")
    func refreshDoesNotResurrectTheMark() {
        let estado = SessionState.shared
        let previo = PrivateSessionMark.raw()
        defer {
            if let previo { PrivateSessionMark.set(previo) } else { PrivateSessionMark.clear() }
            estado.refreshPrivateSessionMirror()
        }

        estado.hasPrivateSession = false      // el espejo dice «solo grupos»
        PrivateSessionMark.clear()            // el relevo de humano: la marca queda AUSENTE
        #expect(PrivateSessionMark.raw() == nil, "premisa: la marca está ausente")

        estado.refreshPrivateSessionMirror()

        #expect(PrivateSessionMark.raw() == nil, """
            el refresco PERSISTIÓ el valor del espejo y la ausencia desapareció. Con eso, el default
            estricto deja de proteger y el teléfono no queda como recién instalado.
            """)
        #expect(estado.hasPrivateSession == true, """
            y el espejo tiene que quedar en el default conservador de la marca ausente, no en el valor
            del humano anterior.
            """)
    }

    @Test("refrescar cuando ya coinciden es un no-op")
    func refreshIsANoOpWhenAlreadyInSync() {
        let estado = SessionState.shared
        let previo = estado.hasPrivateSession
        defer { estado.hasPrivateSession = previo }

        estado.hasPrivateSession = true
        estado.refreshPrivateSessionMirror()
        #expect(estado.hasPrivateSession == true)
        #expect(PrivateSessionMark.raw() == true)
    }
}
