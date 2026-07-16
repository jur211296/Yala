//
//  CloudAuthService.swift
//  Yala
//
//  Sesión real del Modo Nube (I7c): Sign in with Apple nativo → `signInWithIdToken` de Supabase Auth →
//  JWT + refresh token en un Keychain propio (via `CloudAuthKeychainStorage`, AfterFirstUnlock). Es el
//  motor de la sesión que `LiveCloudSessionProvider` expone al `CloudSyncRuntime` (el seam que I9 dejó
//  con `NoopCloudSessionProvider`).
//
//  INSTANCIA ÚNICA process-global (`shared`): el panel DEBUG y `LiveCloudSessionProvider` consumen LA
//  MISMA — dos `AuthClient` competirían por el mismo storage de Keychain y la rotación del refresh de
//  uno invalidaría el del otro (AJUSTE review).
//
//  GUARD DE CONSTRUCCIÓN (AJUSTE review): sin `CloudBackendConfig.isConfigured` NADA se instancia
//  (`client == nil`, sin observer de revocación) → en producción HOY (placeholder) toda la superficie
//  queda inerte y el runtime conserva el Noop de I9. Cero cambio de comportamiento (DARK).
//
//  Cero silencios: errores tipados + breadcrumb `CloudSyncBreadcrumb` (fuera de `#if DEBUG`, sin PII —
//  JAMÁS se loguea el token, el email ni el `sub` completo).
//

import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

import Auth

/// Decisión PURA de captura del perfil de Apple (email/fullName) — extraída para testear SIN el SDK la
/// regla anti-sangrado de PII entre cuentas (fix review R2 #1): si el Apple ID entrante DIFIERE del
/// almacenado, el perfil previo se BORRA y se sobrescribe completo (un cambio de cuenta JAMÁS reusa el
/// email/nombre de otra persona); si es la misma cuenta (o primer sign-in del device), solo se rellenan
/// los huecos (Apple entrega email/fullName SOLO en el primer sign-in de esa cuenta).
nonisolated enum CloudAuthProfileCapture {

    struct Decision: Equatable {
        /// Borrar email/fullName almacenados ANTES de escribir (cambio de Apple ID).
        let clearStoredProfile: Bool
        let writeEmail: Bool
        let writeFullName: Bool
    }

    static func decide(
        storedAppleUserID: String?,
        incomingAppleUserID: String,
        hasStoredEmail: Bool,
        hasStoredFullName: Bool,
        hasIncomingEmail: Bool,
        hasIncomingFullName: Bool
    ) -> Decision {
        let accountChanged = storedAppleUserID != nil && storedAppleUserID != incomingAppleUserID
        if accountChanged {
            // Cuenta DISTINTA: nada del perfil previo sobrevive; se escribe lo que venga (aunque no
            // venga nada — mejor un perfil vacío que el de otra persona).
            return Decision(
                clearStoredProfile: true,
                writeEmail: hasIncomingEmail,
                writeFullName: hasIncomingFullName
            )
        }
        // Misma cuenta (o sin perfil previo): solo rellenar huecos, nunca sobrescribir.
        return Decision(
            clearStoredProfile: false,
            writeEmail: hasIncomingEmail && !hasStoredEmail,
            writeFullName: hasIncomingFullName && !hasStoredFullName
        )
    }
}

/// Lógica post-credencial del canje SIWA (B1, 5.1.1(v)) — extraída para testear SIN instanciar el
/// delegate de ASAuthorization: decodifica el `authorizationCode` (UTF-8, no vacío) y decide invocar el
/// hook. Hook `nil` (default — producción sin componer / tests) = no-op ANTES de mirar el code (byte-
/// idéntico). Hook instalado pero sin code utilizable → canario `siwaExchangeFailed` (Apple no entregó
/// el code → no habrá token revocable de este sign-in; población cero pre-feature, ver el brief B1).
@MainActor
enum SIWAExchangeCapture {

    /// Decodifica el `credential.authorizationCode` (Data UTF-8) a String no vacío. Pura.
    nonisolated static func code(from data: Data?) -> String? {
        guard let data, let code = String(data: data, encoding: .utf8), !code.isEmpty else { return nil }
        return code
    }

    /// Invoca el hook con el code decodificado + el appleUserID de ESTE sign-in (AJUSTE #1: el par
    /// viaja junto hasta el Keychain). El sign-in JAMÁS falla ni se retrasa por esto: el hook real
    /// lanza su propio Task best-effort (composición en `SIWAExchangeSeam`).
    static func dispatch(
        hook: (@MainActor (_ authorizationCode: String, _ appleUserID: String) -> Void)?,
        codeData: Data?,
        appleUserID: String
    ) {
        guard let hook else { return }
        guard let code = code(from: codeData) else {
            CloudSyncBreadcrumb.siwaExchangeFailed(reason: "no-code")
            TelemetryService.siwaExchangeFailed(reason: "no-code")
            return
        }
        hook(code, appleUserID)
    }
}

/// Errores tipados del flujo de auth (sin PII).
enum CloudAuthError: Error, Equatable {
    /// El subsistema no está configurado (producción placeholder) → no hay `AuthClient`.
    case notConfigured
    /// Apple no devolvió un `identityToken` utilizable.
    case missingIdentityToken
    /// Un sign-in ya está en vuelo (los taps del panel son idempotentes por-flujo).
    case signInAlreadyInFlight
}

@MainActor
final class CloudAuthService: NSObject {

    /// Instancia ÚNICA (lazy). Compartida por el panel DEBUG y `LiveCloudSessionProvider`.
    static let shared = CloudAuthService()

    /// `nil` cuando `CloudBackendConfig.isConfigured == false` (producción placeholder) → todo no-op.
    private let client: AuthClient?

    /// Keychain propio para el perfil capturado (email/fullName) del PRIMER sign-in + el appleUserID
    /// (para `getCredentialState`). Service dedicado, NO colisiona con la sesión del SDK (otra `account`).
    private let profileStore = CloudAuthKeychainStorage()

    // Estado del flujo SIWA en vuelo.
    private var currentNonce: String?
    private var signInContinuation: CheckedContinuation<Void, Error>?
    private var authController: ASAuthorizationController?

    private var didRegisterRevocationObserver = false

    /// Hook INYECTADO del canje SIWA (B1, AJUSTE #2 del review — layering): la composición de producción
    /// (`SIWAExchangeSeam.installProductionHook()`, un ÚNICO punto en AppBootstrapper) instala el closure
    /// real que canjea el `authorizationCode` por el refresh token de Apple vía el Worker y persiste el
    /// PAR (token, appleUserID) en el Keychain. Default `nil` = no-op (tests byte-idénticos; sin
    /// dependencia CloudAuthService→CloudAccountClient — molde `deviceTokenProvider` de G8-3).
    var siwaExchangeHook: (@MainActor (_ authorizationCode: String, _ appleUserID: String) -> Void)?

    // Keys del perfil capturado (accounts dentro del service del `profileStore`).
    private static let keyCapturedEmail = "cloudauth.captured.email"
    private static let keyCapturedFullName = "cloudauth.captured.fullName"
    private static let keyAppleUserID = "cloudauth.appleUserID"

    // MARK: - Init

    private override init() {
        if CloudBackendConfig.isConfigured, let baseURL = CloudBackendConfig.supabaseURL {
            // `Authorization: Bearer <anon>` como DEFAULT es intencional y benigno (no un olor): es el
            // mismo par de headers que monta `SupabaseClient` upstream. El SDK SOBRESCRIBE Authorization
            // con el JWT del usuario en los requests autenticados (refresh/signOut/user); el default solo
            // aplica a los endpoints pre-sesión (p.ej. el propio token exchange), donde el rol `anon`
            // (clave PÚBLICA gobernada por RLS) es exactamente lo esperado.
            let configuration = AuthClient.Configuration(
                url: baseURL.appendingPathComponent("auth/v1"),
                headers: [
                    "Authorization": "Bearer \(CloudBackendConfig.anonKey)",
                    "apikey": CloudBackendConfig.anonKey,
                ],
                storageKey: "yala.cloudauth.session",
                localStorage: CloudAuthKeychainStorage(),
                autoRefreshToken: true
            )
            self.client = AuthClient(configuration: configuration)
        } else {
            self.client = nil
        }
        super.init()
        registerRevocationObserverIfNeeded()
    }

    // MARK: - Estado de sesión (consumido por LiveCloudSessionProvider + panel)

    var isConfigured: Bool { client != nil }

    /// El `sub` de la sesión (owner-scoping). Formato lowercase (== `uuid` text de Postgres/JWT).
    /// `nil` = sin sesión. `currentSession` puede estar expirado pero el `user.id` no cambia.
    var currentUserID: String? {
        client?.currentSession?.user.id.uuidString.lowercased()
    }

    /// ¿Hay una sesión almacenada (con refresh token)?
    var hasSession: Bool { client?.currentSession != nil }

    /// Contrato I7c (preflight de I9): `true` siempre que HAY sesión almacenada — tener sesión implica
    /// tener refresh token. Cuando el refresh falla terminal, el SDK limpia el storage → `currentSession`
    /// pasa a `nil` → esto pasa a `false` de forma natural. NUNCA reportar `false` con token vigente
    /// (bloquearía pushes que habrían tenido éxito).
    var canRenewSession: Bool { client?.currentSession != nil }

    /// Expiración del access token actual (para el panel). `nil` sin sesión.
    var sessionExpiry: Date? {
        guard let ts = client?.currentSession?.expiresAt else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    /// JWT de Supabase VIGENTE (el SDK auto-refresca dentro de `session`). `nil` = sin sesión / fallo.
    func accessToken() async -> String? {
        guard let client else { return nil }
        do {
            return try await client.session.accessToken
        } catch {
            CloudSyncBreadcrumb.authAccessTokenUnavailable()
            return nil
        }
    }

    /// appleUserID capturado del último sign-in (para el match del PAR SIWA — AJUSTE #1 del brief B1 —
    /// y `getCredentialState`). `nil` = nunca hubo sign-in en este device.
    func storedAppleUserID() -> String? { readProfileString(Self.keyAppleUserID) }

    /// Email capturado en el primer sign-in (para I14). `nil` si Apple nunca lo entregó / sin captura.
    func capturedEmail() -> String? { readProfileString(Self.keyCapturedEmail) }

    /// Nombre completo capturado en el primer sign-in (para I14).
    func capturedFullName() -> String? { readProfileString(Self.keyCapturedFullName) }

    // MARK: - Sign in with Apple

    /// Lanza el flujo nativo de Sign in with Apple y, si tiene éxito, crea la sesión de Supabase vía
    /// `signInWithIdToken`. Nonce: aleatorio seguro → SHA-256 HEX al request de Apple, RAW a Supabase
    /// (gotcha "Unacceptable audience" si se cruzan). Captura email/fullName SOLO en el primer sign-in.
    func signInWithApple() async throws {
        guard client != nil else { throw CloudAuthError.notConfigured }
        guard signInContinuation == nil else { throw CloudAuthError.signInAlreadyInFlight }

        let rawNonce = Self.randomNonceString()
        currentNonce = rawNonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256Hex(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.authController = controller

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.signInContinuation = continuation
            controller.performRequests()
        }
    }

    /// Cierra la sesión LOCAL (no revoca refresh tokens en el server — es el sign-out del device) y
    /// BORRA el perfil capturado (email/fullName/appleUserID) del Keychain propio — fix review R2 #1:
    /// sin este borrado, un usuario B que firme después en el mismo device heredaría el email/nombre
    /// de A (el guard "solo rellenar huecos" vería datos presentes y los reusaría).
    func signOut() async {
        guard let client else { return }
        clearCapturedProfile()
        do {
            try await client.signOut(scope: .local)
            CloudSyncBreadcrumb.authSignedOut(reason: "user")
        } catch {
            #if DEBUG
            print("CloudAuthService.signOut: \(error)")
            #endif
            CloudSyncBreadcrumb.authSignOutFailed()
        }
    }

    // MARK: - #23 mitigación cliente: revocación de credencial de Apple

    /// Chequea el estado de la credencial de Apple al volver a foreground; si fue revocada / no existe,
    /// cierra la sesión local. Llamable desde el panel o el ciclo de vida de la app.
    func refreshCredentialStateIfNeeded() async {
        guard client != nil, let appleUserID = readProfileString(Self.keyAppleUserID) else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let state: ASAuthorizationAppleIDProvider.CredentialState
        do {
            state = try await provider.credentialState(forUserID: appleUserID)
        } catch {
            return  // transitorio — no tocamos la sesión ante un fallo de consulta
        }
        switch state {
        case .revoked, .notFound:
            CloudSyncBreadcrumb.authCredentialRevoked()
            await signOut()
        case .authorized, .transferred:
            break
        @unknown default:
            break
        }
    }

    /// Descripción del estado de la credencial de Apple para el panel DEBUG. `nil` = sin appleUserID
    /// capturado (nunca hubo sign-in en este device). Sin PII (solo el enum).
    func credentialStateDescription() async -> String? {
        guard client != nil, let appleUserID = readProfileString(Self.keyAppleUserID) else { return nil }
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: appleUserID)
            switch state {
            case .authorized: return "authorized"
            case .revoked: return "revoked"
            case .notFound: return "notFound"
            case .transferred: return "transferred"
            @unknown default: return "unknown"
            }
        } catch {
            return "query failed"
        }
    }

    private func registerRevocationObserverIfNeeded() {
        guard client != nil, !didRegisterRevocationObserver else { return }
        didRegisterRevocationObserver = true
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                CloudSyncBreadcrumb.authCredentialRevoked()
                Task { await self.signOut() }
            }
        }
    }

    // MARK: - Nonce (testeable)

    /// Nonce aleatorio criptográficamente seguro (charset URL-safe). `SecRandomCopyBytes`; ante un fallo
    /// del RNG del sistema hace `preconditionFailure` (jamás un nonce débil). `nonisolated`: función pura.
    nonisolated static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                preconditionFailure("SecRandomCopyBytes failed: \(status)")
            }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    /// SHA-256 del input en HEX minúscula (lo que va al request de Apple). `nonisolated`: función pura.
    nonisolated static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Perfil capturado (Keychain propio)

    private func captureProfileIfPresent(_ credential: ASAuthorizationAppleIDCredential) {
        // Regla anti-sangrado de PII (pura, `CloudAuthProfileCapture.decide`): cuenta distinta →
        // sobrescribir el perfil completo; misma cuenta → solo rellenar huecos. appleUserID SIEMPRE
        // (para getCredentialState).
        let incomingFullName: String? = credential.fullName.flatMap { name in
            let full = PersonNameComponentsFormatter().string(from: name)
            return full.isEmpty ? nil : full
        }
        let decision = CloudAuthProfileCapture.decide(
            storedAppleUserID: readProfileString(Self.keyAppleUserID),
            incomingAppleUserID: credential.user,
            hasStoredEmail: readProfileString(Self.keyCapturedEmail) != nil,
            hasStoredFullName: readProfileString(Self.keyCapturedFullName) != nil,
            hasIncomingEmail: credential.email != nil,
            hasIncomingFullName: incomingFullName != nil
        )
        if decision.clearStoredProfile {
            clearCapturedProfile()
        }
        writeProfileString(credential.user, forKey: Self.keyAppleUserID)
        if decision.writeEmail, let email = credential.email {
            writeProfileString(email, forKey: Self.keyCapturedEmail)
        }
        if decision.writeFullName, let full = incomingFullName {
            writeProfileString(full, forKey: Self.keyCapturedFullName)
        }
    }

    /// Borra email/fullName/appleUserID del Keychain propio (sign-out y cambio de cuenta).
    private func clearCapturedProfile() {
        for key in [Self.keyCapturedEmail, Self.keyCapturedFullName, Self.keyAppleUserID] {
            do {
                try profileStore.remove(key: key)
            } catch {
                #if DEBUG
                print("CloudAuthService.clearCapturedProfile: \(error)")
                #endif
            }
        }
    }

    private func readProfileString(_ key: String) -> String? {
        do {
            guard let data = try profileStore.retrieve(key: key) else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            // `retrieve` ya devuelve nil para itemNotFound; llegar aquí = OSStatus real (fix R2 #5 —
            // simétrico con la ruta de escritura, nada de try? que colapsa el error).
            #if DEBUG
            print("CloudAuthService.readProfileString: \(error)")
            #endif
            return nil
        }
    }

    private func writeProfileString(_ value: String, forKey key: String) {
        do {
            try profileStore.store(key: key, value: Data(value.utf8))
        } catch {
            #if DEBUG
            print("CloudAuthService.writeProfileString: \(error)")
            #endif
        }
    }

    // MARK: - Continuation

    private func finishSignIn(_ result: Result<Void, Error>) {
        authController = nil
        currentNonce = nil
        guard let continuation = signInContinuation else { return }
        signInContinuation = nil
        continuation.resume(with: result)
    }
}

// MARK: - ASAuthorizationControllerDelegate / PresentationContextProviding
//
// Los métodos del delegate NO son `@MainActor` en el SDK, pero se invocan en el main thread → se marcan
// `nonisolated` y saltan con `MainActor.assumeIsolated` (compila limpio bajo default-MainActor isolation).

extension CloudAuthService: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        MainActor.assumeIsolated {
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                finishSignIn(.failure(CloudAuthError.missingIdentityToken))
                return
            }
            captureProfileIfPresent(credential)
            // B1 (5.1.1(v)): capturar TAMBIÉN el authorizationCode — es de un solo uso y expira en ~5 min,
            // por eso el canje corre EN el sign-in (hook best-effort), no al borrar la cuenta.
            let siwaCodeData = credential.authorizationCode
            let appleUserID = credential.user
            Task { @MainActor in
                do {
                    _ = try await self.client?.signInWithIdToken(
                        credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                    )
                    CloudSyncBreadcrumb.authSignedIn()
                    // Tras el exchange EXITOSO (hay JWT de Supabase para el Worker). Jamás bloquea/retrasa.
                    SIWAExchangeCapture.dispatch(
                        hook: self.siwaExchangeHook, codeData: siwaCodeData, appleUserID: appleUserID
                    )
                    self.finishSignIn(.success(()))
                } catch {
                    CloudSyncBreadcrumb.authSignInFailed(reason: "idtoken-exchange")
                    self.finishSignIn(.failure(error))
                }
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        MainActor.assumeIsolated {
            CloudSyncBreadcrumb.authSignInFailed(reason: "apple-authorization")
            finishSignIn(.failure(error))
        }
    }
}

extension CloudAuthService: ASAuthorizationControllerPresentationContextProviding {

    nonisolated func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
                ?? scenes.flatMap(\.windows).first {
                return window
            }
            // Un flujo SIWA interactivo SIEMPRE corre con la app en foreground (hay un window scene).
            // El único init de `UIWindow` no deprecado en iOS 26 es `init(windowScene:)`.
            guard let scene = scenes.first else {
                preconditionFailure("SIWA requires an active UIWindowScene")
            }
            return UIWindow(windowScene: scene)
        }
    }
}
