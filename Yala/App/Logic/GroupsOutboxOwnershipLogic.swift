//
//  GroupsOutboxOwnershipLogic.swift
//  Yala
//
//  **De quién es cada cambio de grupos que espera subir** (ticket
//  `groups-outbox-rows-without-a-live-session-have-no-exit`, decisión 2 del encargo del 2026-09-28).
//
//  Hasta ese día `GroupSyncOutbox` no tenía dueño: `pushPending` subía todas las filas vivas con el token de la sesión que
//  hubiera, así que si la sesión de A caducaba con cambios sin subir y entraba B, esos cambios llegaban al servidor firmados
//  por B. Ahora cada fila lleva el `sub` de la cuenta que la apuntó (`GroupSyncOutbox.ownerUserID`), la subida solo manda las
//  de la sesión viva y las demás se quedan: para su dueño, o para el descarte avisado del cierre.
//
//  ## Por qué el dueño sale de un REGISTRO de sesiones y no de la sesión del drain
//
//  El drain traduce el SwiftData History al outbox cuando corre, no cuando se escribe. Un gasto apuntado sin red con la
//  sesión de A ya caducada se queda en el History hasta el siguiente drain, y ése puede ser el primer ciclo de B. Estampar
//  «la sesión del drain» era el bug por otra puerta. Lo que se necesita es **qué cuenta tenía este teléfono cuando se
//  escribió**, y eso lo dice un registro de inicios y cierres de sesión (`SessionSignInLog`), fechado con el mismo reloj que
//  las transacciones del History. La sesión que esté abierta al drenar no cuenta para nada.
//
//  La primera versión guardaba solo «el último dueño que vio el drain» y la review adversarial del 2026-09-28 la tumbó por
//  tres caminos: tras actualizar la app con el libro vacío, todo el History pendiente iba a la sesión de ese momento; una
//  sesión de otra cuenta que entraba y se cerraba al momento (el rechazo de «otra cuenta» de la puerta de la nube) se
//  quedaba con lo que se escribiera después; y una relectura del History con el token re-anclado re-traducía lo de A como
//  de B. Con el registro, las tres preguntas tienen la misma respuesta: la fecha de la transacción.
//

import Foundation

/// **Qué cuenta tenía abierta este teléfono en cada momento.** Una entrada por inicio de sesión —la cuenta que entra— y una
/// por cierre sin borrado —la cuenta a la que vuelve el teléfono—. Lo escribe `CloudAuthService` en sus dos canjes y en
/// `signOut()`, y lo siembra el arranque con la sesión que ya hubiera (`seedIfAbsent`). Lo lee el drain de Grupos
/// (`GroupsSyncClient.performDrain`).
///
/// **Describe a este teléfono**, así que va en `UserDefaults.standard` bajo `cloudSync.*`, que el borrado de datos no toca a
/// propósito (`DataWipeService.removeUserPreferenceKeys`): tras un borrado, lo que quede en el History ya no existe, y lo que
/// se escriba después se fecha contra las entradas nuevas. Sin PII: el `sub` es el identificador opaco de Supabase que ya
/// guardan el espejo del outbox y el llavero.
nonisolated struct SessionSignInLog: Codable, Equatable, Sendable {

    struct Entry: Codable, Equatable, Sendable {
        /// La cuenta que el teléfono tiene desde `at`. `nil` = ninguna que se pueda probar.
        let sub: String?
        let at: Date
    }

    var entries: [Entry]

    static let defaultsKey = "cloudSync.sessionSignInLog"
    /// Tope de entradas: con él, lo más viejo se va. Una transacción más vieja que la entrada más antigua que queda se lee
    /// «sin dueño» y se retiene, que es el lado seguro.
    static let maxEntries = 64

    /// **El dueño de lo escrito en `date`**: la cuenta de la última entrada anterior o igual. `nil` sin entradas antes.
    func owner(at date: Date) -> String? {
        entries.last { $0.at <= date }.flatMap { $0.sub?.isEmpty == false ? $0.sub : nil }
    }

    // MARK: Almacén

    /// `nil` = el registro nunca se escribió en este teléfono (instalación anterior a este build).
    static func read(defaults: UserDefaults = .standard) -> SessionSignInLog? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            return try decoder.decode(SessionSignInLog.self, from: data)
        } catch {
            #if DEBUG
            print("SessionSignInLog: Error leyendo el registro de sesiones: \(error)")
            #endif
            return nil
        }
    }

    private static func write(_ log: SessionSignInLog, defaults: UserDefaults) {
        var trimmed = log
        if trimmed.entries.count > maxEntries { trimmed.entries.removeFirst(trimmed.entries.count - maxEntries) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        do {
            defaults.set(try encoder.encode(trimmed), forKey: defaultsKey)
        } catch {
            #if DEBUG
            print("SessionSignInLog: Error guardando el registro de sesiones: \(error)")
            #endif
        }
    }

    /// **La primera vez que este build ve el teléfono**: todo lo anterior es de la cuenta que ya estaba (`sub`), desde
    /// siempre. Antes de este build el teléfono tenía una sesión como mucho, y la que queda es la única candidata honesta
    /// para lo que se quedó sin drenar. Sin cuenta que dar, el registro nace vacío y lo anterior se retiene. Idempotente: si
    /// el registro ya existe no hace nada.
    static func seedIfAbsent(sub: String?, defaults: UserDefaults = .standard) {
        guard read(defaults: defaults) == nil else { return }
        let seed = sub.flatMap { $0.isEmpty ? nil : Entry(sub: $0, at: .distantPast) }
        write(SessionSignInLog(entries: seed.map { [$0] } ?? []), defaults: defaults)
    }

    /// **Entró `sub` en `date`.** `previousSub` es la sesión que había justo antes del canje: siembra el registro si este
    /// build aún no lo había visto, para que lo anterior no se quede sin dueño.
    static func recordSignIn(sub: String?, previousSub: String?, at date: Date, defaults: UserDefaults = .standard) {
        guard let sub, !sub.isEmpty else { return }
        seedIfAbsent(sub: previousSub, defaults: defaults)
        var log = read(defaults: defaults) ?? SessionSignInLog(entries: [])
        log.entries.append(Entry(sub: sub, at: date))
        write(log, defaults: defaults)
    }

    /// **Se cerró la sesión DE PASO de `closingSub` en `date`.** El teléfono vuelve a la cuenta que tenía antes de que
    /// `closingSub` entrara: es una sesión que se abre y se cierra sin usarse (el rechazo de «otra cuenta» de la puerta de la
    /// nube, la salida del adopt), y lo que se escriba después sigue siendo de la de antes. **Solo para esas**
    /// (`CloudAuthService.signOut(returningToPreviousAccount:)`): tras una revocación de Apple la persona sigue siendo la que
    /// cerró, y volver a la cuenta de antes le daría sus cambios a otra (review adversarial del 2026-09-28). Sin entrada de
    /// `closingSub` —una sesión anterior a este build— no cambia nada.
    static func recordSignOut(closingSub: String?, at date: Date, defaults: UserDefaults = .standard) {
        guard let closingSub, !closingSub.isEmpty, var log = read(defaults: defaults),
              let index = log.entries.lastIndex(where: { $0.sub == closingSub }) else { return }
        let previous = index > 0 ? log.entries[index - 1].sub : nil
        log.entries.append(Entry(sub: previous, at: date))
        write(log, defaults: defaults)
    }
}

nonisolated enum GroupsOutboxOwnershipLogic {

    /// **El dueño de una transacción del History**: la cuenta que el registro dice que tenía el teléfono cuando se escribió.
    /// `nil` = no se puede probar —sin registro, o sin entrada anterior—, y esa fila no la sube ninguna sesión.
    static func owner(transactionAt date: Date, log: SessionSignInLog?) -> String? {
        log?.owner(at: date)
    }

    /// **¿La sube esta sesión?** Solo si es suya. Sin sesión no se filtra: la subida no pasa del token, que es quien dice
    /// «sesión caducada», y filtrarlo todo le haría decir «no había nada que subir».
    static func isUploadable(rowOwner: String?, sessionOwner: String?) -> Bool {
        guard let sessionOwner, !sessionOwner.isEmpty else { return true }
        return rowOwner == sessionOwner
    }

    /// **¿La retiene la sesión viva porque no es suya?** Con sesión, toda fila de otro dueño o sin dueño probado. Sin sesión
    /// ninguna: ahí el bloqueo es la sesión caducada, no la otra cuenta.
    static func isHeldForAnotherAccount(rowOwner: String?, sessionOwner: String?) -> Bool {
        !isUploadable(rowOwner: rowOwner, sessionOwner: sessionOwner)
    }
}
