//
//  GroupDetailDismissDecision.swift
//  Yala
//
//  Lógica pura del "dismiss-first" del detalle de grupo (commit 063f6aff): al cambiar
//  `dataVersion`, decidir si cerrar la vista ANTES del reload debounced, leyendo el estado
//  del modelo `group` directo (sin carrera con la salida de loadData). Extraída de
//  `GroupDetailView.onChange(dataVersion)` para poder testearla sin UI.
//

import Foundation

enum GroupDetailDismissDecision {
    /// Decide si el detalle de grupo debe cerrarse tras un cambio de `dataVersion`.
    ///
    /// - `contextIsNil`: el `group.modelContext == nil` (el grupo salió del store).
    /// - `isDeleted`: el `group.isDeleted` (borrado local/remoto).
    /// - `isArchived`: estado de archivado ACTUAL del grupo.
    /// - `wasArchivedOnAppear`: si el grupo ya estaba archivado al abrir la vista.
    ///
    /// Cierra si el grupo desapareció del store (context nil / borrado), o si SE archivó
    /// durante esta sesión. NO cierra si ya estaba archivado al abrir (el usuario entró a
    /// propósito a un grupo archivado) ni si sigue activo.
    static func shouldDismiss(
        contextIsNil: Bool,
        isDeleted: Bool,
        isArchived: Bool,
        wasArchivedOnAppear: Bool
    ) -> Bool {
        if contextIsNil || isDeleted { return true }
        if isArchived && !wasArchivedOnAppear { return true }
        return false
    }
}
