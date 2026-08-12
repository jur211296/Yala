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
//  Molde `AccountEntitlementStore`, y su seguridad —medido— **no viene de la purga sino del sello**: no
//  existe ningún dominio de `UserDefaults` por sesión (`PreferenceSyncService.local` es `.standard`
//  hardcodeado), así que la caché de una sesión de VISITA (M1) cae siempre en el dominio del dueño. Un
//  snapshot cuyo sello no casa con el `sub` vivo se ignora, corra o no corra ninguna purga.
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
}
