//
//  PrivateSessionMark.swift
//  Yala
//
//  EL EJE 1 del ADR 2026-09-09 «Sesiones — dos ejes»: ¿hay sesión privada en ESTE dispositivo?
//
//  POR QUÉ EXISTE. Hasta el 2026-09-12 este eje no tenía fuente propia: las nueve veces que la app lo
//  necesitaba lo derivaba de un flag de ONBOARDING —«por dónde entró esta persona»— que el rediseño
//  retiró. Derivar un eje de un flag que va a morir es lo que hacía inejecutable el barrido: al
//  borrarlo, nueve decisiones de producto —incluida qué se borra al cerrar sesión— se quedaban sin
//  fuente. Aquí el eje se PERSISTE, y es un hecho del DISPOSITIVO.
//
//  POR QUÉ UNA MARCA POSITIVA Y NO LA PRESENCIA DEL STORE (decisión de Jürgen, 2026-09-12). La
//  alternativa era derivarlo de si existe el archivo del store personal. **Un gate derivado de una
//  AUSENCIA falla abierto**: si el fichero falta porque el montaje falló, o porque iCloud todavía no
//  ha bajado, la app trataría a alguien con una vida personal entera como si solo hubiera venido por
//  un grupo, y le escondería sus cuentas. La marca se escribe cuando la sesión privada NACE.
//
//  DÓNDE VIVE, Y POR QUÉ NO VIAJA. `UserDefaults` local, con el prefijo `cloudSync.` que el barrido
//  de preferencias excluye a propósito (ver abajo «la vida de la marca»). **Nunca al iCloud-KV**, y
//  eso es lo que arregla: el flag que cumplía este papel antes sí viajaba por el KV del Apple ID con
//  merge never-downgrade, así que el valor de OTRO dispositivo le recortaba la shell al dueño de éste
//  y había que repararlo a mano en el relevo de humano. «¿Hay vida personal EN ESTE teléfono?» es un
//  hecho del dispositivo, no del Apple ID.
//
//  El precedente del repo para un hecho de sesión persistido es `AccountKindStore` (el eje 2), y la
//  diferencia con él importa: allí el dato describe la CUENTA, así que va SELLADO con el `userID` y
//  un snapshot sin sello se lee como «no sé». Aquí el dato describe el DISPOSITIVO, que no tiene
//  identidad que sellar — misma conclusión sobre el iCloud-KV, por un camino distinto.
//
//  LAS DOS LECTURAS, Y POR QUÉ SON DOS. La marca puede estar AUSENTE (una instalación anterior a
//  este código que aún no ha arrancado, o un dispositivo recién barrido), así que hace falta un
//  default — y **no hay un default que sirva para las dos preguntas**:
//
//    · `hasPrivateSession` (ausente ⇒ `true`) responde «¿hay vida personal que PROTEGER?». Fallar a
//      `true` hace esperar de más y conservar de más, que es el lado barato.
//    · `confirmedPrivateSession` (ausente ⇒ `false`) responde «¿puedo AFIRMAR que esta sesión es
//      privada?». La consumen las decisiones cuyo `true` equivocado BORRA, y hoy son las dos mitades
//      de la señal de vaciado del Apple ID: si «Vaciar datos» la EMITE a los demás dispositivos
//      (`DestructiveScopeLogic.wipeSignalsAppleIDDevices`) y si este dispositivo la OBEDECE
//      (`wipeSignalObeyedByThisSession`, con un lector en cada extremo del canal). Ahí `true` por
//      ausencia vacía el iPad del dueño, o vacía este teléfono por orden de otro — el daño que la
//      review adversarial del paso 9 cazó en el emisor y el ticket
//      `remote-wipe-signal-honored-by-any-session` cerró en el receptor.
//
//  Un solo default con un solo nombre habría metido ese segundo caso en la dirección equivocada sin
//  que nada lo dijera. Por eso el tipo obliga a elegir, y el nombre de cada lectura dice hacia dónde
//  falla.
//
//  LA VIDA DE LA MARCA. Tres reglas, y la de en medio es la que no se ve venir:
//    · NACE / CAMBIA en los OCHO sitios donde el modelo dice que la sesión privada empieza o deja de
//      existir. La encienden el onboarding personal terminado, restaurar de iCloud a la app y adoptar
//      una cuenta existente (los tres en `ContentView`) y activar Yala completo; la apagan las DOS
//      puertas de entrada por grupo (invitación y organizador), la reposición tras vaciar en
//      solo-grupos y el seam de uitest.
//
//      **Los ocho pasan por `SessionState.hasPrivateSession`, y eso es un invariante, no un estilo.**
//      Su `didSet` es el ÚNICO escritor de la marca en toda la app; asignar ahí persiste Y refresca la
//      shell en el mismo render, mientras que un `set` directo haría lo primero y no lo segundo —
//      dejando la pestaña de Grupos puesta hasta el arranque siguiente. Lo cuenta
//      `PrivateSessionMarkTests`: si aparece un noveno, decide de qué lado va; si aparece un segundo
//      escritor directo, es el bug que acaba de describirse.
//    · SOBREVIVE a «Vaciar datos», local o remoto. Vaciar no cambia QUIÉN eres: un solo-grupos que
//      vacía sigue siendo un solo-grupos. Por eso la key lleva el prefijo `cloudSync.`, que
//      `DataWipeService.removeUserPreferenceKeys` excluye — no es un accidente de nombre.
//    · MUERE en los dos sitios que devuelven el teléfono a «recién instalado»:
//      `SwiftDataConfiguration.performSignOutWipeIfArmed` (todo cierre de sesión) y
//      `DataWipeService.clearHandoverPrivateSessionMark` (el relevo de humano de «Empiezo de cero»).
//
//  ADR 2026-09-09 «Sesiones — dos ejes» §2 · ticket `shell-derives-from-two-session-axes`.
//

import Foundation

/// La marca persistida del eje 1. `nonisolated` porque se lee desde vistas `@MainActor` y se limpia
/// desde el boot-wipe pre-mount, que corre fuera del main actor.
nonisolated enum PrivateSessionMark {

    static let userDefaultsKey = "cloudSync.hasPrivateSession"

    // MARK: - Lecturas

    /// **¿Hay vida personal que PROTEGER en este dispositivo?** Ausente ⇒ `true`.
    ///
    /// Es la lectura por defecto y la que usan los NUEVE consumidores que deciden qué se conserva,
    /// qué se espera antes de borrar y qué se le enseña a la persona. Su dirección de fallo es
    /// conservar de más.
    static func hasPrivateSession(_ defaults: UserDefaults = .standard) -> Bool {
        raw(defaults) ?? true
    }

    /// **¿Puedo AFIRMAR que esta sesión es privada?** Ausente ⇒ `false`.
    ///
    /// Para las decisiones que, al equivocarse hacia `true`, **BORRAN**. Hoy hay tres, y son las dos
    /// mitades de un mismo canal: si la señal de vaciado SALE hacia los demás dispositivos del Apple ID,
    /// y si este dispositivo la OBEDECE (dos lectores: donde se detecta y donde se drena).
    ///
    /// **El criterio se ensanchó el 2026-09-14, y conviene saber por qué.** Hasta entonces decía «alcanzan
    /// datos que están FUERA de este teléfono», que describía al único cliente que había. Los dos nuevos no
    /// siempre cumplen eso: obedecer de más en una sesión de la nube sube los borrados a SU cuenta —sí sale
    /// fuera— pero en una solo-grupos sin espejo el borrado se queda aquí. Lo que comparten los tres es el
    /// SIGNO del error, no su alcance: hacia `true` se destruye, hacia `false` solo se conserva de más.
    /// Ese es el criterio para el cuarto que venga.
    static func confirmedPrivateSession(_ defaults: UserDefaults = .standard) -> Bool {
        raw(defaults) ?? false
    }

    /// Lo persistido tal cual, sin default. `nil` = la marca no se ha escrito nunca en este
    /// dispositivo. Lo consume el backfill y los tests; producción elige una de las dos de arriba.
    static func raw(_ defaults: UserDefaults = .standard) -> Bool? {
        guard defaults.object(forKey: userDefaultsKey) != nil else { return nil }
        return defaults.bool(forKey: userDefaultsKey)
    }

    // MARK: - Escrituras

    /// La sesión privada nace (`true`) o deja de existir (`false`) en este dispositivo.
    ///
    /// El embudo normal es `SessionState.hasPrivateSession`, que además refresca la shell; esto se
    /// llama directo desde los caminos sin `SessionState` a mano (el seam de uitest, el boot).
    static func set(_ value: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: userDefaultsKey)
        if !value { PrivateSessionAppleIDWitness.clear(defaults) }
    }

    /// El dispositivo vuelve a «recién instalado».
    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsKey)
        PrivateSessionAppleIDWitness.clear(defaults)
    }

    // MARK: - Backfill

    /// **El backfill de un arranque** (decisión de Jürgen, 2026-09-12): escribe por primera vez la
    /// celda del modelo nuevo en el parque que venía de antes de que el eje existiera.
    ///
    /// **`hasCompletedOnboarding` es el gate, y no es cosmético: es lo que hace que la AUSENCIA exista
    /// de verdad en producción.** Sin él, el backfill escribía una marca positiva en dos sitios donde no
    /// hay nada que migrar y donde el modelo dice que NO hay sesión privada:
    ///  - la instalación fresca (celda A), donde correría antes de que nadie se diera de alta y se
    ///    convertiría en el primer escritor de la marca, contradiciendo el invariante de la cabecera
    ///    («la marca se escribe cuando la sesión privada NACE»);
    ///  - el arranque siguiente a un cierre de sesión (celda G), donde `performSignOutWipeIfArmed` acaba
    ///    de llamar a `clear()` pre-mount y su `resetPrefs()` ha borrado el flag ⇒ el backfill
    ///    resucitaría la marca en el mismo lanzamiento. Con eso el default estricto de
    ///    `confirmedPrivateSession` sería inalcanzable: la ausencia duraría milisegundos y «Vaciar
    ///    datos» podría ordenar a los demás dispositivos del Apple ID vaciarse en un teléfono que acaba
    ///    de volver a «recién instalado».
    ///
    /// **`hasGroupsOnlyNeutralMount` es quien distingue la celda, y llegó a este parámetro por una
    /// premisa CAÍDA.** El diseño del 13-sep escribía `true` sin preguntar nada, apoyado en que no hay
    /// usuarios solo-grupos porque Grupos «estuvo cerrado». La review adversarial lo midió y es falso:
    /// `groupsBackendCompiledDefault` está en `true` y el percent de producción, en `100` — pequeño,
    /// pero no vacío. Y un alta solo-grupos deja `hasCompletedOnboarding = true`, así que cumplía este
    /// gate: se le habría escrito «tiene vida personal» de forma permanente, con la app entera sobre un
    /// store vacío y la señal de vaciado saliendo hacia sus otros dispositivos.
    ///
    /// La señal que sí distingue es `StorageModePersistence.groupsOnlyNeutralMountKey`: la arman las DOS
    /// altas solo-grupos, describe este dispositivo y lleva el prefijo `cloudSync.` que el barrido de
    /// preferencias excluye ⇒ sobrevive a todo lo que borraba al flag. **Su límite, dicho entero:**
    /// existe desde el 2026-09-10, así que un alta solo-grupos anterior a esa fecha no la tiene y cae
    /// del lado conservador (`true`).
    ///
    /// **Ese residual dejó de ser barato el 2026-09-14, y ese mismo día se cerró MIDIENDO que su población
    /// es cero.** El daño que describía era real: desde que el RECEPTOR lee el mismo eje
    /// (`DestructiveScopeLogic.wipeSignalObeyedByThisSession`), a esa celda —marca ausente,
    /// `hasCompletedOnboarding == true`, mount neutro sin armar ⇒ backfill a `true`— se le vaciaría el
    /// teléfono por orden de otro dispositivo, que es justo el bug que el receptor cierra para todos los
    /// demás. Lo que no existe es nadie dentro de ella, y son cuatro mediciones independientes:
    ///
    ///  1. **Telemetría de producción, sus 90 días de retención** — cubre entera la vida del camino, nacido
    ///     el 11-ago con `5fc75b94`. Eventos `register` con `detail = groupsOrganizer` ⇒ **0**; con
    ///     `groupInvite` ⇒ **0**. Lo único del periodo: 5 altas personales (`local/initial`) y 1
    ///     `cloud/migration`. Las dos altas solo-grupos emiten ese KPI y `MetricsService.start()` corre
    ///     incondicional en el cold launch, sin opt-in que lo apague.
    ///  2. **El backend de Grupos al que apunta un build de release** (`CloudBackendConfig`, rama `#else` ⇒
    ///     producción): `auth.users`, `profiles`, `split_groups`, `group_members`, `group_invites` y
    ///     `groups_consents`, **todas en 0**. Las dos altas exigen sesión remota antes de escribir nada
    ///     (`GroupsGateLogic.nextStep` corta en `.presentSignIn` sin ella) ⇒ sin identidad no hay alta.
    ///  3. **El universo de distribución**: la App Store pública sirve **2.0.4** (6-jul-2026), anterior al
    ///     camino; el alta solo-grupos solo viajó en los builds 11, 12 y 13 de TestFlight, y TestFlight
    ///     tiene **3 testers** (2 instalados, 1 invitado sin instalar).
    ///  4. **Esto no ha corrido nunca en el teléfono de nadie**: ningún build distribuido contiene
    ///     `PrivateSessionMark` (el 13 se cortó el 9-sep; el eje llegó el 12-sep).
    ///
    /// Decisión de Jürgen (2026-09-14): se cierra con el número. No se inventa una señal que distinga a un
    /// solo-grupos viejo —las candidatas derivan el eje de una AUSENCIA, que es lo que la cabecera de este
    /// fichero prohíbe— ni se acota por el otro lado con un predicado local al receptor, que divergiría en
    /// silencio del que gobierna el borrado.
    ///
    /// **Qué la reabriría, que es lo único que hay que vigilar.** La celda necesita la marca AUSENTE, y hoy
    /// toda alta solo-grupos la ESCRIBE en el acto (`SessionState.hasPrivateSession = false`) además de
    /// armar el neutro, así que el backfill ni llega a mirarla. Vuelve a haber población si aparece un alta
    /// solo-grupos que no haga las dos cosas — lo fija
    /// `PrivateSessionMarkWiringTests.bothGroupsOnlySignUpsWriteTheAxisAndArmTheNeutralMount`.
    /// Ticket: `remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark` (cerrado el 2026-09-14).
    ///
    /// Ese mismo barrido borra `hasCompletedOnboarding` (`DataWipeService.removeUserPreferenceKeys`),
    /// así que el gate es exacto: distingue «parque existente» de «dispositivo que empieza de cero» sin
    /// necesitar ninguna marca propia.
    ///
    /// Idempotente por PRESENCIA de la key, no por su valor: una marca escrita a `false` por una entrada
    /// solo-grupos no se puede re-derivar en el arranque siguiente.
    @discardableResult
    static func backfillIfNeeded(hasGroupsOnlyNeutralMount: Bool,
                                 hasCompletedOnboarding: Bool,
                                 _ defaults: UserDefaults = .standard) -> Bool {
        guard hasCompletedOnboarding else { return false }
        guard raw(defaults) == nil else { return false }
        set(!hasGroupsOnlyNeutralMount, defaults)
        return raw(defaults) != nil
    }
}
