//
//  OwnerKeyValueStore.swift
//  Yala
//
//  **La ÚNICA puerta de escritura al `NSUbiquitousKeyValueStore`.**
//
//  Ese store es el iCloud key-value del **Apple ID del DISPOSITIVO**. Una invitada con sesión
//  secundaria (M1) no cambia la cuenta de iCloud del móvil, así que todo lo que se escriba ahí
//  durante su sesión aterriza en el iCloud del DUEÑO y viaja a los otros dispositivos de él: su
//  nombre, su divisa, su idioma, el faro que encamina sus otros móviles a una cuenta que no es la
//  suya. El daño no es hipotético — es el `.claude/rules/swiftdata-cloudkit.md` §«Preferencias y
//  fronteras de cuenta» visto desde el otro lado de la frontera.
//
//  **Por qué una puerta y no un guard por escritor** (decisión del owner, 2026-08-12). El ticket
//  `secundaria-la-visita-escribe-en-el-dominio-del-dueno` midió SEIS vías y avisó de que «la séptima
//  entrará sin que nadie la vea». Al re-medir contra el árbol, la séptima y la OCTAVA **ya estaban
//  dentro** y ninguna de las dos figuraba en el ticket:
//
//  - `LanguageManager.overrideLanguage` — el idioma que elige la invitada viajaba al Apple ID del
//    dueño y le cambiaba la app en sus otros móviles;
//  - `ScheduledPaymentNotificationService` — el flip del interruptor maestro de avisos de pagos.
//
//  ⇒ «acordarse en N sitios» ya había fallado dos veces más de lo que nadie había contado. Esto es
//  la guard del HANDLER de `.claude/rules/gateway-attest.md`: un sitio que decide, y un source-scan
//  con conteo (`OwnerKeyValueWiringTests`) que impide que exista un noveno camino.
//
//  **Las LECTURAS no se bloquean**, y es deliberado: leer no modifica el store del dueño, y varias
//  decisiones de arranque las necesitan. Lo que sí está gateado aguas arriba es ACTUAR sobre lo
//  leído — `PreferenceSyncService.bootstrap` se salta `checkForRemoteWipeSignal` en `.localOnly`,
//  porque una señal de wipe de los otros dispositivos del dueño jamás debe operar sobre la sesión de
//  la invitada.
//
//  **Lo que esta puerta NO cubre** (y por qué no es un descuido): el `UserDefaults.standard`. Ese es
//  el OTRO medio por el que la sesión secundaria toca el dominio del dueño —`PreferenceSyncService`
//  escribe su espejo local SIEMPRE, también en `.localOnly`— y cerrarlo exige un dominio de
//  preferencias por sesión, que hoy no existe (`local` está hardcodeado a `.standard`). Está medido
//  y anotado en el ticket; no se tapa aquí para no dar por cerrada una frontera que sigue abierta.
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

/// La puerta sirve a todo el que pedía el store del faro, con el guard M1 puesto.
extension OwnerKeyValueStore: BeaconKeyValueStore {}

// MARK: - La decisión

/// Pura y con una sola pregunta, para que la tabla se pueda fijar aparte del cableado.
nonisolated enum OwnerKeyValueGate {

    enum Decision: Equatable {
        /// Sesión del dueño del dispositivo: el iCloud KV es suyo.
        case write
        /// Sesión secundaria M1 viva: el iCloud KV es del DUEÑO y esta sesión no es él.
        case blocked
    }

    static func decide(secondarySessionActive: Bool) -> Decision {
        secondarySessionActive ? .blocked : .write
    }
}

// MARK: - El store guardado

/// El store que TODO el árbol usa para escribir en iCloud KV. `NSUbiquitousKeyValueStore.default` no
/// se nombra en ningún otro sitio salvo los lectores declarados en `OwnerKeyValueWiringTests`.
final class OwnerKeyValueStore: OwnerKeyValueWriting {

    /// Producción. La resolución del descriptor es por LLAMADA y no de inicialización: una sesión
    /// secundaria puede activarse con el proceso ya arrancado, y un valor capturado al `init` dejaría
    /// la puerta abierta el resto de la sesión.
    static let shared = OwnerKeyValueStore(
        backing: NSUbiquitousKeyValueStore.default,
        secondarySessionActive: { SecondarySessionStore.isActive() })

    private let backing: OwnerKeyValueWriting
    private let secondarySessionActive: () -> Bool

    init(backing: OwnerKeyValueWriting, secondarySessionActive: @escaping () -> Bool) {
        self.backing = backing
        self.secondarySessionActive = secondarySessionActive
    }

    /// `true` sii la escritura puede correr. Un `false` NO es un error del llamador: es la frontera
    /// haciendo su trabajo, y por eso no lanza ni loguea por sitio — el canario está en el llamador
    /// que quiera observarse.
    private var canWrite: Bool {
        OwnerKeyValueGate.decide(secondarySessionActive: secondarySessionActive()) == .write
    }

    // MARK: Escrituras (gateadas)

    func setBool(_ value: Bool, forKey key: String) {
        guard canWrite else { return }
        backing.setBool(value, forKey: key)
    }

    func setString(_ value: String, forKey key: String) {
        guard canWrite else { return }
        backing.setString(value, forKey: key)
    }

    func setDouble(_ value: Double, forKey key: String) {
        guard canWrite else { return }
        backing.setDouble(value, forKey: key)
    }

    func setInt(_ value: Int, forKey key: String) {
        guard canWrite else { return }
        backing.setInt(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        guard canWrite else { return }
        backing.removeObject(forKey: key)
    }

    /// También gateado: un `synchronize()` en secundaria empujaría a iCloud lo que otro camino haya
    /// dejado en el store por fuera de esta puerta. Es barato y cierra la rendija.
    @discardableResult func synchronize() -> Bool {
        guard canWrite else { return false }
        return backing.synchronize()
    }

    // MARK: Observación

    /// El objeto que EMITE `didChangeExternallyNotification`, para quien quiera suscribirse.
    ///
    /// Existe para que nadie tenga que nombrar el store crudo por una suscripción. **Y no es
    /// cosmético**: `NotificationCenter.addObserver(object:)` filtra por identidad del emisor, así que
    /// pasar la PUERTA ahí registra un observer que no dispara nunca — las preferencias que llegan de
    /// otro dispositivo dejarían de aplicarse, en silencio. Lo cazó `OwnerKeyValueWiringTests` el mismo
    /// día que se escribió la frontera.
    static var notificationSource: AnyObject { NSUbiquitousKeyValueStore.default }

    /// El nombre de esa notificación, por el mismo motivo.
    static var didChangeExternallyNotification: Notification.Name {
        NSUbiquitousKeyValueStore.didChangeExternallyNotification
    }

    // MARK: Lecturas (libres, ver la cabecera)

    func bool(forKey key: String) -> Bool { backing.bool(forKey: key) }
    func string(forKey key: String) -> String? { backing.string(forKey: key) }
    func double(forKey key: String) -> Double { backing.double(forKey: key) }
    func longLong(forKey key: String) -> Int64 { backing.longLong(forKey: key) }
    func object(forKey key: String) -> Any? { backing.object(forKey: key) }
}
