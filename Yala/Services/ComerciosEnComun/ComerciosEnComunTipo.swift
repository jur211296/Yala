//
//  ComerciosEnComunTipo.swift
//  Yala
//
//  «Comercios en común»: qué se aporta. Lo que viaja no es la categoría de la persona (tiene sus nombres y 16 idiomas)
//  sino el tipo de comercio de la lista cerrada de la foto (`VisionMerchantKind`). Al aprobar, el teléfono traduce la
//  subcategoría a ese tipo con el MISMO traductor que usa la foto, al revés: el tipo cuya subcategoría sembrada es esta.
//  Si no es exactamente uno (una categoría creada o renombrada con otro icono), no se aporta nada.
//

import Foundation

enum ComerciosEnComunTipo {

    /// Alquiler e impuestos nunca viajan: dirían a quién le paga la persona. El servidor los rechaza también.
    static let excludedKinds: Set<VisionMerchantKind> = [.rent, .taxes]

    /// Solo lo capturado aporta: voz, Siri, foto, captura de pantalla, aviso o correo del banco, Apple Pay y
    /// automatizaciones. Lo escrito a mano, los pagos programados, las suscripciones, los grupos y lo que apuntó una IA
    /// por el conector (`aiConnector`: el nombre lo escribió un modelo, no una lectura) no aportan.
    static func sourceContributes(_ source: DraftSourceType) -> Bool {
        switch source {
        case .voice, .siri, .receiptPhoto, .screenshotList, .screenshotSingle, .emailAlert, .applePay, .automation:
            return true
        case .scheduledPayment, .subscription, .groupExpense, .groupSettlement, .manual, .groupScheduledExpense,
             .aiConnector:
            return false
        }
    }

    /// El tipo que corresponde a la subcategoría `index` entre `candidates`, o `nil` si no hay uno solo.
    /// `targets` son las subcategorías sembradas de cada tipo (`MerchantKindSubcategory.target`).
    static func kind(
        forCandidateAt index: Int,
        in candidates: [MerchantKindSubcategory.Candidate],
        targets: [(VisionMerchantKind, MerchantKindSubcategory.Target)]
    ) -> VisionMerchantKind? {
        guard candidates.indices.contains(index), candidates[index].isExpense else { return nil }
        let kinds = targets.compactMap { kind, target -> VisionMerchantKind? in
            guard !excludedKinds.contains(kind) else { return nil }
            return MerchantKindSubcategory.match(target: target, isExpense: true, in: candidates) == index ? kind : nil
        }
        return kinds.count == 1 ? kinds[0] : nil
    }

    /// Las subcategorías sembradas de todos los tipos, en el idioma de la app.
    @MainActor
    static var allTargets: [(VisionMerchantKind, MerchantKindSubcategory.Target)] {
        VisionMerchantKind.allCases.map { ($0, MerchantKindSubcategory.target(for: $0)) }
    }
}
