//
//  L10n+UXAudit22Lote14.swift
//  Yala
//
//  Textos de la implementación de la auditoría UX 2.2, lote 14 (Yala IA). Van en su propio fichero para no pisar
//  `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l14(_ key: String) -> String {
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
    enum UXL14 {

        // MARK: - Tono y estilo en un solo paso (L14-3)

        static var personalizeTitle: String { l14("yalaAI.onboarding.l14.personalize.title") }
        static var personalizeSubtitle: String { l14("yalaAI.onboarding.l14.personalize.subtitle") }
        static var toneHeader: String { l14("yalaAI.onboarding.l14.personalize.toneHeader") }
        static var focusHeader: String { l14("yalaAI.onboarding.l14.personalize.focusHeader") }
        /// La frase con la que empieza el ejemplo según el tono. «Normal» no lleva ninguna: datos sin adornos.
        static var toneOpenerConsiderate: String { l14("yalaAI.onboarding.l14.toneOpener.considerate") }
        static var toneOpenerSarcastic: String { l14("yalaAI.onboarding.l14.toneOpener.sarcastic") }

        // MARK: - El permiso, último paso de la presentación (L14-2)

        static var consentTitle: String { l14("yalaAI.onboarding.l14.consent.title") }
        static var consentSubtitle: String { l14("yalaAI.onboarding.l14.consent.subtitle") }
        static var consentReadsTitle: String { l14("yalaAI.onboarding.l14.consent.readsTitle") }
        static var consentReadsBody: String { l14("yalaAI.onboarding.l14.consent.readsBody") }
        static var consentUseTitle: String { l14("yalaAI.onboarding.l14.consent.useTitle") }
        static var consentUseBody: String { l14("yalaAI.onboarding.l14.consent.useBody") }
        static var consentDecideTitle: String { l14("yalaAI.onboarding.l14.consent.decideTitle") }
        /// «Lo apagas cuando quieras en Perfil › Privacidad y datos IA.» El camino se arma con los títulos reales de las
        /// dos pantallas, así que no puede nombrar una que no existe en ese idioma.
        static func consentDecideBody(_ path: String) -> String {
            String(format: l14("yalaAI.onboarding.l14.consent.decideBody"), path)
        }
        static var consentCTA: String { l14("yalaAI.onboarding.l14.consent.cta") }

        // MARK: - El saludo dice las dos cosas que hace (L14-4)

        static var greetingTwoUses: String { l14("chat.l14.greetingTwoUses") }
        static var logTitle: String { l14("chat.l14.logTitle") }
        static var logBody: String { l14("chat.l14.logBody") }
        static var logHint: String { l14("chat.l14.logHint") }
        static var askTitle: String { l14("chat.l14.askTitle") }
    }
}
