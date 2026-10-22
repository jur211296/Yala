//
//  BridgedEditPolicy.swift
//  Yala
//
//  Pure-logic de qué campos son editables al abrir `NewTransactionView` para EDITAR una
//  TransactionItem bridgeada de Grupos, y qué banner mostrar. Testeable sin SwiftUI/SwiftData.
//
//  Contexto: una TX bridgeada tiene el grupo como fuente de verdad para monto/fecha/tipo
//  (siempre bloqueados). Los campos personales (cuenta/subcategoría/tags) dependen del TIPO
//  de TX bridgeada:
//    - Caso A real (yo pagué, TX en mi cuenta real): todo personal editable — el bridge la
//      preserva (nunca pisa cuenta/subcat/tags).
//    - Caso B clasificable (pagó otro, TX virtual `-myShare`): subcat/tags editables, pero la
//      CUENTA no (es la cuenta de sistema "Grupos" por diseño). El bridge ahora hace
//      preserve+update de esta virtual → la clasificación sobrevive los re-bridges.
//    - Virtuales derivadas (préstamo, saldo inicial — subcat de sistema) y settlements: todo
//      bloqueado (son puramente derivadas o se gestionan desde el grupo).
//

import Foundation

enum BridgedEditPolicy {

    /// Forma de la TX en edición, derivada de sus campos. `hasPendingPointerDraft` refleja si
    /// existe un draft-puntero `[.subcategory]` pendiente para su `splitExpenseID` (afecta SOLO
    /// al banner, no a los permisos de edición).
    struct TxShape: Equatable {
        let hasSplitExpenseID: Bool
        let hasSplitSettlementID: Bool
        /// La cuenta no ha hidratado (`tx.account == nil` — ventana CloudKit-lazy). Una TX
        /// bridgeada sin cuenta resuelta se trata CONSERVADORAMENTE como derivada (todo
        /// bloqueado): sin cuenta no se puede distinguir Caso A real de virtual, y habilitar
        /// la edición ahí contradiría al resto de la vista (que la trata como no-Caso-A).
        let accountIsNil: Bool
        let accountIsSystem: Bool
        /// La subcategoría existe Y es de sistema (`isAnySystem`). `false` si nil o de usuario.
        let subcategoryIsSystem: Bool
        let hasPendingPointerDraft: Bool
        /// El `splitExpenseID`/`splitSettlementID` apunta a un `SplitExpense`/`SplitSettlement` que EXISTE.
        ///
        /// Sin esto la policy trataba «tiene puntero» como «es de grupo», y una TX cuyo gasto ya se borró
        /// quedaba en solo-lectura para siempre: no editable (el grupo manda) y no borrable (el editor
        /// bloquea Borrar en Caso A), con un banner que ofrece «abrir el grupo» donde ya no hay nada. El
        /// usuario se quedaba con dinero incorrecto en Panel, presupuestos y reportes SIN NINGUNA SALIDA.
        ///
        /// **Default `true` a propósito**: es el comportamiento anterior, y quien no puede resolver el
        /// puntero (todos los tests de forma pura, y cualquier caller que solo tenga la TX a mano) debe
        /// seguir viendo la policy de siempre. El único que puede afirmar lo contrario es quien tiene
        /// `ModelContext` para preguntárselo al store.
        var pointerResolves: Bool = true
    }

    /// Clasificación de la TX en edición.
    enum Classification: Equatable {
        /// No bridgeada (TX personal normal, o creación) → todo editable.
        case notBridged
        /// Caso A real: `splitExpenseID`, cuenta REAL (no sistema).
        case caseAReal
        /// Caso B clasificable: `splitExpenseID`, cuenta de sistema, subcat nil o de usuario.
        case caseBClassifiable
        /// Virtual derivada: `splitExpenseID`, cuenta de sistema, subcat de SISTEMA.
        case derivedVirtual
        /// TX de liquidación (`splitSettlementID`).
        case settlement
    }

    /// Banner contextual a mostrar en el form.
    enum Banner: Equatable {
        case none
        /// Draft-puntero pendiente → invita a clasificar desde el Inbox (`assignFromInbox`).
        case assignFromInbox
        /// Settlement → se edita desde el grupo (`editSettlementInGroup`).
        case editSettlementInGroup
        /// Caso A real → edit parcial "cuenta/categoría/etiquetas" (`editPartialBanner`).
        case editPartial
        /// Caso B clasificable → edit "categoría/etiquetas" (`editPartialBannerCaseB`).
        case editPartialCaseB
        /// Virtual derivada → solo lectura, se edita desde el grupo (`editFromGroup`).
        case editFromGroup
    }

    static func classify(_ s: TxShape) -> Classification {
        // HUÉRFANA: el puntero existe pero no apunta a nada. Es una TX personal y nada más — devolver
        // cualquier otra clasificación la dejaría atrapada, porque toda restricción de esta policy se
        // justifica en «el grupo es la fuente de verdad» y aquí no hay grupo que mande. La dirección
        // segura ante un puntero muerto es DEVOLVERLE el control al usuario, nunca quitárselo.
        guard s.pointerResolves else { return .notBridged }
        // Settlement manda: su TX puede tener también cuenta de sistema, pero se distingue por
        // `splitSettlementID` y se gestiona íntegra desde el grupo.
        if s.hasSplitSettlementID { return .settlement }
        guard s.hasSplitExpenseID else { return .notBridged }
        // Cuenta sin hidratar → conservador: todo bloqueado (ver doc de `accountIsNil`).
        if s.accountIsNil { return .derivedVirtual }
        if !s.accountIsSystem { return .caseAReal }
        // Cuenta de sistema: derivada si su subcat es de sistema; clasificable (`-myShare`) si
        // la subcat es nil o de usuario.
        return s.subcategoryIsSystem ? .derivedVirtual : .caseBClassifiable
    }

    /// ¿Editable la CUENTA? Solo en TX no bridgeadas y en Caso A real (cuenta personal).
    static func canEditAccount(_ c: Classification) -> Bool {
        switch c {
        case .notBridged, .caseAReal: return true
        case .caseBClassifiable, .derivedVirtual, .settlement: return false
        }
    }

    /// ¿Editables SUBCATEGORÍA y TAGS? En no bridgeadas, Caso A real y Caso B clasificable.
    static func canEditSubcategoryAndTags(_ c: Classification) -> Bool {
        switch c {
        case .notBridged, .caseAReal, .caseBClassifiable: return true
        case .derivedVirtual, .settlement: return false
        }
    }

    /// ¿Puede GUARDAR cambios personales? True si algún campo personal es editable.
    static func canSave(_ c: Classification) -> Bool {
        canEditAccount(c) || canEditSubcategoryAndTags(c)
    }

    /// Banner a mostrar. Un draft-puntero pendiente (solo posible en TX de gasto sin clasificar)
    /// manda sobre el resto: invita a clasificar desde el Inbox. Una shape `.notBridged` nunca
    /// tiene `splitExpenseID` ⇒ el guard del puntero no puede disparar para ella.
    static func banner(_ s: TxShape) -> Banner {
        // Antes del draft-puntero: con el gasto borrado, «clasifícalo desde el Inbox» manda al usuario a
        // un borrador que tampoco se puede aprobar. Sin grupo detrás no hay banner que ofrecer.
        guard s.pointerResolves else { return .none }
        if s.hasPendingPointerDraft && s.hasSplitExpenseID { return .assignFromInbox }
        switch classify(s) {
        case .notBridged: return .none
        case .settlement: return .editSettlementInGroup
        case .caseAReal: return .editPartial
        case .caseBClassifiable: return .editPartialCaseB
        case .derivedVirtual: return .editFromGroup
        }
    }
}
