//
//  PersonalContainerSwap.swift
//  Yala
//
//  R4 del relanzamiento cero · el swap de persona SIN relanzar (remount sin mirror).
//
//  ## Qué problema cierra
//
//  Cambiar de humano en un device costaba DOS relanzamientos: el sign-out `.cloud` armaba un wipe que solo
//  el boot podía ejecutar, y el login siguiente re-escribía el par `.cloud`+`mirrorOffArmed`, que exige otro
//  proceso para remontar. R2 ya se llevó el segundo (el alta nube sobre un mount neutro no remonta nada).
//  Éste se lleva el primero: los DOS extremos de la transición son configuraciones SIN mirror
//  (`cloudMirrorOff` → wipe → `neutralNoMirror`, las dos `cloudKitDatabase: .none` sobre el mismo archivo),
//  así que aquí no hay ningún `NSPersistentCloudKitContainer` que matar ni que arrancar — que es justo la
//  pieza cuyo comportamiento no se puede probar desde un test.
//
//  ## Lo que NO se toca, y por qué el alcance es exactamente éste
//
//  Ninguna transición que ENCIENDA o APAGUE un mirror. El eje 3 del spike R3 midió en device que con el
//  mirror `.private` vivo el release también cierra la conexión (5 descriptores → 0), pero dejó un residual
//  que reordena la pregunta: **el mirror emitió 5 eventos en los 10 s POSTERIORES al release** ⇒ el trabajo
//  en vuelo de CloudKit SOBREVIVE al container. Para R4 eso da igual (no hay mirror por construcción); para
//  cualquier debate futuro de ensanchar esto al cutover, es la pregunta previa.
//
//  ## La red se CONSERVA, y no es opcional
//
//  El wipe de boot sigue armado ANTES de intentar nada, y este orquestador jamás lo desarma por su cuenta:
//  lo desarma el propio wipe al ejecutarse, sea en el boot o aquí. ⇒ **el fallo del swap degrada a la
//  pantalla de relanzamiento de hoy, jamás a datos a medias.** Si el release no verifica, se repone el
//  container superviviente y el usuario ve exactamente lo que veía antes de este chip.
//
//  ## Por qué el canario es el mecanismo (spike R3, ejes 1c y 4b)
//
//  Con el container VIVO, borrar los archivos por debajo **no lanza y no crashea**: el fetch devuelve 0
//  filas en silencio y el superviviente ESCRIBE y RESUCITA el archivo que el wipe acababa de borrar. Y la
//  lista de retenedores no se puede cerrar por inspección, porque una fila `@Model` retenida mantiene vivo
//  el container por sí sola. ⇒ soltar-por-lista no es una estrategia; el sentinel + los descriptores sí.
//

import Foundation
import SwiftData

// MARK: - Dueño del container personal

/// **El `ModelContainer` deja de ser una constante del `struct App` y pasa a ser ESTADO de proceso.**
///
/// Hasta R4 vivía como propiedad almacenada de `YalaApp`, inicializada una vez y para siempre; el swap
/// necesita poder soltarlo y reponer otro con el proceso vivo, y un `struct App` no da dónde hacerlo.
/// El `nil` no es un estado de error: es la ventana del swap, y mientras dura **no existe ninguna vista
/// con `@Query` ni con `@Environment(\.modelContext)` montada** — que es precisamente lo que el release
/// verificado necesita para tener alguna posibilidad de salir verde.
///
/// `generation` sube en cada remonte y se usa como `.id(...)` de la jerarquía: sin él, SwiftUI podría
/// reusar vistas cuyo estado interno (ViewModels con filas del store anterior) sobreviviría al swap.
@MainActor
@Observable
final class PersonalContainerHost {

    static let shared = PersonalContainerHost()

    /// `nil` SOLO durante la ventana del swap (jerarquía colapsada, cover terminal en pantalla).
    private(set) var container: ModelContainer?
    private(set) var generation = 0

    private init() {
        container = Self.buildContainer()
    }

    /// Construye el container con los hooks PRE-MOUNT en su orden congelado. Es el mismo cuerpo que vivía
    /// en `YalaApp.sharedModelContainer`; se movió aquí entero para que el remonte del swap use
    /// literalmente el mismo camino que el arranque y no una copia que pueda divergir.
    ///
    /// El orden de los cuatro hooks NO se toca (M1 primero desarma la secundaria, luego el wipe personal,
    /// luego el de grupos, luego las tareas de entrada M1), y `personalConfiguration` se evalúa ANTES de
    /// `markContainerCloudKitState` porque es su evaluación la que CAPTURA el testigo del mount.
    static func makeContainer() throws -> ModelContainer {
        SwiftDataConfiguration.performSecondaryWipeIfArmed()
        SwiftDataConfiguration.performSignOutWipeIfArmed()
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed()
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded()
        let personalConfiguration = SwiftDataConfiguration.personalConfiguration
        SwiftDataConfiguration.markContainerCloudKitState(
            decision: SwiftDataConfiguration.personalStoreMountedDecision)
        return try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalConfiguration,
                           SwiftDataConfiguration.groupsConfiguration,
                           SwiftDataConfiguration.syncMetaConfiguration
        )
    }

    /// **El camino del ARRANQUE, y el `fatalError` se conserva aquí a propósito.** Sin container no hay
    /// app: no existe pantalla que mostrar ni estado al que degradar, y morir con el error en el crash log
    /// es más honesto que arrancar sobre nada. Es el comportamiento de siempre, movido de sitio sin tocar.
    ///
    /// **El REMONTE del swap NO usa esto**, y esa asimetría es el punto: ahí sí hay a dónde degradar (el
    /// cover terminal, con el wipe de boot ya consumado), así que un `fatalError` cambiaría «te pedimos que
    /// reabras la app» por «la app se cerró sola» — peor para el usuario y sin ninguna ganancia.
    static func buildContainer() -> ModelContainer {
        do {
            return try makeContainer()
        } catch {
            fatalError("Error al inicializar ModelContainer de Yala: \(error)")
        }
    }

    /// Suelta la referencia del host y devuelve un `weak` sentinel sobre lo que soltó.
    ///
    /// **Devolver el sentinel es lo que hace posible el aborto REVERSIBLE**: si el release no verifica, el
    /// orquestador puede re-fortalecer esa misma referencia y dejar la app exactamente como estaba. Sin
    /// ella, soltar sería un punto de no retorno y un solo retenedor olvidado dejaría al usuario en una
    /// pantalla sin container y sin camino de vuelta.
    func releaseForSwap() -> PersonalContainerSentinel {
        let sentinel = PersonalContainerSentinel(container)
        container = nil
        return sentinel
    }

    /// Repone el container que sobrevivió a un release fallido. La jerarquía se remonta sobre el MISMO
    /// store, sin wipe: es el estado de antes del intento, con el wipe de boot todavía armado.
    func restoreAfterFailedSwap(_ container: ModelContainer) {
        self.container = container
        generation += 1
    }

    /// Monta el container nuevo tras un wipe consumado.
    func adoptAfterSwap(_ container: ModelContainer) {
        self.container = container
        generation += 1
    }
}

/// Sentinel `weak` sobre el container soltado. Envuelto en un tipo propio y no como una `weak var` local
/// para que el orquestador pueda pasarlo entre funciones sin que Swift lo re-fortalezca por el camino.
@MainActor
final class PersonalContainerSentinel {
    private weak var value: ModelContainer?

    init(_ container: ModelContainer?) {
        value = container
    }

    var isAlive: Bool { value != nil }

    /// Re-fortalece la referencia si el objeto sigue vivo. Es la mitad del aborto reversible.
    func strongIfAlive() -> ModelContainer? { value }
}

// MARK: - El orquestador

@MainActor
enum PersonalContainerSwap {

    /// Resultado del intento, con la causa. Los tres abortos son estados DISTINTOS y el canario tiene que
    /// poder nombrarlos: «este mount no admite swap» es una decisión de alcance, «el objeto sigue vivo» es
    /// un retenedor, y «quedan descriptores» es la pila de Core Data sin soltar el archivo — el caso que un
    /// `weak` sentinel a secas declararía verificado y NO lo es.
    enum Outcome: Equatable {
        /// Swap consumado: store vaciado, container nuevo montado, jerarquía reconstruida. Sin relanzar.
        case swapped
        /// El mount de este proceso lleva mirror adjunto ⇒ fuera del alcance medido. Ni se intenta.
        case skippedMountHasMirror
        /// El release no verificó. Se repuso el container y el usuario ve la pantalla de relanzamiento.
        case abortedRelease(PersonalSwapReleaseLogic.Verdict)
        /// El wipe se consumó pero el container nuevo no se pudo construir. El disco queda consistente
        /// (store vacío, par `.icloud`, neutro armado) y la pantalla es el cover terminal: el arranque
        /// siguiente monta neutro y aterriza en el Welcome.
        case abortedRemount
    }

    /// Cuánto se espera a que el container muera. El eje 1 del spike lo midió en **0 ms** (dealloc
    /// síncrono), así que esto no es un presupuesto de latencia esperada: es el techo de una espera que en
    /// el caso bueno no llega a dar una vuelta. Se poletea cada 50 ms en vez de dormir el total, para que
    /// el camino feliz no le cueste al usuario una pantalla de espera que no necesita.
    static let releasePollInterval: Duration = .milliseconds(50)
    static let releaseTimeout: Duration = .seconds(3)

    /// **El swap completo.** Llamado por el coordinador de sign-out DESPUÉS de armar el wipe de boot y de
    /// entrar en `.awaitingRelaunch`, o sea con la red ya puesta y el cover terminal ya en pantalla.
    ///
    /// Los pasos, y por qué van en este orden:
    ///  1. **Guard de alcance** — si este proceso montó con mirror, no se toca nada (la Opción C está
    ///     acotada a transiciones sin mirror por decisión del owner, y es lo único que el spike midió).
    ///  2. **Colapsar la jerarquía** — `container = nil` desmonta las vistas, y con ellas los ViewModels y
    ///     los `@Query` que retienen filas. Es el paso que más retenedores se lleva y el único que no se
    ///     puede hacer desde una lista.
    ///  3. **Quiesce** — soltar lo que no cuelga de la UI (motores, journal, servicios de proceso).
    ///  4. **Release verificado** — sentinel `nil` **Y** cero descriptores. Un fallo aquí ABORTA.
    ///  5. **Wipe** — el MISMO `performSignOutWipeIfArmed` que corre al boot. No una copia: si divergiera,
    ///     el camino degradado y el swap dejarían el device en estados distintos.
    ///  6. **Remonte + re-bootstrap** — con el testigo del mount recapturado.
    @discardableResult
    static func attemptSignOutSwap() async -> Outcome {
        guard PersonalSwapReleaseLogic.mountAdmitsSwap(
            mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision
        ) else {
            CloudSyncBreadcrumb.swapSkippedMountHasMirror()
            return .skippedMountHasMirror
        }

        // (2) La jerarquía se va: sin esto, 37 ViewModels y 67 `@Query` retienen filas y el release no
        // tiene ninguna posibilidad. Un turno de runloop para que SwiftUI complete el desmontaje antes de
        // preguntar por el sentinel — sin él estaríamos midiendo el árbol todavía vivo.
        let sentinel = PersonalContainerHost.shared.releaseForSwap()
        await Task.yield()

        // (3) Lo que no cuelga de la UI.
        AppBootstrapper.shared.releaseModelContextsForSwap()

        // (4) El canario. Es el mecanismo, no una precaución.
        let verdict = await awaitVerifiedRelease(sentinel: sentinel)
        guard PersonalSwapReleaseLogic.authorizesWipe(verdict) else {
            // Aborto REVERSIBLE: se repone el container superviviente y la app queda como estaba, con el
            // wipe de boot armado. El usuario ve la pantalla de relanzamiento de siempre.
            //
            // **El `if let` cubre el otro aborto, `abortDescriptorsOpen`**, que es el caso raro y el que
            // hace falta entender: ahí el OBJETO murió (no hay nada que reponer) pero la pila de Core Data
            // no soltó el archivo. El host se queda sin container ⇒ la pantalla es el cover terminal, y el
            // store NO se ha tocado: el wipe de boot sigue armado y lo ejecuta el arranque siguiente.
            if let survivor = sentinel.strongIfAlive() {
                PersonalContainerHost.shared.restoreAfterFailedSwap(survivor)
                await AppBootstrapper.shared.rebootstrapAfterSwap(container: survivor)
            }
            CloudSyncBreadcrumb.swapReleaseAborted(reason: breadcrumbReason(verdict))
            return .abortedRelease(verdict)
        }

        // (5) El mismo wipe que el boot. Deja el device recién instalado Y arma el neutro durable.
        SwiftDataConfiguration.performSignOutWipeIfArmed()

        // (6) Remonte. La captura del testigo se reabre ANTES de evaluar `personalConfiguration`: sin esto
        // el testigo se quedaría en `.cloudMirrorOff` y «Restaurar de iCloud» no pediría reabrir la app.
        //
        // El remonte usa la variante que LANZA y no la del arranque: aquí sí hay a dónde degradar. Si el
        // container nuevo no se pudiera construir, el host se queda sin container ⇒ la pantalla es el cover
        // terminal, que es exactamente lo que el usuario vería sin este chip. Y el estado en disco ya es
        // consistente: el wipe se consumó entero (store vacío, par `.icloud`, neutro armado), así que el
        // arranque siguiente monta neutro y aterriza en el Welcome. Jamás datos a medias.
        SwiftDataConfiguration.reopenPersonalStoreMountedDecisionCaptureForSwap()
        let fresh: ModelContainer
        do {
            fresh = try PersonalContainerHost.makeContainer()
        } catch {
            #if DEBUG
            print("PersonalContainerSwap: el remonte post-wipe lanzó: \(error)")
            #endif
            CloudSyncBreadcrumb.swapRemountFailed()
            return .abortedRemount
        }
        PersonalContainerHost.shared.adoptAfterSwap(fresh)
        await AppBootstrapper.shared.rebootstrapAfterSwap(container: fresh)

        CloudSyncBreadcrumb.swapCompleted()
        return .swapped
    }

    /// Poll del release con los DOS instrumentos. Devuelve el veredicto FINAL (el último medido), no el
    /// primero: durante la ventana el objeto puede seguir vivo un instante y eso no es un fallo.
    ///
    /// Una CANCELACIÓN devuelve el veredicto pesimista de ese momento, que es el sesgo seguro: hace abortar
    /// el wipe en vez de ejecutarlo sobre un release no verificado (molde exacto de `awaitDeath` del
    /// harness del spike).
    static func awaitVerifiedRelease(sentinel: PersonalContainerSentinel) async
        -> PersonalSwapReleaseLogic.Verdict {
        var waited: Duration = .zero
        var last = currentVerdict(sentinel: sentinel)
        while last != .released && waited < releaseTimeout {
            do {
                try await Task.sleep(for: releasePollInterval)
            } catch {
                return last
            }
            waited += releasePollInterval
            last = currentVerdict(sentinel: sentinel)
        }
        return last
    }

    private static func currentVerdict(sentinel: PersonalContainerSentinel)
        -> PersonalSwapReleaseLogic.Verdict {
        PersonalSwapReleaseLogic.verdict(
            sentinelAlive: sentinel.isAlive,
            openDescriptors: openDescriptorCountForPersonalStore())
    }

    // MARK: - El instrumento (portado del spike R3 al store REAL)

    /// **Cuántos descriptores abiertos de ESTE proceso apuntan al archivo del store personal.**
    ///
    /// Es el instrumento que el spike R3 tuvo que elegir DESPUÉS de descartar el obvio: «al cerrarse la
    /// última conexión SQLite hace checkpoint y borra `-wal`/`-shm`» **no discrimina**, porque Core Data
    /// activa el WAL persistente y los dos sidecars siguen en disco con la conexión ya cerrada (MEDIDO,
    /// spec §11.1). `fcntl(F_GETPATH)` sobre cada descriptor es la lectura directa: 0 = la pila de Core
    /// Data soltó el archivo de verdad.
    ///
    /// El prefijo cubre los tres archivos del trío (base, `-wal`, `-shm`) porque los tres cuelgan del mismo
    /// path base. La URL se deriva de una `ModelConfiguration` efímera —patrón `deleteStoreFiles`— para no
    /// pasar por `personalConfiguration`, que capturaría el testigo del mount al preguntarlo.
    ///
    /// 1024 cubre de sobra los descriptores de un proceso de app; `_SC_OPEN_MAX` puede ser enorme y
    /// recorrerlo entero costaría más que la medición.
    static func openDescriptorCountForPersonalStore() -> Int {
        let prefix = ModelConfiguration(SwiftDataConfiguration.databaseName,
                                        schema: SwiftDataConfiguration.personalSchema,
                                        cloudKitDatabase: .none).url.path
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        var count = 0
        for descriptor in Int32(0)..<Int32(1024) {
            guard fcntl(descriptor, F_GETPATH, &buffer) == 0 else { continue }
            if String(cString: buffer).hasPrefix(prefix) { count += 1 }
        }
        return count
    }

    private static func breadcrumbReason(_ verdict: PersonalSwapReleaseLogic.Verdict) -> String {
        switch verdict {
        case .released: return "released"
        case .abortObjectAlive: return "container-alive"
        case .abortDescriptorsOpen(let count): return "descriptors-open:\(count)"
        }
    }
}
