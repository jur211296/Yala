//
//  GoogleUserPairStore.swift
//  Yala
//
//  Custodia del PAR (googleUserID, sub-de-Supabase) del último sign-in con Google — molde EXACTO de
//  `SIWARefreshTokenStore` (hazard cross-cuenta M1, H5 del brief BRIEF-GOOGLE-SIGNIN-V1): el
//  `disconnect()` del borrado de cuenta (sesión 3) exige el MATCH del par contra la sesión vigente
//  antes de revocar — una sesión Google del SDK de la cuenta A viva al borrar la cuenta B revocaría
//  el grant OAuth del DUEÑO sin este match.
//
//  Se escribe SOLO tras el `signInWithIdToken` exitoso y SOLO con AMBOS valores presentes (ajuste #1
//  del /review-plan: `GIDGoogleUser.userID` es `String?`; si falta cualquiera ⇒ skip con breadcrumb
//  `googlePairCaptureSkipped`, jamás un par incompleto — el consumidor de sesión 3 tiene skip natural
//  sin par). Ciclo de vida: SOBREVIVE el sign-out normal (credencial del PROVIDER, no de la sesión —
//  misma semántica que el par SIWA); re-sign-in lo sobreescribe (clear-before-write).
//
//  INVARIANTE del writer (heredada del SERIO #1 del review de B1): `write` BORRA el par previo ANTES
//  de escribir y luego escribe user → sub. Sin el clear, una sobrescritura matada entre los 2 writes
//  dejaría el estado cruzado `(googleUserID nuevo, sub viejo)` — y el match pasaría con la cuenta
//  equivocada. Con el clear, todo estado intermedio es `()`, `(user)` o `(user, sub)` DEL MISMO
//  sign-in → el reader devuelve nil o un par coherente, jamás uno cruzado.
//

import Foundation

/// PAR (googleUserID del SDK, `sub` de Supabase) en el Keychain propio de auth (service
/// `com.yala.cloudauth`, AfterFirstUnlockThisDeviceOnly — reusa `CloudAuthKeychainStorage`).
/// Las DOS keys se tratan como unidad: el reader exige ambas (un par a medias — kill entre writes —
/// se trata como ausencia).
nonisolated struct GoogleUserPairStore {

    static let userIDKey = "cloudauth.googleUserID"
    static let subKey = "cloudauth.googleUserID.sub"

    struct Pair: Equatable {
        let googleUserID: String
        let sub: String
    }

    private let storage: CloudAuthKeychainStorage

    init(storage: CloudAuthKeychainStorage = CloudAuthKeychainStorage()) {
        self.storage = storage
    }

    /// El par completo, o `nil` si falta CUALQUIERA de las dos keys (o el Keychain falla — best-effort).
    func read() -> Pair? {
        do {
            guard
                let userData = try storage.retrieve(key: Self.userIDKey),
                let subData = try storage.retrieve(key: Self.subKey),
                let user = String(data: userData, encoding: .utf8), !user.isEmpty,
                let sub = String(data: subData, encoding: .utf8), !sub.isEmpty
            else { return nil }
            return Pair(googleUserID: user, sub: sub)
        } catch {
            #if DEBUG
            print("GoogleUserPairStore.read: \(error)")
            #endif
            return nil
        }
    }

    /// Escribe el PAR: CLEAR del par previo primero (invariante anti-cruce, ver header), luego
    /// user → sub. Lanza si el Keychain falla al escribir (el caller cuenta el breadcrumb).
    func write(_ pair: Pair) throws {
        // El clear NO es opcional: sin él, un kill entre los 2 stores de una sobrescritura mezclaría
        // el user nuevo con el sub viejo (par CRUZADO que el match de sesión 3 no detecta).
        clear()
        try storage.store(key: Self.userIDKey, value: Data(pair.googleUserID.utf8))
        try storage.store(key: Self.subKey, value: Data(pair.sub.utf8))
    }

    /// Borra AMBAS keys. Best-effort (itemNotFound es éxito en el storage).
    func clear() {
        for key in [Self.userIDKey, Self.subKey] {
            do {
                try storage.remove(key: key)
            } catch {
                #if DEBUG
                print("GoogleUserPairStore.clear: \(error)")
                #endif
            }
        }
    }
}
