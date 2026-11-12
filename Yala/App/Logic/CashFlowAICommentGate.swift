import Foundation

/// Cuándo el flujo de caja pide y enseña sus frases de IA.
///
/// Las tres condiciones a la vez: la persona encendió el chip, aceptó el aviso de datos y es Pro. El chip solo se
/// enciende siendo Pro, pero su preferencia sobrevive al fin de la suscripción; sin mirar el plan, quien dejó de ser
/// Pro seguía llamando al gateway en cada apertura de las gráficas, que contesta 403 (ticket
/// `cashflow-ai-comment-does-not-check-pro`).
enum CashFlowAICommentGate {
    static func isEnabled(toggleOn: Bool, consentAccepted: Bool, isPro: Bool) -> Bool {
        toggleOn && consentAccepted && isPro
    }
}
