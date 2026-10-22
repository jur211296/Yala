//
//  PrivateSessionAppleIDWitness.swift
//  Yala
//
//  EL TESTIGO del Apple ID con el que nació la sesión privada de ESTE dispositivo: el `recordName` del
//  usuario en el contenedor CloudKit PERSONAL.
//
//  POR QUÉ EXISTE. Hasta el 2026-09-14 la app no guardaba nada con lo que contestar «¿sigue siendo el
//  mismo Apple ID?». Veía `NSUbiquityIdentityDidChange` en dos sitios, pero uno lo convertía en el aviso
//  de «reabre para sincronizar» —que responde a otra pregunta— y el otro solo tiraba el ancla del export.
//  Sin testigo, el cierre que el ADR §1 exige al cambiar de cuenta era inejecutable.
//
//  POR QUÉ `userRecordID()` Y NO EL TOKEN DE iCLOUD. `FileManager.ubiquityIdentityToken` es la
//  tentación barata —Apple lo documenta para esto— y aquí está **descartado**, con la medición escrita
//  en `.claude/rules/swiftdata-cloudkit.md`: ese token mide iCloud **Drive**, no CloudKit. Con Drive
//  apagado y la sesión de iCloud viva vale `nil` mientras CloudKit funciona, así que una persona que
//  apaga Drive sin tocar su cuenta produciría un token distinto ⇒ «cambiaste de Apple ID» ⇒ se le
//  borrarían los datos. El `userRecordID` lo contesta el canal que de verdad importa, y su ausencia
//  llega como error de la propia llamada, que es la única fuente que no puede discrepar de él.
//
//  POR QUÉ EL CONTENEDOR PERSONAL Y NO EL DE GRUPOS. El repo ya tiene un testigo de identidad iCloud
//  persistido (`GroupICloudIdentitySeed.defaultsKey`), y **no se reusa**: es del contenedor de GRUPOS,
//  que tiene fecha de caducidad escrita en su propia cabecera (el commit 2 de la Fase 4 le retira el
//  entitlement ⇒ a partir de ahí su fetch falla siempre). Colgar de él el cierre de la sesión privada
//  sería atarlo a una pieza que ya sabe que se muere. El contenedor personal es el que espeja esta
//  sesión: es el que tiene que contestar por ella.
//
//  DÓNDE VIVE Y CUÁNTO DURA. `UserDefaults` local, prefijo `cloudSync.` — el mismo que el eje 1 y por
//  la misma razón: **«Vaciar datos» no cambia de quién es este teléfono**, así que el testigo tiene que
//  sobrevivirle (`DataWipeService.removeUserPreferenceKeys` excluye ese prefijo a propósito).
//
//  **MUERE CON LA MARCA, y por eso el borrado vive DENTRO de `PrivateSessionMark`** (`clear()`, y
//  `set(false)`). La primera versión de este fichero afirmaba que moría «en un solo sitio, el
//  boot-wipe», y era FALSO: el eje muere en DOS —el boot-wipe y `clearHandoverPrivateSessionMark`, el
//  relevo de humano de «Empiezo de cero»— y además se APAGA desde ocho sitios más. Con el borrado
//  colgado solo del boot-wipe, el dueño que entrega su teléfono dejaba el testigo de SU Apple ID
//  puesto: la persona siguiente terminaba su onboarding, encendía la marca, y en el arranque de
//  después la app le ofrecía cerrar la sesión y borrarle SUS datos, diciéndole que eran de la cuenta
//  anterior. El invariante es «testigo ⊆ sesión privada viva», y lo único que puede sostenerlo es el
//  embudo por el que ya pasan las nueve escrituras de la marca — no una lista de call-sites que hay
//  que acordarse de ampliar.
//
//  NUNCA AL iCLOUD-KV. Es un hecho del DISPOSITIVO («¿con qué cuenta monté yo?»), no del Apple ID, y
//  el KV viaja justo por la cuenta cuyo cambio se quiere detectar: guardarlo ahí haría que el testigo
//  se mudara con la identidad que vigila. Mismo razonamiento que `PrivateSessionMark`.
//
//  SIN PII EN LOS LOGS: el `recordName` es un identificador de cuenta y JAMÁS se loguea.
//
//  ADR 2026-09-09 §1 · ticket `apple-id-change-should-close-the-private-session`.
//

import CloudKit
import Foundation
import OSLog

nonisolated enum PrivateSessionAppleIDWitness {

    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    /// SSOT de la key. Vive junto a su escritor a propósito: separar la key del `set` es exactamente
    /// cómo se llega a tener una key sin nadie que la escriba (lección de `GroupICloudIdentitySeed`).
    static let userDefaultsKey = "cloudSync.privateSessionAppleIDRecordName"

    // MARK: - Seam

    /// Fetch de la identidad del usuario en el contenedor PERSONAL. Inyectable porque el camino que
    /// importa —«no se pudo preguntar»— hay que poder recorrerlo sin red.
    ///
    /// **El default es el de PRODUCCIÓN, y lo que impide que un host de test salga a CloudKit no es
    /// este seam: es que el cableado del arranque no lo llama bajo test** (`AppBootstrapper`, gateado
    /// por `isRunningTests`/`isUITesting`). Se dice aquí porque un lector que asumiera lo contrario
    /// añadiría un call-site nuevo creyéndolo inerte. Los tests del predicado son puros y no lo tocan;
    /// los que ejercitan el testigo inyectan el suyo y llaman a `_testReset()` después.
    nonisolated(unsafe) static var identityFetcher: @Sendable () async throws -> String = {
        try await CKContainer(identifier: SwiftDataConfiguration.cloudKitContainerIdentifier)
            .userRecordID().recordName
    }

    // MARK: - Lectura

    /// La identidad guardada, o `nil` si nunca se sembró en este dispositivo.
    static func witness(_ defaults: UserDefaults = .standard) -> String? {
        guard let value = defaults.string(forKey: userDefaultsKey), !value.isEmpty else { return nil }
        return value
    }

    /// Le pregunta a CloudKit quién es el usuario de ahora. `nil` = **no se pudo preguntar** (sin red,
    /// sin cuenta, `notAuthenticated`, `managedAccountRestricted`), que no es lo mismo que «cambió»:
    /// el predicado lo trata como «no sé» y no cierra nada.
    ///
    /// El error se loguea sin el identificador y sin `localizedDescription` del payload de cuenta: basta
    /// el código para distinguir una red caída de una cuenta ausente.
    static func currentIdentity() async -> String? {
        do {
            let recordName = try await identityFetcher()
            return recordName.isEmpty ? nil : recordName
        } catch {
            let code = (error as? CKError)?.code.rawValue
            logger.notice("AppleIDWitness: no se pudo leer la identidad de CloudKit (code: \(code ?? -1, privacy: .public))")
            return nil
        }
    }

    // MARK: - Escritura

    /// Guarda la identidad como testigo de esta sesión privada. Ignora el vacío: un testigo en blanco
    /// se leería como «nunca sembrado» y volvería a sembrarse en el arranque siguiente, pero escribirlo
    /// deja una key presente que miente sobre lo que se hizo.
    static func adopt(_ recordName: String, _ defaults: UserDefaults = .standard) {
        guard !recordName.isEmpty else { return }
        defaults.set(recordName, forKey: userDefaultsKey)
    }

    /// El dispositivo vuelve a «recién instalado». **El llamador de producción es `PrivateSessionMark`**
    /// —su `clear()` y su `set(false)`—, que es el embudo por el que pasan las nueve escrituras del eje:
    /// ver la cabecera. Colgarlo de los call-sites uno a uno es exactamente lo que dejó vivo el testigo
    /// del dueño anterior en el relevo de «Empiezo de cero».
    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsKey)
    }

    #if DEBUG
    /// Test-only: devuelve el seam a producción. Lo llaman los tests entre casos.
    static func _testReset() {
        identityFetcher = {
            try await CKContainer(identifier: SwiftDataConfiguration.cloudKitContainerIdentifier)
                .userRecordID().recordName
        }
    }
    #endif
}
