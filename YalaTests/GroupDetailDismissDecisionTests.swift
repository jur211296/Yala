//
//  GroupDetailDismissDecisionTests.swift
//  YalaTests
//
//  Regresión del dismiss-first del detalle de grupo (commit 063f6aff) — lógica pura,
//  sin UI ni SwiftData.
//
//  Los tests con nombre `softDeleted*` son la red del ticket
//  `groups-deleted-group-detail-stays-open`: el soft-delete NO borra la fila (pone
//  `isHiddenForAll`), así que sin su propio parámetro los demás argumentos caían todos
//  en la rama "no cerrar" y el owner se quedaba delante del grupo que acababa de borrar.
//

import Testing

@testable import Yala

struct GroupDetailDismissDecisionTests {

    @Test func contextNil_dismisses() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: true, isDeleted: false, isHiddenForAll: false,
            isArchived: false, wasArchivedOnAppear: false) == true)
    }

    @Test func deleted_dismisses() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: true, isHiddenForAll: false,
            isArchived: false, wasArchivedOnAppear: false) == true)
    }

    @Test func becameArchivedThisSession_dismisses() {
        // Estaba activo al abrir (wasArchivedOnAppear=false) y ahora está archivado → cerrar.
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isHiddenForAll: false,
            isArchived: true, wasArchivedOnAppear: false) == true)
    }

    @Test func alreadyArchivedOnOpen_doesNotDismiss() {
        // El usuario entró a propósito a un grupo YA archivado → NO cerrar.
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isHiddenForAll: false,
            isArchived: true, wasArchivedOnAppear: true) == false)
    }

    @Test func activeAndPresent_doesNotDismiss() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isHiddenForAll: false,
            isArchived: false, wasArchivedOnAppear: false) == false)
    }

    @Test func deletedTakesPrecedenceEvenIfWasArchived() {
        // Borrado gana sobre cualquier estado de archivado.
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: true, isHiddenForAll: false,
            isArchived: true, wasArchivedOnAppear: true) == true)
    }

    // MARK: - Soft-delete (FU-02) — ticket groups-deleted-group-detail-stays-open

    /// El caso del device: owner borra el grupo desde Ajustes. `softDelete` no saca la fila del
    /// store, así que `contextIsNil` e `isDeleted` siguen en false y el grupo sigue activo y sin
    /// archivar. Solo `isHiddenForAll` distingue este estado del de un grupo normal — y sin él
    /// esta misma llamada devolvía `false`, que es exactamente el bug reportado.
    @Test func softDeleted_dismisses() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isHiddenForAll: true,
            isArchived: false, wasArchivedOnAppear: false) == true)
    }

    /// Borrar un grupo que el usuario abrió YA archivado. La excepción de `wasArchivedOnAppear`
    /// existe para no echarle de un archivado al que entró a propósito, pero un borrado sí debe
    /// echarle: aquí la rama del archivado no cierra (`isArchived && !wasArchivedOnAppear` es
    /// false) y el cierre depende ENTERAMENTE del soft-delete. Es el caso donde el bug era más
    /// persistente, y se llega a él sin trucos: la sección de borrar se muestra con solo ser
    /// owner, también dentro de un grupo archivado.
    @Test func softDeletedWhileAlreadyArchivedOnOpen_dismisses() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isHiddenForAll: true,
            isArchived: true, wasArchivedOnAppear: true) == true)
    }

    /// El soft-delete que llega por SYNC (otro device del owner lo borró): `GroupsSyncClient`
    /// escribe `isHiddenForAll` desde el wire y el pull bumpea `dataVersion`, que es el mismo
    /// disparador. Misma entrada que el borrado local — se fija para que el criterio no se
    /// estreche a "solo si lo borré yo en esta pantalla".
    @Test func softDeletedArrivingFromSync_dismisses() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isHiddenForAll: true,
            isArchived: false, wasArchivedOnAppear: true) == true)
    }

    /// Control negativo del parámetro nuevo: con el flag apagado, el criterio anterior queda
    /// intacto. Si alguien invirtiera la condición, este test y `softDeleted_dismisses` no
    /// pueden estar los dos en verde.
    @Test func notSoftDeleted_keepsPreviousBehaviour() {
        #expect(GroupDetailDismissDecision.shouldDismiss(
            contextIsNil: false, isDeleted: false, isHiddenForAll: false,
            isArchived: true, wasArchivedOnAppear: true) == false)
    }
}
