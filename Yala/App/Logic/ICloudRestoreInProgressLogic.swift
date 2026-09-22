//
//  ICloudRestoreInProgressLogic.swift
//  Yala
//
//  ¿Está ESTE proceso bajando el corpus del propio dueño AHORA MISMO?
//
//  Existe por un caso concreto: quien cambia de móvil o reinstala entra por «Restaurar desde iCloud»
//  y, mientras sus datos bajan, toca «atrás» y entra por la card de su cuenta. Ahí
//  `CrossAccountEntryGuardLogic` ve filas locales sin claim que las reclame —el claim vive en
//  `UserDefaults` y muere con la reinstalación, que es justo la mitad del escenario— y le bloquea la
//  entrada a su propia cuenta diciéndole que los datos son de otra.
//
//  LA SEÑAL ES ACOTADA A PROPÓSITO, y el porqué es lo que hay que entender antes de tocarla: un «hay
//  un import en curso» genérico se enciende también cuando el mirror de CloudKit re-importa por su
//  cuenta en cualquier arranque, y con ella encendida el guard dejaría adoptar sobre el corpus de otro
//  humano — exactamente la puerta que el guard existe para cerrar.
//
//  ES UNA VENTANA, NO UN INTERRUPTOR, y esa distinción se pagó (fix del 2026-08-13, mismo día que la
//  primera versión). La v1 tenía dos términos —«esta sesión pidió restaurar» Y «el import no ha
//  asentado»— y el primero era un latch que no se apagaba nunca, así que TODA la ventana dependía del
//  segundo. Pero `hasCompletedFirstImport` se enciende SOLO en la rama de import EXITOSO, y hay
//  escenarios en los que no llega jamás (backup ausente, import que falla) ⇒ la señal se quedaba viva
//  hasta que el usuario matara la app, y con ella el guard cross-cuenta DESARMADO: cualquiera podía
//  firmar sobre el corpus de otro humano. El sesgo declarado («ante la duda, false») estaba invertido
//  respecto al implementado, porque `!(A && B)` con `A` desconocido devuelve `true`, que es ABRIR.
//
//  ⇒ hoy la ventana se cierra por CUATRO caminos, y los dos últimos son los que la hacen fail-closed
//  de verdad, porque no dependen de que corra ningún callback:
//
//   1. **Nunca se abrió** — nadie pidió restaurar en este proceso.
//   2. **El flujo TERMINÓ y no dejó descarga detrás** (`noteRestoreFinished`) — precisión, no red: el
//      usuario que toca «atrás» a mitad cancela ese `Task` y este camino no corre. **Esa frase fue una
//      aspiración hasta el 2026-09-21**: `forceFetchAndWait` no observaba cancelación, así que el flujo
//      abandonado despertaba al minuto y medio y SÍ apagaba. Hoy la espera se corta y el apagado va
//      detrás del `guard !Task.isCancelled` de `RestoreProgressView`, que es lo que lo hace cierto.
//      **Y ya no es «gane o pierda»** (mismo día,
//      `restore-timeout-closes-the-session-window-with-the-import-still-running`): agotar el tope de
//      90 s **con el import en marcha** no apaga nada, porque las filas siguen entrando y apagar ahí es
//      el bug que esta lógica existe para cerrar. Lo que cierra ese caso es (3) o (4).
//      **Abandonar NO es un quinto camino**: `noteRestoreAbandoned` suelta la titularidad y deja el
//      reloj donde está, así que la ventana del abandonado sigue viva aquí hasta que la cierren (3) o
//      (4). Lo único que cambia es que la entrada SIGUIENTE estrena reloj en vez de heredarlo.
//   3. **El import ASENTÓ** — sus filas ya son corpus como cualquier otro.
//   4. **La CADUCIDAD** — sin actividad de import pasada la gracia, y el tope duro pase lo que pase.
//
//  Y el latch sigue viviendo en memoria a propósito: si el proceso muere, la ventana muere con él.
//
//  Residual DECLARADO: quien espera a que el restore termine del todo y solo DESPUÉS toca «atrás»
//  sigue viendo la pantalla de bloqueo. La señal está apagada y así tiene que ser — para él la salida
//  es el copy de la pieza 2 (`welcome.cloud.blockedRestoreHint`), no un veredicto distinto.
//

import Foundation

nonisolated enum ICloudRestoreInProgressLogic {

    /// - Parameters:
    ///   - restoreRequestedThisSession: el usuario abrió el restore de iCloud en ESTE proceso y la
    ///     búsqueda llegó a arrancar (iCloud disponible y sin wipe reciente — los dos estados en que
    ///     `WelcomeRestoreView` NO importa nada).
    ///   - hasCompletedFirstImport: CloudKit cerró al menos un `importEvent`
    ///     (`iCloudSyncService.hasCompletedFirstImport`).
    ///   - isImportQuiescent: pasó la ventana de quietud desde el último import
    ///     (`iCloudSyncService.isImportQuiescent`).
    ///
    /// - Returns: `true` SOLO si el corpus local de este device lo está trayendo el propio dueño
    ///   ahora. Ante cualquier duda, `false` — y `false` significa «el guard decide como siempre».
    ///   - hasObservedImportActivity: `iCloudSyncService.hasObservedImportActivity` — ¿llegó ALGÚN
    ///     `.importEvent`, con o sin error? Es lo que distingue «el import va lento» de «no hay
    ///     absolutamente nada que importar», y un store vacío nunca lo enciende.
    ///   - now / graceForNoActivity / hardCap: la caducidad. Ver el bloque de abajo.
    static func isRestoringNow(
        restoreStartedAt: Date?,
        hasCompletedFirstImport: Bool,
        isImportQuiescent: Bool,
        hasObservedImportActivity: Bool,
        now: Date,
        graceForNoActivity: TimeInterval = 60,
        hardCap: TimeInterval = 600
    ) -> Bool {
        guard let restoreStartedAt else { return false }
        let elapsed = now.timeIntervalSince(restoreStartedAt)

        // (1) TOPE DURO. La red que no depende de nada: ni de que un callback corra, ni de que
        // CloudKit emita, ni de que la pantalla se desmonte por donde esperamos. Un import que lleva
        // diez minutos sin asentar no es una restauración en curso, es un estado atascado.
        guard elapsed < hardCap else { return false }

        // (2) EL IMPORT ASENTÓ ⇒ esas filas ya son corpus como cualquier otro.
        // `hasCompletedFirstImport` solo NO basta y la asimetría es la misma que documenta
        // `waitForImportQuiescence`: la quiescencia es `true` ANTES del primer import, así que
        // preguntar solo por ella daría «ya terminó» cuando no ha empezado.
        if hasCompletedFirstImport && isImportQuiescent { return false }

        // (3) NO HAY NADA QUE IMPORTAR, y es la salida que faltaba. `hasCompletedFirstImport` se
        // enciende SOLO en la rama de import exitoso (`iCloudSyncService.swift:265-272`, dentro del
        // `else if let endDate`), así que con un backup ausente o un import que falla no llega nunca —
        // y (2) por sí solo dejaba la ventana abierta hasta que el usuario matara la app.
        // `hasObservedImportActivity` es la señal que lo distingue: la enciende CUALQUIER
        // `.importEvent`, con o sin error, y un store que nada importa jamás la enciende.
        // La gracia existe porque al principio también es `false`: apagar ahí devolvería el bloqueo al
        // dueño legítimo que sí está restaurando y solo espera al primer evento.
        if !hasObservedImportActivity && elapsed >= graceForNoActivity { return false }

        return true
    }

    /// **¿El flujo que acaba de terminar deja alguna descarga detrás?** Es lo que decide si
    /// `RestoreProgressView` apaga la ventana (`noteRestoreFinished`) o la deja viva.
    ///
    /// **El bug que cierra** (`restore-timeout-closes-the-session-window-with-the-import-still-running`,
    /// 2026-09-21): el apagado era incondicional —«gane o pierda»—, así que agotar el tope de 90 s con
    /// el import de CloudKit en marcha ponía `restoreStartedAt = nil` en el acto. La pantalla decía
    /// «seguimos trayendo tus datos» —y era verdad— mientras la señal afirmaba lo contrario: quien
    /// tocaba atrás y firmaba con su propia cuenta se encontraba con que sus datos eran «de otra
    /// persona», con las filas entrando en ese mismo momento.
    ///
    /// **Vive AQUÍ y no como un derivado de `RestoreImportSettlement`, y esa es la corrección que trajo
    /// la review.** El primer intento lo colgó de aquel enum (`self != .stillImporting`), que es el que
    /// elige el COPY de la pantalla — y el copy agrupa en `.inconclusive` dos poblaciones que a esta
    /// pregunta contestan distinto: la que no vio un solo import y la que vio uno con un ERROR VIGENTE.
    /// La segunda tiene descarga viva la mayor parte de las veces: `iCloudSyncService.isRetriable` da
    /// `true` a `.networkUnavailable`, `.requestRateLimited`, `.zoneBusy` y al `default`, y el testigo
    /// se enciende en la cabecera del `case .importEvent`, antes del `if let error`. O sea que a un
    /// restore grande con la red floja —el caso NORMAL— se le apagaba la ventana con CloudKit todavía
    /// trayendo filas: el bug del ticket, sin arreglar, entrando por el copy.
    ///
    /// Los dos términos son los mismos que gobiernan la ventana aquí arriba, y no por casualidad: esto
    /// es el complemento exacto de sus caminos (2) y (3).
    ///
    ///  · **`settled`** — el import ASENTÓ. Sus filas ya son corpus como cualquier otro (camino 2).
    ///  · **`!hasObservedImportActivity`** — no llegó un solo `.importEvent` en todo el proceso, así que
    ///    no hay nada bajando ni lo hubo (camino 3). Es la población del usuario realmente nuevo, y
    ///    cerrarle la ventana en el acto es la PRECISIÓN que este apagado aporta sobre la caducidad:
    ///    sin él viviría hasta la gracia de 60 s con el guard de frontera de cuenta entornado.
    ///
    /// **Lo que queda fuera a propósito**: el import que arrancó y no asentó, con o sin error. Su
    /// ventana la cierran el asentamiento o la caducidad, igual que la de quien se va de la pantalla —
    /// y el tope duro de 600 s la acota pase lo que pase. Es el mismo residuo que el camino (3) de
    /// arriba ya acepta y documenta para el import que FALLA.
    static func closesTheSessionWindow(settled: Bool, hasObservedImportActivity: Bool) -> Bool {
        settled || !hasObservedImportActivity
    }
}
