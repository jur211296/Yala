//
//  SecondarySessionRetirement.swift
//  Yala
//
//  LA ÚNICA PIEZA DEL BARRIDO DE M1 QUE NO ES UN BORRADO: la retirada de lo que la sesión de visita
//  pudo dejar EN DISCO antes de que su código desapareciera.
//
//  POR QUÉ EXISTE. El ADR 2026-09-09 «Sesiones — dos ejes» retira la sesión secundaria, y con ella se
//  van su descriptor, sus tres stores y su cajón de preferencias. Borrar el código no borra los bytes:
//  un dispositivo que llegó a tener una visita activa se queda con `YalaModel-Secondary` y compañía
//  ocupando espacio, con las preferencias de otra persona dentro, y sin una sola línea de la app que
//  sepa que existen. Decisión de Jürgen (2026-09-09): «`YalaModel-Secondary` se borra del disco al
//  actualizar».
//
//  A QUIÉN ALCANZA DE VERDAD, medido antes de escribirlo — **en pasado, porque este mismo PR se lleva
//  las pruebas.** Hasta el 2026-09-13, la entrada en producción nunca llegó a abrirse: el percent propio
//  del feature estaba en `0` en el bloque de producción del gateway, el `absentDefault` del flag remoto
//  era fail-closed antes del primer fetch, y desde el 2026-09-12 el encendido compilado también estaba
//  en `false`. El único escritor del descriptor vivía detrás de esos tres, así que **en el parque de
//  TestFlight nadie pudo crear estos archivos**; donde sí pueden existir es en un build DEV contra
//  staging, que servía `100`. El PR retira la var del gateway y el flag del cliente, así que esa
//  medición ya no es reproducible desde el árbol de hoy: se comprueba en `git show HEAD~1` o en el
//  parte del ticket `shell-derives-from-two-session-axes`. Esto corre igual en los dos entornos: es
//  barato, y la alternativa —«seguro que no hay nada»— es justo la clase de suposición que este repo
//  paga cara.
//
//  KILL-SAFE **Y FAILURE-SAFE, que no es lo mismo y costó un hallazgo de review.** Cada paso es
//  idempotente por sí mismo (borrar un archivo que no está es un no-op, y `removeObject` sobre una key
//  ausente también), así que un kill a mitad deja el trabajo a medias y el arranque siguiente lo repite
//  entero. Pero un kill no es el único modo de fallo: **el borrado del archivo puede FALLAR** —una
//  protección de datos, un `-wal` retenido, un error de I/O— y la primera versión de esto tiraba ese
//  resultado y escribía la marca igual. Con eso, el corpus de otra persona se quedaba en el teléfono
//  del dueño para siempre, porque el arranque siguiente ya no volvía a mirar. Ahora la marca se escribe
//  **solo si los tres archivos se fueron**, y si alguno no se pudo borrar queda rastro y se reintenta.
//
//  EL ORDEN DE LOS DOS ÚLTIMOS PASOS NO ES LIBRE. El cajón de la visita se llama `yala.session.<sub>`
//  y ese `<sub>` solo vive dentro del descriptor: destruirlo DESPUÉS de borrar el descriptor sería
//  dejarlo huérfano para siempre, con el nombre y la divisa de otra persona dentro del teléfono del
//  dueño. Es la misma trampa que documentaba el código del cajón, y sobrevive a su fichero porque el
//  orden sigue importando aquí. Por si el descriptor ya se hubiera perdido en una versión
//  anterior, además se barre el directorio de preferencias por prefijo: los dos caminos son
//  complementarios y ninguno basta solo.
//
//  LO QUE **NO** ALCANZA, y conviene decirlo aquí porque el nombre del tipo promete más: esto limpia el
//  CONTENEDOR de la app, no el Keychain. `CloudAuthKeychainStorage` guarda la sesión de nube bajo un
//  único `kSecAttrService` para todo el proceso —no está particionado por sesión, medido— así que si la
//  persona invitada llegó a firmar con su cuenta, su sesión sobrevive a esta retirada. Con el alcance
//  de arriba eso solo puede pasar en un teléfono de QA o en un build DEV, y por eso tiene ticket propio
//  (`secondary-session-retirement-leaves-the-guest-cloud-session`) en vez de un paso más aquí.
//
//  ADR 2026-09-09 «Sesiones — dos ejes» · ticket `shell-derives-from-two-session-axes` (paso 12, PR-B).
//

import Foundation

nonisolated enum SecondarySessionRetirement {

    /// Marca de «la retirada ya corrió en este dispositivo». Lleva el prefijo `cloudSync.` para que
    /// `DataWipeService.removeUserPreferenceKeys` la excluya: vaciar los datos no resucita los archivos
    /// de una visita que ya no existe, así que volver a barrer no tendría nada que encontrar.
    static let doneKey = "cloudSync.secondarySessionRetired"

    /// Las cuatro preferencias que el descriptor y sus banderas ocupaban. Son literales a propósito:
    /// los tipos que las declaraban se borran en este mismo PR, y una retirada que dependiera de ellos
    /// no podría existir. `cloudSync.debug.secondarySessionEnabled` entra porque un teléfono de QA con
    /// el toggle puesto se lo llevaría puesto para siempre.
    static let legacyDefaultsKeys = [
        "cloudSync.secondarySession.userID",
        "cloudSync.secondaryWipeArmed",
        "cloudSync.secondarySession.entryPurgeDone",
        "cloudSync.debug.secondarySessionEnabled"
    ]

    /// Las preferencias del modelo viejo de sesiones: por dónde entró la persona y qué eligió usar. Las
    /// dos murieron con la sesión de visita —hoy la shell la decide `PrivateSessionMark`— y ninguna tiene
    /// ya lector, así que lo que queda en disco es basura con un nombre que confunde. Ojo: `onboardingMode`
    /// tenía además una copia en el iCloud-KV del Apple ID, y ésa **no se toca desde aquí**: borrar en el
    /// KV viaja a todos los dispositivos de esa persona, y la retirada es un hecho de ESTE teléfono. Se
    /// queda inerte (nadie la lee) y se va con la cuenta el día que se borre.
    static let legacySessionModeKeys = ["onboardingMode", "usageFocus"]

    /// Prefijo del cajón de preferencias por sesión. El sufijo era el `sub` de la cuenta de la visita.
    static let legacySuitePrefix = "yala.session."

    /// Sufijo de los tres stores de la visita. Los nombres completos se componen sobre los del
    /// dispositivo (`YalaModel` / `YalaModel-Dev`) para que un build DEV borre los suyos y no los de un
    /// build de producción que comparta el aparato.
    static let legacyStoreSuffix = "-Secondary"

    // MARK: - Producción

    /// Corre PRE-MOUNT, en el mismo punto del arranque donde vivían los dos hooks de frontera de M1.
    ///
    /// Los guards de entorno son los mismos que tenían aquellos: bajo tests y bajo XCUITest no hay nada
    /// que retirar —el descriptor de los XCUITest vive en el dominio volátil— y tocar el disco ahí solo
    /// añadiría una fuente de ruido entre corridas.
    @MainActor
    static func purgeIfNeeded() {
        guard !SwiftDataConfiguration.isRunningTests, !SwiftDataConfiguration.isUITesting else { return }
        purgeIfNeeded(
            defaults: .standard,
            storeNames: [
                SwiftDataConfiguration.databaseName + legacyStoreSuffix,
                SwiftDataConfiguration.syncMetaDatabaseName + legacyStoreSuffix,
                SwiftDataConfiguration.groupsDatabaseName + legacyStoreSuffix
            ],
            deleteStore: { SwiftDataConfiguration.deleteLegacyStoreFiles(named: $0) },
            orphanSuiteNames: { orphanSuiteNamesOnDisk() },
            purgeSharedSurfaces: {
                WidgetDataCache.clearCache()
                AppGroupInboundPurge.purgeInboundSurfaces()
                NotificationService.shared.cancelAllNotifications()
                NotificationService.shared.clearDeliveredNotifications()
            })
    }

    /// Variante inyectable: los tests ejercitan el ORDEN y la idempotencia sin tocar archivos reales.
    ///
    /// - Parameters:
    ///   - storeNames: los tres stores de la visita, ya compuestos con la variante del dispositivo.
    ///   - deleteStore: borra el trío SQLite (base + `-wal` + `-shm`) de un nombre de store.
    ///   - deleteStore: borra el trío SQLite de un nombre de store. **Devuelve `false` solo si el
    ///     archivo BASE existía y no se pudo borrar** — que no exista es éxito.
    ///   - orphanSuiteNames: cajones `yala.session.*` que siguen en el directorio de preferencias.
    ///     Cubre el caso en que el descriptor se perdiera antes de esta versión.
    ///   - purgeSharedSurfaces: lo que la frontera de la visita limpiaba y los archivos no alcanzan —
    ///     el snapshot del widget en el App Group, las colas de Apple Pay/Siri/imágenes y las
    ///     notificaciones. **Corre SOLO si este teléfono tuvo visita de verdad**, y ese condicional es
    ///     el fondo del asunto: purgar a ciegas le borraría al 100 % del parque su cola pendiente y su
    ///     widget, que es un daño nuevo mucho mayor que el residuo que viene a limpiar.
    @discardableResult
    static func purgeIfNeeded(
        defaults: UserDefaults,
        storeNames: [String],
        deleteStore: (String) -> Bool,
        orphanSuiteNames: () -> [String] = { [] },
        destroySuite: (String) -> Void = { name in
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        },
        purgeSharedSurfaces: () -> Void = {}
    ) -> Bool {
        guard !defaults.bool(forKey: doneKey) else { return false }

        // **¿Hubo visita en este teléfono?** Se decide ANTES de borrar nada, porque las dos señales que
        // lo dicen —el descriptor y las banderas— están entre lo que esta función retira.
        let tuvoVisita = legacyDefaultsKeys.contains { defaults.object(forKey: $0) != nil }
            || !orphanSuiteNames().isEmpty

        var todosBorrados = true
        for name in storeNames where !deleteStore(name) {
            todosBorrados = false
        }

        // El cajón NOMBRADO por el descriptor primero, mientras el descriptor sigue ahí. El saneado del
        // `sub` reproduce el que componía el nombre: mismo `sub` ⇒ mismo nombre, que es lo que permite
        // destruirlo. Un `sub` que no deje ni un carácter utilizable no compone nombre y no se
        // toca nada — jamás se resuelve un dominio «por defecto», que borraría el del dueño entero.
        if let userID = defaults.string(forKey: legacyDefaultsKeys[0]), !userID.isEmpty {
            let sanitized = userID.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
            if !sanitized.isEmpty {
                destroySuite(legacySuitePrefix + sanitized)
            }
        }

        // Y los que ya no tienen quien los nombre.
        for name in orphanSuiteNames() {
            destroySuite(name)
        }

        for key in legacyDefaultsKeys + legacySessionModeKeys {
            defaults.removeObject(forKey: key)
        }

        // Las superficies COMPARTIDAS, y solo para quien tuvo visita. El snapshot del widget con los
        // saldos de la otra persona vivía en el App Group, no en el store; y su defensa —el sello que
        // lo marcaba— se retira en este mismo PR, así que si no se limpia aquí no lo rechaza ya nadie.
        if tuvoVisita {
            purgeSharedSurfaces()
        }

        // **La marca, solo si el disco quedó limpio.** Si algún archivo se resistió, no se escribe: el
        // arranque siguiente lo reintenta entero. Un `false` aquí es la diferencia entre un residuo
        // temporal y uno permanente.
        guard todosBorrados else {
            CloudSyncBreadcrumb.secondarySessionRetirementIncomplete()
            return false
        }
        defaults.set(true, forKey: doneKey)
        return true
    }

    // MARK: - Cajones huérfanos

    /// Los `yala.session.*` que quedan en el directorio de preferencias del contenedor.
    ///
    /// Un suite de `UserDefaults` se materializa como `<contenedor>/Library/Preferences/<nombre>.plist`,
    /// así que enumerarlo por prefijo encuentra los que ningún descriptor puede ya nombrar. Si el
    /// directorio no existe o no se puede leer, devuelve vacío: la retirada pierde este camino y
    /// conserva el otro, que es la dirección de fallo barata.
    static func orphanSuiteNamesOnDisk(
        fileManager: FileManager = .default
    ) -> [String] {
        guard let preferences = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Preferences") else { return [] }
        let entries: [String]
        do {
            entries = try fileManager.contentsOfDirectory(atPath: preferences.path)
        } catch {
            // Con `try?` este fallo era invisible, y no es un no-evento: sin este camino los cajones
            // que perdieron su descriptor se quedan en el teléfono con datos de otra persona dentro.
            #if DEBUG
            print("SecondarySessionRetirement: no se pudo enumerar Preferences: \(error)")
            #endif
            return []
        }
        return entries
            .filter { $0.hasPrefix(legacySuitePrefix) && $0.hasSuffix(".plist") }
            .map { String($0.dropLast(".plist".count)) }
    }
}
