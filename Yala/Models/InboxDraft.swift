//
//  InboxDraft.swift
//  Yala
//
//  Modelo para borradores de transacciones en la bandeja de entrada.
//  Fase 8: Registro Inteligente
//

import Foundation
import SwiftData

// MARK: - Enums

enum DraftSourceType: String, Codable {
    case voice
    case receiptPhoto
    case screenshotList
    case screenshotSingle
    case emailAlert
    case scheduledPayment
    case subscription
    case applePay
    case automation     // External automation (email parsed by AI, etc.)
    case siri           // Siri natural language entry
    case groupExpense   // A0-Bridge: caso A/B sin match — apunta a TX existente via splitExpenseID
    case groupSettlement // A0-Bridge: caso C/D — TX cuenta real diferida hasta asignar cuenta
    case manual         // FU-02 cleanup: draft convertido tras soft-delete/leave/remove. Editable como personal.
    case groupScheduledExpense // Pago planificado de grupo: al aprobar abre el form de grupo y crea el SplitExpense.

    /// True para sources de grupos que NO permiten eliminar/rechazar (solo asignar+finalizar).
    /// `.groupScheduledExpense` NO se incluye: aún no existe un SplitExpense, así que debe poder
    /// saltarse/rechazarse como un pago planificado (el descarte hace skip de la ocurrencia).
    var isFromGroup: Bool {
        self == .groupExpense || self == .groupSettlement
    }
}

enum DraftStatus: String, Codable {
    case pending
    case approved
    case rejected
}

/// M6: Razón por la que el bridge creó un InboxDraft pendiente Caso A. Mapea a una
/// L10n key estable que se interpola en `GroupExpenseAccountFinalizationSheet`.
enum DraftOriginReason: String {
    /// Sync remoto trajo el SplitExpense pero la TX cuenta real local aún no llegó.
    case remoteCreate = "groups.bridge.draftReasonRemoteCreate"
    /// Cambio de moneda en el grupo invalidó la cuenta personal previa.
    case currencyChanged = "groups.bridge.draftReasonCurrencyChanged"
}

/// M6: Campos que un draft espera del user para finalizar. Centraliza los strings
/// dispersos en `needsUserInput: [String]` para evitar typos cross-file.
/// `nonisolated`: son constantes String puras (sin relación con el main actor); permite
/// referenciarlas desde contextos nonisolated como `GroupTransactionBridge.computeFreezePlan`.
nonisolated enum DraftInputRequirement {
    static let account = "account"
    static let subcategory = "subcategory"
    static let amount = "amount"
}

// MARK: - InboxDraft

@Model
final class InboxDraft: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
    // MARK: - Campos del draft

    /// Descripción/nota del gasto (CloudKit: default required)
    var note: String = ""

    /// Monto con signo (negativo = gasto, positivo = ingreso). Nil si no detectado.
    var amount: Double?

    /// Fecha de la transacción. Nil si no detectada (usa createdAt como fallback).
    var date: Date?

    /// Cuenta asociada. Requerido para aprobar.
    @Relationship(deleteRule: .nullify, inverse: \Account.inboxDrafts)
    var account: Account?

    /// Subcategoría asociada. Requerido para aprobar.
    @Relationship(deleteRule: .nullify, inverse: \Subcategory.inboxDrafts)
    var subcategory: Subcategory?

    /// Etiquetas asociadas (relación N:N) - CloudKit: must be optional.
    /// LEGACY: kept only for cascade .nullify. Read via resolvedTagIDs() helper.
    /// Writers MUST use setTags(from:) to keep both sides (M2M + CSV) in sync.
    @Relationship(deleteRule: .nullify, inverse: \Tag.inboxDrafts)
    var tags: [Tag]?

    /// CSV mirror of `tags` M2M — SSOT for read (eager, travels in the draft record).
    /// Sobrevive el race CloudKit lazy hydration: M2M puede aparecer nil mientras
    /// llegan los Tag records. Approve lee desde CSV para no perder tags.
    var tagIDs: String?

    /// Transacción creada al aprobar (para sincronización)
    /// Se establece deleteRule: .nullify para que si se elimina la transacción,
    /// el draft conserve su referencia nula y pueda detectar que fue eliminada.
    @Relationship(deleteRule: .nullify, inverse: \TransactionItem.approvedDraft)
    var approvedTransaction: TransactionItem?

    // MARK: - Metadatos de origen

    /// Tipo de fuente (voz, foto, screenshot, etc.) - CloudKit: default required
    var sourceTypeRaw: String = "voice"

    /// Texto crudo OCR/STT para referencia
    var rawText: String?

    /// Extracto breve que justifica la extracción
    var evidence: String?

    // MARK: - Confianza por campo (0.0 - 1.0)

    var confidenceAmount: Double?
    var confidenceDate: Double?
    var confidenceMerchant: Double?
    var confidenceSubcategory: Double?

    // MARK: - Estado y validación

    /// Campos que requieren input del usuario (["account", "amount", etc.]) - CloudKit: default required
    var needsUserInput: [String] = []

    /// Nombres de tags creados automáticamente (para mostrar badge "nuevo")
    var newlyCreatedTagNames: [String] = []

    /// Estado del draft - CloudKit: default required
    var statusRaw: String = "pending"

    // MARK: - Cached Display Values (para cuando los objetos relacionados son eliminados)

    /// Nombre de cuenta cacheado al aprobar
    var cachedAccountName: String?

    /// Nombre de subcategoría cacheado al aprobar
    var cachedSubcategoryName: String?

    /// Color hex de categoría cacheado al aprobar
    var cachedCategoryColorHex: String?

    /// Icono de subcategoría cacheado al aprobar
    var cachedSubcategoryIcon: String?

    /// Código de moneda cacheado al aprobar
    var cachedCurrencyCode: String?

    // MARK: - Scheduled Payment Link

    /// ID del pago planificado que originó este draft (si aplica)
    var sourceScheduledPaymentID: String?

    // MARK: - Shared Expense Link
    /// ID del SplitExpense que originó este draft
    var splitExpenseID: String?
    /// Zone ID del grupo para queries rápidos
    var splitGroupZoneID: String?
    /// ID del SplitSettlement que originó este draft (drafts source=.groupSettlement)
    var splitSettlementID: String?

    // MARK: - Group Bridge Draft Link (A0-Bridge)
    /// Sin uso por el bridge actual: todas las creaciones de drafts en `GroupTransactionBridge`
    /// lo dejan nil. El puntero de un draft `.groupExpense` a su TransactionItem (subcat=nil) se
    /// resuelve por `splitExpenseID` (ver la rama `.groupExpense` de `DraftService.approveDraft`),
    /// NO por este campo. Se conserva por compat de schema CloudKit; un valor no-nil no debe
    /// asumirse como discriminador del puntero.
    var targetTransactionID: String?

    /// Opt-out flag: cuando `true`, este draft fue creado por el alert opt-in del form
    /// con bridge effective OFF. La TX virtual YA EXISTE (creada por el bridge en el save
    /// original). Al aprobar, el flow debe SOLO crear la TX real con `splitExpenseID`/
    /// `splitSettlementID` ligado — NO invocar el bridge (recrearía el par duplicando).
    var optInPersonalOnly: Bool = false

    // MARK: - Origin Hint (M6: drafts creados por bridge ante modificaciones remotas)

    /// Key L10n del hint contextual cuando draft viene de modificación remota.
    /// Ej: "groups.bridge.draftReasonRemoteCreate", "groups.bridge.draftReasonCurrencyChanged".
    /// Renderizado en `GroupExpenseAccountFinalizationSheet` con interpolación de actor/group.
    var originReasonKey: String?

    /// Nombre snapshot del actor visible en el contexto del draft (ej. payer del expense).
    /// Snapshot al crear — no se actualiza si el actor renombra después.
    var originActorName: String?

    /// Nombre snapshot del grupo en el contexto del draft.
    /// Snapshot al crear para evitar fetch en hot path del UI render.
    var originGroupName: String?

    // MARK: - Timestamps (CloudKit: defaults required)

    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    // MARK: - Computed Properties

    var sourceType: DraftSourceType {
        get { DraftSourceType(rawValue: sourceTypeRaw) ?? .voice }
        set { sourceTypeRaw = newValue.rawValue }
    }

    var status: DraftStatus {
        get { DraftStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    /// Fecha efectiva (date o createdAt como fallback)
    var effectiveDate: Date {
        date ?? createdAt
    }

    /// Indica si el draft tiene todos los campos requeridos para aprobar
    var isReadyToApprove: Bool {
        account != nil && amount != nil && subcategory != nil
    }

    /// Indica si la transacción aprobada fue eliminada (permite re-aprobar)
    var wasTransactionDeleted: Bool {
        status == .approved && approvedTransaction == nil
    }

    /// Indica si todos los campos están completos (para mostrar vista completa vs incompleta)
    /// Para drafts archivados usa SOLO valores cacheados (las relaciones pueden estar invalidadas)
    /// Para drafts pendientes usa las relaciones vivas
    var hasAllRequiredFields: Bool {
        guard amount != nil else { return false }

        switch status {
        case .approved, .rejected:
            // Archived: use ONLY cached values (relationships may be invalidated)
            return cachedAccountName != nil && cachedSubcategoryName != nil
        case .pending:
            // Pending: use live relationships
            return account != nil && subcategory != nil
        }
    }

    /// Nombre de cuenta para mostrar
    /// Para archivados: SOLO cache. Para pendientes: relación viva.
    var displayAccountName: String? {
        switch status {
        case .approved, .rejected:
            return cachedAccountName
        case .pending:
            return account?.name
        }
    }

    /// Nombre de subcategoría para mostrar
    var displaySubcategoryName: String? {
        switch status {
        case .approved, .rejected:
            return cachedSubcategoryName
        case .pending:
            return subcategory?.name
        }
    }

    /// Color de categoría para mostrar
    var displayCategoryColorHex: String {
        switch status {
        case .approved, .rejected:
            return cachedCategoryColorHex ?? "#6366F1"
        case .pending:
            return subcategory?.category?.colorHex ?? "#6366F1"
        }
    }

    /// Icono de subcategoría para mostrar
    var displaySubcategoryIcon: String {
        switch status {
        case .approved, .rejected:
            return cachedSubcategoryIcon ?? "tag.fill"
        case .pending:
            return subcategory?.iconName ?? subcategory?.category?.iconName ?? "tag.fill"
        }
    }

    /// Código de moneda para mostrar
    var displayCurrencyCode: String? {
        switch status {
        case .approved, .rejected:
            return cachedCurrencyCode
        case .pending:
            return account?.currencyCode
        }
    }

    /// Icono SF Symbol según el tipo de fuente
    var sourceIcon: String {
        switch sourceType {
        case .voice: return "mic.fill"
        case .receiptPhoto: return "camera.fill"
        case .screenshotList: return "photo.stack.fill"
        case .screenshotSingle: return "photo.fill"
        case .emailAlert: return "envelope.fill"
        case .scheduledPayment: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .subscription: return "creditcard.and.123"
        case .applePay: return "apple.logo"
        case .automation: return "gearshape.fill"
        case .siri: return "mic.badge.plus"
        case .groupExpense: return "person.2.fill"
        case .groupSettlement: return "arrow.left.arrow.right.circle.fill"
        case .manual: return "square.and.pencil"
        case .groupScheduledExpense: return "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    /// True si este draft NO permite eliminar/rechazar (solo asignar+finalizar).
    /// Drafts de grupos solo se eliminan al borrar el expense/settlement origen.
    var isFromGroup: Bool { sourceType.isFromGroup }

    /// True si el draft NO puede aprobarse con quick-approve (swipe / bulk): requiere abrir el
    /// form dedicado que crea la entidad correcta. `.groupScheduledExpense` crea un `SplitExpense`
    /// de grupo vía `GroupExpenseFormView`, NO una `TransactionItem` personal — aprobarlo por el
    /// path genérico lo registraría como gasto personal y nunca lo compartiría con el grupo.
    var requiresApprovalForm: Bool { sourceType == .groupScheduledExpense }

    // MARK: - Init

    init(
        note: String = "",
        amount: Double? = nil,
        date: Date? = nil,
        account: Account? = nil,
        subcategory: Subcategory? = nil,
        tags: [Tag] = [],
        sourceType: DraftSourceType = .voice,
        rawText: String? = nil,
        evidence: String? = nil,
        confidenceAmount: Double? = nil,
        confidenceDate: Double? = nil,
        confidenceMerchant: Double? = nil,
        confidenceSubcategory: Double? = nil,
        needsUserInput: [String] = ["account", "subcategory"],
        status: DraftStatus = .pending,
        newlyCreatedTagNames: [String] = [],
        splitExpenseID: String? = nil,
        splitGroupZoneID: String? = nil,
        splitSettlementID: String? = nil,
        targetTransactionID: String? = nil,
        originReasonKey: String? = nil,
        originActorName: String? = nil,
        originGroupName: String? = nil,
        optInPersonalOnly: Bool = false,
        tagIDs: String? = nil
    ) {
        self.note = note
        self.amount = amount
        self.date = date
        self.account = account
        self.subcategory = subcategory
        self.tags = tags
        // Auto-mirror: si caller no pasó tagIDs explícito, derivar desde `tags`.
        self.tagIDs = tagIDs ?? CSVMirrorCodec.encode(tags.map(\.id))
        self.sourceTypeRaw = sourceType.rawValue
        self.rawText = rawText
        self.evidence = evidence
        self.confidenceAmount = confidenceAmount
        self.confidenceDate = confidenceDate
        self.confidenceMerchant = confidenceMerchant
        self.confidenceSubcategory = confidenceSubcategory
        self.needsUserInput = needsUserInput
        self.newlyCreatedTagNames = newlyCreatedTagNames
        self.statusRaw = status.rawValue
        self.splitExpenseID = splitExpenseID
        self.splitGroupZoneID = splitGroupZoneID
        self.splitSettlementID = splitSettlementID
        self.targetTransactionID = targetTransactionID
        self.originReasonKey = originReasonKey
        self.originActorName = originActorName
        self.originGroupName = originGroupName
        self.optInPersonalOnly = optInPersonalOnly
        self.createdAt = Date.now
        self.updatedAt = Date.now
    }
}
