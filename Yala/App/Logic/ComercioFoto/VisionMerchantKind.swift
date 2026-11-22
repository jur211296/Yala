//
//  VisionMerchantKind.swift
//  Yala
//
//  Captura por foto (decisión 75 de Jürgen, 15-nov; encargo del 22-nov): la IA reconoce el comercio y dice a qué se
//  dedica con su conocimiento general (Starbucks es un restaurante, Wong un supermercado, Inkafarma una farmacia). Lo
//  dice con una palabra de esta lista cerrada (`merchantKind` en la respuesta de `photo.read`), y el teléfono la traduce
//  a una subcategoría del usuario (`MerchantKindSubcategory`).
//
//  No viaja nada nuevo: ni los nombres de las categorías del usuario ni su historial. Por eso vale igual con los datos en
//  iCloud que en la cuenta de Yala, y el permiso de voz y foto no cambia.
//
//  La lista es también el `enum` del esquema del gateway (`PHOTO_SCHEMA` en `gateway/src/ai/routes.ts`): el test
//  `gateway/test/ai.photo-comercio.test.ts` lee este fichero y exige que las dos coincidan.
//

import Foundation
import SwiftData

nonisolated enum VisionMerchantKind: String, CaseIterable, Sendable {
    case supermarket
    case restaurant
    case delivery
    case bar
    case nightlife
    case pharmacy
    case health
    case beauty
    case personalCare = "personal_care"
    case clothing
    case electronics
    case home
    case gifts
    case fuel
    case parking
    case vehicleService = "vehicle_service"
    case rideshare
    case publicTransport = "public_transport"
    case travel
    case streaming
    case software
    case phoneInternet = "phone_internet"
    case utilities
    case fitness
    case sports
    case education
    case entertainment
    case hobbies
    case petStore = "pet_store"
    case vet
    case insurance
    case bankFee = "bank_fee"
    case taxes
    case rent

    /// La lista tal como la lee el prompt de la foto: «supermarket, restaurant, …».
    static var promptList: String { allCases.map(\.rawValue).joined(separator: ", ") }

    /// La palabra de la respuesta, tolerante a mayúsculas, espacios y guiones («Personal care», «public-transport»).
    /// `nil` para lo que no está en la lista: una palabra inventada no elige categoría.
    static func parse(_ raw: String?) -> VisionMerchantKind? {
        guard let raw else { return nil }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return VisionMerchantKind(rawValue: key)
    }

    /// Lo que dice el banco de comercios del teléfono (`MerchantCatalog`, 666 marcas) cuando la IA no lo sabe. Solo las
    /// categorías del banco que no dejan duda: «health» junta clínicas, farmacias y apps; «retail», ropa y electrónica.
    static func fromCatalog(category: String) -> VisionMerchantKind? {
        switch category {
        case "supermarket": return .supermarket
        case "food": return .restaurant
        case "delivery": return .delivery
        case "fuel": return .fuel
        case "streaming", "music": return .streaming
        case "telecom": return .phoneInternet
        case "utilities": return .utilities
        case "fitness": return .fitness
        case "education": return .education
        case "insurance": return .insurance
        case "gaming": return .hobbies
        default: return nil
        }
    }
}

/// Traduce el tipo de comercio a una subcategoría del usuario. Pura: recibe las subcategorías ya leídas.
nonisolated enum MerchantKindSubcategory {

    /// La subcategoría sembrada que corresponde a cada tipo: su nombre en el idioma de la app y su icono de semilla.
    struct Target: Equatable {
        let name: String
        let icon: String
    }

    /// Una subcategoría del usuario, reducida a lo que decide.
    struct Candidate: Equatable {
        let name: String
        let icon: String?
        let isExpense: Bool
    }

    /// El nombre (en el idioma de la app) y el icono de la subcategoría sembrada de cada tipo. Los iconos son los de
    /// `CategorySeed`; los fija `ComercioFotoCategoriaTests.iconosDeSemilla`.
    @MainActor
    static func target(for kind: VisionMerchantKind) -> Target {
        switch kind {
        case .supermarket: return Target(name: L10n.Subcategory.supermarkets, icon: "basket.fill")
        case .restaurant: return Target(name: L10n.Subcategory.restaurants, icon: "fork.knife")
        case .delivery: return Target(name: L10n.Subcategory.delivery, icon: "takeoutbag.and.cup.and.straw.fill")
        case .bar: return Target(name: L10n.Subcategory.bars, icon: "wineglass.fill")
        case .nightlife: return Target(name: L10n.Subcategory.nightlife, icon: "party.popper.fill")
        case .pharmacy: return Target(name: L10n.Subcategory.pharmacy, icon: "cross.case.fill")
        case .health: return Target(name: L10n.Subcategory.health, icon: "stethoscope")
        case .beauty: return Target(name: L10n.Subcategory.beauty, icon: "comb.fill")
        case .personalCare: return Target(name: L10n.Subcategory.personalCare, icon: "sparkles")
        case .clothing: return Target(name: L10n.Subcategory.clothing, icon: "tshirt.fill")
        case .electronics: return Target(name: L10n.Subcategory.tech, icon: "laptopcomputer")
        case .home: return Target(name: L10n.Subcategory.homeDecor, icon: "lamp.desk.fill")
        case .gifts: return Target(name: L10n.Subcategory.gifts, icon: "gift.fill")
        case .fuel: return Target(name: L10n.Subcategory.fuel, icon: "fuelpump.fill")
        case .parking: return Target(name: L10n.Subcategory.parking, icon: "parkingsign.circle.fill")
        case .vehicleService: return Target(name: L10n.Subcategory.vehicleMaintenance, icon: "wrench.fill")
        case .rideshare: return Target(name: L10n.Subcategory.rideshare, icon: "car.fill")
        case .publicTransport: return Target(name: L10n.Subcategory.publicTransport, icon: "bus.fill")
        case .travel: return Target(name: L10n.Subcategory.travel, icon: "airplane")
        case .streaming: return Target(name: L10n.Subcategory.streaming, icon: "play.tv.fill")
        case .software: return Target(name: L10n.Subcategory.utilitySubs, icon: "app.badge.fill")
        case .phoneInternet: return Target(name: L10n.Subcategory.phone, icon: "phone.fill")
        case .utilities: return Target(name: L10n.Subcategory.utilities, icon: "bolt.fill")
        case .fitness: return Target(name: L10n.Subcategory.fitness, icon: "figure.run")
        case .sports: return Target(name: L10n.Subcategory.sports, icon: "sportscourt.fill")
        case .education: return Target(name: L10n.Subcategory.education, icon: "book.fill")
        case .entertainment: return Target(name: L10n.Subcategory.shows, icon: "ticket.fill")
        case .hobbies: return Target(name: L10n.Subcategory.hobbies, icon: "gamecontroller.fill")
        case .petStore: return Target(name: L10n.Subcategory.petFood, icon: "pawprint.fill")
        case .vet: return Target(name: L10n.Subcategory.vet, icon: "cross.vial.fill")
        case .insurance: return Target(name: L10n.Subcategory.insurance, icon: "shield.fill")
        case .bankFee: return Target(name: L10n.Subcategory.fees, icon: "percent")
        case .taxes: return Target(name: L10n.Subcategory.taxes, icon: "doc.text.fill")
        case .rent: return Target(name: L10n.Subcategory.rent, icon: "key.fill")
        }
    }

    /// El índice de la subcategoría elegida en `candidates`, o `nil`.
    ///
    /// 1. Por nombre (sin mayúsculas ni tildes): la semilla en el idioma de la app. Uno solo → ese.
    /// 2. Si el nombre no decide (lo renombró, o es otro idioma), por el icono de la semilla. Uno solo → ese.
    /// Dos que empatan no eligen: mejor pedirla que poner la que no es.
    static func match(target: Target, isExpense: Bool, in candidates: [Candidate]) -> Int? {
        let eligible = candidates.indices.filter { candidates[$0].isExpense == isExpense }
        let wanted = normalized(target.name)
        if !wanted.isEmpty {
            let byName = eligible.filter { normalized(candidates[$0].name) == wanted }
            if byName.count == 1 { return byName[0] }
            if byName.count > 1 { return nil }
        }
        let byIcon = eligible.filter { candidates[$0].icon == target.icon }
        return byIcon.count == 1 ? byIcon[0] : nil
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Con SwiftData

extension MerchantKindSubcategory {

    /// Las subcategorías visibles, una sola vez por foto.
    @MainActor
    static func fetchVisible(context: ModelContext) -> [Subcategory] {
        do {
            return try context.fetch(FetchDescriptor<Subcategory>(predicate: #Predicate<Subcategory> { $0.isVisible == true }))
        } catch {
            #if DEBUG
            print("MerchantKindSubcategory: Error fetching subcategories: \(error)")
            #endif
            return []
        }
    }

    /// El tipo que dice la IA o, si no dice ninguno, el del banco de comercios del teléfono para ese nombre.
    @MainActor
    static func resolvedKind(aiKind: VisionMerchantKind?, merchant: String?) -> VisionMerchantKind? {
        if let aiKind { return aiKind }
        guard let merchant, !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let known = MerchantCatalog.match(name: merchant) else { return nil }
        return VisionMerchantKind.fromCatalog(category: known.category)
    }

    /// La subcategoría del usuario para ese comercio, o `nil` si no hay tipo o no casa con una sola.
    @MainActor
    static func subcategory(
        kind aiKind: VisionMerchantKind?, merchant: String?, isExpense: Bool, in subcategories: [Subcategory]
    ) -> Subcategory? {
        guard let kind = resolvedKind(aiKind: aiKind, merchant: merchant) else { return nil }
        let candidates = subcategories.map {
            Candidate(name: $0.name, icon: $0.iconName, isExpense: !$0.safeCategory.isIncome)
        }
        return match(target: target(for: kind), isExpense: isExpense, in: candidates).map { subcategories[$0] }
    }
}
