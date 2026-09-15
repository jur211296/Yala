//
//  OwnerKeyValueStore.swift
//  Yala
//
//  **La ÚNICA puerta al `NSUbiquitousKeyValueStore`, y vuelve a tener guard.**
//
//  Ese store es el iCloud key-value del **Apple ID del DISPOSITIVO**: lo que se escribe ahí viaja a todos
//  los dispositivos de esa persona. Una sesión en la nube no cambia la cuenta de iCloud del teléfono, así
//  que quien usa un móvil prestado con su cuenta de grupos tiene debajo el store del DUEÑO.
//
//  **Por qué el guard volvió (2026-09-14).** Se retiró el 2026-09-13 con la sesión de visita, apoyado en que
//  «solo hay una sesión por teléfono y el KV siempre es suyo». Era falso ese mismo día: la celda F del ADR
//  2026-09-09 —una sesión en la nube SOLO GRUPOS sin sesión privada, el móvil prestado que ese ADR hace
//  normal— son dos identidades sobre este store. Sin guard, las 36 preferencias cruzaban en los dos
//  sentidos: quien tenía el móvil prestado recibía el idioma, la moneda y los ajustes del dueño, y al
//  cambiarlos se los cambiaba a él en su iPad. Decisión de Jürgen: **cada cuenta, sus preferencias**, con el
//  guard aquí y en ningún otro sitio. Ticket `icloud-kv-prefs-cross-sessions-on-a-lent-phone`.
//
//  **La forma es la de siempre, por la misma lección.** El ticket `secundaria-la-visita-escribe-en-el-
//  dominio-del-dueno` midió SEIS vías de escritura y avisó de que «la séptima entrará sin que nadie la vea»;
//  al re-medir, la séptima y la OCTAVA ya estaban dentro (el idioma y el interruptor maestro de avisos de
//  pagos). Un guard por escritor es acordarse en N sitios; una puerta es un sitio que decide, y
//  `OwnerKeyValueWiringTests` cuenta que nadie la rodee. **Ese escáner se borró junto con el guard, y esta
//  cabecera siguió citándolo como la red que quedaba**: no quedaba ninguna. Volvió con él, y más estricto: de
//  los dos lectores crudos que declara ya no exime el fichero, fija cuántas veces nombran el store y qué leen.
//
//  **Qué sesión NO es la dueña** —la tabla es `OwnerKeyValueGate`—, por dos vías:
//   · **La marca del eje 1 está en `false`**: el teléfono AFIRMA que no tiene sesión privada, esté o no la
//     marca del neutro. «Activar Yala completo» levanta el neutro ANTES de relanzar y no enciende el eje
//     hasta el final, y «volver» desde Restaurar deja esa activación pendiente sin límite
//     (`FullModeActivationFlowLogic.CancelEffect.keepPending`). Abrir ahí devolvía el bug entero a quien
//     tiene el móvil prestado, y el arranque del relanzamiento le aplicaba las preferencias del dueño aunque
//     luego cancelara. Lo cazó la review adversarial del 2026-09-14.
//   · **La marca del eje no está, pero el teléfono EMPEZÓ un alta solo-grupos** (la marca del mount neutro
//     solo-grupos, que las dos altas arman en su primera línea). Es la ventana del organizador, que escribe
//     nombre y periodo antes de apagar el eje.
//  Y abre en los otros dos casos, cada uno por algo medido:
//   · **El eje está en `true`**: la sesión privada de siempre, aunque la marca del neutro se quedara pegada.
//   · **No hay ninguna de las dos marcas**: el arranque neutro tras «Cerrar sesión» aplica el `userName` que
//     `isFullyPrefilled` exige para que «Restaurar» vaya directo a la app, y el alta personal escribe sus
//     preferencias y `signalOnboardingCompleted` ANTES de encender el eje. Cerrar ahí rompería restaurar y
//     el alta para toda la población de producción.
//
//  **Cerrada, cierra todo menos DOS lecturas.** Escrituras, borrados y `synchronize()` no llegan, y las
//  lecturas contestan «no hay nada»: las 36 preferencias, el faro, el espejo del interruptor maestro y la
//  cuenta de grupos asociada, que guarda el correo del dueño en claro. Enmascarar la lectura es lo que impide
//  APLICAR, y se apoya en un detalle que hay que conservar: `PreferenceSyncService.readRemoteIKV` corta por
//  PRESENCIA (`object(forKey:) != nil`), así que una clave enmascarada es una clave que no está.
//  **Las dos lecturas que pasan son las señales del Apple ID** (`OwnerKeyValueGate.signalKeysReadableWhenClosed`):
//  no son del dueño sino del canal. Todo dispositivo tiene que VERLAS para darlas por procesadas, y
//  obedecerlas ya lo decide el eje de sesión (`DestructiveScopeLogic.wipeSignalObeyedByThisSession`).
//  Ocultarlas dejaba el vaciado de otro dispositivo pendiente hasta que la puerta se abriera, y la sesión
//  privada que nace de «Activar Yala completo» lo obedecía entonces: se vaciaba recién creada. Escribirlas
//  sigue cerrado.
//
//  **Lo que esta puerta NO cubre, dicho entero:**
//   · **La herencia del arranque neutro.** Tras «Cerrar sesión» nadie ha elegido todavía: ese arranque aplica
//     las preferencias del Apple ID, y quien entra después por un grupo se las encuentra en local. La puerta
//     no puede saber quién va a entrar. Ticket `neutral-boot-hands-owner-prefs-to-whoever-signs-in-next`.
//   · **La sesión en la nube completa (celda E).** Su eje vale `true`, y el faro y el cutover tienen que
//     escribir aquí desde ella. Sus 36 preferencias van al backend salvo el idioma, que `LanguageManager`
//     sigue escribiendo aquí. Ticket `language-override-bypasses-the-cloud-prefs-channel`.
//   · **Lo que la sesión solo-grupos guarda en local con la puerta cerrada no sube cuando nace la privada.**
//     El onboarding de «Activar Yala completo» escribe sus preferencias con el eje todavía en `false`, y el
//     centinela del interruptor maestro se marca en local sin su espejo. Al abrirse la puerta nada los sube,
//     y el siguiente arranque aplica los del Apple ID si los había. Ticket
//     `full-activation-local-state-never-reaches-the-apple-id-kv`.
//   · **Los dos lectores CRUDOS declarados** (`ContentView`, `AppPreferences`), que no pasan por aquí: leen las
//     dos señales —que la puerta también deja pasar— y se suscriben al emisor. `OwnerKeyValueWiringTests` fija
//     sus sentencias exactas, así que una escritura cruda nueva en ellos no pasa en verde.
//   · **Las altas solo-grupos anteriores al 2026-09-10**, que no tienen la marca del neutro: el backfill del
//     eje les escribe `true` y la puerta les abre. Población medida en cero (`PrivateSessionMark.backfillIfNeeded`).
//   · **Un coste aceptado**: activar la nube desde solo-grupos intenta escribir el faro en la promoción, con
//     la puerta todavía cerrada, y no lo escribe. El faro solo encamina, y el claim de esa promoción no lo
//     necesita: la variante B de `AccountClaimDecision` solo existe en `.returningUser`. Población medida en cero.
//
//  **La observación no se sirve desde la fachada, y ese detalle sí es de comportamiento:**
//  `NotificationCenter.addObserver(object:)` filtra por identidad del emisor, así que hay que dar el store
//  CRUDO (`notificationSource`) o el observer no dispara nunca — en silencio.
//

import Foundation

// MARK: - Superficie

/// Lo que la app hace con el iCloud KV. Inyectable para poder afirmar sobre escrituras sin iCloud.
protocol OwnerKeyValueWriting: AnyObject {
    func setBool(_ value: Bool, forKey key: String)
    func setString(_ value: String, forKey key: String)
    func setDouble(_ value: Double, forKey key: String)
    func setInt(_ value: Int, forKey key: String)
    func removeObject(forKey key: String)
    func bool(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func double(forKey key: String) -> Double
    func longLong(forKey key: String) -> Int64
    func object(forKey key: String) -> Any?
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: OwnerKeyValueWriting {
    func setBool(_ value: Bool, forKey key: String) { set(value, forKey: key) }
    func setString(_ value: String, forKey key: String) { set(value, forKey: key) }
    func setDouble(_ value: Double, forKey key: String) { set(value, forKey: key) }
    func setInt(_ value: Int, forKey key: String) { set(value, forKey: key) }
    // `bool`/`string`/`double`/`longLong`/`object`/`removeObject`/`synchronize` ya son nativas.
}

/// El store crudo conforma también al protocolo del faro — la conformance vivía en `CloudBeacon.swift`
/// y se mudó aquí para que ese fichero deje de nombrar el store del dueño.
extension NSUbiquitousKeyValueStore: BeaconKeyValueStore {}

/// La puerta sirve a todo el que pedía el store del faro, con el guard puesto.
extension OwnerKeyValueStore: BeaconKeyValueStore {}

// MARK: - La decisión

/// Pura, para que la tabla se pueda fijar aparte del cableado. El porqué de cada rama, en la cabecera.
nonisolated enum OwnerKeyValueGate {

    enum Decision: Equatable {
        /// La sesión de este teléfono es la dueña del iCloud-KV del Apple ID, o nada dice que no lo sea.
        case open
        /// El teléfono afirma que no tiene sesión privada, o empezó un alta solo-grupos sin afirmarla: el
        /// store es del dueño del Apple ID, y esta sesión no es él.
        case closed
    }

    /// **Las dos lecturas del eje entran por separado, porque ninguna basta sola:** la marca ausente no la
    /// decide el eje sino la otra marca. `hasPrivateSession == false` solo se da con la marca en `false`;
    /// `confirmedPrivateSession == true`, solo con la marca en `true`; lo que queda es la marca ausente.
    static func decide(groupsOnlySessionStarted: Bool,
                       hasPrivateSession: Bool,
                       confirmedPrivateSession: Bool) -> Decision {
        if !hasPrivateSession { return .closed }
        if confirmedPrivateSession { return .open }
        return groupsOnlySessionStarted ? .closed : .open
    }

    /// Lo que decide ESTE teléfono ahora, con sus dos marcas. `defaults` solo se inyecta en tests; producción
    /// lee `.standard`, que es donde las escriben las altas, las activaciones y el cierre de sesión.
    static func current(_ defaults: UserDefaults = .standard) -> Decision {
        decide(
            groupsOnlySessionStarted: StorageModePersistence.isGroupsOnlyNeutralMountArmed(defaults),
            hasPrivateSession: PrivateSessionMark.hasPrivateSession(defaults),
            confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession(defaults))
    }

    /// Las señales del Apple ID, que se LEEN también con la puerta cerrada (el porqué, en la cabecera). Van
    /// como literales porque sus nombres viven en un enum privado de `PreferenceSyncService` (`WipeKey`);
    /// `OwnerKeyValueWiringTests` fija que son los mismos.
    static let signalKeysReadableWhenClosed: Set<String> = ["lastWipeTimestamp", "lastOnboardingTimestamp"]
}

// MARK: - El store guardado

/// El store que TODO el árbol usa para el iCloud KV. `NSUbiquitousKeyValueStore` no se nombra en ningún otro
/// sitio salvo los dos lectores declarados en `OwnerKeyValueWiringTests`, con lo que leen fijado.
/// `nonisolated`: la fachada no tiene estado mutable y sus usuarios viven en contextos que no son el main
/// actor (el init por defecto de `CloudBeacon`, los boot-hooks pre-mount).
nonisolated final class OwnerKeyValueStore: OwnerKeyValueWriting {

    /// Producción. **La decisión se resuelve por LLAMADA y nunca se captura**: la sesión cambia con el
    /// proceso vivo —un alta solo-grupos arma el neutro, una activación enciende el eje—, y un valor tomado
    /// en el `init` de este singleton dejaría la puerta como estaba cuando se construyó.
    static let shared = OwnerKeyValueStore(
        backing: NSUbiquitousKeyValueStore.default,
        decision: { OwnerKeyValueGate.current() })

    private let backing: OwnerKeyValueWriting
    private let decision: () -> OwnerKeyValueGate.Decision

    init(backing: OwnerKeyValueWriting, decision: @escaping () -> OwnerKeyValueGate.Decision) {
        self.backing = backing
        self.decision = decision
    }

    /// `false` es la frontera haciendo su trabajo, no un error del llamador: por eso no lanza ni loguea en
    /// cada sitio.
    private var isOpen: Bool { decision() == .open }

    /// Una lectura pasa con la puerta abierta, o si es una de las señales del Apple ID.
    private func canRead(_ key: String) -> Bool {
        OwnerKeyValueGate.signalKeysReadableWhenClosed.contains(key) || isOpen
    }

    // MARK: Escrituras (guardadas)

    func setBool(_ value: Bool, forKey key: String) {
        guard isOpen else { return }
        backing.setBool(value, forKey: key)
    }

    func setString(_ value: String, forKey key: String) {
        guard isOpen else { return }
        backing.setString(value, forKey: key)
    }

    func setDouble(_ value: Double, forKey key: String) {
        guard isOpen else { return }
        backing.setDouble(value, forKey: key)
    }

    func setInt(_ value: Int, forKey key: String) {
        guard isOpen else { return }
        backing.setInt(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        guard isOpen else { return }
        backing.removeObject(forKey: key)
    }

    /// También guardado: con la puerta cerrada, un `synchronize()` empujaría a iCloud lo que otro camino
    /// hubiera dejado en el store por fuera de aquí.
    @discardableResult func synchronize() -> Bool {
        guard isOpen else { return false }
        return backing.synchronize()
    }

    // MARK: Observación

    /// El objeto que EMITE `didChangeExternallyNotification`, para quien quiera suscribirse.
    ///
    /// Existe para que nadie tenga que nombrar el store crudo por una suscripción. **Y no es
    /// cosmético**: `NotificationCenter.addObserver(object:)` filtra por identidad del emisor, así que
    /// pasar la PUERTA ahí registra un observer que no dispara nunca — las preferencias que llegan de
    /// otro dispositivo dejarían de aplicarse, en silencio. Lo fija `OwnerKeyValueWiringTests`, con sus dos
    /// suscriptores. La notificación sigue llegando con la puerta cerrada; lo que se aplica al recibirla sale
    /// de las lecturas de abajo, que ya vienen vacías.
    static var notificationSource: AnyObject { NSUbiquitousKeyValueStore.default }

    /// El nombre de esa notificación, por el mismo motivo.
    static var didChangeExternallyNotification: Notification.Name {
        NSUbiquitousKeyValueStore.didChangeExternallyNotification
    }

    // MARK: Lecturas (enmascaradas con la puerta cerrada, salvo las señales)

    /// Cerrada, cada lectura contesta lo mismo que una clave que nunca se escribió. `object` es la que
    /// carga el peso: es por donde `PreferenceSyncService.readRemoteIKV` decide si hay algo que aplicar.
    func bool(forKey key: String) -> Bool { canRead(key) ? backing.bool(forKey: key) : false }
    func string(forKey key: String) -> String? { canRead(key) ? backing.string(forKey: key) : nil }
    func double(forKey key: String) -> Double { canRead(key) ? backing.double(forKey: key) : 0 }
    func longLong(forKey key: String) -> Int64 { canRead(key) ? backing.longLong(forKey: key) : 0 }
    func object(forKey key: String) -> Any? { canRead(key) ? backing.object(forKey: key) : nil }
}
