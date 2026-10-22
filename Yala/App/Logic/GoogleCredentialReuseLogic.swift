//
//  GoogleCredentialReuseLogic.swift
//  Yala
//
//  vb1f (opción C, decisión de Jürgen del 2026-10-14). Quien entra con Google en «¡Hola de nuevo!» y su cuenta se creó
//  con Apple llega a «Esa cuenta usa otro método»; su «Registrarse con Google» abría otra vez la hoja de Google, con la
//  credencial recién obtenida tirada. Ahora esa credencial viaja al alta y se canjea sin hoja.
//
//  Aquí vive solo la DECISIÓN —qué credencial vale y para qué inicio de sesión—, pura y testeable. El canje lo hace
//  `CloudAuthService`, que es el único con el cliente de Supabase, y la pantalla decide cuándo recogerla.
//

import Foundation

/// Lo que devuelve la hoja de Google y hace falta para canjearlo con Supabase, más el perfil que el canje captura. Solo
/// en memoria: ningún sitio lo persiste.
nonisolated struct GoogleSignInCredential: Equatable, Sendable {
    let idToken: String
    let accessToken: String
    /// El nonce SIN hashear: Google firmó su SHA-256 en el id token y Supabase lo compara contra este.
    let rawNonce: String
    let googleUserID: String?
    let email: String?
    let fullName: String?
    let obtainedAt: Date
}

nonisolated enum GoogleCredentialReuseLogic {

    /// Cuánto vale una credencial para reusarla. El id token de Google dura una hora; diez minutos cubren de sobra leer
    /// «Esa cuenta usa otro método», tocar «Registrarse con Google» y aceptar el consentimiento. Pasado eso, la hoja.
    static let lifetime: TimeInterval = 10 * 60

    /// ¿Se puede reusar `credential`, que nació de la sesión `boundToSub`, ahora que la sesión viva es `liveSub`?
    ///
    /// Tiene que ser LA MISMA sesión: la credencial se recoge justo antes de soltarla, y una sesión distinta (otra
    /// cuenta que entró entre medias) diría que esa credencial ya no es de quien está delante. Un reloj que vuelve atrás
    /// también la descarta: no se puede saber cuánto tiempo pasó.
    static func reusable(
        _ credential: GoogleSignInCredential,
        boundToSub: String,
        liveSub: String?,
        now: Date
    ) -> GoogleSignInCredential? {
        guard liveSub == boundToSub, isFresh(credential, now: now) else { return nil }
        return credential
    }

    static func isFresh(_ credential: GoogleSignInCredential, now: Date) -> Bool {
        let age = now.timeIntervalSince(credential.obtainedAt)
        return age >= 0 && age < lifetime
    }

    /// La credencial que se le pasa al inicio de sesión que va a ocurrir. **Sirve al siguiente y a ninguno más**: quien
    /// llama la olvida siempre, se use o no. Solo con Google —una credencial de Google no abre una sesión de Apple— y solo
    /// si sigue fresca en el momento de usarla, no solo en el de recogerla.
    static func credentialForNextSignIn(
        _ pending: GoogleSignInCredential?,
        provider: CloudSignInProvider,
        now: Date
    ) -> GoogleSignInCredential? {
        guard provider == .google, let pending, isFresh(pending, now: now) else { return nil }
        return pending
    }
}
