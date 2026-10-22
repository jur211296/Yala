//
//  SIWATokenRevocation.swift
//  Yala
//
//  Revocación REAL del token de Sign in with Apple al ELIMINAR la cuenta (B1 del gate §12 — App Store
//  Guideline 5.1.1(v); antes seam no-op G5-D1b). Arquitectura del brief congelado BRIEF-B1-SIWA-REVOKE:
//
//    - El canje del `authorization_code` (de un solo uso, ~5 min) ocurre EN el sign-in vía el hook
//      `CloudAuthService.siwaExchangeHook` (composición `SIWAExchangeSeam`, instalada en UN punto —
//      AppBootstrapper). El Worker firma el `client_secret` con la .p8 (jamás client-side) y devuelve
//      el refresh token de Apple, que se custodia como PAR (token, appleUserID) en el Keychain propio
//      (`SIWARefreshTokenStore`) — AJUSTE #1 del review: el match del par al revocar cierra el hazard
//      cross-cuenta M1 (un exchange fallido de la secundaria dejaría el token del DUEÑO; sin el match,
//      borrar la secundaria revocaría la autorización SIWA del dueño).
//    - `revokeIfNeeded()` (paso 4a del borrado, orden congelado de `AccountDeletionService`) lee el
//      par, exige el match contra el `cloudauth.appleUserID` vigente y revoca vía el Worker con el JWT
//      de Supabase aún vivo (verificación stateless). Timeout 4s (molde `PushTokenSignOutSeam`).
//
//  Contrato best-effort INTACTO: jamás lanza ni bloquea el borrado (la revocación es requisito de
//  review, no de correctitud del wipe). Residual población-cero documentado en qa/cloud/README: solo
//  devices de dogfooding con sesión SIWA previa al capture carecen de token (re-sign-in lo cura).
//  Ciclo de vida del par: sobrevive el sign-out normal (credencial de APPLE, no de la sesión Supabase;
//  verificado 2026-07-16 que ni la matriz de sign-out ×4 ni la purga de frontera de secundaria barren
//  estas keys — el match por appleUserID hace el residuo inofensivo); re-sign-in lo sobreescribe
//  (el más fresco gana); borrado exitoso lo limpia vía el revoke.
//

import Foundation

// MARK: - Custodia del PAR en el Keychain

/// PAR (refresh token de Apple, appleUserID del sign-in que lo acuñó) en el Keychain propio de auth
/// (service `com.yala.cloudauth`, AfterFirstUnlockThisDeviceOnly — reusa `CloudAuthKeychainStorage`).
/// Las DOS keys se tratan como unidad: el reader exige ambas (un par a medias — kill entre writes — se
/// trata como ausencia → skip del revoke, misma clase que el residual población-cero). INVARIANTE del
/// writer (SERIO #1 del review adversarial): `write` BORRA el par previo ANTES de escribir y luego
/// escribe user → token. Sin el clear, una SOBRESCRITURA matada entre los 2 writes podía dejar el
/// estado cruzado `(token del DUEÑO, user de la SECUNDARIA)` — y el match del AJUSTE #1 habría PASADO,
/// revocando al dueño al borrar la secundaria. Con el clear, todo estado intermedio es `()`, `(user)` o
/// `(user, token)` DEL MISMO sign-in → el reader devuelve nil o un par coherente, jamás uno cruzado.
nonisolated struct SIWARefreshTokenStore {

    static let tokenKey = "cloudauth.appleRefreshToken"
    static let userKey = "cloudauth.appleRefreshToken.user"

    struct Pair: Equatable {
        let refreshToken: String
        let appleUserID: String
    }

    private let storage: CloudAuthKeychainStorage

    init(storage: CloudAuthKeychainStorage = CloudAuthKeychainStorage()) {
        self.storage = storage
    }

    /// El par completo, o `nil` si falta CUALQUIERA de las dos keys (o el Keychain falla — best-effort).
    func read() -> Pair? {
        do {
            guard
                let tokenData = try storage.retrieve(key: Self.tokenKey),
                let userData = try storage.retrieve(key: Self.userKey),
                let token = String(data: tokenData, encoding: .utf8), !token.isEmpty,
                let user = String(data: userData, encoding: .utf8), !user.isEmpty
            else { return nil }
            return Pair(refreshToken: token, appleUserID: user)
        } catch {
            #if DEBUG
            print("SIWARefreshTokenStore.read: \(error)")
            #endif
            return nil
        }
    }

    /// Escribe el PAR: CLEAR del par previo primero (invariante anti-cruce, ver header), luego
    /// user → token. Lanza si el Keychain falla al escribir (el caller cuenta el canario).
    func write(_ pair: Pair) throws {
        // El clear NO es opcional: sin él, un kill entre los 2 stores de una sobrescritura mezclaría
        // el token viejo con el user nuevo (par CRUZADO que el match por appleUserID no detecta).
        clear()
        try storage.store(key: Self.userKey, value: Data(pair.appleUserID.utf8))
        try storage.store(key: Self.tokenKey, value: Data(pair.refreshToken.utf8))
    }

    /// Borra AMBAS keys (revoke exitoso). Best-effort (itemNotFound es éxito en el storage).
    func clear() {
        for key in [Self.tokenKey, Self.userKey] {
            do {
                try storage.remove(key: key)
            } catch {
                #if DEBUG
                print("SIWARefreshTokenStore.clear: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Composición del canje (hook post-sign-in)

/// Composición de PRODUCCIÓN del hook de canje SIWA — el ÚNICO punto que la instala es
/// AppBootstrapper (AJUSTE #2: `CloudAuthService` no depende de `CloudAccountClient`; el hook default
/// es `nil` = no-op). Best-effort con timeout 4s (molde `PushTokenSignOutSeam`): el sign-in JAMÁS
/// falla ni se retrasa por esto. Residual documentado: kill de la app en esos ~4s = sin token
/// custodiado (misma clase que población-cero; re-sign-in lo cura).
@MainActor
enum SIWAExchangeSeam {

    /// Tope del canje best-effort (offline → se abandona; el próximo sign-in re-acuña el par).
    static let exchangeTimeout: Duration = .seconds(4)

    /// Dependencias inyectables (molde `deviceTokenProvider`/`AccountDeletionService.Dependencies`).
    struct Dependencies {
        var accessToken: @MainActor () async -> String?
        /// `POST /account/siwa/exchange` → refresh token de Apple, o `nil` en cualquier fallo.
        var exchange: @MainActor (_ jwt: String, _ authorizationCode: String) async -> String?
        var storePair: @MainActor (SIWARefreshTokenStore.Pair) throws -> Void

        nonisolated static let live = Dependencies(
            accessToken: { await CloudAuthService.shared.accessToken() },
            exchange: { jwt, code in
                // SIN `attestProvider` a propósito: `POST /account/siwa/exchange` va por `requireUser`
                // (`gateway/src/sync/siwa.ts:100`) — es adyacente al sign-in, anterior al `/attest/bind`.
                // Su hermano `siwaRevoke` SÍ lo lleva (`requireUserAndAttest`, `siwa.ts:167`).
                let outcome = await CloudAccountClient().siwaExchange(jwt: jwt, authorizationCode: code)
                switch outcome {
                case .success(let refreshToken):
                    return refreshToken
                case .sessionExpired, .transient:
                    return nil
                }
            },
            storePair: { try SIWARefreshTokenStore().write($0) }
        )
    }

    /// Instala el hook real en `CloudAuthService.shared`. Llamar UNA vez (AppBootstrapper).
    static func installProductionHook() {
        CloudAuthService.shared.siwaExchangeHook = { code, appleUserID in
            Task { @MainActor in
                await performExchange(authorizationCode: code, appleUserID: appleUserID)
            }
        }
    }

    /// Resultado interno de la carrera (jwt + red DENTRO del tope — LOW #3 del review: el refresh del
    /// SDK de Supabase puede ir a red sin tope propio, así que `accessToken()` también corre acotado).
    private enum ExchangeRace: Sendable {
        case noJwt
        case failed  // exchange rechazado / timeout
        case success(String)
    }

    /// Canjea y custodia el PAR. Testeable con deps inyectadas; jamás lanza.
    static func performExchange(
        authorizationCode: String,
        appleUserID: String,
        deps: Dependencies = .live
    ) async {
        // Carrera (accessToken + exchange) vs timeout 4s (molde PushTokenSignOutSeam) — el perdedor
        // se cancela. El tope cubre TAMBIÉN el refresh del JWT (offline-con-token-expirado incluido).
        let result: ExchangeRace = await withTaskGroup(of: ExchangeRace.self) { group in
            group.addTask { @MainActor in
                guard let jwt = await deps.accessToken(), !jwt.isEmpty else { return .noJwt }
                guard let token = await deps.exchange(jwt, authorizationCode) else { return .failed }
                return .success(token)
            }
            group.addTask {
                try? await Task.sleep(for: exchangeTimeout)
                return .failed
            }
            let first = await group.next() ?? .failed
            group.cancelAll()
            return first
        }

        let refreshToken: String?
        switch result {
        case .noJwt:
            CloudSyncBreadcrumb.siwaExchangeFailed(reason: "no-jwt")
            MetricsService.siwaExchangeFailed(reason: "no-jwt")
            return
        case .failed:
            refreshToken = nil
        case .success(let token):
            refreshToken = token
        }

        guard let refreshToken else {
            CloudSyncBreadcrumb.siwaExchangeFailed(reason: "exchange")
            MetricsService.siwaExchangeFailed(reason: "exchange")
            return
        }

        do {
            try deps.storePair(SIWARefreshTokenStore.Pair(refreshToken: refreshToken, appleUserID: appleUserID))
            CloudSyncBreadcrumb.siwaExchangeStored()
        } catch {
            #if DEBUG
            print("SIWAExchangeSeam: storePair falló: \(error)")
            #endif
            CloudSyncBreadcrumb.siwaExchangeFailed(reason: "keychain")
            MetricsService.siwaExchangeFailed(reason: "keychain")
        }
    }
}

// MARK: - Revocación (paso 4a del borrado)

@MainActor
enum SIWATokenRevocation {

    /// Tope del revoke best-effort (offline → se abandona sin limpiar el par; un retry del borrado —
    /// idempotente — lo reintenta; en el peor caso el token queda custodiado, jamás filtrado).
    static let revokeTimeout: Duration = .seconds(4)

    /// Dependencias inyectables (molde `AccountDeletionService.Dependencies` — tests sin singleton).
    struct Dependencies {
        var readPair: @MainActor () -> SIWARefreshTokenStore.Pair?
        /// appleUserID VIGENTE (`cloudauth.appleUserID`) para el match del par (AJUSTE #1).
        var currentAppleUserID: @MainActor () -> String?
        var accessToken: @MainActor () async -> String?
        /// `POST /account/siwa/revoke` → true solo con 200 `{revoked:true}`.
        var revoke: @MainActor (_ jwt: String, _ refreshToken: String) async -> Bool
        var clearPair: @MainActor () -> Void

        /// Attest de producción (mismo molde que `AccountDeletionService.Dependencies.liveAttest`).
        nonisolated static let live = Dependencies(
            readPair: { SIWARefreshTokenStore().read() },
            currentAppleUserID: { CloudAuthService.shared.storedAppleUserID() },
            accessToken: { await CloudAuthService.shared.accessToken() },
            revoke: { jwt, refreshToken in
                let client = CloudAccountClient(attestProvider: AttestSessionProvider.live)
                return await client.siwaRevoke(jwt: jwt, refreshToken: refreshToken) == .success
            },
            clearPair: { SIWARefreshTokenStore().clear() }
        )
    }

    /// Revoca el token de SIWA si aplica (paso 4a del borrado — el JWT de Supabase sigue válido: la
    /// verificación del Worker es stateless). Best-effort por diseño — JAMÁS lanza ni bloquea el
    /// borrado de cuenta hacia el caller.
    static func revokeIfNeeded() async {
        await revokeIfNeeded(deps: .live)
    }

    /// Cuerpo testeable con deps inyectadas.
    static func revokeIfNeeded(deps: Dependencies) async {
        guard let pair = deps.readPair() else {
            // Sin par custodiado: sesión previa al capture (población cero, ver header) o exchange fallido.
            CloudSyncBreadcrumb.siwaRevokeSkippedNoToken()
            return
        }

        // AJUSTE #1 — match obligatorio: par de OTRA cuenta de Apple (p.ej. residuo del dueño bajo la
        // secundaria) → no-op SIN POST y SIN limpiar (el par sigue siendo válido para su dueño).
        guard let current = deps.currentAppleUserID(), current == pair.appleUserID else {
            CloudSyncBreadcrumb.siwaRevokeSkippedStaleToken()
            return
        }

        // Carrera (accessToken + revoke) vs timeout 4s (molde PushTokenSignOutSeam). El tope cubre
        // TAMBIÉN el refresh del JWT (LOW #3 del review: el SDK de Supabase puede ir a red sin tope
        // propio — el contrato ≤4s aplica igual en offline-con-token-expirado).
        let result: RevokeRace = await withTaskGroup(of: RevokeRace.self) { group in
            group.addTask { @MainActor in
                guard let jwt = await deps.accessToken(), !jwt.isEmpty else { return .noJwt }
                return await deps.revoke(jwt, pair.refreshToken) ? .revoked : .failed
            }
            group.addTask {
                try? await Task.sleep(for: revokeTimeout)
                return .failed
            }
            let first = await group.next() ?? .failed
            group.cancelAll()
            return first
        }

        switch result {
        case .revoked:
            // Éxito → el par muere con la cuenta (NO limpiar en fallo: queda custodiado para un retry).
            deps.clearPair()
            CloudSyncBreadcrumb.siwaRevoked()
        case .noJwt:
            CloudSyncBreadcrumb.siwaRevokeFailed(reason: "no-jwt")
            MetricsService.siwaRevokeFailed(reason: "no-jwt")
        case .failed:
            CloudSyncBreadcrumb.siwaRevokeFailed(reason: "revoke")
            MetricsService.siwaRevokeFailed(reason: "revoke")
        }
    }

    /// Resultado interno de la carrera de revoke (jwt + red dentro del tope de 4s).
    private enum RevokeRace: Sendable {
        case noJwt
        case failed  // rechazo / timeout
        case revoked
    }
}
