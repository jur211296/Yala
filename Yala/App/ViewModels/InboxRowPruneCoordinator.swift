//
//  InboxRowPruneCoordinator.swift
//  Yala
//
//  Puente MainActor síncrono para que la capa de servicio (DraftService /
//  ScheduledPaymentDraftService) pode la fila del Inbox JUSTO ANTES de borrar un `InboxDraft`.
//
//  Motivación — crash CRÍTICO 2.0.5/iOS 27 (SIGTRAP de SwiftData): `InboxDraftRowView` recibe el
//  `InboxDraft` (@Model) y lee sus propiedades en el `body` (`hasAllRequiredFields`, relaciones,
//  `status`…), por lo que OBSERVA el objeto y re-renderiza al invalidarse — aunque la fila esté
//  visualmente cubierta por un sheet de finalización/conversión de gasto de grupo. La lista del
//  Inbox se dibuja desde el array CACHEADO del `InboxViewModel` (no `@Query`), así que la fila
//  sigue montada hasta que se poda. Si el draft se borra con la fila aún montada, el siguiente
//  render lee un @Model borrado y la app muere. Podar la fila del array ANTES del `context.delete`
//  la desmonta, cerrando la ventana. (El prune vía `dataVersion → loadData()` llega tarde: es
//  asíncrono y no gana la carrera contra el re-render del @Model invalidado — por eso el crash
//  ocurría pese a que los borradores ya llamaban `incrementDataVersion()`.)
//
//  `weak`: se auto-desconecta al cerrarse el Inbox; `pruneRow` es no-op si la bandeja no está
//  montada (un borrado desde otro contexto no tiene fila que crashear).
//

import Foundation
import SwiftData

@MainActor
final class InboxRowPruneCoordinator {
    static let shared = InboxRowPruneCoordinator()
    private init() {}

    weak var viewModel: InboxViewModel?

    /// Llamar SIEMPRE justo antes de `context.delete(<InboxDraft>)` en flujos que borran un draft
    /// con la bandeja potencialmente montada (aprobar/finalizar/convertir gasto de grupo, incluidos
    /// los drafts-puntero hermanos). No-op si el Inbox no está abierto.
    func pruneRow(_ id: PersistentIdentifier) {
        viewModel?.removeDraft(id: id)
    }
}
