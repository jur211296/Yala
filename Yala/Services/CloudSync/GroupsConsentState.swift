//
//  GroupsConsentState.swift
//  Yala
//
//  Estado LOCAL del consentimiento informado de GRUPOS. Desde el chip C1 (2026-08-11) esto es una CACHÉ
//  SELLADA de un hecho que vive en la cuenta (`groups_consents` en Supabase), no la fuente de verdad.
//
//  ## Qué cambió en C1, y por qué no era un refactor
//
//  Antes esto eran dos `PrefSyncKey` de la familia `intPresence` (`groupsConsentAcceptedAt` +
//  `groupsConsentTextVersion`) escritas por `PreferenceSyncService`. Su DESTINO era una propiedad del
//  INSTANTE en que se escribían: con `storageMode == .icloud` —el default del parque— acababan en el
//  iCloud KV del Apple ID del device, y Grupos va al 100 % SIN exigir Modo Nube. ⇒ **para el grueso de los
//  usuarios el registro del consentimiento no existía en ningún sitio que Yala controle** (RGPD Art. 7.1).
//  Las dos keys SALIERON del enum `PrefSyncKey`: el canal de prefs ya no transporta este consent.
//
//  ## La forma de la caché: el `userID` va DENTRO
//
//  Molde `AccountEntitlementStore`, y su seguridad —medido— **no viene de la purga sino del sello**: un
//  snapshot cuyo sello no casa con el `sub` vivo se ignora, corra o no corra ninguna purga.
//
//  **Corrección de 2026-09-05**: la frase que justificaba esto decía «no existe ningún dominio de
//  `UserDefaults` por sesión (`PreferenceSyncService.local` es `.standard` hardcodeado)». Eso CADUCÓ
//  el 2026-08-26 — `SessionDefaults` existe y `PreferenceSyncService.local` es hoy una computed que
//  resuelve la puerta. Lo que sigue siendo verdad, y por eso el sello sigue haciendo falta, es que
//  **este fichero NO pasa por la puerta**: `defaults` de aquí abajo es `.standard` a pelo, así que la
//  caché de una visita cae en el dominio del dueño igual que antes. Ver la CUSTODIA, más abajo.
//
//  ## Append-only: aquí ya no se puede borrar nada remoto
//
//  `clear()` limpia SOLO local. El grant de `groups_consents` no tiene `update` ni `delete`, así que el
//  invariante append-only dejó de ser una convención de estos docblocks y pasó a ser una propiedad del
//  servidor. Eso cierra por construcción el incidente `bdbc46d1` (un `.int(0)` al outbox de prefs pisando
//  por LWW el epoch de una cuenta VIVA, porque el wire de prefs no tiene tombstone) — y de paso hace que
//  los cinco call-sites del `clear()` dejen de ser un campo de minas: cualquiera de ellos es seguro ahora,
//  en cualquier rama de `storageMode`, porque ninguno alcanza la cuenta.
//
//  ## El consent LEGACY (el del parque que ya aceptó)
//
//  `readSnapshot()` es legacy-aware A PROPÓSITO: si no hay snapshot pero SÍ está la key vieja con epoch
//  > 0, deriva el snapshot en memoria sin escribir nada. Sin eso, la primera lectura tras actualizar la app
//  —que ocurre en el primer render, antes de que corra ningún paso de boot— le volvería a pedir el consent
//  a quien ya lo dio. La ESCRITURA (sellar + registrar contra la cuenta) la hace `adoptLegacyIfNeeded`
//  desde `GroupsConsentRegistrar`, cuando ya hay sesión a la que atribuirlo.
//

import Foundation

/// La caché local del consent, sellada con la cuenta a la que pertenece.
struct GroupsConsentSnapshot: Codable, Equatable, Sendable {
    /// El `sub` de la cuenta que aceptó. `nil` SOLO en dos casos legítimos: el consent adoptado de un build
    /// anterior a C1 (que se escribía sin identidad ninguna) y el seam `-uitest-groups-consent`. En cuanto
    /// hay sesión, `adoptLegacyIfNeeded` lo re-sella.
    var userID: String?
    /// Versión del texto que se aceptó (`GroupsConsentText.version` en el instante de aceptar).
    var textVersion: Int
    /// La hora de la ACEPTACIÓN. Jamás la del reintento que consiguió red.
    var acceptedAt: Date
}

/// El consent local del DUEÑO, dormido mientras hay una visita usando el teléfono.
///
/// `Codable` y no un diccionario suelto para que un formato que cambie falle al decodificar en vez de
/// reponer basura sobre el consent del dueño. Fuera del enum a propósito: `GroupsConsentState` es
/// `@MainActor` y las dos funciones de custodia son `nonisolated` —las llaman los hooks de frontera,
/// que corren pre-mount— así que su tipo tampoco puede estar aislado.
nonisolated struct GroupsConsentCustody: Codable, Equatable, Sendable {
    var snapshot: Data?
    var legacyAcceptedAt: Int?
    var legacyTextVersion: Int?

    /// Sin nada dentro no se custodia: un slot vacío haría que la reposición RETIRARA las tres keys
    /// del dueño al salir, que es justo el daño que esto viene a impedir.
    var isEmpty: Bool { snapshot == nil && legacyAcceptedAt == nil && legacyTextVersion == nil }
}

@MainActor
enum GroupsConsentState {

    /// Key del snapshot sellado en `UserDefaults`. `nonisolated` porque `hasLocalRecord(in:)` —el gate
    /// del boot-cleanup del wipe— corre fuera del MainActor.
    nonisolated static let snapshotKey = "groups.consent.snapshot"

    /// Las dos keys del formato ANTERIOR a C1 (eran `PrefSyncKey.groupsConsentAcceptedAt` /
    /// `.groupsConsentTextVersion`, ya fuera del enum). Se conservan como literales porque siguen
    /// existiendo en el disco de todo device que aceptó antes de esta versión: se LEEN para adoptar y se
    /// BORRAN en las fronteras. No se vuelven a escribir nunca.
    nonisolated static let legacyAcceptedAtKey = "groupsConsentAcceptedAt"
    nonisolated static let legacyTextVersionKey = "groupsConsentTextVersion"

    /// `UserDefaults` de lectura/escritura. `nonisolated(unsafe)` para inyección en tests (molde
    /// `PendingJoinStore`).
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    /// El `sub` de la sesión de nube viva. Inyectable en tests (molde
    /// `PreferenceSyncService.cloudUserIDProvider`).
    static var currentUserIDProvider: @MainActor () -> String? = { CloudAuthService.shared.currentUserID }

    // MARK: - Lectura

    /// `true` si el usuario ya aceptó el consent de grupos Y ese consent vale para la sesión viva.
    /// La decisión completa (sello + §8) vive en `GroupsConsentDecisionLogic`.
    static var isAccepted: Bool {
        GroupsConsentDecisionLogic.isAccepted(
            snapshot: readSnapshot(), sessionUserID: currentUserIDProvider())
    }

    /// El snapshot local, o el derivado del formato legacy si aún no se ha adoptado. NO escribe.
    static func readSnapshot() -> GroupsConsentSnapshot? {
        if let data = defaults.data(forKey: snapshotKey) {
            do {
                return try JSONDecoder().decode(GroupsConsentSnapshot.self, from: data)
            } catch {
                // Un JSON ilegible se trata como ausente, JAMÁS como «no aceptado» persistente: el
                // refresco desde la cuenta lo repone. Molde `AccountEntitlementStore.read`.
                #if DEBUG
                print("GroupsConsentState: snapshot ilegible, se descarta: \(error)")
                #endif
            }
        }
        return legacySnapshot()
    }

    /// El consent del formato anterior a C1, derivado en memoria (sin escribir). `nil` si no hay.
    static func legacySnapshot() -> GroupsConsentSnapshot? {
        let epoch = defaults.integer(forKey: legacyAcceptedAtKey)
        guard epoch > 0 else { return nil }
        // Sin versión persistida se asume la 1: es la única que existió mientras esas keys se escribieron.
        let version = defaults.object(forKey: legacyTextVersionKey) as? Int ?? 1
        return GroupsConsentSnapshot(
            userID: nil, textVersion: version, acceptedAt: Date(timeIntervalSince1970: TimeInterval(epoch)))
    }

    // MARK: - Escritura

    /// Persiste el snapshot (pisa el anterior, incluido el de otra cuenta — el device tiene una sesión a la
    /// vez y guardar el historial de cuentas anteriores sería una fuga sin ninguna ganancia).
    static func write(_ snapshot: GroupsConsentSnapshot) {
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: snapshotKey)
        } catch {
            #if DEBUG
            print("GroupsConsentState: Error guardando snapshot: \(error)")
            #endif
        }
    }

    /// Limpia el consent de este DEVICE. Idempotente.
    ///
    /// Desde C1 esto es puramente local en las tres ramas de `storageMode` —ya no pasa por
    /// `PreferenceSyncService`— y **no puede alcanzar el servidor por construcción**: el grant de
    /// `groups_consents` no tiene `delete`. Por eso los cinco call-sites (los tres cierres solo-grupos, el
    /// boot-cleanup del wipe personal y la frontera M1) dejaron de tener que razonar en qué rama de
    /// `behavior` caerían: un sign-out es «hasta luego» y la cuenta sigue recordando su consent, que es lo
    /// que el usuario vuelve a encontrarse al firmar de nuevo.
    ///
    /// **Lo que NO limpia, a propósito: el intent durable** (`GroupsConsentPendingIntent`). Ese intent
    /// lleva el `sub` de su dueño DENTRO, así que no puede registrarse contra la cuenta equivocada, y
    /// borrarlo aquí destruiría la prueba de una aceptación real que solo esperaba a tener red.
    static func clear() {
        defaults.removeObject(forKey: snapshotKey)
        defaults.removeObject(forKey: legacyAcceptedAtKey)
        defaults.removeObject(forKey: legacyTextVersionKey)
    }

    /// ¿Hay algún rastro local de consent? Lo usa el gate del boot-cleanup del wipe de sign-out, que tiene
    /// que decidir si vale la pena llamar al `clear()`. Cubre las DOS formas —snapshot nuevo y keys
    /// legacy— porque un device que no haya vuelto a aceptar desde la actualización solo tiene la vieja.
    /// `nonisolated` porque el gate que la llama (`performSignOutWipeIfArmed`) corre fuera del MainActor y
    /// esta función no toca estado aislado: todo sale del `defaults` que recibe.
    nonisolated static func hasLocalRecord(in defaults: UserDefaults) -> Bool {
        defaults.data(forKey: snapshotKey) != nil
            || defaults.object(forKey: legacyAcceptedAtKey) != nil
    }

    // MARK: - Custodia del registro del DUEÑO en las fronteras de la sesión secundaria

    /// El slot donde duerme el consent local del dueño mientras hay una visita dentro.
    ///
    /// **Nadie lo lee salvo la reposición**, y eso es la mitad del diseño: `readSnapshot()` no lo
    /// mira, así que la visita no puede heredar por accidente un consent que no dio. Vive en el
    /// dominio del dueño, que es donde estaban las keys que guarda.
    nonisolated static let ownerCustodyKey = "groups.consent.owner.custody"

    /// Guarda el consent local del dueño en el slot. Idempotente por PRESENCIA del slot; devuelve
    /// `true` si había algo que custodiar.
    ///
    /// **No borra nada**: quien retira las tres keys es el `clear()` de `SecondarySessionBoundaryPurge`,
    /// que corre inmediatamente después. Esta función va justo ANTES de esa purga y ese orden es el
    /// mecanismo entero — invertirlo custodia un dominio ya vacío. Pinneado en
    /// `GroupsConsentCustodyTests`.
    ///
    /// **Por qué custodiar y no borrar** (decisión del owner, 2026-09-03): la frontera de entrada
    /// TIENE que retirar el consent del dueño —el legacy va sin sello y `GroupsConsentDecisionLogic`
    /// lo da por bueno para cualquiera, así que sin retirarlo la visita hereda un permiso que no
    /// dio—, pero borrarlo tiene dos costes que el `clear()` a secas pagaba enteros: el dueño vuelve
    /// a ver una pantalla de permiso que ya aceptó, y como responsables del tratamiento perdemos la
    /// prueba de ese consentimiento. El repo ya tiene precedente en esta dirección: el registro de
    /// `groups_consents` es append-only por diseño (C1).
    ///
    /// **Custodia las TRES keys, no sólo las dos legacy.** El ticket sólo nombraba las legacy porque
    /// para el snapshot SELLADO `GroupsConsentRegistrar.handleSignIn` lo repone en cada arranque. Pero
    /// medido: ese camino es no-op sin sesión Yala viva (`refreshFromServer` sale por su primer
    /// `guard`), y Grupos va al 100 % SIN exigir Modo Nube ⇒ el dueño que cerró sesión pierde su
    /// snapshot con el mismo síntoma exacto que el del legacy. Cubrir media frontera con el mismo
    /// mecanismo habría dejado el arreglo contradiciéndose ante la misma persona.
    ///
    /// **La idempotencia va por presencia y no por contenido**: la frontera se re-ejecuta entera tras
    /// un kill a mitad, y para entonces lo que hay en las tres keys puede ser ya de la visita.
    /// Sobrescribir la custodia con eso sería perder el registro del dueño por el camino que existe
    /// para conservarlo.
    @discardableResult
    nonisolated static func custodyOwnerRecord(in defaults: UserDefaults) -> Bool {
        guard defaults.data(forKey: ownerCustodyKey) == nil else { return false }
        let record = GroupsConsentCustody(
            snapshot: defaults.data(forKey: snapshotKey),
            legacyAcceptedAt: defaults.object(forKey: legacyAcceptedAtKey) == nil
                ? nil : defaults.integer(forKey: legacyAcceptedAtKey),
            legacyTextVersion: defaults.object(forKey: legacyTextVersionKey) == nil
                ? nil : defaults.integer(forKey: legacyTextVersionKey))
        guard !record.isEmpty else { return false }
        do {
            defaults.set(try JSONEncoder().encode(record), forKey: ownerCustodyKey)
            return true
        } catch {
            // Fallo ABIERTO a propósito: sin custodia, el `clear()` de la purga hace lo de siempre
            // (borrar), que es el comportamiento de hoy. Custodiar a medias —retirar sin poder
            // reponer— sería peor que no custodiar.
            #if DEBUG
            print("GroupsConsentState: no se pudo custodiar el consent del dueño: \(error)")
            #endif
            return false
        }
    }

    /// Repone el consent custodiado y vacía el slot. Devuelve `true` si repuso algo.
    ///
    /// **PISA lo que haya**, y es lo correcto en el punto donde corre: la frontera de SALIDA, después
    /// de que la purga se haya llevado lo de la visita. Lo que ella aceptó no se pierde —el registro
    /// vive en su cuenta, append-only, y `refreshFromServer` se lo devuelve en su propio teléfono.
    ///
    /// El slot se vacía SIEMPRE, también si el JSON no se puede leer: un slot ilegible no repone
    /// nada y dejarlo atascaría la custodia de la visita siguiente.
    @discardableResult
    nonisolated static func restoreOwnerRecord(in defaults: UserDefaults) -> Bool {
        guard let data = defaults.data(forKey: ownerCustodyKey) else { return false }
        defaults.removeObject(forKey: ownerCustodyKey)
        let record: GroupsConsentCustody
        do {
            record = try JSONDecoder().decode(GroupsConsentCustody.self, from: data)
        } catch {
            #if DEBUG
            print("GroupsConsentState: custodia ilegible, se descarta: \(error)")
            #endif
            return false
        }
        apply(record.snapshot, forKey: snapshotKey, in: defaults)
        apply(record.legacyAcceptedAt, forKey: legacyAcceptedAtKey, in: defaults)
        apply(record.legacyTextVersion, forKey: legacyTextVersionKey, in: defaults)
        return true
    }

    /// Escribe el valor custodiado, o RETIRA la key si el dueño no la tenía. La segunda mitad no es
    /// cosmética: reponer sólo lo que había dejaría en pie lo que escribió la visita.
    private nonisolated static func apply(_ value: Data?, forKey key: String, in defaults: UserDefaults) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    private nonisolated static func apply(_ value: Int?, forKey key: String, in defaults: UserDefaults) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

}
