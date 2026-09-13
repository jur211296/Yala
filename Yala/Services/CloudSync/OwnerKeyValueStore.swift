//
//  OwnerKeyValueStore.swift
//  Yala
//
//  **El ÚNICO sitio que nombra `NSUbiquitousKeyValueStore`.**
//
//  Ese store es el iCloud key-value del **Apple ID del DISPOSITIVO**: lo que se escribe ahí viaja a
//  todos los dispositivos de esa persona. Aquí no queda ninguna decisión —desde la retirada de la
//  sesión de visita (ADR 2026-09-09) solo hay una sesión por teléfono y el KV siempre es suyo—, pero
//  la fachada se queda, y no por inercia:
//
//  **La lección que la sostiene es de FORMA, no del caso que la motivó.** Nació como puerta con un
//  guard porque el ticket `secundaria-la-visita-escribe-en-el-dominio-del-dueno` midió SEIS vías de
//  escritura y avisó de que «la séptima entrará sin que nadie la vea»; al re-medir contra el árbol, la
//  séptima y la OCTAVA ya estaban dentro y ninguna figuraba en el ticket (el idioma que elegía la
//  visita, y el interruptor maestro de avisos de pagos). ⇒ «acordarse en N sitios» había fallado dos
//  veces más de lo que nadie había contado. Lo que impide que exista un noveno camino no es el guard
//  —que ya no hace falta— sino el source-scan con conteo de `OwnerKeyValueWiringTests`, y ése solo
//  puede contar si hay UN sitio que nombrar. Si algún día vuelven a convivir dos identidades sobre
//  este store, el guard se repone AQUÍ y en ningún otro sitio.
//
//  **La observación no se sirve desde la fachada, y ese detalle sí es de comportamiento:**
//  `NotificationCenter.addObserver(object:)` filtra por identidad del emisor, así que hay que dar el
//  store CRUDO (`notificationSource`) o el observer no dispara nunca — en silencio.
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

/// La fachada sirve a todo el que pedía el store del faro.
extension OwnerKeyValueStore: BeaconKeyValueStore {}

// MARK: - El store guardado

/// El store que TODO el árbol usa para escribir en iCloud KV. `NSUbiquitousKeyValueStore.default` no
/// se nombra en ningún otro sitio salvo los lectores declarados en `OwnerKeyValueWiringTests`.
/// `nonisolated`: la fachada no tiene estado mutable y sus lectores viven en contextos que no son el
/// main actor (el init por defecto de `CloudBeacon`, los boot-hooks pre-mount). Antes lo era por
/// inferencia, a través de la closure que resolvía el descriptor de la sesión de visita; al retirarla
/// hay que declararlo, o `CloudBeacon` deja de compilar sin warning de aislamiento.
nonisolated final class OwnerKeyValueStore: OwnerKeyValueWriting {

    static let shared = OwnerKeyValueStore(backing: NSUbiquitousKeyValueStore.default)

    private let backing: OwnerKeyValueWriting

    init(backing: OwnerKeyValueWriting) {
        self.backing = backing
    }

    // MARK: Escrituras

    func setBool(_ value: Bool, forKey key: String) {
        backing.setBool(value, forKey: key)
    }

    func setString(_ value: String, forKey key: String) {
        backing.setString(value, forKey: key)
    }

    func setDouble(_ value: Double, forKey key: String) {
        backing.setDouble(value, forKey: key)
    }

    func setInt(_ value: Int, forKey key: String) {
        backing.setInt(value, forKey: key)
    }

    func removeObject(forKey key: String) {
        backing.removeObject(forKey: key)
    }

    @discardableResult func synchronize() -> Bool {
        backing.synchronize()
    }

    // MARK: Observación

    /// El objeto que EMITE `didChangeExternallyNotification`, para quien quiera suscribirse.
    ///
    /// Existe para que nadie tenga que nombrar el store crudo por una suscripción. **Y no es
    /// cosmético**: `NotificationCenter.addObserver(object:)` filtra por identidad del emisor, así que
    /// pasar la PUERTA ahí registra un observer que no dispara nunca — las preferencias que llegan de
    /// otro dispositivo dejarían de aplicarse, en silencio. Lo cazó `OwnerKeyValueWiringTests` el mismo
    /// día que se escribió la fachada.
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
