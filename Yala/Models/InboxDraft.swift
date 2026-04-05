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
}

enum DraftStatus: String, Codable {
    case pending
    case approved
    case rejected
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

    /// Etiquetas asociadas (relación N:N) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify, inverse: \Tag.inboxDrafts)
    var tags: [Tag]?

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
        }
    }

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
        newlyCreatedTagNames: [String] = []
    ) {
        self.note = note
        self.amount = amount
        self.date = date
        self.account = account
        self.subcategory = subcategory
        self.tags = tags
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
        self.createdAt = Date.now
        self.updatedAt = Date.now
    }
}
