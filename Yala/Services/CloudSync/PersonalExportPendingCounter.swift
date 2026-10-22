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

        var touched: Set<PersistentIdentifier> = []
        for transaction in transactions where PrivateSignOutExportGateLogic.isPendingLocalWrite(
            timestamp: transaction.timestamp,
            author: transaction.author,
            confirmedExportStart: confirmedExportStart
        ) {
            for change in transaction.changes {
                let identifier = change.changedPersistentIdentifier
                guard CloudSyncEngine.personalStoreEntityNames.contains(identifier.entityName) else { continue }
                switch change {
                case .insert, .delete:
                    touched.insert(identifier)
                case .update(let update):
                    if updatedAttributeCount(update) > 0 { touched.insert(identifier) }
                @unknown default:
                    touched.insert(identifier)  // un cambio que no sabemos leer cuenta: el lado seguro
                }
            }
        }
        let pending = touched.count
        if confirmedExportStart == nil { return pending == 0 ? 0 : nil }
        return pending
    }

    /// Abre el existencial del update para leer sus atributos (el tipo del modelo es su `associatedtype`).
    private static func updatedAttributeCount<U: HistoryUpdate>(_ update: U) -> Int {
        update.updatedAttributes.count
    }
}
