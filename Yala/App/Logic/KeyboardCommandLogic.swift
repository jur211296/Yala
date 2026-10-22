//
//  KeyboardCommandLogic.swift
//  Yala
//
//  iPad con teclado, puntero y arrastrar (fase 3 del carril adaptativo): las decisiones de los atajos, del menú
//  contextual de un registro y de soltar un recibo, sin vistas. Las vistas solo las cablean.
//

import Foundation

enum KeyboardCommandLogic {

    /// ⌘1…⌘6: las páginas en el orden de la barra lateral (`RootTabLayoutLogic.orderedTabs`), así el número de cada
    /// atajo coincide con la posición que el usuario ve.
    static func sectionTabs(orderedTabs: [ConfigurableTab]) -> [ConfigurableTab] {
        Array(orderedTabs.prefix(6))
    }

    /// Los atajos globales ABREN pantallas. Con algo ya presentado —una hoja, un aviso, el splash— no hacen nada:
    /// una presentación que se enciende con el anchor ocupado no llega a montarse y puede dejar su flag pegado
    /// (`.claude/rules/swiftui-ds.md`, «Presentaciones»). Se pregunta a UIKit en el momento de la tecla, no antes.
    static func globalCommandsAllowed(shellBlocker: String?, anythingPresented: Bool) -> Bool {
        shellBlocker == nil && !anythingPresented
    }

    enum Direction: Equatable { case previous, next }

    /// ↑↓ en Registros: el registro vecino del abierto, en el orden de la lista. Sin nada abierto (o si lo abierto
    /// ya no está en la lista filtrada), las dos flechas abren el primero. En los extremos, `nil`: no se da la vuelta.
    static func neighbor<ID: Equatable>(of current: ID?, in ids: [ID], direction: Direction) -> ID? {
        guard let first = ids.first else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else { return first }
        switch direction {
        case .previous: return index > 0 ? ids[index - 1] : nil
        case .next: return index < ids.count - 1 ? ids[index + 1] : nil
        }
    }
}

// MARK: - Menú contextual de un registro

/// Qué ofrece el menú contextual (y ⌫) de un registro. **Nunca ofrece lo que el editor prohíbe**, y es más estricto
/// que él a propósito: el editor habilita Duplicar y Borrar en un registro de grupo cuyo gasto ya no existe
/// (`bridgedPointerResolves`), pero saberlo exige un fetch al store de grupos que una fila no hace. El menú trata TODO
/// registro con puntero de grupo como de grupo; el huérfano se sigue arreglando desde el editor. Borrar uno vivo se
/// exporta por el espejo a los demás aparatos y el siguiente sync lo resucita como borrador (M6).
enum RecordContextActionLogic {

    struct Shape: Equatable {
        let hasBalanceAdjustmentType: Bool
        let hasSplitExpenseID: Bool
        let hasSplitSettlementID: Bool
        let accountIsNil: Bool
        let accountIsSystem: Bool
        let subcategoryIsSystem: Bool
    }

    struct Actions: Equatable {
        let canEdit: Bool
        let canDuplicate: Bool
        let canChangeCategory: Bool
        let canDelete: Bool
    }

    static func actions(_ s: Shape) -> Actions {
        let isGroupRecord = s.hasSplitExpenseID || s.hasSplitSettlementID
        // Transferencias y ajustes de saldo llevan subcategoría de sistema obligatoria (`bulkUpdateSubcategory` ya
        // rechaza las transferencias). En lo de grupo, lo mismo que `BridgedEditPolicy` le deja al editor.
        let bridged = BridgedEditPolicy.classify(BridgedEditPolicy.TxShape(
            hasSplitExpenseID: s.hasSplitExpenseID,
            hasSplitSettlementID: s.hasSplitSettlementID,
            accountIsNil: s.accountIsNil,
            accountIsSystem: s.accountIsSystem,
            subcategoryIsSystem: s.subcategoryIsSystem,
            hasPendingPointerDraft: false))
        let canChangeCategory = !s.hasBalanceAdjustmentType
            && !s.subcategoryIsSystem
            && BridgedEditPolicy.canEditSubcategoryAndTags(bridged)
        return Actions(
            canEdit: true,
            canDuplicate: !isGroupRecord,
            canChangeCategory: canChangeCategory,
            canDelete: !isGroupRecord)
    }
}

// MARK: - Menú contextual de un grupo

/// «Abrir grupo» desde el menú va donde va el toque (`GroupCardView.handleTap`): abre el detalle salvo en una solicitud
/// en revisión o rechazada, que tienen su propia puerta (decisión de Jürgen, 2026-09-06). Un congelado sí se abre.
enum GroupContextActionLogic {
    static func offersOpen(_ mode: GroupCardDisplayMode) -> Bool {
        switch mode {
        case .active, .migratedFrozen, .migratedNeedsUpdate, .migratedPaused: return true
        case .pendingApproval, .rejected: return false
        }
    }
}

// MARK: - Soltar un recibo

/// Soltar una imagen o un PDF sobre Yala abre Nuevo registro por imagen por el MISMO camino que la extensión de
/// compartir (`AppBootstrapper.enqueueSharedImage`). Lo que añade es el candado Pro: sin él, el fichero quedaría en
/// `PendingImages/` y la recuperación del arranque lo re-emitiría en cada vuelta a primer plano.
enum ReceiptDropLogic {
    enum Decision: Equatable {
        /// Sin acceso a la entrada por imagen: el aviso de Pro, y el fichero NO se guarda.
        case upgrade
        /// Con acceso: se guarda y se presenta (el consentimiento de IA lo decide `enqueueSharedImage`).
        case present
    }

    /// En la shell de solo grupos no se acepta: el Panel, que es quien presenta la imagen, no existe ahí, y lo
    /// soltado se quedaría esperando en `PendingImages/` hasta salir de esa shell.
    static func accepts(isGroupsOnly: Bool) -> Bool {
        !isGroupsOnly
    }

    static func decide(canAccessImageInput: Bool) -> Decision {
        canAccessImageInput ? .present : .upgrade
    }
}
