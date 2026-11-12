//
//  CloudConsentCopyLogic.swift
//  Yala
//
//  El botón del consentimiento de la nube dice lo que va a pasar al tocarlo (UX 2.2 · L6-4, decisión de Jürgen).
//
//  Hasta la 2.2 decía «Entiendo y quiero activar la nube» en los tres contextos, y a quien volvía a una cuenta que ya
//  usaba le pedía «activar» algo que ya tenía. **Lo único que cambia con el contexto es el verbo del botón**: el título,
//  los tres puntos y el pie —el contrato que se acepta, `CloudConsentText.version`— son los mismos en los tres, que es
//  lo que `CloudConsentCopyTests` exige.
//

enum CloudConsentCopyLogic {
    static func acceptTitle(for path: CloudMigrationController.ConsentPath) -> String {
        switch path {
        case .adopt: L10n.UXLote6.consentAcceptEnter
        case .bornCloud: L10n.UXLote6.consentAcceptCreate
        case .migration: L10n.UXLote6.consentAcceptMove
        }
    }
}
