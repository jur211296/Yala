//
//  PersonalExportPendingCounter.swift
//  Yala
//
//  Paso 9 del rediseño de sesiones: cuenta los cambios LOCALES del store personal que el espejo de
//  CloudKit todavía podría no haber subido. Es el número que la salida de emergencia del cierre privado
//  enseña («cambios que aún no llegaron a iCloud: N», decisión de Jürgen del 2026-09-09) y el cero que
//  autoriza a borrar. La decisión de qué transacción cuenta es pura y vive en
//  `PrivateSignOutExportGateLogic.isPendingLocalWrite`; aquí se lee el historial y se agrupa por objeto.
//
//  Cuenta OBJETOS distintos, no transacciones: un gasto editado tres veces es un cambio para quien lo
//  lee, y es también lo que el espejo sube (un registro por objeto).
//
//  El `> 0` sobre `updatedAttributes` descuenta la actualización SIN atributos. **Es cinturón, no el
//  mecanismo**: medido con mutante el 2026-09-11 (M15, quitarle el `> 0`), la reescritura idéntica de
//  `swiftdata-cloudkit.md` no llega hasta aquí — el historial no entrega NINGUNA actualización para
//  ella, ni siquiera una con la lista vacía, así que el cero de ese caso lo da el historial y no este
//  filtro. Ningún test lo mata, y por eso se dice aquí en vez de fingir que lo cubre.
//
//  **Lo creado y borrado después del ancla SÍ cuenta** (review adversarial del paso 9). El ancla es el
//  INICIO de un export, y ese export pudo llevarse el alta si la leyó del historial después de que se
//  guardara: entonces el objeto está en iCloud, el borrado tiene que viajar, y si no viaja el objeto
//  reaparece al restaurar. El borrado es un cambio del historial, así que el espejo lo exporta y el
//  contador vuelve a cero en el export siguiente. Contar de más cuesta una espera; netear resucitaba datos.
//
//  Solo lee: ningún `save()`, así que puede correr con un import en marcha sin tocar el invariante de
//  quiescencia del contexto compartido.
//
//  **Lo que la app escribe sola no es un cambio tuyo** (card «Cerrar sesión en una cuenta vacía dice “Cambios por
//  subir: 893”», 2026-11-19). Medido en el simulador: una cuenta nueva en iCloud privado, sin tocar nada, deja 80
//  objetos en el historial (11 categorías, 62 subcategorías y 7 avisos de serie); en un iPhone se suma un año de tipos
//  de cambio, una fila por día. Con un ancla anterior al alta —el ancla sobrevive al borrado del cierre— todo eso salía
//  como «Cambios por subir» y el cierre esperaba su subida. No cuentan:
//   - **los tipos de cambio** (`rebuildableEntityNames`), en cualquier cambio: son una caché que la app vuelve a bajar;
//     cada movimiento guarda su propia tasa e importe convertido;
//   - **lo que la app creó sola y nadie tocó después** (`untouchedAppDefaults`): solo con un ALTA tras el ancla y ningún
//     cambio ni borrado posterior, y solo si sigue siendo lo que la app vuelve a crear al entrar (categoría o
//     subcategoría de serie o de sistema; aviso de serie con sus valores de serie). Si la persona lo editó, cuenta.
//  Un borrado cuenta siempre (salvo de tipos de cambio): no se sabe si lo borrado estaba ya en iCloud.
//

import Foundation
import SwiftData

@MainActor
enum PersonalExportPendingCounter {

    /// Holgura del fetch por timestamp: se pide un segundo antes del ancla y el filtro exacto lo hace la
    /// lógica pura. El predicado `>` sobre `timestamp` es el que el motor ya usa en producción
    /// (`CloudSyncEngine.recoverIfHistoryTokenIncomparable`); no se estrena otro.
    static let fetchSlack: TimeInterval = 1

    /// Cambios locales pendientes de subir. `nil` = no hay forma honesta de dar un número:
    ///  - el historial no se pudo leer, o
    ///  - **no hay ancla** (nunca se vio un export con éxito) y hay escrituras locales: sin ancla no se sabe
    ///    cuáles viajaron ya, y un número inventado («3.412 cambios sin subir» a quien lo tiene todo en
    ///    iCloud) sería un aviso de pérdida falso. Sin ancla y sin escrituras locales sí es un cero honesto.
    ///
    /// El `nil` NUNCA es un cero: la espera lo trata como «no se puede demostrar» y jamás borra por él.
    ///
    /// El historial es por CONTAINER (tres stores); se acota al personal por NOMBRE DE ENTIDAD, que es la
    /// única vía: `storeIdentifier` no es un keypath soportado en el `#Predicate` de un `HistoryDescriptor`
    /// (medido en `GroupsDrainHistoryStoreAnchorTests`).
    static func pendingChangeCount(context: ModelContext, confirmedExportStart: Date?) -> Int? {
        let transactions: [DefaultHistoryTransaction]
        do {
            if let confirmedExportStart {
                let cutoff = confirmedExportStart.addingTimeInterval(-fetchSlack)
                transactions = try context.fetchHistory(
                    HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp > cutoff }))
            } else {
                transactions = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
            }
        } catch {
            #if DEBUG
            print("PersonalExportPendingCounter: Error leyendo el historial: \(error)")
            #endif
            return nil
        }

        // Altas y el resto por separado: una alta sin nada después puede ser algo que la app creó sola.
        var inserted: Set<PersistentIdentifier> = []
        var touched: Set<PersistentIdentifier> = []
        for transaction in transactions where PrivateSignOutExportGateLogic.isPendingLocalWrite(
            timestamp: transaction.timestamp,
            author: transaction.author,
            confirmedExportStart: confirmedExportStart
        ) {
            for change in transaction.changes {
                let identifier = change.changedPersistentIdentifier
                guard CloudSyncEngine.personalStoreEntityNames.contains(identifier.entityName),
                      !rebuildableEntityNames.contains(identifier.entityName) else { continue }
                switch change {
                case .insert:
                    inserted.insert(identifier)
                case .delete:
                    touched.insert(identifier)
                case .update(let update):
                    if personUpdatedAttributeCount(update) > 0 { touched.insert(identifier) }
                @unknown default:
                    touched.insert(identifier)  // un cambio que no sabemos leer cuenta: el lado seguro
                }
            }
        }
        let onlyInserted = inserted.subtracting(touched)
        let appDefaults = untouchedAppDefaults(among: onlyInserted, context: context)
        let pending = inserted.union(touched).subtracting(appDefaults).count
        if confirmedExportStart == nil { return pending == 0 ? 0 : nil }
        return pending
    }

    /// Entidades del store personal que la app reconstruye sola y que nunca son un cambio de la persona: los tipos de
    /// cambio vienen de la API y se vuelven a bajar al entrar (`ExchangeRateService.preloadHistoricalIfNeeded`).
    static let rebuildableEntityNames: Set<String> = ["ExchangeRate"]

    /// De las altas sin nada posterior, las que la app vuelve a crear igual al entrar: categorías y subcategorías de
    /// serie o de sistema, y avisos de serie que siguen con sus valores de serie. Un fallo al leer devuelve `[]`: entonces
    /// todo cuenta, que es el lado seguro (esperar de más, nunca borrar algo de la persona sin subirlo).
    static func untouchedAppDefaults(
        among candidates: Set<PersistentIdentifier>, context: ModelContext
    ) -> Set<PersistentIdentifier> {
        guard !candidates.isEmpty else { return [] }
        do {
            if _testThrowOnDefaultsFetch { throw CocoaError(.fileReadUnknown) }
            var defaults: Set<PersistentIdentifier> = []
            for category in try context.fetch(FetchDescriptor<Category>(
                predicate: #Predicate { $0.isDefaultSeed || $0.isSystem })) {
                defaults.insert(category.persistentModelID)
            }
            for subcategory in try context.fetch(FetchDescriptor<Subcategory>(
                predicate: #Predicate { $0.isDefaultSeed || $0.isSystem })) {
                defaults.insert(subcategory.persistentModelID)
            }
            let serie = Dictionary(
                NotificationItem.createDefaults().map { ($0.typeRaw, NotificationDefaultShape($0)) },
                uniquingKeysWith: { first, _ in first })
            for notification in try context.fetch(FetchDescriptor<NotificationItem>())
            where serie[notification.typeRaw] == NotificationDefaultShape(notification) {
                defaults.insert(notification.persistentModelID)
            }
            return candidates.intersection(defaults)
        } catch {
            #if DEBUG
            print("PersonalExportPendingCounter: Error leyendo lo creado por la app: \(error)")
            #endif
            return []
        }
    }

    /// Seam de test: hace fallar la lectura de lo creado por la app DENTRO del `do`, para fijar que un fallo cuenta todo.
    /// Estático: resetéalo en `defer`.
    static var _testThrowOnDefaultsFetch = false

    /// Lo que la persona puede cambiar de un aviso. Igual al de serie ⇒ entrar en Yala lo vuelve a crear idéntico.
    ///
    /// La configuración de los informes se compara DECODIDA: es un JSON cuyo orden de claves cambia de una codificación a
    /// otra (medido en la suite, 2026-11-19: dos avisos de serie salían «distintos» unas corridas sí y otras no).
    private struct NotificationDefaultShape: Equatable {
        let name: String, text: String, hour: Int, minute: Int, isActive: Bool
        let iconName: String, colorHex: String, report: ReportConfig?, weekdaysRaw: String?
        init(_ item: NotificationItem) {
            name = item.name; text = item.text; hour = item.hour; minute = item.minute; isActive = item.isActive
            iconName = item.iconName; colorHex = item.colorHex; weekdaysRaw = item.weekdaysRaw
            report = item.configurationData.flatMap { ReportConfig.fromData($0) }
        }
    }

    /// Atributos que solo escribe la app, y que cualquier teléfono vuelve a calcular igual al arrancar. Medido en el
    /// simulador (2026-11-19): el segundo arranque de una cuenta nueva escribe el papel de sistema de tres subcategorías de
    /// serie (`SubcategorySystemRoleBackfill`, en cada arranque), y sin esto salían como «3 cambios por subir».
    static let appMaintainedAttributes: Set<AnyKeyPath> = [\Subcategory.systemRoleRaw]

    /// Abre el existencial del update para contar sus atributos (el tipo del modelo es su `associatedtype`), sin los que
    /// solo escribe la app (`appMaintainedAttributes`).
    private static func personUpdatedAttributeCount<U: HistoryUpdate>(_ update: U) -> Int {
        update.updatedAttributes.filter { !appMaintainedAttributes.contains($0) }.count
    }
}
