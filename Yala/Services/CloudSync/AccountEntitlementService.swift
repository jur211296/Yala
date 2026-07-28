//
//  AccountEntitlementService.swift
//  Yala
//
//  Orquesta el derecho Pro de la CUENTA de Yala (C-8, 2026-07-27): vincula la suscripción de este
//  device a la cuenta y mantiene fresco el snapshot que `ProEntitlementLogic` combina con el
//  entitlement local de StoreKit.
//
//  Las dos operaciones y cuándo corren:
//   - `bindIfPossible()` — hay sesión de nube Y una transacción firmada en el device ⇒ POST del JWS.
//     Es lo que rescata a los Pro de HOY, cuyas compras son anteriores al `appAccountToken`: sin este
//     bind su derecho jamás llegaría a la cuenta. Idempotente y barato (una llamada por refresco).
//   - `refresh()` — trae el estado de la cuenta y lo cachea. Gobernado por `shouldRefresh` (min 6 h)
//     para no castigar cada foreground.
//
//  Reglas duras de esta capa:
//   - Un fallo de red NUNCA borra el snapshot ni degrada a Free: el `expiresAt` cacheado lo firmó
//     Apple y sigue siendo válido offline. Solo un 200 explícito lo reemplaza.
//   - El snapshot SIEMPRE se escribe con el `userID` de la sesión viva; `ProEntitlementLogic` no
//     acepta una caché de otra cuenta ni un segundo.
//   - `ownerMismatch` (409) es terminal y silencioso para el usuario: su Pro local sigue intacto,
//     simplemente esa suscripción pertenece a otra cuenta de Yala.
//

import Foundation

@MainActor
final class AccountEntitlementService {

    static let shared = AccountEntitlementService()

    private let store: AccountEntitlementStore
    private let client: CloudAccountClient
    /// Token de la sesión de nube. Inyectable para tests (evita el singleton de auth).
    private let jwtProvider: @MainActor () async -> String?
    private let userIDProvider: @MainActor () -> String?
    /// JWS de la suscripción activa del device (`nil` = usuario Free en este Apple ID).
    private let storeKitJWSProvider: @MainActor () async -> String?
    /// ¿Hay backend al que preguntar? En producción hoy es `false` (placeholder) y `sync` sale sin
    /// tocar la red. Inyectable: un test que provee su propio cliente HTTP ya decidió que sí lo hay.
    private let isConfiguredProvider: @MainActor () -> Bool

    /// Guard de reentrada: foreground + boot + post-compra pueden coincidir; una sola en vuelo.
    private var isWorking = false
    /// Un `force` que llega con otra sync en vuelo NO se descarta: se re-ejecuta al terminar. Sin
    /// esto, el bind post-compra (el que más urge) lo perdía la sync del foreground que dispara el
    /// propio cierre de la hoja de StoreKit, y el throttle de 6 h lo fijaba el perdedor.
    private var forceRequestedWhileWorking = false

    /// Dependencias `nil` = las de producción, resueltas DENTRO del init: los valores por defecto de
    /// un parámetro se evalúan en contexto `nonisolated` y estos singletons son `@MainActor` (error
    /// en Swift 6). Los tests inyectan las suyas y no tocan ningún singleton.
    init(
        store: AccountEntitlementStore? = nil,
        client: CloudAccountClient? = nil,
        jwtProvider: (@MainActor () async -> String?)? = nil,
        userIDProvider: (@MainActor () -> String?)? = nil,
        storeKitJWSProvider: (@MainActor () async -> String?)? = nil,
        isConfiguredProvider: (@MainActor () -> Bool)? = nil
    ) {
        self.store = store ?? .shared
        self.client = client ?? CloudAccountClient()
        self.jwtProvider = jwtProvider ?? { await CloudAuthService.shared.accessToken() }
        self.userIDProvider = userIDProvider ?? { CloudAuthService.shared.currentUserID }
        self.storeKitJWSProvider = storeKitJWSProvider ?? {
            await StoreKitManager.shared.fetchActiveTransactionJWS()
        }
        // Un cliente HTTP inyectado implica backend: el default solo aplica a producción.
        self.isConfiguredProvider = isConfiguredProvider ?? (client != nil ? { true } : { CloudBackendConfig.isConfigured })
    }

    /// Snapshot cacheado (lo consume `StoreKitManager` al resolver `isProUser`).
    var cachedSnapshot: AccountEntitlementSnapshot? { store.read() }

    /// Sincroniza el derecho de la cuenta: vincula si este device tiene suscripción, y refresca el
    /// snapshot si toca. `force` salta el min-interval (post-compra, post-sign-in).
    /// Devuelve `true` si el snapshot cambió (el caller re-deriva `isProUser`).
    @discardableResult
    func sync(force: Bool = false) async -> Bool {
        guard isConfiguredProvider() else { return false }
        guard let userID = userIDProvider() else { return false }
        guard !isWorking else {
            if force { forceRequestedWhileWorking = true }
            return false
        }
        guard force || ProEntitlementLogic.shouldRefresh(snapshot: store.read(), sessionUserID: userID) else {
            return false
        }
        isWorking = true
        defer {
            isWorking = false
            if forceRequestedWhileWorking {
                forceRequestedWhileWorking = false
                Task { @MainActor in await self.sync(force: true) }
            }
        }

        guard let jwt = await jwtProvider() else { return false }

        // 1. Bind: solo si este device tiene una suscripción firmada. La respuesta del bind YA trae
        //    el estado de la cuenta, así que hace de refresco y ahorra la segunda llamada.
        if let jws = await storeKitJWSProvider() {
            let outcome = await client.bindEntitlement(jwt: jwt, storeKitJWS: jws)
            if case .success(let product, let expiresAt) = outcome {
                return persist(product: product, expiresAt: expiresAt, userID: userID)
            }
            #if DEBUG
            print("AccountEntitlementService: bind no aplicado: \(outcome)")
            #endif
            // `ownerMismatch` es terminal (la suscripción es de otra cuenta), pero el estado de ESTA
            // cuenta sigue siendo consultable: seguimos al GET.
        }

        // 2. Refresco puro (device sin suscripción propia: el caso que motiva C-8).
        let outcome = await client.entitlement(jwt: jwt)
        switch outcome {
        case .success(let product, let expiresAt):
            return persist(product: product, expiresAt: expiresAt, userID: userID)
        case .sessionExpired, .transient, .ownerMismatch:
            // JAMÁS borrar la caché por un fallo: el snapshot vigente vale hasta su expiry firmado.
            #if DEBUG
            print("AccountEntitlementService: refresh sin resultado: \(outcome)")
            #endif
            return false
        }
    }

    /// Frontera de cuenta (sign-out, cambio de dueño): el derecho de una cuenta no sobrevive a su
    /// salida. Es EL punto de la frontera — `CloudAuthService.signOut` llama aquí, no al store — para
    /// que toda invalidación futura tenga un solo sitio donde vivir.
    ///
    /// Re-deriva `isProUser` in-session: sin esto, un usuario cuyo Pro venía SOLO de la cuenta se
    /// queda con la UI Pro abierta (tema, iconos, export, chat) y con el flag `true` en el App Group
    /// —que lee el intent de Siri— hasta el siguiente relanzamiento, por caminos de cierre que no
    /// relanzan el proceso.
    func handleSignOut() async {
        store.clear()
        await StoreKitManager.shared.updateSubscriptionStatus()
    }

    /// Sesión nueva: el derecho de esa cuenta debe aparecer YA, no en el próximo foreground. Es el
    /// caso central de C-8 — entrar con tu cuenta de Yala en un device con otro Apple ID.
    func handleSignIn() async {
        guard await sync(force: true) else { return }
        await StoreKitManager.shared.updateSubscriptionStatus()
    }

    private func persist(product: String?, expiresAt: Date?, userID: String) -> Bool {
        // La sesión pudo cambiar (o cerrarse) durante el await de red: escribir aquí resucitaría el
        // snapshot que la frontera de cuenta acaba de purgar, o lo escribiría con el dueño viejo.
        guard userIDProvider() == userID else {
            #if DEBUG
            print("AccountEntitlementService: respuesta de una sesión que ya no está — se descarta")
            #endif
            return false
        }
        let previous = store.read()
        let snapshot = AccountEntitlementSnapshot(
            userID: userID, product: product, expiresAt: expiresAt, refreshedAt: .now)
        store.write(snapshot)
        // Solo el DERECHO cuenta como cambio — `refreshedAt` se mueve en cada sync y re-derivar
        // `isProUser` por eso sería ruido en cada foreground.
        return previous?.userID != snapshot.userID
            || previous?.expiresAt != snapshot.expiresAt
            || previous?.product != snapshot.product
    }
}
