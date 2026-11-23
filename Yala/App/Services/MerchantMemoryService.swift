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

/// Level of suggestion confidence for merchant memory decisions
enum SuggestionLevel: Equatable {
    case none
    case suggest
    case autoAssign
}

@MainActor
final class MerchantMemoryService {

    private let modelContext: ModelContext
    /// La lista común de comercios (`ComerciosEnComun`): propone cuando la memoria no tiene nada de ese comercio.
    private let comunes: ComerciosEnComun

    /// `comunes` sin pasar es `.shared` (un valor por defecto `.shared` se evaluaría fuera del actor principal).
    init(modelContext: ModelContext, comunes: ComerciosEnComun? = nil) {
        self.modelContext = modelContext
        self.comunes = comunes ?? .shared
    }

    // MARK: - Pure Decision Logic

    /// Pure function to decide suggestion level based on approval count and correction rate.
    static func decideSuggestion(countApproved: Int, correctionRate: Double) -> SuggestionLevel {
        if countApproved >= 5 && correctionRate <= 0.1 { return .autoAssign }
        if countApproved >= 3 && correctionRate <= 0.3 { return .suggest }
        return .none
    }

    // MARK: - Suggest

    /// Busca memoria para un merchant y retorna sugerencia según política.
    ///
    /// Orden («Comercios en común», 2026-11-22): 1) la memoria con su política; 2) la memoria que existe aunque no
    /// llegue al umbral GANA a la lista común (propone lo suyo, desde la primera vez); 3) sin memoria, la lista común
    /// PROPONE (nunca `.autoAssign`). Después, quien llama sigue con la IA y el banco de 666, como antes.
    func suggest(for merchantRaw: String) -> MerchantSuggestion {
        guard !merchantRaw.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .none
        }

        if let memory = findMemory(for: merchantRaw), let subcategory = memory.subcategory {
            switch Self.decideSuggestion(countApproved: memory.countApproved, correctionRate: memory.correctionRate) {
            case .autoAssign:
                return .autoAssign(subcategory)
            case .suggest:
                return .suggest(subcategory)
            case .none:
                return comunes.tipo(paraComercio: merchantRaw) != nil ? .suggest(subcategory) : .none
            }
        }

        if comunes.tipo(paraComercio: merchantRaw) != nil,
           let common = comunes.subcategoria(
               paraComercio: merchantRaw, isExpense: true, en: MerchantKindSubcategory.fetchVisible(context: modelContext)) {
            return .suggest(common)
        }
        return .none
    }

    /// ¿Hay memoria de este comercio, aunque sea de una vez? La línea «Así suele categorizarse…» de «Esto leí» solo sale
    /// sin ella: con ella, la categoría es de la persona.
    func hasMemory(for merchantRaw: String) -> Bool {
        findMemory(for: merchantRaw)?.subcategory != nil
    }

    /// Como `suggest(for:)`, pero descarta la subcategoría que contradiga el tipo del borrador: **manda el tipo**,
    /// con el mismo criterio que el chat, Siri y visión (`DraftBuilder.matchesNature`).
    ///
    /// La memoria guarda `comercio → subcategoría` sin naturaleza, así que un comercio aprendido sobre ingresos le
    /// rellenaba a un gasto una subcategoría de ingreso (o al revés) en Apple Pay, la voz y la Bandeja. La fila entraba
    /// con el signo contrario a su categoría: Registros y Estadísticas la restaban como un reembolso y el widget de
    /// inicio, que solo mira el signo, la sumaba (ticket `merchant-memory-suggests-across-natures-in-three-more-places`).
    /// Descartada, el borrador nace sin subcategoría y pide elegirla, igual que sin memoria de ese comercio.
    func suggest(for merchantRaw: String, isExpense: Bool) -> MerchantSuggestion {
        switch suggest(for: merchantRaw) {
        case .autoAssign(let sub):
            return DraftBuilder.matchesNature(sub, isExpense: isExpense) ? .autoAssign(sub) : .none
        case .suggest(let sub):
            return DraftBuilder.matchesNature(sub, isExpense: isExpense) ? .suggest(sub) : .none
        case .none:
            return .none
        }
    }

    // MARK: - Update Memory

    /// Actualiza la memoria al aprobar un draft.
    /// - Parameters:
    ///   - merchantRaw: Nombre crudo del comercio (de la nota del draft)
    ///   - subcategory: Subcategoría final elegida por el usuario
    ///   - wasCorrection: true si el usuario cambió la subcategoría sugerida
    ///   - source: de dónde vino el borrador. Con él, un gasto capturado se encola para «Comercios en común»
    ///     (`ComerciosEnComun.registrarAporte`, que decide si aporta); sin él (`nil`), no se aporta nada.
    func updateMemory(merchantRaw: String, subcategory: Subcategory, wasCorrection: Bool, source: DraftSourceType? = nil) {
        if let source {
            comunes.registrarAporte(
                merchantRaw: merchantRaw, subcategory: subcategory, source: source,
                visibles: MerchantKindSubcategory.fetchVisible(context: modelContext))
        }

        let canonical = MerchantCanonicalizer.canonicalize(merchantRaw)
        guard !canonical.isEmpty else { return }

        if let existing = findMemory(for: merchantRaw) {
            if wasCorrection {
                existing.countCorrected += 1
                existing.subcategory = subcategory
            } else {
                existing.countApproved += 1
            }
            existing.lastApprovedAt = Date.now

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
                lastApprovedAt: Date.now,
                aliases: [merchantRaw.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
            // Modo Nube I2: born-cloud identity capture (gateado DARK; no-op en producción hoy).
            SyncIdentityService.captureIfEnabled(memory)
            modelContext.insert(memory)
        }
    }

    // MARK: - Decay

    /// Aplica decay a memorias no usadas en 6+ meses.
    /// Reduce countApproved y elimina memorias vacías.
    func applyDecay() {
        guard let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date.now) else {
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

        // 2. Fuzzy match: buscar memorias y comparar similaridad
        var allDescriptor = FetchDescriptor<MerchantMemory>()
        allDescriptor.fetchLimit = 500
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
