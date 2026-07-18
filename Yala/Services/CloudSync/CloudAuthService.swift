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
import GoogleSignIn

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
            MetricsService.siwaExchangeFailed(reason: "no-code")
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
    /// El usuario canceló el sheet de sign-in (Google) — la UI lo consume SIN alert (sesión 2;
    /// el cancel de SIWA sigue llegando como `ASAuthorizationError` crudo, fuera de alcance).
    case cancelled
    /// No hay view controller presentador para el sheet de Google (antes `preconditionFailure` —
    /// nota 5 post-implementación sesión 1: un throw permite a la UI degradar sin trap).
    case presentationUnavailable
}

/// Provider de sign-in del Modo Nube. `rawValue` = string del wire (`profiles.provider` /
/// body del claim / faro `CloudBeacon`).
nonisolated enum CloudSignInProvider: String {
    case apple
    case google
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

    /// Sign-in de GOOGLE en vuelo — guard COMPARTIDO con el de SIWA (`signInContinuation`): un
    /// sign-in Apple y uno Google jamás conviven (los taps del panel son idempotentes por-flujo).
    private var googleSignInInFlight = false

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
    /// Provider del ÚLTIMO sign-in exitoso (`"apple"` | `"google"`) — credencial de SESIÓN (se borra
    /// en `signOut()`, a diferencia de los pares por-provider que sobreviven). Fuente para el
    /// `provider` del claim (`storedProvider()`).
    private static let keyProvider = "cloudauth.provider"

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

    /// FUERZA el refresh del access token (`refreshSession()` canjea el refresh token AHORA) y devuelve el
    /// JWT nuevo. A diferencia de `accessToken()` — que solo auto-refresca cuando quedan <30s de margen —
    /// esto siempre rota: el retry-once del 401 del canal de Grupos (H-2026-07-18-4) lo necesita para
    /// rescatar un 401 disparado en la ventana de expiry (un `accessToken()` normal ahí devolvería el
    /// MISMO token vencido). `nil` sin config / sin sesión / fallo (do/catch, jamás `try?` silenciador).
    func forceRefreshAccessToken() async -> String? {
        guard let client else { return nil }
        do {
            let session = try await client.refreshSession()
            return session.accessToken
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

    /// Provider del último sign-in exitoso (`"apple"` | `"google"`). `nil` = sin sesión firmada en
    /// este device (o key perdida — los call-sites de claim caen a `?? "apple"` con residual anotado).
    func storedProvider() -> String? { readProfileString(Self.keyProvider) }

    // MARK: - Sign in with Apple

    /// Lanza el flujo nativo de Sign in with Apple y, si tiene éxito, crea la sesión de Supabase vía
    /// `signInWithIdToken`. Nonce: aleatorio seguro → SHA-256 HEX al request de Apple, RAW a Supabase
    /// (gotcha "Unacceptable audience" si se cruzan). Captura email/fullName SOLO en el primer sign-in.
    func signInWithApple() async throws {
        guard client != nil else { throw CloudAuthError.notConfigured }
        // Guard in-flight BIDIRECCIONAL (fix review adversarial #1): sin `!googleSignInInFlight`, un
        // SIWA arrancado durante el await del sheet de Google podía aterrizar su exchange entre el
        // exchange de Google y su reanudación → par (googleUserID_G, sub_APPLE) CRUZADO por valores,
        // que el clear-before-write del store no puede prevenir.
        guard signInContinuation == nil, !googleSignInInFlight else {
            throw CloudAuthError.signInAlreadyInFlight
        }

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

    /// Despacho por provider (sesión 2 — un solo call-site para las vistas parametrizadas).
    func signIn(with provider: CloudSignInProvider) async throws {
        switch provider {
        case .apple: try await signInWithApple()
        case .google: try await signInWithGoogle()
        }
    }

    // MARK: - Google Sign-In (sesión 1 del brief BRIEF-GOOGLE-SIGNIN-V1)

    /// Lanza el flujo de Google Sign-In (SDK GoogleSignIn-iOS ≥9 con nonce CUSTOM — patrón idéntico a
    /// SIWA: aleatorio seguro → SHA-256 HEX al SDK, RAW a Supabase; `skip_nonce_check` queda OFF en el
    /// proyecto Supabase, restricción dura del brief) y, si tiene éxito, crea la sesión de Supabase
    /// vía `signInWithIdToken(provider: .google)`. El `accessToken` de Google acompaña SIEMPRE
    /// (GoTrue valida `at_hash` si viene en el id_token).
    ///
    /// Cancel del usuario (`GIDSignInError.canceled`) → `CloudAuthError.cancelled` (sesión 2,
    /// D2): la UI lo consume en silencio (sin alert ni breadcrumb — un cancel no es fallo).
    func signInWithGoogle() async throws {
        guard let client else { throw CloudAuthError.notConfigured }
        // Guard in-flight COMPARTIDO con SIWA: un sign-in Apple y uno Google jamás conviven.
        guard signInContinuation == nil, !googleSignInInFlight else {
            throw CloudAuthError.signInAlreadyInFlight
        }
        googleSignInInFlight = true
        defer { googleSignInInFlight = false }

        let rawNonce = Self.randomNonceString()

        // Un flujo de sign-in interactivo SIEMPRE corre con la app en foreground (hay un root VC) —
        // misma premisa que el `presentationAnchor` de SIWA. throw (no trap): la UI degrada a su
        // path de error normal (nota 5 post-implementación sesión 1).
        guard let presenter = Self.topPresentingViewController() else {
            throw CloudAuthError.presentationUnavailable
        }

        let result: GIDSignInResult
        do {
            // Firma verificada contra GIDSignIn.h 9.2.0:
            // `signInWithPresentingViewController:hint:additionalScopes:nonce:completion:` →
            // Swift async `signIn(withPresenting:hint:additionalScopes:nonce:)`.
            result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: nil,
                nonce: Self.sha256Hex(rawNonce)
            )
        } catch {
            // Cancel del usuario → tipado limpio, SIN breadcrumb (no es fallo).
            if Self.isGoogleCancellation(error) {
                throw CloudAuthError.cancelled
            }
            CloudSyncBreadcrumb.authSignInFailed(reason: "google-authorization")
            throw error
        }

        guard let idToken = result.user.idToken?.tokenString else {
            CloudSyncBreadcrumb.authSignInFailed(reason: "google-missing-idtoken")
            throw CloudAuthError.missingIdentityToken
        }

        do {
            _ = try await client.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: result.user.accessToken.tokenString,
                    nonce: rawNonce
                )
            )
        } catch {
            CloudSyncBreadcrumb.authSignInFailed(reason: "idtoken-exchange")
            throw error
        }
        CloudSyncBreadcrumb.authSignedIn()
        writeProfileString("google", forKey: Self.keyProvider)

        // Captura de perfil con la MISMA regla anti-sangrado que SIWA (helper compartido). La
        // identidad Google almacenada es el `googleUserID` del PAR (leída ANTES de re-escribirlo).
        // Corre TRAS el exchange exitoso (a diferencia de SIWA, que captura en el delegate): así un
        // exchange fallido jamás deja perfil capturado SIN par — un perfil huérfano dejaría ciega la
        // regla anti-sangrado del siguiente sign-in (identidad almacenada nil ⇒ "primer sign-in").
        // Google re-entrega email/nombre en CADA sign-in, así que no se pierde nada.
        // Cambio CROSS-provider (fix review adversarial #2): un perfil capturado de proveniencia
        // APPLE es invisible a la decisión de abajo (compara contra el googleUserID del par) — sin
        // este pre-clear, el email/nombre del humano SIWA anterior sobreviviría como perfil de esta
        // sesión Google, y su `keyAppleUserID` residual dejaría la red de revocación de Apple
        // (`refreshCredentialStateIfNeeded`) apuntando al humano equivocado: si ÉL revocara su
        // autorización SIWA, cerraría ESTA sesión Google.
        if storedAppleUserID() != nil {
            clearCapturedProfile()
        }
        let googleUserID = result.user.userID
        if let googleUserID {
            let profile = result.user.profile
            applyProfileCapture(
                persistIncomingUserIDToKey: nil,  // la identidad Google se persiste como PAR (abajo)
                storedUserID: GoogleUserPairStore(storage: profileStore).read()?.googleUserID,
                incomingUserID: googleUserID,
                email: profile.flatMap { $0.email.isEmpty ? nil : $0.email },
                fullName: profile.flatMap { $0.name.isEmpty ? nil : $0.name }
            )
        }

        // PAR (googleUserID, sub) — AJUSTE #1 del /review-plan: SOLO con AMBOS presentes
        // (`GIDGoogleUser.userID` es `String?`); si falta cualquiera ⇒ skip con breadcrumb, jamás un
        // par incompleto (el `disconnect()` de sesión 3 tiene skip natural sin par).
        if let googleUserID, let sub = currentUserID {
            do {
                try GoogleUserPairStore(storage: profileStore)
                    .write(.init(googleUserID: googleUserID, sub: sub))
            } catch {
                #if DEBUG
                print("CloudAuthService.signInWithGoogle: pair write failed: \(error)")
                #endif
                CloudSyncBreadcrumb.googlePairCaptureSkipped(reason: "keychain")
            }
        } else {
            CloudSyncBreadcrumb.googlePairCaptureSkipped(
                reason: googleUserID == nil ? "no-google-user-id" : "no-sub")
        }
    }

    /// ¿Es el error el CANCEL del usuario en el sheet de Google? Por NSError domain+code (AJUSTE #6
    /// del /review-plan: cubre tanto el enum `GIDSignInError` bridgeado como un NSError crudo del
    /// SDK — y es fabricable en tests sin el flujo real).
    nonisolated static func isGoogleCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == kGIDSignInErrorDomain
            && nsError.code == GIDSignInError.canceled.rawValue
    }

    /// Root/topmost view controller del key window — presentador del sheet web de Google (mismo
    /// criterio de ventana que el `presentationAnchor` de SIWA, devolviendo UIViewController).
    private static func topPresentingViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    /// Cierra la sesión LOCAL (no revoca refresh tokens en el server — es el sign-out del device) y
    /// BORRA el perfil capturado (email/fullName/appleUserID) del Keychain propio — fix review R2 #1:
    /// sin este borrado, un usuario B que firme después en el mismo device heredaría el email/nombre
    /// de A (el guard "solo rellenar huecos" vería datos presentes y los reusaría).
    func signOut() async {
        guard let client else { return }
        clearCapturedProfile()
        // `keyProvider` es credencial de SESIÓN (no del provider) → muere con el sign-out. Cubre de
        // una vez los 6 paths de `CloudSessionSignOut` (todos llaman este `signOut()`).
        clearStoredProvider()
        // Higiene Google (H6 del brief): sign-out LOCAL del SDK — jamás `disconnect()` (eso revoca el
        // grant OAuth entero; es el paso 4b del borrado de cuenta, sesión 3). Sin esto, la sesión del
        // SDK de la cuenta A quedaría viva al entrar B. No-op si nunca hubo sign-in Google. El PAR
        // Google NO se borra (paridad con el par SIWA: credencial del provider, no de la sesión).
        GIDSignIn.sharedInstance.signOut()
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
        // Cambio CROSS-provider simétrico (fix review adversarial #2): perfil capturado de
        // proveniencia GOOGLE (par presente, sin appleUserID) es invisible a `decide` → pre-clear.
        // El PAR Google NO se borra (credencial del provider — el match por `sub` de sesión 3 hace
        // el residuo inofensivo). Byte-idéntico para todo estado pre-Google (par imposible).
        if readProfileString(Self.keyAppleUserID) == nil,
           GoogleUserPairStore(storage: profileStore).read() != nil {
            clearCapturedProfile()
        }
        applyProfileCapture(
            persistIncomingUserIDToKey: Self.keyAppleUserID,
            storedUserID: readProfileString(Self.keyAppleUserID),
            incomingUserID: credential.user,
            email: credential.email,
            fullName: incomingFullName
        )
    }

    /// Trozo COMPARTIDO de la captura de perfil (Apple + Google) — la regla anti-sangrado vive en
    /// `CloudAuthProfileCapture.decide` (pura, testeada); esto solo la aplica sobre el Keychain.
    /// `persistIncomingUserIDToKey`: Apple persiste su identidad aquí (`keyAppleUserID`, SIEMPRE —
    /// para `getCredentialState`); Google pasa `nil` (su identidad se persiste como PAR en el
    /// call-site, tras el exchange). Extraído con BYTE-IDENTIDAD del path SIWA (ajuste #2).
    private func applyProfileCapture(
        persistIncomingUserIDToKey userIDKey: String?,
        storedUserID: String?,
        incomingUserID: String,
        email: String?,
        fullName: String?
    ) {
        let decision = CloudAuthProfileCapture.decide(
            storedAppleUserID: storedUserID,
            incomingAppleUserID: incomingUserID,
            hasStoredEmail: readProfileString(Self.keyCapturedEmail) != nil,
            hasStoredFullName: readProfileString(Self.keyCapturedFullName) != nil,
            hasIncomingEmail: email != nil,
            hasIncomingFullName: fullName != nil
        )
        if decision.clearStoredProfile {
            clearCapturedProfile()
        }
        if let userIDKey {
            writeProfileString(incomingUserID, forKey: userIDKey)
        }
        if decision.writeEmail, let email {
            writeProfileString(email, forKey: Self.keyCapturedEmail)
        }
        if decision.writeFullName, let fullName {
            writeProfileString(fullName, forKey: Self.keyCapturedFullName)
        }
    }

    /// Borra `keyProvider` (credencial de sesión) — separado de `clearCapturedProfile` porque el
    /// clear del perfil también corre a MITAD de un sign-in (cambio de cuenta) donde el provider
    /// aún no se re-escribió.
    private func clearStoredProvider() {
        do {
            try profileStore.remove(key: Self.keyProvider)
        } catch {
            #if DEBUG
            print("CloudAuthService.clearStoredProvider: \(error)")
            #endif
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
                    // Provider de la sesión (fuente del claim) — espejo del write en signInWithGoogle.
                    self.writeProfileString("apple", forKey: Self.keyProvider)
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
