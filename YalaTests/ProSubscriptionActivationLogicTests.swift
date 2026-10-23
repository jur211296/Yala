//
//  ProSubscriptionActivationLogicTests.swift
//  YalaTests
//
//  Pinnea el borde compra/restore → Pro (bug TF 2.1 b11: éxito en sandbox y la
//  app seguía Free). Tres cosas que estos tests impiden, en orden de daño:
//   1. Celebrar un `.success` que no dejó `isProUser` en true.
//   2. Tirar la Transaction verificada y fiarse solo de `currentEntitlements`
//      vacío — in-session y al reabrir.
//   3. Restaurar en silencio cuando no hay derecho.
//
//  Dos mitades: la DECISIÓN (tablas) y el CABLEADO (source-scan). Ninguna cubre
//  a la otra: la tabla puede estar perfecta mientras `purchase` sigue poniendo
//  `didJustSubscribe = true` a ciegas.
//

import Foundation
import Testing

@testable import Yala

@Suite("ProSubscriptionActivationLogic · compra y restore no celebran Free")
struct ProSubscriptionActivationLogicTests {

    typealias L = ProSubscriptionActivationLogic
    typealias Facts = L.TransactionFacts
    typealias Cached = L.LastVerifiedLocal

    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let later = now.addingTimeInterval(30 * 24 * 3600)
    static let earlier = now.addingTimeInterval(-60)

    static func yearly(
        revoked: Date? = nil,
        expires: Date? = later,
        autoRenewable: Bool = true,
        original: UInt64? = nil
    ) -> Facts {
        Facts(
            productID: "com.yala.pro.yearly",
            productTypeIsAutoRenewable: autoRenewable,
            revocationDate: revoked,
            expirationDate: expires,
            originalID: original
        )
    }

    static func monthly(
        revoked: Date? = nil,
        expires: Date? = later,
        original: UInt64? = nil
    ) -> Facts {
        Facts(
            productID: "com.yala.pro.monthly",
            productTypeIsAutoRenewable: true,
            revocationDate: revoked,
            expirationDate: expires,
            originalID: original
        )
    }

    /// El `originalID` de la suscripción de este Apple ID, y el de otro Apple ID en el mismo teléfono.
    static let suscripcion: UInt64 = 2_000_000_101
    static let otroAppleID: UInt64 = 2_000_000_909

    // MARK: - Compra .success → Pro aunque currentEntitlements esté vacío

    /// EL caso del ticket: Apple devolvió `.success`, la Transaction es Pro vigente,
    /// y `currentEntitlements` todavía no la lista. Antes esto dejaba Free y celebraba.
    @Test func compraVerificada_sinEntitlements_esProLocal() {
        let purchase = Self.yearly()
        let last = L.updatedLastVerified(entitlements: [purchase], previous: nil, now: Self.now)
        #expect(L.localActive(entitlements: [], lastVerified: last, now: Self.now))
        #expect(L.shouldCelebratePurchase(isProUser: true))
    }

    @Test func compraVerificada_conEntitlementsVaciosEnLaMismaPasada_esPro() {
        #expect(L.isActiveLocalEntitlement(Self.yearly(), now: Self.now))
        #expect(L.localActive(entitlements: [Self.yearly()], lastVerified: nil, now: Self.now))
    }

    /// Producto ajeno, revocada, caducada o no auto-renovable: no es Pro, no se celebra.
    @Test func compraQueNoEsDerechoVigente_noEsPro() {
        let ajenos: [Facts] = [
            Facts(productID: "com.otro.pro", productTypeIsAutoRenewable: true,
                  revocationDate: nil, expirationDate: Self.later),
            Self.yearly(revoked: Self.now),
            Self.yearly(expires: Self.now),
            Self.yearly(expires: Self.earlier),
            Self.yearly(autoRenewable: false),
        ]
        for facts in ajenos {
            #expect(L.isActiveLocalEntitlement(facts, now: Self.now) == false,
                    "no debía ser Pro: \(facts.productID) revoked=\(facts.revocationDate != nil)")
            #expect(L.localActive(entitlements: [facts], lastVerified: nil, now: Self.now) == false)
        }
        #expect(L.shouldCelebratePurchase(isProUser: false) == false)
    }

    /// Justo en el instante de expiración ya NO hay derecho (`>`, no `>=`).
    @Test func expiracionEnElInstante_noEsPro() {
        #expect(L.isActiveLocalEntitlement(Self.monthly(expires: Self.now), now: Self.now) == false)
    }

    @Test func sinExpirationDate_sigueVigenteSiLoDemasCasa() {
        #expect(L.isActiveLocalEntitlement(Self.yearly(expires: nil), now: Self.now))
    }

    // MARK: - Celebración gated

    @Test func noCelebrarSiSigueFree() {
        #expect(L.shouldCelebratePurchase(isProUser: false) == false)
    }

    @Test func celebrarSoloSiYaEsPro() {
        #expect(L.shouldCelebratePurchase(isProUser: true))
    }

    // MARK: - Restore empty vs found

    @Test func restoreSinDerecho_pideFeedback() {
        #expect(L.restoreOutcome(isProUser: false) == .noEntitlement)
    }

    @Test func restoreConDerecho_esPro() {
        #expect(L.restoreOutcome(isProUser: true) == .restoredPro)
        #expect(L.localActive(entitlements: [Self.monthly()], lastVerified: nil, now: Self.now))
    }

    // MARK: - lastVerified: reopen + lag de currentEntitlements

    /// Reopen con `currentEntitlements` vacío: si la compra verificada sigue vigente, Pro.
    @Test func entitlementsVacios_conservanLastVerifiedVigente() {
        let previous = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later)
        let next = L.updatedLastVerified(entitlements: [], previous: previous, now: Self.now)
        #expect(next == previous)
        #expect(L.localActive(entitlements: [], lastVerified: next, now: Self.now))
    }

    @Test func lastVerifiedCaducado_noDaPro_ySeBorra() {
        let previous = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.earlier)
        let next = L.updatedLastVerified(entitlements: [], previous: previous, now: Self.now)
        #expect(next == nil)
        #expect(L.localActive(entitlements: [], lastVerified: previous, now: Self.now) == false)
    }

    /// Apple lista la suscripción caducada y lo guardado también venció: es el fin de Pro de verdad.
    @Test func entitlementCaducado_conLastVerifiedVencido_borraYNoDaPro() {
        let previous = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.earlier)
        let next = L.updatedLastVerified(
            entitlements: [Self.yearly(expires: Self.earlier)],
            previous: previous,
            now: Self.now
        )
        #expect(next == nil)
        #expect(L.localActive(entitlements: [Self.yearly(expires: Self.earlier)],
                              lastVerified: previous, now: Self.now) == false)
    }

    // MARK: - Renovar una suscripción terminada (card 7c97, 2026-10-22)

    /// EL caso de la card: tras renovar desde «Tu suscripción terminó», StoreKit sigue listando un rato la suscripción
    /// VIEJA, caducada, y aún no la nueva. La compra verificada (guardada hasta dentro de 30 días) no puede caer por esa
    /// lectura. Hasta ese día este mismo caso estaba fijado al revés (`entitlementCaducado_borraLastVerified`), y por eso
    /// la hoja volvía a salir: la lectura de volver a primer plano dejaba Free y borraba la compra.
    @Test func renovar_laSuscripcionViejaCaducadaListada_noApagaLaCompra() {
        let compra = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later, originalID: Self.suscripcion)
        let vieja = Self.yearly(expires: Self.earlier, original: Self.suscripcion)
        #expect(L.isSupersededExpiredListing(vieja, lastVerified: compra, now: Self.now))
        #expect(L.updatedLastVerified(entitlements: [vieja], previous: compra, now: Self.now) == compra)
        #expect(L.localActive(entitlements: [vieja], lastVerified: compra, now: Self.now))
    }

    /// El recorrido entero: la compra (con la vieja listada al lado) guarda su derecho con su `originalID`, y la lectura
    /// siguiente, que solo ve la vieja, lo conserva. Vale también si se pasa del mensual al anual: mismo grupo, mismo
    /// `originalID`, otro producto.
    @Test func renovar_lecturaDespuesDeLaCompra_siguePro() {
        for vieja in [Self.yearly(expires: Self.earlier, original: Self.suscripcion),
                      Self.monthly(expires: Self.earlier, original: Self.suscripcion)] {
            let compra = Self.yearly(original: Self.suscripcion)
            let guardado = L.updatedLastVerified(entitlements: [compra, vieja], previous: nil, now: Self.now)
            #expect(guardado?.originalID == Self.suscripcion, "El derecho guardado tiene que llevar el originalID.")
            #expect(L.localActive(entitlements: [compra, vieja], lastVerified: guardado, now: Self.now))
            let siguiente = L.updatedLastVerified(entitlements: [vieja], previous: guardado, now: Self.now)
            #expect(siguiente == guardado)
            #expect(L.localActive(entitlements: [vieja], lastVerified: siguiente, now: Self.now))
        }
    }

    /// Control: sin compra guardada, la suscripción caducada sigue siendo el fin de Pro. Sin él, una regla que diera Pro
    /// con cualquier caducada pasaría los dos casos de arriba.
    @Test func renovar_sinCompraGuardada_laCaducadaSigueSiendoFree() {
        let vieja = Self.yearly(expires: Self.earlier, original: Self.suscripcion)
        #expect(L.isSupersededExpiredListing(vieja, lastVerified: nil, now: Self.now) == false)
        #expect(L.updatedLastVerified(entitlements: [vieja], previous: nil, now: Self.now) == nil)
        #expect(L.localActive(entitlements: [vieja], lastVerified: nil, now: Self.now) == false)
    }

    /// Otro Apple ID en el mismo teléfono con su Pro caducado: es un veredicto, no la suscripción vieja. El derecho
    /// guardado del Apple ID anterior no sobrevive a él (lo cazó la review del 2026-10-22).
    @Test func renovar_laCaducadaDeOtroAppleID_sigueSiendoFree() {
        let delAnterior = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later, originalID: Self.suscripcion)
        let otro = Self.yearly(expires: Self.earlier, original: Self.otroAppleID)
        #expect(L.isSupersededExpiredListing(otro, lastVerified: delAnterior, now: Self.now) == false)
        #expect(L.updatedLastVerified(entitlements: [otro], previous: delAnterior, now: Self.now) == nil)
        #expect(L.localActive(entitlements: [otro], lastVerified: delAnterior, now: Self.now) == false)
    }

    /// Sin `originalID` en cualquiera de los dos lados (un derecho que guardó un build anterior, una transacción sin él)
    /// no se puede situar la caducada: manda Apple, como antes.
    @Test func renovar_sinOriginalID_laCaducadaManda() {
        let viejoBuild = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later)
        let conId = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later, originalID: Self.suscripcion)
        let casos: [(Facts, Cached)] = [
            (Self.yearly(expires: Self.earlier, original: Self.suscripcion), viejoBuild),
            (Self.yearly(expires: Self.earlier), conId),
        ]
        for (vieja, guardado) in casos {
            #expect(L.isSupersededExpiredListing(vieja, lastVerified: guardado, now: Self.now) == false)
            #expect(L.localActive(entitlements: [vieja], lastVerified: guardado, now: Self.now) == false)
        }
    }

    /// Un reembolso sí manda aunque el derecho guardado no haya vencido, también si llega como la transacción vieja.
    @Test func renovar_unaRevocada_noCuentaComoSuscripcionVieja() {
        let compra = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later, originalID: Self.suscripcion)
        for revocada in [Self.yearly(revoked: Self.now, original: Self.suscripcion),
                         Self.yearly(revoked: Self.earlier, expires: Self.earlier, original: Self.suscripcion)] {
            #expect(L.isSupersededExpiredListing(revocada, lastVerified: compra, now: Self.now) == false)
            #expect(L.updatedLastVerified(entitlements: [revocada], previous: compra, now: Self.now) == nil)
            #expect(L.localActive(entitlements: [revocada], lastVerified: compra, now: Self.now) == false)
        }
    }

    /// Un derecho guardado sin fecha no se puede situar frente a la caducada: manda Apple, como antes.
    @Test func renovar_derechoGuardadoSinFecha_laCaducadaManda() {
        let sinFecha = Cached(productID: "com.yala.pro.yearly", expirationDate: nil, originalID: Self.suscripcion)
        let vieja = Self.yearly(expires: Self.earlier, original: Self.suscripcion)
        #expect(L.isSupersededExpiredListing(vieja, lastVerified: sinFecha, now: Self.now) == false)
        #expect(L.localActive(entitlements: [vieja], lastVerified: sinFecha, now: Self.now) == false)
    }

    /// Solo una CADUCADA es la suscripción vieja: una nuestra que no es renovable (no vigente sin haber vencido) sigue
    /// siendo veredicto aunque comparta `originalID`.
    @Test func renovar_unaNoRenovableSinCaducar_noEsLaSuscripcionVieja() {
        let compra = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later, originalID: Self.suscripcion)
        let noRenovable = Self.yearly(autoRenewable: false, original: Self.suscripcion)
        #expect(L.isSupersededExpiredListing(noRenovable, lastVerified: compra, now: Self.now) == false)
        #expect(L.localActive(entitlements: [noRenovable], lastVerified: compra, now: Self.now) == false)
    }

    /// Un producto ajeno caducado no es nuestra suscripción vieja (y ya no era veredicto: no es de Yala).
    @Test func renovar_productoAjenoCaducado_noEsLaSuscripcionVieja() {
        let compra = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later, originalID: Self.suscripcion)
        let ajeno = Facts(productID: "com.otro.pro", productTypeIsAutoRenewable: true,
                          revocationDate: nil, expirationDate: Self.earlier, originalID: Self.suscripcion)
        #expect(L.isSupersededExpiredListing(ajeno, lastVerified: compra, now: Self.now) == false)
        #expect(L.localActive(entitlements: [ajeno], lastVerified: compra, now: Self.now))
    }

    /// Una revocación conocida gana: no conservamos un Pro que Apple quitó.
    @Test func entitlementRevocado_borraLastVerified() {
        let previous = Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later)
        let next = L.updatedLastVerified(
            entitlements: [Self.yearly(revoked: Self.now)],
            previous: previous,
            now: Self.now
        )
        #expect(next == nil)
        #expect(L.localActive(entitlements: [Self.yearly(revoked: Self.now)],
                              lastVerified: previous, now: Self.now) == false)
    }

    @Test func entitlementActivo_reemplazaLastVerified() {
        let previous = Cached(productID: "com.yala.pro.monthly", expirationDate: Self.later)
        let next = L.updatedLastVerified(entitlements: [Self.yearly()], previous: previous, now: Self.now)
        #expect(next == Cached(productID: "com.yala.pro.yearly", expirationDate: Self.later))
    }
}

// MARK: - Cableado (source-scan)

@Suite("ProSubscriptionActivationLogic · cableado de producción (source-scan)")
struct ProSubscriptionActivationWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "marcador no encontrado: \(marker)")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Sin esto, la tabla queda verde y `purchase` vuelve a celebrar a ciegas.
    @Test func purchaseAplicaLaTransaccionVerificadaYNoCelebraACiegas() throws {
        let src = try Self.source("Yala/App/Services/StoreKitManager.swift")
        let purchase = try Self.body(of: "func purchase(_ product: Product) async -> Bool {", in: src)
        #expect(purchase.contains("updateSubscriptionStatus(verifiedPurchase: transaction)"), """
            La compra tiene que aplicar la Transaction verificada. Si solo llama \
            `updateSubscriptionStatus()` a secas, currentEntitlements vacío vuelve a dejar Free.
            """)
        #expect(purchase.contains("shouldCelebratePurchase(isProUser: isProUser)"), """
            didJustSubscribe no puede ser `true` incondicional: solo si el usuario ya es Pro.
            """)
        #expect(!purchase.contains("didJustSubscribe = true"), """
            Un `didJustSubscribe = true` suelto reintroduce el sheet de éxito con la app en Free.
            """)
    }

    /// La regla de la suscripción vieja (card 7c97) solo actúa si el manager lleva el `originalID` de cada transacción
    /// y lo guarda y lo lee con el derecho. Sin cualquiera de las tres, la tabla sigue verde y la regla no hace nada en
    /// producción: lo guardado llega sin `originalID` y la caducada vuelve a dejar Free tras renovar.
    @Test func elDerechoGuardadoViajaConSuOriginalID() throws {
        let src = try Self.source("Yala/App/Services/StoreKitManager.swift")
        let facts = try Self.body(of: "private func facts(from transaction: StoreKit.Transaction) -> ProSubscriptionActivationLogic.TransactionFacts {", in: src)
        #expect(facts.contains("originalID: transaction.originalID"), "Los hechos de la transacción no llevan su originalID.")
        let load = try Self.body(of: "private func loadLastVerified() -> ProSubscriptionActivationLogic.LastVerifiedLocal? {", in: src)
        #expect(load.contains("forKey: lastVerifiedOriginalIDKey"), "El derecho guardado se lee sin su originalID.")
        let persist = try Self.body(of: "private func persistLastVerified(_ last: ProSubscriptionActivationLogic.LastVerifiedLocal?) {", in: src)
        #expect(persist.contains("String(originalID), forKey: lastVerifiedOriginalIDKey"),
                "El derecho guardado se escribe sin su originalID.")
        #expect(persist.components(separatedBy: "removeObject(forKey: lastVerifiedOriginalIDKey)").count == 3,
                "Al borrar el derecho (o guardarlo sin id) tiene que irse también su originalID.")
    }

    @Test func restoreHablaSiNoHayDerecho() throws {
        let src = try Self.source("Yala/App/Services/StoreKitManager.swift")
        let restore = try Self.body(of: "func restorePurchases() async {", in: src)
        #expect(restore.contains("restoreOutcome(isProUser: isProUser)"), """
            El restore tiene que pasar por el seam: si no, un Free se queda sin feedback.
            """)
        #expect(restore.contains("L10n.Subscription.restoreEmpty"), """
            Sin copy de «no hay suscripción» el restore vuelve a tragarse el resultado vacío.
            """)
    }

    @Test func successSheetEstaGateadaPorIsProUser() throws {
        let subscription = try Self.source("Yala/App/Views/Settings/SubscriptionView.swift")
        let trial = try Self.source("Yala/App/Views/Subscription/ProTrialOfferSheet.swift")
        for (name, src) in [("SubscriptionView", subscription), ("ProTrialOfferSheet", trial)] {
            #expect(
                src.contains("didSubscribe && store.isProUser")
                    || src.contains("store.isProUser && didSubscribe"),
                """
                \(name) tiene que exigir isProUser además de didJustSubscribe. Si no, un flag \
                suelto vuelve a montar SubscriptionSuccessView con la app en Free.
                """
            )
        }
    }
}
