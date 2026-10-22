//
//  BeaconOrphanLogic.swift
//  Yala
//
//  ¿El faro de iCloud-KV (`CloudBeacon`) apunta a una cuenta que YA NO EXISTE?
//
//  Decisión de Jürgen (2026-09-09, ticket `beacon-routes-only-never-blocks`): «un faro que apunta a una
//  cuenta inexistente se limpia solo —o al menos no bloquea— en cuanto [I] lo descubre». El caso que la
//  motiva es el fresh start de producción (ticket 2, `auth.users` incluido): desde entonces el faro de todo
//  Apple ID que tuvo cuenta en la nube apunta a una cuenta borrada.
//
//  ## La regla es de PRUEBA, no de sospecha
//
//  Limpiar el faro es irreversible y cross-device: vive en el iCloud-KV del Apple ID, así que su borrado
//  viaja a todos sus dispositivos. Por eso esto solo contesta cuando PUEDE PROBAR que la cuenta del faro no
//  existe, y lo que no prueba se queda como está —donde basta con que el faro no bloquee, que es lo que ya
//  garantiza la pantalla de mismatch con sus dos salidas—.
//
//  Las dos pruebas, y por qué la segunda no es una intuición:
//
//  1. **Misma cuenta.** El hash del faro es el de la identidad que acaba de firmar, y el backend dice que no
//     tiene cuenta.
//  2. **Faro de Apple y sesión de Apple.** Sign in with Apple solo firma con el Apple ID del TELÉFONO, y el
//     faro vive en el iCloud-KV de ESE MISMO Apple ID (el KV es por bundle: Yala y Yala Dev no lo comparten,
//     medido en los dos `.entitlements`). Si la identidad Apple de este Apple ID no tiene cuenta, la cuenta
//     que el faro dice que se creó con ella ya no existe. **Es la que cubre el fresh start**: el hash del
//     faro es del uuid de Supabase, y al borrarse `auth.users` volver a firmar da OTRO uuid, así que la
//     prueba 1 sola no dispararía nunca.
//
//  **Google con otro hash NO es prueba**: la persona puede haber firmado con otra cuenta de Google, y la del
//  faro seguir viva. Limpiarlo ahí le quitaría el encaminamiento a una cuenta que existe.
//

import Foundation

nonisolated enum BeaconOrphanLogic {

    /// Con qué se probó que la cuenta del faro ya no existe. Viaja al breadcrumb: la limpieza es irreversible
    /// y, si algún día se equivoca, lo único que quedará es saber qué prueba la disparó.
    enum Proof: String, Equatable {
        case sameAccount
        case appleIdentityHasNoAccount
    }

    /// `nil` = no hay prueba ⇒ el faro se queda.
    ///
    /// - Parameters:
    ///   - accountExists: lo que el backend contestó para la identidad que acaba de firmar.
    ///   - sessionSubHash: `CloudBeacon.hash(sub)` de esa identidad.
    ///   - sessionProvider: el método con el que firmó, tipado; `nil` si no se sabe, y entonces solo vale la
    ///     prueba 1.
    static func proof(
        accountExists: Bool,
        beaconLinked: Bool,
        beaconAccountHash: String?,
        beaconProvider: String?,
        sessionSubHash: String,
        sessionProvider: CloudSignInProvider?
    ) -> Proof? {
        guard !accountExists, beaconLinked else { return nil }
        // Dos hashes vacíos serían «iguales» sin nombrar a nadie: el faro sin hash (`writeCloudAccountLinked`
        // con sub vacío) no puede probar nada por esta vía.
        if let hash = beaconAccountHash, !hash.isEmpty, hash == sessionSubHash {
            return .sameAccount
        }
        if beaconProvider == CloudSignInProvider.apple.rawValue, sessionProvider == .apple {
            return .appleIdentityHasNoAccount
        }
        return nil
    }
}
