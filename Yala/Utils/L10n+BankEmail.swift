//
//  L10n+BankEmail.swift
//  Yala
//
//  «Correo del banco» (2.3): la dirección de reenvío, el cupo de prueba y las guías de Gmail, Outlook e iCloud Mail.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func bankEmailString(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum BankEmail {
        static var title: String { bankEmailString("bankEmail.title") }
        static var intro: String { bankEmailString("bankEmail.intro") }
        static var addressCaption: String { bankEmailString("bankEmail.addressCaption") }
        static var addressLoading: String { bankEmailString("bankEmail.addressLoading") }
        static var addressError: String { bankEmailString("bankEmail.addressError") }
        static var retry: String { bankEmailString("bankEmail.retry") }
        static var copyAddress: String { bankEmailString("bankEmail.copyAddress") }
        static var copied: String { bankEmailString("bankEmail.copied") }
        static var seePro: String { bankEmailString("bankEmail.seePro") }
        static var guidesCaption: String { bankEmailString("bankEmail.guidesCaption") }
        static var privacyFooter: String { bankEmailString("bankEmail.privacyFooter") }
        static var proLine: String { bankEmailString("bankEmail.proLine") }
        static var trialExhausted: String { bankEmailString("bankEmail.trialExhausted") }
        static var guarantee: String { bankEmailString("bankEmail.guarantee") }
        static var copyCode: String { bankEmailString("bankEmail.copyCode") }
        static var checkCode: String { bankEmailString("bankEmail.checkCode") }
        static var searching: String { bankEmailString("bankEmail.searching") }
        static var confirmInGoogle: String { bankEmailString("bankEmail.confirmInGoogle") }
        static var gmailGaveUp: String { bankEmailString("bankEmail.gmailGaveUp") }
        static var gmailGaveUpOffline: String { bankEmailString("bankEmail.gmailGaveUpOffline") }
        static func gmailNotYet(_ seconds: Int) -> String { String(format: bankEmailString("bankEmail.gmailNotYet"), seconds) }
        static func gmailSearchFailed(_ seconds: Int) -> String { String(format: bankEmailString("bankEmail.gmailSearchFailed"), seconds) }
        static func skipped(_ count: Int) -> String { String(format: bankEmailString("bankEmail.skipped"), count) }
        static func trialUsed(_ used: Int, _ limit: Int) -> String { String(format: bankEmailString("bankEmail.trialUsed"), used, limit) }
        static func guideTitle(_ provider: String) -> String { String(format: bankEmailString("bankEmail.guideTitle"), provider) }
        static func openProvider(_ provider: String) -> String { String(format: bankEmailString("bankEmail.openProvider"), provider) }
    }
}
