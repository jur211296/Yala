//
//  UITestDemoAccountLogic.swift
//  Yala
//
//  La cuenta que eligen las demos de foto y voz sin red (`-uitest-image-result`, `-uitest-voice-result`). Solo DEBUG.
//
//  La app real elige cuenta sola únicamente si hay UNA cuenta activa en la divisa del movimiento; con varias deja que
//  la persona elija (chip «Selecciona cuenta» y Guardar apagado). Eso es correcto y no se toca. Pero la semilla `ficha`
//  de las capturas tiene tres en la divisa principal (principal, efectivo y tarjeta), y la demo tiene que salir lista
//  para guardar: la foto del recibo va a la cuenta corriente y la voz («on my card») a la tarjeta de crédito.
//

#if DEBUG
import Foundation

enum UITestDemoAccountLogic {
    enum Demo {
        case photo
        case voice

        /// El tipo de cuenta que la demo da por dicho cuando hay varias en la divisa.
        var preferredType: AccountType {
            switch self {
            case .photo: return .checking
            case .voice: return .creditCard
            }
        }
    }

    /// La cuenta de la demo: la única activa en `currencyCode`, o —si hay varias— la única de ese tipo. `nil` si ni
    /// así se puede decidir, y entonces la demo enseña el chip como la app real.
    static func account(for demo: Demo, among accounts: [Account], currencyCode: String) -> Account? {
        let code = currencyCode.uppercased()
        let candidates = accounts.filter {
            !$0.isArchived && !$0.isSystemAccount && $0.currencyCode.uppercased() == code
        }
        if candidates.count == 1 { return candidates.first }
        let ofType = candidates.filter { $0.type == demo.preferredType.rawValue }
        return ofType.count == 1 ? ofType.first : nil
    }
}
#endif
