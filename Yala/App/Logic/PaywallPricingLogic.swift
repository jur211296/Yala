//
//  PaywallPricingLogic.swift
//  Yala
//
//  Lógica pura de lo que el paywall y la oferta de prueba dicen de los precios (auditoría UX 2.2, lote 17).
//
//  Tres cosas que mentían o no salían, y por eso viven aquí, con test:
//  1. «Ahorra N %» no salía NUNCA: `NSDecimalNumber(decimal:).intValue` devuelve 0 con un `Decimal` de mantisa
//     larga, y (1 − 29,99/12/4,99) × 100 = 49,9164996659986639946… lo es. Se redondea antes de convertir.
//  2. «Gratis 30 días, luego…» y «Empieza tu prueba gratis» salían también a quien ya usó la prueba: la oferta
//     introductoria existe en el producto, pero Apple ya no se la da a esa cuenta y cobra desde el primer día.
//  3. La restauración que la persona cancela no es un error: no se avisa.
//

import Foundation
import StoreKit

enum PaywallPricingLogic {

    /// Porcentaje que ahorra el anual frente a doce mensualidades, truncado. `nil` si no hay ahorro o faltan precios.
    static func yearlySavingsPercent(monthly: Decimal, yearly: Decimal) -> Int? {
        guard monthly > 0, yearly > 0 else { return nil }
        var savings = (1 - ((yearly / 12) / monthly)) * 100
        var truncated = Decimal()
        NSDecimalRound(&truncated, &savings, 0, .down)
        let percent = NSDecimalNumber(decimal: truncated).intValue
        return percent > 0 ? percent : nil
    }

    /// Días de la prueba gratis que se pueden PROMETER: `nil` si el producto no la tiene o la cuenta ya no tiene
    /// derecho a ella.
    static func promisedTrialDays(
        hasFreeTrialOffer: Bool,
        periodUnit: Product.SubscriptionPeriod.Unit?,
        periodValue: Int,
        isEligible: Bool
    ) -> Int? {
        guard hasFreeTrialOffer, isEligible, let periodUnit else { return nil }
        switch periodUnit {
        case .day: return periodValue
        case .week: return periodValue * 7
        case .month: return periodValue * 30
        case .year: return periodValue * 365
        @unknown default: return periodValue
        }
    }

    /// Cómo se avisa de que «Restaurar compras» falló. `nil` = no se avisa (la persona canceló).
    static func restoreFailureAlert(isUserCancellation: Bool, message: String) -> (title: String, message: String)? {
        guard !isUserCancellation else { return nil }
        return (L10n.Subscription.restoreErrorTitle, message)
    }

    /// `true` si el error es la propia persona cancelando (el inicio de sesión de Apple, por ejemplo).
    static func isUserCancellation(_ error: Error) -> Bool {
        if let storeKitError = error as? StoreKitError, case .userCancelled = storeKitError { return true }
        if let skError = error as? SKError, skError.code == .paymentCancelled { return true }
        return false
    }
}
