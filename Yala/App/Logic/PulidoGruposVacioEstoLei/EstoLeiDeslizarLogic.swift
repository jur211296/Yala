//
//  EstoLeiDeslizarLogic.swift
//  Yala
//
//  Deslizar una tarjeta de «Esto leí» con la hoja en grande (decisión de Jürgen, 27-nov-2026): una lectura nueva se
//  descarta a Archivados, como «Descartar» del editor y de la Bandeja; una ya guardada borra el registro que creó, con la
//  misma pregunta que «Eliminar» de un registro (elegido por Jürgen el 27-nov: «Borra el registro»).
//
//  Lo que decide el gesto (cuánto se mueve, si se abre, si se ejecuta) vive aquí para poder probarlo sin pantalla.
//

import CoreGraphics
import Foundation
import SwiftData

enum EstoLeiDeslizarLogic {

    enum Accion: Equatable {
        /// Lectura nueva: a Archivados, con «Deshacer».
        case descartar
        /// Ya guardada: borra el registro que creó, tras confirmarlo.
        case eliminar
    }

    /// Qué hace deslizar esta fila, o `nil` si no se desliza. Lo de un grupo no se borra desde aquí: se borra en su grupo
    /// (`RecordBulkActionLogic`), igual que en Registros.
    static func accion(isPending: Bool, isSaved: Bool, canDiscard: Bool, recordDeletable: Bool) -> Accion? {
        if isPending { return canDiscard ? .descartar : nil }
        if isSaved { return recordDeletable ? .eliminar : nil }
        return nil
    }

    // MARK: - El gesto

    /// Lo que mide el botón que asoma detrás de la tarjeta.
    static let anchoBoton: CGFloat = 96

    /// Fracción del ancho a partir de la cual soltar ejecuta la acción sin tocar el botón, como un deslizamiento completo
    /// de una lista del sistema.
    static let fraccionCompleta: CGFloat = 0.6

    enum AlSoltar: Equatable {
        case cerrar
        case abrir
        case ejecutar
    }

    /// Dónde va la tarjeta mientras el dedo la arrastra: nunca a la derecha de su sitio ni más allá de su ancho.
    static func desplazamiento(traslacion: CGFloat, abierto: Bool, ancho: CGFloat) -> CGFloat {
        let base: CGFloat = abierto ? -anchoBoton : 0
        let tope = max(ancho, anchoBoton)
        return min(0, max(-tope, base + traslacion))
    }

    /// Al soltar: más allá de `fraccionCompleta` del ancho, ejecuta; más allá de medio botón, se queda abierta; si no, vuelve.
    static func alSoltar(traslacion: CGFloat, abierto: Bool, ancho: CGFloat) -> AlSoltar {
        let recorrido = -desplazamiento(traslacion: traslacion, abierto: abierto, ancho: ancho)
        if ancho > 0, recorrido >= ancho * fraccionCompleta { return .ejecutar }
        if recorrido >= anchoBoton / 2 { return .abrir }
        return .cerrar
    }

    // MARK: - La hoja tras quitar una fila

    /// Tras quitar una fila: sin filas (ni de las pasadas a un grupo), la hoja se cierra; con todo lo que queda guardado,
    /// se cierra como al guardar; si no, sigue con lo que queda.
    enum DespuesDeQuitar: Equatable {
        case cerrarHoja
        case cerrarComoAlGuardar
        case seguir
    }

    static func despuesDeQuitar(filasRestantes: Int, pendientesRestantes: Int) -> DespuesDeQuitar {
        if filasRestantes == 0 { return .cerrarHoja }
        if pendientesRestantes == 0 { return .cerrarComoAlGuardar }
        return .seguir
    }
}

extension EstoLeiDeslizarLogic {
    /// La acción de un borrador de la hoja. Uno ya borrado no se lee (leer un modelo borrado aborta en el teléfono).
    @MainActor
    static func accion(for draft: InboxDraft) -> Accion? {
        guard !draft.isDeleted, draft.modelContext != nil else { return nil }
        let deletable = draft.approvedTransaction.map { record in
            !record.isDeleted && record.modelContext != nil
                && RecordBulkActionLogic.allows(.delete, .init(record: record))
        } ?? false
        return accion(
            isPending: draft.status == .pending,
            isSaved: draft.status == .approved,
            canDiscard: !draft.sourceType.blocksInboxDismissal,
            recordDeletable: deletable
        )
    }
}

/// El borrado del registro que creó una lectura ya guardada: el mismo que «Eliminar» del editor de un registro
/// (`NewTransactionView.deleteTransaction`), con su pareja si es una transferencia.
@MainActor
enum EstoLeiBorrarRegistro {
    static func borrar(_ transaction: TransactionItem, context: ModelContext) throws {
        if transaction.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer,
           let pairID = transaction.transferPairID {
            let fetchPairID = pairID
            let descriptor = FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.transferPairID == fetchPairID })
            for pair in try context.fetch(descriptor) where pair.persistentModelID != transaction.persistentModelID {
                context.delete(pair)
            }
        }
        context.delete(transaction)
        try context.save()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }
}
