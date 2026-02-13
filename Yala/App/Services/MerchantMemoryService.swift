//
//  MerchantMemoryService.swift
//  Yala
//
//  Servicio para gestionar la memoria de comercios:
//  sugerencias, actualización al aprobar, y decay.
//  Fase 8.5: Merchant Memory
//

import Foundation
import SwiftData

/// Resultado de consultar la memoria de un comercio
enum MerchantSuggestion {
    /// Sin datos suficientes para sugerir
    case none
    /// Sugerencia con confianza media (usuario debe confirmar)
    case suggest(Subcategory)
    /// Autoasignación con confianza alta (usuario puede cambiar)
    case autoAssign(Subcategory)
}

@MainActor
final class MerchantMemoryService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Suggest

    /// Busca memoria para un merchant y retorna sugerencia según política.
    func suggest(for merchantRaw: String) -> MerchantSuggestion {
        guard !merchantRaw.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .none
        }

        guard let memory = findMemory(for: merchantRaw),
              let subcategory = memory.subcategory else {
            return .none
        }

        // Policy: countApproved >= 5, correctionRate <= 0.1 → autoAssign
        if memory.countApproved >= 5 && memory.correctionRate <= 0.1 {
            return .autoAssign(subcategory)
        }

        // Policy: countApproved >= 3, correctionRate <= 0.3 → suggest
        if memory.countApproved >= 3 && memory.correctionRate <= 0.3 {
            return .suggest(subcategory)
        }

        return .none
    }

    // MARK: - Update Memory

    /// Actualiza la memoria al aprobar un draft.
    /// - Parameters:
    ///   - merchantRaw: Nombre crudo del comercio (de la nota del draft)
    ///   - subcategory: Subcategoría final elegida por el usuario
    ///   - wasCorrection: true si el usuario cambió la subcategoría sugerida
    func updateMemory(merchantRaw: String, subcategory: Subcategory, wasCorrection: Bool) {
        let canonical = MerchantCanonicalizer.canonicalize(merchantRaw)
        guard !canonical.isEmpty else { return }

        if let existing = findMemory(for: merchantRaw) {
            if wasCorrection {
                existing.countCorrected += 1
                existing.subcategory = subcategory
            } else {
                existing.countApproved += 1
            }
            existing.lastApprovedAt = Date()

            // Agregar alias si es nuevo
            let rawTrimmed = merchantRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawTrimmed.isEmpty && !existing.aliases.contains(rawTrimmed) {
                existing.aliases.append(rawTrimmed)
            }
        } else {
            let memory = MerchantMemory(
                merchantCanonical: canonical,
                subcategory: subcategory,
                countApproved: wasCorrection ? 0 : 1,
                countCorrected: wasCorrection ? 1 : 0,
                lastApprovedAt: Date(),
                aliases: [merchantRaw.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
            modelContext.insert(memory)
        }
    }

    // MARK: - Decay

    /// Aplica decay a memorias no usadas en 6+ meses.
    /// Reduce countApproved y elimina memorias vacías.
    func applyDecay() {
        guard let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) else {
            return
        }

        let descriptor = FetchDescriptor<MerchantMemory>(
            predicate: #Predicate<MerchantMemory> { $0.lastApprovedAt < sixMonthsAgo }
        )

        let staleMemories: [MerchantMemory]
        do {
            staleMemories = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("MerchantMemoryService: Error fetching stale memories for decay: \(error)")
            #endif
            return
        }

        for memory in staleMemories {
            memory.countApproved = max(0, memory.countApproved - 1)
            if memory.countApproved == 0 && memory.countCorrected == 0 {
                modelContext.delete(memory)
            }
        }
    }

    // MARK: - Private

    /// Busca memoria por nombre canónico exacto o por alias con fuzzy matching.
    private func findMemory(for merchantRaw: String) -> MerchantMemory? {
        let canonical = MerchantCanonicalizer.canonicalize(merchantRaw)
        guard !canonical.isEmpty else { return nil }

        // 1. Buscar por canonical exacto
        let descriptor = FetchDescriptor<MerchantMemory>(
            predicate: #Predicate<MerchantMemory> { $0.merchantCanonical == canonical }
        )
        let exactResults: [MerchantMemory]
        do {
            exactResults = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("MerchantMemoryService: Error fetching memory by canonical: \(error)")
            #endif
            exactResults = []
        }
        if let exact = exactResults.first {
            return exact
        }

        // 2. Fuzzy match: buscar todas las memorias y comparar similaridad
        let allDescriptor = FetchDescriptor<MerchantMemory>()
        let allMemories: [MerchantMemory]
        do {
            allMemories = try modelContext.fetch(allDescriptor)
        } catch {
            #if DEBUG
            print("MerchantMemoryService: Error fetching all memories for fuzzy match: \(error)")
            #endif
            return nil
        }

        let threshold = 0.85

        for memory in allMemories {
            // Comparar contra canonical
            if MerchantCanonicalizer.similarity(canonical, memory.merchantCanonical) >= threshold {
                return memory
            }
            // Comparar contra aliases
            for alias in memory.aliases {
                let aliasCanonical = MerchantCanonicalizer.canonicalize(alias)
                if MerchantCanonicalizer.similarity(canonical, aliasCanonical) >= threshold {
                    return memory
                }
            }
        }

        return nil
    }
}
