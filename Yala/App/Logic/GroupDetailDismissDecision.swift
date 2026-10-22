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
    /// - `isHiddenForAll`: el soft-delete FU-02 (`SplitGroup.isHiddenForAll`).
    /// - `isArchived`: estado de archivado ACTUAL del grupo.
    /// - `wasArchivedOnAppear`: si el grupo ya estaba archivado al abrir la vista.
    ///
    /// Cierra si el grupo desapareció del store (context nil / borrado), si lo borraron con
    /// el soft-delete, o si SE archivó durante esta sesión. NO cierra si ya estaba archivado
    /// al abrir (el usuario entró a propósito a un grupo archivado) ni si sigue activo.
    ///
    /// **Por qué el soft-delete necesita su propia señal.** `GroupService.softDelete` no borra
    /// la fila: pone `isHiddenForAll = true`, guarda y bumpea `dataVersion`. Así que ni
    /// `contextIsNil` ni `isDeleted` (que es el de SwiftData — fila fuera del store) se
    /// encienden, y sin este parámetro los cuatro que había caían todos en la rama "no cerrar": el
    /// owner confirmaba dos veces un borrado irreversible y se quedaba delante del mismo grupo,
    /// con sus gastos y su título, teniendo que tocar Atrás a mano para comprobar que la app
    /// le había hecho caso (device QA TF 2.1 build 12, ticket
    /// `groups-deleted-group-detail-stays-open`). Las otras dos salidas destructivas de la sheet
    /// de Ajustes ya cerraban: archivar por la rama de `isArchived`, y salir del grupo porque
    /// `performLocalCleanupAndDelete` sí borra la fila y enciende `isDeleted`.
    ///
    /// **Sin equivalente a `wasArchivedOnAppear`, a propósito.** Un grupo archivado es un destino
    /// legítimo (tiene su sección en la lista); uno soft-deleted no lo es: las cuatro puertas al
    /// push del detalle salen de `activeGroups`/`filteredGroups`, que filtran `!isHiddenForAll`,
    /// así que no existe el caso "entré a propósito a un grupo oculto" que haya que respetar.
    static func shouldDismiss(
        contextIsNil: Bool,
        isDeleted: Bool,
        isHiddenForAll: Bool,
        isArchived: Bool,
        wasArchivedOnAppear: Bool
    ) -> Bool {
        if contextIsNil || isDeleted || isHiddenForAll { return true }
        if isArchived && !wasArchivedOnAppear { return true }
        return false
    }
}
