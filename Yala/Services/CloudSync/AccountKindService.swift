//
//  AccountKindService.swift
//  Yala
//
//  Guarda el TIPO de la cuenta en la nube entre lanzamientos, y lo corrige cuando el servidor lo dice.
//
//  POR QUÉ HAY UN SERVICIO Y NO SOLO UN DEFAULT. La decisión de Jürgen (2026-09-09) es «`kind`
//  ausente ⇒ `groups_only`, **PERO con corrección al refrescar**»: el sign-in no se bloquea si el
//  gateway calla, y la sesión no se queda en el modo equivocado. Sin este servicio, la segunda mitad
//  no existiría — medido: `GET /account/exists` tenía UN solo llamador en toda la app
//  (`WelcomeCloudSignInView.runSignInFlow`), que corre ANTES de que haya sesión y no vuelve a correr.
//  Un gateway caído en ese instante dejaría la cuenta completa rodando como solo-grupos para siempre,
//  que es justo lo contrario de lo que la decisión pedía.
//
//  DÓNDE VIVE EL DATO. `UserDefaults`, sellado con el `userID`, molde de `AccountEntitlementStore`.
//  Los otros dos sitios donde la app guarda hechos de la sesión NO sirven aquí:
//    · Keychain (`cloudauth.provider`) muere en `signOut`, y es lo que queremos, pero es del PROVEEDOR;
//    · iCloud-KV (`CloudBeacon`) VIAJA a otros dispositivos del mismo Apple ID, donde puede haber otra
//      cuenta en la nube activa — el dato describiría una cuenta distinta de la que está firmada.
//
//  NO RUTEA NADA. Quién lee este dato para elegir pantalla es `CloudIdentityRoutingLogic` (bloque [I]), y
//  quien lo descubre en el momento de firmar es `CloudIdentityDiscovery`. Este servicio es la otra mitad:
//  la CORRECCIÓN en el arranque, para la sesión que ya estaba viva y a la que nadie va a preguntar de nuevo.
//
//  **Tenía un tercer método, `handleSignIn()`, y se retiró el 2026-09-10.** Lo dejó preparado el paso 2 para
//  que el sign-in descubriera el tipo, y llegó al bloque [I] con **cero call-sites**. El descubrimiento en
//  las puertas lo hace `CloudIdentityDiscovery` —que además necesita saber si la cuenta EXISTE, algo que
//  `refresh()` descarta por dentro— así que mantenerlo era dejar dos caminos para el mismo hecho, y por ahí
//  se separan. Si algún día vuelve a hacer falta, es una línea.
//
//  ADR 2026-09-09 «Sesiones — dos ejes» §11 · ticket `backend-account-kind-complete-or-groups-only`.
//

import Foundation

/// Persistencia del snapshot. Espejo de `AccountEntitlementStore`, incluida su regla de oro: un JSON
/// ilegible se lee como «no sé», nunca como un valor concreto.
@MainActor
final class AccountKindStore {
    static let shared = AccountKindStore()

    private let defaults: UserDefaults
    private static let key = "cloudSync.accountKind"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func read() -> AccountKindSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        do {
            return try JSONDecoder().decode(AccountKindSnapshot.self, from: data)
        } catch {
            #if DEBUG
            print("AccountKindStore: snapshot ilegible, se ignora: \(error)")
            #endif
            return nil
        }
    }

    func write(_ snapshot: AccountKindSnapshot) {
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.key)
        } catch {
            #if DEBUG
            print("AccountKindStore: Error al guardar el snapshot: \(error)")
            #endif
        }
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// Refresca el tipo de cuenta contra el backend y lo deja cacheado.
@MainActor
final class AccountKindService {
    static let shared = AccountKindService()

    private let store: AccountKindStore
    private let client: CloudAccountClient
    private let jwtProvider: @MainActor () async -> String?
    private let userIDProvider: @MainActor () -> String?
    private let now: () -> Date

    /// `client` se construye SIN `attestProvider` a propósito: `/account/exists` lo sirve
    /// `requireUser`, que NO exige App Attest —es una ruta pre-sesión, anterior a `/attest/bind`— y
    /// cablear attest donde no se exige es lo que rompe el alta. Ver `.claude/rules/gateway-attest.md`.
    init(
        store: AccountKindStore? = nil,
        client: CloudAccountClient? = nil,
        jwtProvider: (@MainActor () async -> String?)? = nil,
        userIDProvider: (@MainActor () -> String?)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store ?? AccountKindStore.shared
        self.client = client ?? CloudAccountClient()
        self.jwtProvider = jwtProvider ?? { await CloudAuthService.shared.accessToken() }
        self.userIDProvider = userIDProvider ?? { CloudAuthService.shared.currentUserID }
        self.now = now
    }

    /// Lo que la app se cree AHORA, sin ir a la red.
    var current: AccountKind {
        AccountKindLogic.resolve(cached: store.read(), sessionUserID: userIDProvider())
    }

    /// Pregunta al backend y corrige lo cacheado. Es la mitad «con corrección» de la decisión.
    ///
    /// Silenciosa por diseño: si no hay sesión, si el gateway calla o si la respuesta no trae `kind`,
    /// **no se toca lo guardado**. Un servidor que no contesta no es una prueba de que la cuenta haya
    /// cambiado de tipo.
    @discardableResult
    func refresh() async -> AccountKind {
        guard let userID = userIDProvider(), !userID.isEmpty else { return .groupsOnly }
        guard let jwt = await jwtProvider() else { return current }

        let outcome = await client.exists(jwt: jwt)
        guard case let .exists(existe, kind, _) = outcome, existe else { return current }

        // El userID se re-lee DESPUÉS del await: entre la petición y la respuesta puede haberse
        // cerrado la sesión o entrado otra cuenta, y escribir aquí resucitaría un snapshot que la
        // frontera acaba de purgar. Es el mismo guard que `AccountEntitlementService.persist`.
        guard let userIDVivo = userIDProvider(), userIDVivo == userID else { return current }

        if let snapshot = AccountKindLogic.snapshotToPersist(
            remote: kind, sessionUserID: userIDVivo, cached: store.read(), now: now()
        ) {
            store.write(snapshot)
        }
        return AccountKindLogic.resolve(cached: store.read(), sessionUserID: userIDVivo)
    }

    /// Al salir: el dato de la cuenta se va con ella.
    ///
    /// El sello por `userID` ya impide que la siguiente cuenta LEA este snapshot, pero borrarlo es lo
    /// que evita que un dato de alguien siga en el disco de un dispositivo que ya no es suyo.
    func handleSignOut() {
        store.clear()
    }

    /// Tras «Volver a iCloud»: el servidor acaba de degradar la cuenta a solo-grupos y lo cacheado
    /// dice lo contrario.
    ///
    /// **Sin esto, la ÚNICA degradación del sistema no llegaría al dispositivo**: el reverse cutover
    /// no cierra sesión, así que nada invalidaría el snapshot y la app seguiría diciendo «tus datos
    /// viven en la nube» a quien acaba de devolverlos a iCloud. Se refresca en vez de escribir
    /// `groupsOnly` a mano: quien manda es el servidor, y así un reverse que no llegó a completarse
    /// no deja al cliente creyéndose una degradación que no ocurrió.
    func handleReverseCutoverCompleted() async {
        await refresh()
    }
}
