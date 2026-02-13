//
//  MerchantMemory.swift
//  Yala
//
//  Memoria de comercios: aprende de las aprobaciones del usuario
//  para sugerir o autoasignar subcategorías.
//  Fase 8.5: Merchant Memory
//

import Foundation
import SwiftData

@Model
final class MerchantMemory {
    /// Nombre normalizado del comercio (canonicalizado) - CloudKit: default required
    var merchantCanonical: String = ""

    /// Subcategoría más frecuente asociada a este comercio
    @Relationship(deleteRule: .nullify, inverse: \Subcategory.merchantMemories)
    var subcategory: Subcategory?

    /// Veces que el usuario aprobó con esta subcategoría - CloudKit: default required
    var countApproved: Int = 0

    /// Veces que el usuario cambió la subcategoría sugerida - CloudKit: default required
    var countCorrected: Int = 0

    /// Última vez que se aprobó una transacción de este comercio - CloudKit: default required
    var lastApprovedAt: Date = Date()

    /// Variantes del nombre del comercio (nombres crudos originales) - CloudKit: default required
    var aliases: [String] = []

    // MARK: - Computed Properties

    /// Tasa de corrección: proporción de veces que el usuario cambió la sugerencia
    var correctionRate: Double {
        let total = countApproved + countCorrected
        guard total > 0 else { return 0 }
        return Double(countCorrected) / Double(total)
    }

    /// Confianza calculada: alta si muchas aprobaciones y pocas correcciones
    var confidence: Double {
        let baseConfidence = min(Double(countApproved) / 5.0, 1.0)
        return baseConfidence * (1.0 - correctionRate)
    }

    // MARK: - Init

    init(
        merchantCanonical: String,
        subcategory: Subcategory? = nil,
        countApproved: Int = 1,
        countCorrected: Int = 0,
        lastApprovedAt: Date = Date(),
        aliases: [String] = []
    ) {
        self.merchantCanonical = merchantCanonical
        self.subcategory = subcategory
        self.countApproved = countApproved
        self.countCorrected = countCorrected
        self.lastApprovedAt = lastApprovedAt
        self.aliases = aliases
    }
}
