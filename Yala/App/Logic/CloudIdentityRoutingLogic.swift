//
//  CloudIdentityRoutingLogic.swift
//  Yala
//
//  El bloque **[I]** del ADR 2026-09-09 «Sesiones — dos ejes» §7: la tabla que dice, para cada puerta
//  por la que se entra a una cuenta en la nube, qué pasa con cada uno de los tres resultados posibles.
//
//  POR QUÉ EXISTE. Hasta hoy cada puerta se inventaba el tipo de cuenta a su manera —«Ya tengo cuenta»
//  adoptaba como completa a quien solo tenía grupos, y «Vengo por un grupo» trataba como solo-grupos a
//  quien tenía años de datos en la nube— porque lo deducía de `storageMode`, una preferencia LOCAL que
//  en un móvil recién instalado no existe. `g15_01` puso el dato en el backend y `AccountKindLogic` lo
//  trajo al cliente; lo que faltaba, y es esto, es **quién lo usa para elegir pantalla**.
//
//  ## Los dos ejes son DOS PARÁMETROS, y el segundo no es decorativo
//
//  `Gate` son las puertas **físicas** (dónde tapeó la persona) y `DeviceSessionState` es el estado del
//  móvil. La puerta de Grupos cubre **dos filas** de la tabla del ADR según ese estado, y ahí el eje
//  decide de verdad: la MISMA acción —crear un grupo, abrir una invitación— significa «alta solo-grupos»
//  en un móvil limpio y «asociar una cuenta a mi Yala privado» en uno con sesión privada. La matriz de
//  escenarios lo dice en su fila «C · llega una invitación (link)»: misma regla que asociar.
//
//  En las otras tres puertas el eje **no cambia el destino**, y eso es una afirmación con test
//  (`ejeNoDecideEnLasPuertasQueNoLoUsan`), no un descuido.
//
//  **El eje es un enum de cuatro estados y no un `Bool`, y eso lo decidió una lente adversarial.** Con un
//  booleano, «no hay sesión privada» era cierto por tres motivos distintos —móvil limpio, ya en la nube
//  completa, y solo-grupos— y la puerta de Grupos los trataba a los tres como «adopta». El detalle, en el
//  docblock de `DeviceSessionState`.
//
//  ## Lo que esta tabla NO hace
//
//  No pregunta al backend (eso es `CloudIdentityDiscovery`), no aplica el guard cross-cuenta (eso es
//  `CrossAccountEntryGuardLogic`, y cada puerta lo aplica con SUS inputs) y no ejecuta ningún destino.
//  Pura a propósito: el caller resuelve los hechos vivos y los pasa.
//

import Foundation

nonisolated enum CloudIdentityRoutingLogic {

    /// Las puertas **físicas** por las que se llega a una cuenta en la nube. Son cuatro, no cinco: la de
    /// Grupos cubre dos filas de la tabla del ADR según `hasPrivateSession` (ver el encabezado).
    enum Gate: Equatable, CaseIterable {
        /// Welcome → «Soy nuevo» → card «nube». El alta born-cloud.
        case welcomeFirstTimeCloud
        /// Welcome → «Ya tengo cuenta» → Apple/Google.
        case welcomeExistingAccount
        /// La mini-app de Grupos: «Vengo por un grupo», una invitación por link, o el tab.
        case groups
        /// Ajustes → «¿Dónde viven tus datos?» → migrar lo personal a la nube.
        case settingsMigrateToCloud
    }

    /// En qué estado está **este dispositivo** cuando alguien firma. Es el segundo eje del ADR §2, y es
    /// un enum y no un `Bool` por un bug que la primera versión tenía y que una lente adversarial cazó.
    ///
    /// **`hasPrivateSession == false` era falso por tres motivos distintos**, y la puerta de Grupos los
    /// trataba a los tres como «móvil limpio, adopta»:
    ///
    /// · **A/B** — instalación fresca: adoptar es lo correcto.
    /// · **E** — el dispositivo YA está en la nube completa (`storageMode == .cloud`). Si su sesión caduca
    ///   —refresh token revocado, contraseña cambiada— y la persona vuelve a firmar desde el tab Grupos,
    ///   con el `Bool` salía `adoptAsCompleteAndOpenGroups`: se le montaba a pantalla completa la
    ///   migración de su propia cuenta, **re-adoptando un dispositivo ya adoptado**. Y si su claim local
    ///   no estaba (reinstalación), el guard cross-cuenta le decía «estos datos no son tuyos» **al dueño
    ///   de los datos**.
    /// · **F** — solo grupos: no hay datos personales, pero tampoco los pidió. Activar Yala completo es
    ///   una elección explícita (ADR §8), no algo que ocurra por firmar para ver un grupo.
    ///
    /// Los dos estados de nube comparten regla en la puerta de Grupos —**el dispositivo ya tiene su sesión
    /// de nube resuelta, así que [I] no rutea nada: sigue la cadena de grupos**— y por eso son casos
    /// distintos y no uno: lo que los separa es qué hay debajo, y el ticket 8 (activar Yala completo desde
    /// solo-grupos) va a necesitar distinguirlos.
    enum DeviceSessionState: Equatable, CaseIterable {
        /// A/B · instalación fresca, o Welcome visible con el store ya montado. No hay sesión de nada.
        case fresh
        /// C/D · sesión privada viva (con o sin cuenta de grupos asociada).
        case privateSession
        /// E · la nube completa ya absorbió lo personal en este dispositivo.
        case cloudComplete
        /// F · solo grupos, sin sesión privada.
        case cloudGroupsOnly
    }

    /// Los **tres resultados excluyentes** del ADR §7, y ni uno más.
    ///
    /// «El servidor no dijo el tipo» **no es un cuarto caso**: es una pregunta anterior, y la contesta
    /// `discovery(forExistingAccountWithUnknownKind:)`. Meterlo aquí convertiría la tabla de 15 celdas en
    /// una de 20 y obligaría a cada puerta a repetir el mismo fallback.
    enum Discovery: Equatable, CaseIterable {
        /// No hay cuenta en el backend para esta identidad (`exists == false`).
        case newAccount
        /// Existe y lleva finanzas personales (`kind == complete`).
        case complete
        /// Existe y solo lleva grupos (`kind == groups_only`).
        case groupsOnly
    }

    /// A dónde va la persona. Un caso por desenlace **visible**, no por rama de código: dos celdas que
    /// hacen lo mismo comparten destino, y se dice en la tabla.
    enum Destination: Equatable {
        /// Crear la cuenta como `complete` y seguir al onboarding personal ([P]).
        case createCompleteAccountThenPersonalOnboarding
        /// La cuenta existe y es suya: adoptarla y entrar. **El caller pasa antes por el guard
        /// cross-cuenta** — este destino no autoriza a escribir sobre datos ajenos.
        case adoptAsComplete
        /// Igual que `adoptAsComplete`, pero aterrizando en la pestaña Grupos: quien entró por un grupo
        /// quería un grupo. Adopción **silenciosa**, sin aviso ni banner (decisión de Jürgen 2026-09-09).
        case adoptAsCompleteAndOpenGroups
        /// Entrar con la sesión solo-grupos, sin tocar nada de lo personal.
        case enterGroupsOnly
        /// Entrar solo-grupos y ofrecer «Activar Yala completo»: la persona venía a estrenar Yala y su
        /// cuenta resultó ser de grupos, así que el camino a lo completo se le pone delante.
        case enterGroupsOnlyOfferingFullActivation
        /// Seguir la cadena de Grupos ([G] → crear el grupo, o unirse a la invitación). Es el destino de
        /// «nueva» y de «solo grupos» por la puerta de Grupos: en las dos, **[I] no tiene nada distinto
        /// que hacer** y la cuenta nace del tipo correcto sola (`profiles.kind` es `default 'groups_only'`
        /// y la fila la crean `create_group`/`join_group`).
        case continueGroupsSetup
        /// Sesión privada viva: la cuenta queda **asociada** para grupos, y el recorrido sigue a [G] o a
        /// la hoja «unirme». Lo personal no se toca.
        case associateGroupsAccount
        /// «No encontramos una cuenta» **con salida**: botón al alta con el proveedor ya elegido. Nunca un
        /// callejón con un solo «volver» (era el bug de esta pantalla). En un teléfono que no puede darse de alta
        /// (`WelcomeNewOptionsGate.offersCloudSignUp`: sin App Attest, o con el kill del alta) ese botón es «Volver»,
        /// y sigue sin ser la flecha de la esquina sola (Jürgen, 2026-09-16).
        case offerSignUpNoAccountFound
        /// **Bloqueo**: esa cuenta ya tiene Yala completo. Dos salidas —«Ya tengo cuenta» o asociar otra— y
        /// **ninguna escritura**. Juntar dos datasets personales sería una fusión, que el ADR descartó.
        case blockedAccountIsComplete
        /// **Bloqueo**: ya hay otra cuenta de grupos asociada a esta sesión privada. Una cuenta en la nube
        /// activa por dispositivo, conmutable (ADR §2), así que el copy dice eso y no «ya tiene Yala
        /// completo», que sería falso.
        case blockedAnotherGroupsAccountAssociated
        /// Cutover de lo privado a la nube: la cuenta es nueva y recibe lo que ya existe en el dispositivo.
        case cutoverPrivateToCloud
        /// La cuenta solo-grupos que ya estaba asociada se **promueve** a `complete` y recibe el cutover.
        case promoteAssociatedAccountThenCutover
    }

    /// La tabla del ADR §7.
    ///
    /// - Parameters:
    ///   - gate: la puerta física por la que se entró.
    ///   - discovery: qué contestó el backend, ya resuelto a uno de los tres resultados.
    ///   - deviceState: en qué estado está este dispositivo. **Sin valor por defecto a propósito**: un
    ///     default sería `.fresh` y cualquier puerta nueva heredaría en silencio el ruteo de «móvil
    ///     limpio», que es justo el bug que este bloque existe para cerrar. Sin él, añadir una puerta
    ///     obliga a decidir, y lo comprueba el compilador.
    ///   - isAssociatedGroupsAccount: ¿la cuenta que acaba de firmar es la que YA estaba asociada a esta
    ///     sesión privada? `nil` = «esta puerta no puede saberlo». También sin default, y por lo mismo.
    ///     Solo lo mira la puerta de Ajustes, donde separa «promover la mía» de «una cuenta a la vez».
    static func destination(
        gate: Gate,
        discovery: Discovery,
        deviceState: DeviceSessionState,
        isAssociatedGroupsAccount: Bool?
    ) -> Destination {
        switch gate {
        case .welcomeFirstTimeCloud:
            switch discovery {
            case .newAccount: return .createCompleteAccountThenPersonalOnboarding
            case .complete:   return .adoptAsComplete
            case .groupsOnly: return .enterGroupsOnlyOfferingFullActivation
            }

        case .welcomeExistingAccount:
            switch discovery {
            case .newAccount: return .offerSignUpNoAccountFound
            case .complete:   return .adoptAsComplete
            case .groupsOnly: return .enterGroupsOnly
            }

        case .groups:
            // Aquí es donde el segundo eje decide, y es la única puerta en la que decide.
            switch deviceState {
            case .fresh:
                switch discovery {
                case .newAccount, .groupsOnly: return .continueGroupsSetup
                case .complete:                return .adoptAsCompleteAndOpenGroups
                }
            case .privateSession:
                switch discovery {
                case .newAccount, .groupsOnly: return .associateGroupsAccount
                case .complete:                return .blockedAccountIsComplete
                }
            case .cloudComplete, .cloudGroupsOnly:
                // **El dispositivo ya tiene su sesión de nube resuelta, así que [I] no rutea nada nuevo.**
                // Aquí solo se llega cuando la sesión caducó y la persona vuelve a firmar desde Grupos, y
                // lo único que quería era su grupo. Adoptar sería re-adoptar un dispositivo ya adoptado
                // (en `.cloudComplete`) o activarle Yala completo sin habérselo preguntado (en
                // `.cloudGroupsOnly`, que el ADR §8 pone detrás de una elección explícita).
                return .continueGroupsSetup
            }

        case .settingsMigrateToCloud:
            switch discovery {
            case .newAccount:
                return .cutoverPrivateToCloud
            case .complete:
                return .blockedAccountIsComplete
            case .groupsOnly:
                // «Es mi asociada → promover; otra → bloquear (una cuenta a la vez)».
                //
                // `nil` cae con «otra» y NO con «la mía»: promover exige la PRUEBA de que esta cuenta es
                // la asociada, porque promoverla la convierte en `complete` y absorbe lo personal de
                // alguien. Un call-site que no puede probarlo no debe conseguir la promoción por defecto.
                return isAssociatedGroupsAccount == true
                    ? .promoteAssociatedAccountThenCutover
                    : .blockedAnotherGroupsAccountAssociated
            }
        }
    }

    /// Qué resultado asume la tabla cuando **la cuenta existe pero el servidor no dijo de qué tipo es**.
    ///
    /// Ocurre de verdad y hoy es el caso NORMAL: medido el 2026-09-10, ni staging (último deploy
    /// `2026-08-12`) ni producción (`2026-09-10T06:12Z`, anterior al commit que escribió el campo) sirven
    /// `kind` todavía. Un gateway anterior a `g15_01` omite el campo y eso **no es un fallo de ruteo**.
    ///
    /// **La regla es «lo que esa puerta hace hoy», y no `groupsOnly` para todas.** La decisión de Jürgen
    /// (2026-09-09) «ausente ⇒ `groups_only`, con corrección al refrescar» gobierna qué se CREE la app
    /// sobre la cuenta activa —`AccountKindService.current`, que pinta la shell— y su razón declarada
    /// («equivocarse hacia `complete` es enseñarle a alguien un Panel y unas cuentas que no son suyas») no
    /// aplica a la re-entrada: ahí las cuentas son de quien acaba de firmar, y los datos ajenos ya los
    /// cubre el guard cross-cuenta. Aplicar `groupsOnly` en las puertas del Welcome sería una **regresión
    /// medible en producción**: quien tiene una cuenta completa dejaría de adoptar y entraría a una app
    /// vacía. Y eso no lo arregla el refresco, porque lo que no ocurrió es el adopt, no una etiqueta.
    ///
    /// Ajustes cae en `complete` ⇒ **bloqueo**: sin saber el tipo, jamás fusionar dos datasets personales.
    static func discovery(forExistingAccountWithUnknownKind gate: Gate) -> Discovery {
        switch gate {
        case .welcomeFirstTimeCloud, .welcomeExistingAccount, .settingsMigrateToCloud:
            return .complete
        case .groups:
            return .groupsOnly
        }
    }

    /// En qué estado está este dispositivo, derivado de los tres hechos que la app ya persiste hoy.
    ///
    /// **No es un SSOT nuevo y no debe convertirse en uno.** Quien va a derivar toda la shell de los dos
    /// ejes es `shell-derives-from-two-session-axes` (paso 12), y esta función es exactamente lo que ese
    /// ticket absorberá. Vive aquí porque es un INPUT del bloque [I] y necesita test propio, no porque
    /// este ticket quiera fijar el modelo de sesiones.
    ///
    /// Los tres términos, y qué estado del móvil separa cada uno (los nombres son los de la matriz de
    /// escenarios `docs/sessions/2026-09-09-matriz-escenarios-sesiones.md`):
    ///
    /// - `hasCompletedOnboarding == false` ⇒ **A/B**: instalación fresca, o Welcome visible con el store
    ///   ya montado. Todavía no hay sesión de nada.
    /// - `storageMode == .cloud` ⇒ **E**: la nube completa ya absorbió lo personal (el ADR §2 dice que la
    ///   casilla «privada + nube completa» no existe).
    /// - `hasPrivateSession == false` ⇒ **F**: solo grupos. **Este término es el que no se puede
    ///   omitir**, y es el que se escapa a la vista: en F el `storageMode` sigue siendo `.icloud` —la
    ///   mini-app de Grupos jamás lo toca, es su regla dura— así que sin él una persona en F se
    ///   clasificaría como «tiene sesión privada» y la puerta de Grupos podría **bloquearle su propia
    ///   cuenta**.
    static func deviceState(
        hasCompletedOnboarding: Bool,
        storageMode: StorageMode,
        hasPrivateSession: Bool
    ) -> DeviceSessionState {
        guard hasCompletedOnboarding else { return .fresh }
        guard storageMode == .icloud else { return .cloudComplete }
        return hasPrivateSession ? .privateSession : .cloudGroupsOnly
    }

    /// El resultado que ve la tabla, a partir de lo que contestó el backend.
    ///
    /// Un solo sitio para las dos mitades —«¿existe?» y «¿de qué tipo?»— porque separarlas es lo que
    /// dejaba a cada puerta con su propia versión del fallback.
    static func discovery(exists: Bool, kind: AccountKind?, gate: Gate) -> Discovery {
        guard exists else { return .newAccount }
        switch kind {
        case .complete:   return .complete
        case .groupsOnly: return .groupsOnly
        case nil:         return discovery(forExistingAccountWithUnknownKind: gate)
        }
    }
}
