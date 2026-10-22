//
//  PrivateBirthKeyValueHandover.swift
//  Yala
//
//  **Lo que la sesión solo-grupos guardó en local, al iCloud-KV del Apple ID, en cuanto nace la privada.**
//  Ticket `full-activation-local-state-never-reaches-the-apple-id-kv`.
//
//  EL HUECO. `OwnerKeyValueGate` cierra el iCloud-KV mientras el eje 1 está en `false`, y sigue cerrado durante toda
//  «Activar Yala completo»: el plan persiste el onboarding (`.persistOnboarding`) ANTES de encender el eje
//  (`.completeActivation`), y ese orden es de kill-safety. Así que nombre, moneda, periodo, la respuesta del historial y
//  todo ajuste tocado en solo-grupos llegan a local y no al KV. El siguiente `applyRemoteValues` —arranque,
//  pull-to-refresh del Panel, cambio externo— aplica encima el remoto si existe y difiere: a quien ese Apple ID ya
//  tuvo una vida privada le vuelven las preferencias de entonces, y sus otros dispositivos no reciben las nuevas. El
//  centinela del interruptor maestro de pagos programados, igual: se marca en local y su espejo no llega.
//
//  LA DECISIÓN (Jürgen, 2026-09-30): subir al nacer la sesión privada, **solo en la rama privada NUEVA**. En Restaurar
//  valen las del Apple ID. **La puerta no se abre durante la activación**: esa vía ya la tumbó una review, porque
//  «volver» desde Restaurar deja la activación pendiente sin límite y la puerta no distingue una en curso de una
//  abandonada. Aquí no hace falta: cuando esto sube, el eje ya está en `true` y la puerta ya está abierta.
//
//  POR QUÉ UNA MARCA DURABLE Y NO UNA LÍNEA DETRÁS DEL EJE. Un kill entre encender el eje y subir dejaba el hueco
//  entero: el arranque siguiente, con la puerta ya abierta, aplicaba el remoto sobre lo recién elegido. Por eso:
//   · `arm` va ANTES del eje (`FullModeActivationView.completeFullActivation`), solo si la fuente es `.freshPrivate`;
//   · `consumeIfArmed` va justo DESPUÉS del eje, y otra vez en el arranque, antes de `PreferenceSyncService.bootstrap`.
//  **El arranque la consume siempre**, abra o no: con la puerta abierta sube (el kill fue después del eje); cerrada,
//  la descarta (el kill fue antes del eje, la sesión sigue siendo solo-grupos y reactivar la vuelve a armar). Así la
//  marca no sobrevive a un arranque, y no puede subir nada en una Restauración posterior.
//
//  QUÉ SUBE. El estado local ENTERO de las `PrefSyncKey` —el idioma, desde su suite del App Group, que es donde vive— y
//  el centinela del interruptor maestro si está en `true`:
//   · una clave PRESENTE se escribe con su valor;
//   · una clave AUSENTE se BORRA del KV (review adversarial, 2026-09-30). Saltarla dejaba el remoto de la vida
//     anterior del Apple ID —un idioma, un icono, el primer día de la semana— para que el merge lo aplicara encima en
//     el arranque siguiente: el síntoma del ticket por otra puerta. Borrar no inventa un valor, y es el gesto que ya
//     hace «idioma del sistema» (`LanguageManager.overrideLanguage = nil`); en los otros dispositivos el merge ignora
//     una clave ausente (`PreferenceMergeLogic.decide`, `guard let remote`), así que no les cambia nada;
//   · **salvo el consentimiento de la nube** (`neverRemovedKeys`): es un registro de trazabilidad y ningún camino lo
//     borra (precedente append-only de `swiftdata-cloudkit.md`).
//  Las preferencias, solo si viajan por el KV (`PrefsSyncBehavior.icloudKeyValue`): en `.cloud` van al outbox del backend.
//

import Foundation

enum PrivateBirthKeyValueHandover {

    /// Sin el prefijo `cloudSync.` a propósito: vive un instante —se consume en el mismo gesto y en el arranque—, y si
    /// un barrido de preferencias la alcanzara, lo que se pierde es una subida que ya no hace falta.
    static let pendingKey = "privateBirthKeyValueHandoverPending"

    /// Lo que se sube si está en local pero NO se borra del KV si falta (el porqué, en la cabecera).
    static let neverRemovedKeys: Set<PrefSyncKey> = [.cloudConsentAcceptedAt, .cloudConsentTextVersion]

    /// Qué hizo `consumeIfArmed`. Para los tests y el rastro; producción no decide nada por él.
    enum Outcome: Equatable {
        /// No había marca: la sesión no nació de una activación privada nueva (o ya se subió).
        case nothingOwed
        /// Había marca y la puerta estaba abierta: lo local está en el KV.
        case handedOver
        /// Había marca y la puerta seguía cerrada: el kill fue antes del eje. Se descarta sin subir nada.
        case discardedGateClosed
    }

    /// La escribe `completeFullActivation`, ANTES de encender el eje.
    static func arm(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: pendingKey)
    }

    static func isArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: pendingKey)
    }

    /// Sube lo local si hay marca y la puerta está abierta, y retira la marca en los dos casos. **Retirarla va
    /// DESPUÉS de escribir**: un kill en medio deja la marca, y el arranque siguiente vuelve a subir lo mismo.
    ///
    /// - Parameters:
    ///   - defaults: donde viven la marca, las marcas de la puerta y las preferencias locales.
    ///   - languageSuite: donde vive `appLanguageOverride` (`LanguageManager.sharedDefaults`).
    ///   - store: el iCloud-KV. En producción, la puerta (`OwnerKeyValueStore.shared`): nada de aquí la rodea.
    ///   - preferencesTravelByKeyValue: si las preferencias de esta sesión van al KV y no al outbox del backend.
    @discardableResult
    static func consumeIfArmed(
        defaults: UserDefaults = .standard,
        languageSuite: UserDefaults = LanguageManager.sharedDefaults,
        store: OwnerKeyValueWriting = OwnerKeyValueStore.shared,
        preferencesTravelByKeyValue: Bool =
            PrefsSyncBehavior.resolve(storageMode: CloudSyncFlags.storageMode) == .icloudKeyValue
    ) -> Outcome {
        guard isArmed(defaults) else { return .nothingOwed }
        defer { defaults.removeObject(forKey: pendingKey) }
        guard OwnerKeyValueGate.current(defaults) == .open else { return .discardedGateClosed }

        if preferencesTravelByKeyValue {
            for key in PrefSyncKey.allCases {
                let domain = key == .appLanguageOverride ? languageSuite : defaults
                guard let value = presentValue(key, in: domain) else {
                    if !neverRemovedKeys.contains(key) { store.removeObject(forKey: key.rawValue) }
                    continue
                }
                switch value {
                case .string(let string): store.setString(string, forKey: key.rawValue)
                case .bool(let bool): store.setBool(bool, forKey: key.rawValue)
                case .int(let int): store.setInt(int, forKey: key.rawValue)
                }
            }
        }
        // El espejo que `flipMasterToggleIfNeeded` quiso escribir y la puerta se tragó. Solo `true`: el centinela no
        // se apaga nunca, y su ausencia en el KV es lo que deja volver a voltear.
        let flipKey = ScheduledPaymentNotificationService.masterToggleFlipKey
        if defaults.bool(forKey: flipKey) {
            store.setBool(true, forKey: flipKey)
        }
        store.synchronize()
        return .handedOver
    }

    /// El valor local por PRESENCIA. No es `PreferenceSyncService.readLocal`, que contesta `.int(0)` a un entero
    /// ausente: aquí eso subiría un cero que nadie eligió, en vez de retirar la clave.
    static func presentValue(_ key: PrefSyncKey, in domain: UserDefaults) -> PrefValue? {
        let k = key.rawValue
        guard domain.object(forKey: k) != nil else { return nil }
        switch key.kind {
        case .string: return .string(domain.string(forKey: k) ?? "")
        case .bool: return .bool(domain.bool(forKey: k))
        case .int: return .int(domain.integer(forKey: k))
        }
    }
}
