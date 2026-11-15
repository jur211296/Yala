//
//  UnifiedAccessLogic.swift
//  Yala
//
//  Bienvenida 2.3 · Y23-02 · las dos decisiones del acceso único («Entrar con Google / Apple» de la vitrina), aparte de
//  la vista para fijarlas con su test: qué ve quien no tiene cuenta y cuándo se pide confirmar antes de traer los datos.
//

import Foundation

enum UnifiedAccessLogic {

    /// La pantalla de un acceso SIN cuenta (el servidor dijo `exists:false` y el faro no apunta a otro método).
    /// El acceso único ofrece crearla con el consentimiento en la misma hoja; las demás entradas, y el acceso único sin
    /// la puerta del alta (sin App Attest o con el alta apagada), el «No encontramos una cuenta» de siempre.
    static func phaseWithoutAccount(isUnifiedAccess: Bool, offersSignUp: Bool) -> CloudWelcomeSignInPhase {
        isUnifiedAccess && offersSignUp ? .createAccount : .notFound
    }

    /// ¿Se para antes del adopt a preguntar «¿Cargamos tus datos y entramos?»? Solo en el acceso único y una vez: la
    /// respuesta vuelve a pasar por la verificación ya confirmada.
    ///
    /// Si el adopt viene del alta que encontró la cuenta ya creada (`.signUpFoundExistingAccount`), no se pregunta: la
    /// persona pidió crear y su terminal propia lo dice (ticket `born-cloud-signup-lands-on-existing-account-silently`).
    static func asksBeforeLoading(isUnifiedAccess: Bool, loadConfirmed: Bool, origin: WelcomeAdoptOrigin) -> Bool {
        isUnifiedAccess && !loadConfirmed && origin == .reentry
    }
}
