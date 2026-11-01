//
//  WidgetGroupsRefresh.swift
//  Yala
//
//  Reescribe la foto de los widgets cuando cambia un saldo de grupo (widget «Grupos», 2.2).
//
//  Los guardados personales ya llaman a `WidgetDataCache.updateCache`; los de Grupos no: ~30 escritores entre
//  `GroupService`, `GroupExpenseService` y el pull del canal, y solo el puente personal la llamaba. Lo que todos hacen es
//  subir `dataVersion`, y de ahí cuelga esto (`SessionState.incrementDataVersion`, molde de
//  `CreditCardReminderScheduler.requestReplan`): junta las subidas de un momento, recalcula SOLO la parte de grupos y
//  rehace la foto entera si cambió. Un guardado personal no la rehace dos veces: su `updateCache` ya apuntó los grupos
//  del momento, y la comprobación los encuentra iguales.
//
//  El pull de Grupos sube `dataVersion` por ciclo (`GroupsSyncClient.onRemoteChangesApplied`). Con la app delante,
//  lo que baja llega al widget en menos de un segundo. Un push silencioso con la app en segundo plano NO: iOS la
//  suspende al contestar el push, antes de que pase la espera, y el widget se pone al día al siguiente despertar o
//  primer plano (card aparte; cambiarlo toca el manejador del push, que es sincronización).
//
import Foundation
import SwiftData

/// La decisión, sin estado: lo que el test fija.
enum WidgetGroupsRefreshLogic {
    /// ¿Hay que rehacer la foto? Solo si los grupos se pudieron leer (un fallo de lectura no borra lo que el widget ya
    /// enseña) y cambiaron respecto a la última foto. Tras retirar la foto (`clearCache`) lo último publicado es `nil`,
    /// así que el primer cambio la rehace: «Vaciar datos» conserva los grupos, y en solo grupos nadie más llama a
    /// `updateCache` (lo cazó la review). Con un borrado armado (cierre de sesión), `updateCache` se niega igual.
    static func needsRebuild(published: WidgetGroupsSummary?, current: WidgetGroupsSummary?) -> Bool {
        guard let current else { return false }
        return current != published
    }

    /// ¿Ya la rehizo alguien después de que se pidiera la comprobación? Un guardado personal sube `dataVersion` y llama
    /// a `updateCache`; si la foto se escribió después de la petición, su builder ya leyó el cambio y recalcular los
    /// grupos otra vez sería doble trabajo en el hilo principal.
    static func alreadyCovered(requestedAt: Date?, publishedAt: Date?) -> Bool {
        guard let requestedAt, let publishedAt else { return false }
        return publishedAt >= requestedAt
    }
}

@MainActor
final class WidgetGroupsRefresh {
    static let shared = WidgetGroupsRefresh()

    private var modelContext: ModelContext?
    /// Los grupos de la última foto de este proceso, y cuándo se escribió. `clearCache` los olvida.
    private var published: WidgetGroupsSummary?
    private var publishedAt: Date?
    /// La ÚLTIMA petición de la espera en curso: un cambio que llega durante la espera, después de una foto escrita por
    /// un guardado personal, tiene que comprobarse igual.
    private var requestedAt: Date?
    private var pending: Task<Void, Never>?

    /// Lo que se junta antes de mirar: un pull aplica varias páginas y sube `dataVersion` una vez por ciclo, y un alta de
    /// gasto lo sube en el servicio y en el puente.
    static let coalesceDelay: Duration = .milliseconds(400)

    private init() {}

    func setContext(_ context: ModelContext?) {
        modelContext = context
        if context == nil {
            pending?.cancel()
            pending = nil
        }
    }

    /// Lo llama `WidgetDataCache.updateCache` con los grupos que acaba de escribir.
    func notePublished(_ groups: WidgetGroupsSummary?, at date: Date = .now) {
        published = groups
        publishedAt = date
    }

    /// Lo llama `WidgetDataCache.clearCache`.
    func noteCleared() {
        published = nil
        publishedAt = nil
    }

    /// Hook de una línea para `incrementDataVersion`. Sin contexto (antes del paso 16 del arranque, o en tests que no lo
    /// fijan) no hace nada; con una comprobación ya en espera, se suma a ella.
    func requestCheck(now: Date = .now) {
        guard modelContext != nil else { return }
        requestedAt = now
        guard pending == nil else { return }
        pending = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.coalesceDelay)
            } catch {
                return
            }
            guard let self else { return }
            self.pending = nil
            let requested = self.requestedAt
            self.requestedAt = nil
            guard !WidgetGroupsRefreshLogic.alreadyCovered(requestedAt: requested, publishedAt: self.publishedAt)
            else { return }
            self.check()
        }
    }

    /// Recalcula la parte de grupos y rehace la foto si cambió. Devuelve si la rehizo.
    @discardableResult
    func check() -> Bool {
        // Con un borrado armado `updateCache` se niega: no se calcula nada para nada.
        guard let context = modelContext, !WidgetDataCache.isWipeArmed else { return false }
        let current = WidgetGroupsSnapshotBuilder.build(context: context)
        guard WidgetGroupsRefreshLogic.needsRebuild(published: published, current: current) else { return false }
        WidgetDataCache.updateCache(context: context)
        return true
    }
}
