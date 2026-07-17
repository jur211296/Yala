//
//  PushTokenRegistrar.swift
//  Yala
//
//  Coordinador del registro del device token APNs del canal Grupos → backend (incremento G8-2, DARK detrás
//  de `CloudSyncFlags.groupsBackendEnabled`). Captura el token que emite el OS (AppDelegate handler (a)),
//  lo persiste local y lo sube al gateway (`/push/register`) cuando hay flag + sesión.
//
//  Init INYECTABLE (defaults/client/hasSession) — molde `ProUpsellService.init(defaults:)`: los tests
//  instancian una instancia FRESCA con `makeIsolatedDefaults()` + stub, jamás mutan `.shared`. El
//  `hasSession` es inyectable (el brief nombra `CloudAuthService.shared.hasSession` — se mantiene como
//  DEFECTO; el seam de inyección existe solo para testear el gate sin una sesión real, espejo del
//  `sessionCheck` inyectable de `GroupsSyncClient`).
//
//  Idempotente (upsert server-side): NO lleva marca "ya subido" — re-subir en cada boot es 1 request
//  barato que auto-sana rotaciones del token. CERO logging de token/PII; logs bajo `#if DEBUG`.
//

import Foundation

@MainActor
final class PushTokenRegistrar {

    static let shared = PushTokenRegistrar()

    /// Último device token APNs capturado (hex). El token es OPACO, NO-PII y rotable por el OS — persistirlo
    /// permite el re-registro al boot sin esperar a que el OS re-emita el token. DELIBERADAMENTE FUERA de la
    /// auditoría del wipe de sign-out (`removeUserPreferenceKeys`), igual que `YalaAppDelegate.debugDeviceTokenKey`:
    /// sobrevive al cambio de cuenta para re-registrar con la próxima sesión; el par (user, token) muere
    /// server-side vía el seam de sign-out. Su presencia local sin sesión es inofensiva (el gate de
    /// `attemptUpload` no sube sin flag + sesión).
    static let tokenKey = "push.apnsDeviceToken"

    private let defaults: UserDefaults
    private let client: PushTokenRegistrationClient
    private let hasSession: @MainActor () -> Bool

    /// `client` opcional con default nil (construido en el cuerpo): un `@MainActor` init no puede usarse
    /// como DEFAULT ARGUMENT en la firma (contexto nonisolado). Molde `GroupsSyncClient.merkleClient`.
    init(
        defaults: UserDefaults = .standard,
        client: PushTokenRegistrationClient? = nil,
        hasSession: @escaping @MainActor () -> Bool = { CloudAuthService.shared.hasSession }
    ) {
        self.defaults = defaults
        self.client = client ?? PushTokenRegistrationClient()
        self.hasSession = hasSession
    }

    /// Plataforma reportada al backend: aproximación al `aps-environment` del provisioning (Debug/dev =
    /// development = sandbox; TestFlight/AppStore = production). Residual raro documentado: un build Release
    /// LOCAL firmado con un perfil de development reportaría `ios-prod` pese a hablar con el APNs sandbox —
    /// no ocurre en el tren de distribución (Debug→sandbox, Release-distribución→prod).
    static var currentPlatform: String {
        #if DEBUG
        return "ios-sandbox"
        #else
        return "ios-prod"
        #endif
    }

    /// Token persistido (nil si nunca se capturó).
    var storedToken: String? { defaults.string(forKey: Self.tokenKey) }

    // MARK: - Seams de test

    /// La tarea de subida en vuelo (para que los tests la aguarden sin dormir). SOLO tests.
    private(set) var uploadTask: Task<Void, Never>?
    var _testUploadTask: Task<Void, Never>? { uploadTask }

    // MARK: - API

    /// AppDelegate handler (a): captura SIEMPRE (sin gate — persistir es local) y dispara la subida.
    func capture(token: String) {
        defaults.set(token, forKey: Self.tokenKey)
        attemptUpload()
    }

    /// Sube el token al backend si `groupsBackendEnabled && hasSession` y hay token. NO-OP total con el flag
    /// OFF (SIEMPRE esta fase) o sin sesión: retorna ANTES de tocar la red. Idempotente (upsert server-side).
    func attemptUpload() {
        guard CloudSyncFlags.groupsBackendEnabled, hasSession(),
              let token = storedToken, !token.isEmpty else { return }
        uploadTask = Task { @MainActor [weak self] in
            await self?.performUpload(token: token)
        }
    }

    private func performUpload(token: String) async {
        do {
            try await client.register(deviceToken: token, platform: Self.currentPlatform)
        } catch let error as PushTokenRegistrationError {
            switch error {
            case .serverRejected:
                // Fallo de SERVIDOR (4xx ≠ 401) → canario. NO en offline transitorio ni 401 (sesión).
                MetricsService.canary(.groupPushTokenRegisterFailed)
                #if DEBUG
                print("PushTokenRegistrar: register serverRejected: \(error)")
                #endif
            case .transient, .sessionExpired:
                #if DEBUG
                print("PushTokenRegistrar: register transitorio/sesión (reintenta al próximo boot): \(error)")
                #endif
            }
        } catch {
            #if DEBUG
            print("PushTokenRegistrar: register error inesperado: \(error)")
            #endif
        }
    }
}
