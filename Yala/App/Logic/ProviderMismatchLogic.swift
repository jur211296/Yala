//
//  ProviderMismatchLogic.swift
//  Yala
//
//  Guard R9 SUB-FIRST del sign-in de nube en el Welcome (Google Sign-In sesión 2, brief
//  BRIEF-GOOGLE-SIGNIN-V1 con H4 actualizado): detecta "firmaste con el MÉTODO equivocado"
//  ANTES de mostrar el `.notFound` engañoso, usando el faro iCloud-KV (`CloudBeacon`) como
//  referencia del device.
//
//  H4 (hallazgo WIRE real): GoTrue LINKEA identidades con el mismo email verificado al MISMO
//  `sub` — un sign-in Google puede aterrizar legítimamente en la cuenta creada con Apple. Por
//  eso la señal PRIMARIA es el SUB (hash del faro vs hash de la sesión), JAMÁS el provider a
//  secas: el provider actúa solo como señal secundaria cuando ya se sabe que el sub es OTRO.
//
//  **Paso 6 del rediseño de sesiones (ADR 2026-09-09 §10): el veredicto dejó de ser una pared.**
//  Hasta hoy la pantalla decía «vuelve atrás y entra con ese método» y soltaba la sesión: desde este
//  móvil no había camino hacia una segunda cuenta. Ahora `.mismatch` lleva las DOS salidas (`Exits`)
//  —entrar con el método del faro, o crear una cuenta con el que la persona acaba de usar— porque el
//  faro solo ENCAMINA. Las cinco reglas de la tabla no cambian: cambia lo que lleva su salida.
//
//  Consumo: la rama «cuenta nueva» de `WelcomeCloudSignInView.runSignInFlow` (con las reglas sub-first,
//  `.mismatch` solo es alcanzable con exists == false) ⇒ canario `cloudSignInProviderMismatch` + signOut +
//  NO claim + fase `.providerMismatch`. Y `BornCloudSignUpService`, que deriva de aquí su
//  `providerMatchesBeacon` en vez de comparar el provider a mano.
//

import Foundation

nonisolated enum ProviderMismatchLogic {

    enum Verdict: Equatable {
        case proceed
        /// Cuenta probable con OTRO método: la pantalla de mismatch, con sus DOS salidas.
        case mismatch(Exits)
    }

    /// Las dos salidas de la pantalla de «esa cuenta usa otro método». **Ninguna es «volver»**: la flecha
    /// de atrás sigue ahí, pero ya no es la única forma de avanzar (criterio del ticket
    /// `beacon-routes-only-never-blocks`).
    ///
    /// Por construcción `signInWith != createWith`: si el método del faro fuera el mismo que el usado, la
    /// regla 4 ya habría devuelto `.proceed`, y si el faro no lo sabe, `signInWith` es el OTRO.
    nonisolated struct Exits: Equatable, Sendable {
        /// Con qué método se creó la cuenta que recuerda el faro. `nil` = el faro no lo dice, o trae un valor
        /// que esta versión no conoce: el copy es entonces el GENÉRICO — jamás se interpola un rawValue del wire.
        let accountProvider: CloudSignInProvider?
        /// «Iniciar sesión con …»: el método de la cuenta del faro. Si el faro no lo sabe, el OTRO de los dos
        /// métodos que existen, que es justo la hipótesis de la regla 5: «usaste el otro».
        let signInWith: CloudSignInProvider
        /// «Crear cuenta con …»: el método que la persona acaba de usar, que es el que eligió. **El veredicto la lleva
        /// siempre, pero la pantalla solo la pinta tras la puerta del alta** (`WelcomeNewOptionsGate.offersCloudSignUp`):
        /// un teléfono sin App Attest, o con el kill del alta, ve solo la salida de entrar.
        let createWith: CloudSignInProvider
    }

    /// Reglas EN ORDEN (sub-first, §0 del plan):
    /// 1. `accountExists == true` → `.proceed` SIEMPRE. La cuenta es real: mismo hash ⇒ adopt
    ///    normal; hash distinto ⇒ caso M1 (invitada en el device del dueño) que
    ///    `CrossAccountEntryGuardLogic` ya rutea — un R9 aquí ROMPERÍA la entrada secundaria
    ///    (el faro vive en el iCloud KV del DUEÑO). H4: mismo sub con provider distinto =
    ///    identity-linking legítimo.
    /// 2. `!beaconLinked` → `.proceed` (sin referencia; cae al `.notFound` existente).
    /// 3. `beaconAccountHash == sessionSubHash` → `.proceed` (misma cuenta; con exists=false es
    ///    cuenta borrada server-side con faro stale → `.notFound` honesto, no R9).
    /// 4. `sessionProvider == beaconProvider` → `.proceed` (usó el MISMO método y no hay cuenta:
    ///    la hipótesis "método equivocado" está muerta). El provider jamás dispara por sí solo.
    /// 5. Resto (exists=false + faro presente + provider distinto + hash ausente-o-distinto) →
    ///    `.mismatch` con sus dos salidas.
    ///
    /// `sessionProvider` es el método TIPADO con el que se firmó: el Welcome lo tiene como
    /// `CloudSignInProvider`, y un método desconocido no puede estar «equivocado» ni ofrecerse para crear.
    static func decide(
        accountExists: Bool,
        beaconLinked: Bool,
        beaconAccountHash: String?,
        beaconProvider: String?,
        sessionSubHash: String,
        sessionProvider: CloudSignInProvider
    ) -> Verdict {
        if accountExists { return .proceed }
        guard beaconLinked else { return .proceed }
        if let hash = beaconAccountHash, hash == sessionSubHash { return .proceed }
        if let provider = beaconProvider, provider == sessionProvider.rawValue { return .proceed }
        let accountProvider = beaconProvider.flatMap(CloudSignInProvider.init(rawValue:))
        return .mismatch(Exits(
            accountProvider: accountProvider,
            signInWith: accountProvider ?? otherMethod(than: sessionProvider),
            createWith: sessionProvider))
    }

    /// El OTRO de los dos métodos que existen. `switch` exhaustivo a propósito: el día que haya un tercero,
    /// el compilador obliga a decidir qué «otro» se ofrece, en vez de ofrecer uno a ciegas.
    private static func otherMethod(than provider: CloudSignInProvider) -> CloudSignInProvider {
        switch provider {
        case .apple:  .google
        case .google: .apple
        }
    }

    /// Red POST-claim (también sub-first): tras el claim, el sub es EL MISMO por construcción
    /// (claim JWT-scoped) ⇒ por H4 un `profile.provider` distinto es identity-linking LEGÍTIMO —
    /// jamás alerta ni canario, SOLO el breadcrumb `claimProfileProviderDiffers` (observabilidad).
    /// `profileProvider` nil (respuesta sin profile / campo ausente) → false (nada que observar).
    static func postClaimLinkedDifferentProvider(
        profileProvider: String?,
        sessionProvider: String
    ) -> Bool {
        guard let profileProvider else { return false }
        return profileProvider != sessionProvider
    }

    /// Nombre visible del provider para el copy de mismatch. Desconocido/nil → nil (el caller
    /// usa el body GENÉRICO — jamás interpolar un rawValue del wire en UI).
    static func displayName(forProvider provider: String?) -> String? {
        switch provider {
        case "apple": return "Apple"
        case "google": return "Google"
        default: return nil
        }
    }
}
