//
//  InboxDraft.swift
//  Neto
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

    /// Descripción/nota del gasto
    var note: String

    /// Monto con signo (negativo = gasto, positivo = ingreso). Nil si no detectado.
    var amount: Double?

    /// Fecha de la transacción. Nil si no detectada (usa createdAt como fallback).
    var date: Date?

    /// Cuenta asociada. Requerido para aprobar.
    @Relationship(deleteRule: .nullify)
    var account: Account?

    /// Subcategoría asociada. Requerido para aprobar.
    @Relationship(deleteRule: .nullify)
    var subcategory: Subcategory?

    /// Etiquetas asociadas (relación N:N)
    @Relationship(deleteRule: .nullify)
    var tags: [Tag]

    // MARK: - Metadatos de origen

    /// Tipo de fuente (voz, foto, screenshot, etc.)
    var sourceTypeRaw: String

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

    /// Campos que requieren input del usuario (["account", "amount", etc.])
    var needsUserInput: [String]

    /// Estado del draft
    var statusRaw: String

    // MARK: - Timestamps

    var createdAt: Date
    var updatedAt: Date

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

    /// Icono SF Symbol según el tipo de fuente
    var sourceIcon: String {
        switch sourceType {
        case .voice: return "mic.fill"
        case .receiptPhoto: return "doc.text.fill"
        case .screenshotList: return "list.bullet.rectangle"
        case .screenshotSingle: return "rectangle.on.rectangle"
        case .emailAlert: return "envelope.fill"
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
        status: DraftStatus = .pending
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
        self.statusRaw = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
