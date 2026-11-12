//
//  NewRecordDraft.swift
//  Yala
//
//  Lo escrito en un «Nuevo registro» mientras su hoja sigue abierta (card «Nuevo registro a medias vuelve vacío»,
//  2026-11-04). Al entrar a Yala desde fuera (voz, foto compartida, enlace al Panel) con el formulario a medias en
//  otra pestaña, SwiftUI podía rehacer el CONTENIDO de la hoja sin cerrarla —mismo proceso, misma escena, barra de
//  pestañas intacta (marcador `uitest_lifecycle`: `formularios=3`)— y el formulario nacía vacío, porque su estado vivía
//  en un `@State` de la propia hoja. El borrador lo guarda quien presenta la hoja, que no se rehace: el formulario
//  rehecho retoma su modelo y su foto de partida.
//
//  Solo en memoria (decisión de Jürgen, 2026-11-04): este borrador cubre la hoja rehecha con Yala viva. Que iOS cierre
//  Yala lo cubre otro, en disco y con caducidad de 24 h (`NewRecordDraftStore`, card 77j1, decisión A de Jürgen del
//  mismo día). Se descarta en el `onDismiss` de la hoja, que corre al cerrarla o al guardar, y no al rehacerse.
//
//  Clase sin observación a propósito: el formulario lo lee en su `init` y en su primer `onAppear`, y nada se pinta con
//  él; observarlo invalidaría la vista que presenta al escribirlo durante su propio cuerpo.
//

import SwiftUI

@MainActor
final class NewRecordDraft {
    /// El modelo del formulario abierto. `nil` hasta que el primer formulario lo crea.
    private(set) var viewModel: NewTransactionViewModel?
    /// La foto de lo precargado al abrir (L2-4): con ella, cerrar el formulario retomado sigue preguntando si hay algo
    /// escrito. `nil` hasta el primer `onAppear`.
    var baseline: NewTransactionViewModel.FormSnapshot?

    init() {}

    /// El modelo del formulario: el guardado si la hoja ya tenía uno, uno nuevo si no (y se queda guardado).
    func resolveViewModel() -> NewTransactionViewModel {
        if let viewModel { return viewModel }
        let fresh = NewTransactionViewModel()
        viewModel = fresh
        return fresh
    }

    /// «Registrar otro» sustituye el modelo: el borrador sigue al nuevo.
    func adopt(_ viewModel: NewTransactionViewModel) {
        self.viewModel = viewModel
    }

    /// Hay un formulario a medias que retomar (ya pasó por su primer `onAppear`).
    var isResumable: Bool { viewModel != nil && baseline != nil }

    /// El formulario de esta hoja escribió o recuperó el borrador en disco (`NewRecordDraftStore`, card 77j1). Vive aquí
    /// y no en el formulario porque un formulario rehecho tiene que seguir sabiéndolo.
    var ownsSavedDraft = false

    /// La hoja se cerró (descartar, X sin cambios, guardar): la próxima apertura empieza de cero, y el borrador en disco
    /// de este formulario ya no hace falta.
    func discard(savedDraftsIn defaults: UserDefaults = .standard) {
        viewModel = nil
        baseline = nil
        if ownsSavedDraft { NewRecordDraftStore.clear(in: defaults) }
        ownsSavedDraft = false
    }
}

extension View {
    /// La identidad del contenido de la hoja de «Nuevo registro». Fuera de los tests no cambia nunca; con
    /// `-uitest-rebuild-form-on-return` cambia al volver a primer plano y fuerza el rehecho que el borrador cubre.
    func newRecordSheetIdentity() -> some View {
        id(UITestHooks.shared.formRebuildToken)
    }
}
