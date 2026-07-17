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
//  Consumo: DENTRO de la rama `.accountMissing` de `WelcomeCloudSignInView.runSignInFlow`
//  (con las reglas sub-first, `.mismatch` solo es alcanzable con exists == false — el flujo
//  Apple existente queda byte-idéntico). `.mismatch` ⇒ canario `cloudSignInProviderMismatch`
//  + signOut + NO claim + fase `.providerMismatch`.
//

import Foundation

nonisolated enum ProviderMismatchLogic {

    enum Verdict: Equatable {
        case proceed
        /// Cuenta probable con OTRO método: mostrar la pantalla de mismatch. `knownProvider` es
        /// el provider del faro ("apple"/"google"); nil/desconocido → copy genérico.
        case mismatch(knownProvider: String?)
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
    ///    `.mismatch(knownProvider: beaconProvider)`.
    static func decide(
        accountExists: Bool,
        beaconLinked: Bool,
        beaconAccountHash: String?,
        beaconProvider: String?,
        sessionSubHash: String,
        sessionProvider: String
    ) -> Verdict {
        if accountExists { return .proceed }
        guard beaconLinked else { return .proceed }
        if let hash = beaconAccountHash, hash == sessionSubHash { return .proceed }
        if let provider = beaconProvider, provider == sessionProvider { return .proceed }
        return .mismatch(knownProvider: beaconProvider)
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
