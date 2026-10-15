//
//  GoogleSignInWithAppleAccountTests.swift
//  YalaTests
//
//  vb1f · entrar con Google cuando este iPhone ya tiene cuenta con Apple (decisión de Jürgen del 2026-10-14, A + C).
//
//  · A — en «¡Hola de nuevo!» el faro de iCloud-KV ordena las entradas: el método con que se creó la cuenta va primero y
//    lleva «La que usaste en este iPhone». Lógica pura + el adaptador que lee el faro.
//  · C — «Registrarse con Google», tras «Esa cuenta usa otro método», reusa la credencial de Google que ya se obtuvo. El
//    canje con Supabase no se puede ejercitar sin red ni hoja de Google: aquí va la decisión pura y el cableado por
//    source-scan, con el cuerpo de las líneas que lo sostienen.
//

import Foundation
import Testing

@testable import Yala

// MARK: - A · el orden por faro

@Suite("vb1f · A: el faro ordena «¡Hola de nuevo!» y marca el método usado")
struct WelcomeExistingOrderTests {

    private typealias Logic = WelcomeAccountChoiceLogic
    /// Lo que devuelve `visibleExistingOptions` con la nube abierta.
    private let all: [Logic.ExistingOption] = [.restoreICloud, .cloudSignIn, .googleSignIn]

    @Test("faro de Apple ⇒ Apple primero (ya lo estaba) y con la nota")
    func appleBeacon_keepsApplefirst_andMarksIt() {
        let order = Logic.orderExistingOptions(all, beaconLinked: true, beaconProvider: "apple")
        #expect(order.options == [.restoreICloud, .cloudSignIn, .googleSignIn])
        #expect(order.usedOnThisDevice == .cloudSignIn)
    }

    @Test("faro de Google ⇒ Google sube por delante de Apple y lleva la nota; Restaurar no se mueve")
    func googleBeacon_putsGoogleFirst_andMarksIt() {
        let order = Logic.orderExistingOptions(all, beaconLinked: true, beaconProvider: "google")
        #expect(order.options == [.restoreICloud, .googleSignIn, .cloudSignIn])
        #expect(order.usedOnThisDevice == .googleSignIn)
    }

    /// El faro solo afirma lo que dice: sin cuenta enlazada, sin método o con uno que esta versión no conoce, la
    /// pantalla de siempre. Un `?? .apple` aquí marcaría Apple a quien creó su cuenta con un método futuro.
    @Test("sin faro, sin método o con un método desconocido ⇒ orden de siempre y sin nota",
          arguments: [(false, Optional("apple")), (false, nil), (true, nil), (true, Optional("microsoft"))])
    func noUsableBeacon_leavesTheScreenAsItWas(linked: Bool, provider: String?) {
        let order = Logic.orderExistingOptions(all, beaconLinked: linked, beaconProvider: provider)
        #expect(order.options == all)
        #expect(order.usedOnThisDevice == nil)
    }

    /// Con el kill remoto las dos entradas se ocultan y solo queda Restaurar (que además hace bypass): una nota sobre un
    /// botón que no está sería una nota huérfana.
    @Test("la entrada del faro no está a la vista ⇒ sin nota y sin tocar nada")
    func beaconOptionHidden_noNote() {
        let order = Logic.orderExistingOptions([.restoreICloud], beaconLinked: true, beaconProvider: "google")
        #expect(order.options == [.restoreICloud])
        #expect(order.usedOnThisDevice == nil)
    }

    @Test("reordenar nunca añade ni quita opciones", arguments: ["apple", "google"])
    func reorderKeepsTheSameSet(provider: String) {
        let order = Logic.orderExistingOptions(all, beaconLinked: true, beaconProvider: provider)
        #expect(order.options.count == all.count)
        #expect(Set(order.options.map { "\($0)" }) == Set(all.map { "\($0)" }))
    }
}

/// El adaptador lee el MISMO faro que encamina «Soy nuevo», con su store inyectado (sin él leería el iCloud-KV real del
/// simulador).
@Suite("vb1f · A: el adaptador lee el faro")
@MainActor
struct WelcomeExistingOrderReaderTests {

    private func beacon(linked: Bool, provider: String?) -> CloudBeacon {
        let store = ExistingOrderBeaconStore()
        if linked {
            store.setBool(true, forKey: CloudBeacon.Keys.linked)
            if let provider { store.setString(provider, forKey: CloudBeacon.Keys.provider) }
        }
        return CloudBeacon(store: store)
    }

    @Test("faro de Google en el store ⇒ Google primero y marcado")
    func readsTheBeacon() {
        let order = WelcomeNewBranchRouter.existingOrder(
            beacon: beacon(linked: true, provider: "google"),
            options: [.restoreICloud, .cloudSignIn, .googleSignIn])
        #expect(order.options == [.restoreICloud, .googleSignIn, .cloudSignIn])
        #expect(order.usedOnThisDevice == .googleSignIn)
    }

    @Test("store sin faro ⇒ la pantalla de siempre")
    func emptyStore() {
        let order = WelcomeNewBranchRouter.existingOrder(
            beacon: beacon(linked: false, provider: nil),
            options: [.restoreICloud, .cloudSignIn, .googleSignIn])
        #expect(order.options == [.restoreICloud, .cloudSignIn, .googleSignIn])
        #expect(order.usedOnThisDevice == nil)
    }
}

private final class ExistingOrderBeaconStore: BeaconKeyValueStore, @unchecked Sendable {
    var bools: [String: Bool] = [:]
    var strings: [String: String] = [:]
    var doubles: [String: Double] = [:]
    func setBool(_ value: Bool, forKey key: String) { bools[key] = value }
    func setString(_ value: String, forKey key: String) { strings[key] = value }
    func setDouble(_ value: Double, forKey key: String) { doubles[key] = value }
    func bool(forKey key: String) -> Bool { bools[key] ?? false }
    func string(forKey key: String) -> String? { strings[key] }
    func double(forKey key: String) -> Double { doubles[key] ?? 0 }
    func removeObject(forKey key: String) { bools[key] = nil; strings[key] = nil; doubles[key] = nil }
    @discardableResult func synchronize() -> Bool { true }
}

// MARK: - C · la credencial de Google reusada

@Suite("vb1f · C: qué credencial de Google se puede reusar")
struct GoogleCredentialReuseLogicTests {

    private typealias Logic = GoogleCredentialReuseLogic
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func credential(at date: Date) -> GoogleSignInCredential {
        GoogleSignInCredential(idToken: "id", accessToken: "at", rawNonce: "n", googleUserID: "g",
                               email: nil, fullName: nil, obtainedAt: date)
    }

    @Test("misma sesión y fresca ⇒ se reusa")
    func sameSession_fresh_isReusable() {
        let c = credential(at: t0)
        #expect(Logic.reusable(c, boundToSub: "sub-a", liveSub: "sub-a", now: t0.addingTimeInterval(60)) == c)
    }

    /// La credencial se recoge justo antes de soltar la sesión que nació de ella. Si la sesión viva es otra —u otra
    /// cuenta entró entre medias, o ya no hay sesión— no es de quien está delante.
    @Test("otra sesión o ninguna ⇒ no se reusa", arguments: [Optional("sub-b"), nil])
    func otherOrNoSession_isNotReusable(liveSub: String?) {
        #expect(Logic.reusable(credential(at: t0), boundToSub: "sub-a", liveSub: liveSub, now: t0) == nil)
    }

    /// Los dos vecinos del plazo: 599 s vale, 600 s ya no. Y un reloj que vuelve atrás tampoco: no se sabe cuánto pasó.
    @Test("el plazo se clava en sus vecinos y un reloj hacia atrás la descarta")
    func lifetimeNeighbours() {
        let c = credential(at: t0)
        #expect(Logic.lifetime == 600)
        #expect(Logic.isFresh(c, now: t0))
        #expect(Logic.isFresh(c, now: t0.addingTimeInterval(599)))
        #expect(!Logic.isFresh(c, now: t0.addingTimeInterval(600)))
        #expect(!Logic.isFresh(c, now: t0.addingTimeInterval(-1)))
        #expect(Logic.reusable(c, boundToSub: "s", liveSub: "s", now: t0.addingTimeInterval(600)) == nil)
    }

    @Test("el siguiente inicio de sesión la usa solo si es de Google y sigue fresca")
    func nextSignIn_onlyGoogle_onlyFresh() {
        let c = credential(at: t0)
        #expect(Logic.credentialForNextSignIn(c, provider: .google, now: t0.addingTimeInterval(30)) == c)
        #expect(Logic.credentialForNextSignIn(c, provider: .apple, now: t0.addingTimeInterval(30)) == nil,
                "una credencial de Google no abre una sesión de Apple")
        #expect(Logic.credentialForNextSignIn(c, provider: .google, now: t0.addingTimeInterval(600)) == nil,
                "caducada entre recogerla y usarla ⇒ la hoja")
        #expect(Logic.credentialForNextSignIn(nil, provider: .google, now: t0) == nil)
    }
}

/// **El cableado de C.** El canje real necesita la hoja de Google y Supabase, así que lo que se fija es la forma de las
/// líneas que lo sostienen: dónde se recoge la credencial, quién la gasta y que el camino interactivo siga detrás.
@Suite("vb1f · C: cableado de la credencial reusada (source-scan)")
struct GoogleCredentialReuseWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }
    private static let welcomePath = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
    private static let authPath = "Yala/Services/CloudSync/CloudAuthService.swift"

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static func body(of marker: String, in path: String) throws -> String {
        let text = try source(path)
        let start = try #require(text.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(text[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    /// Líneas de código, sin comentarios ni vacías.
    private static func lines(_ text: String) -> [String] {
        text.split(separator: "\n")
            .map { line -> String in
                var code = String(line)
                if let comment = code.range(of: "//") { code = String(code[..<comment.lowerBound]) }
                return code.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    /// La credencial se recoge en la rama de cuenta nueva —la de las dos salidas al alta—, DESPUÉS del veredicto y ANTES
    /// de soltar la sesión: `signOut()` la olvida, y recogida después siempre daría `nil`.
    @Test("se recoge antes de soltar la sesión, en la rama que lleva al alta, y en ningún otro sitio")
    func credentialIsTakenBeforeTheSignOut() throws {
        let flow = Self.lines(try Self.body(of: "private func runSignInFlow(origin: WelcomeAdoptOrigin) async {",
                                            in: Self.welcomePath))
        let take = "pendingGoogleCredential = CloudAuthService.shared.takeGoogleCredentialForReuse()"
        let decide = try #require(flow.firstIndex(of: "let verdict = ProviderMismatchLogic.decide("))
        let taken = try #require(flow.firstIndex(of: take))
        let signOut = try #require(flow[taken...].firstIndex(of: "await CloudAuthService.shared.signOut()"))
        #expect(decide < taken)
        #expect(signOut == taken + 1, "entre recogerla y soltar la sesión no va nada")
        let file = Self.lines(try Self.source(Self.welcomePath))
        #expect(file.filter { $0.contains("takeGoogleCredentialForReuse(") }.count == 1)
        // Solo dos escritores: el que la recoge y el que la gasta.
        #expect(file.filter { $0.hasPrefix("pendingGoogleCredential =") }.count == 2)
    }

    /// La gasta el SIGUIENTE inicio de sesión de la pantalla, y la olvida se use o no.
    @Test("`ensureSignedIn` la pasa al inicio de sesión y la olvida antes de intentarlo")
    func ensureSignedIn_spendsItOnce() throws {
        let ensure = Self.lines(try Self.body(of: "private func ensureSignedIn() async -> Bool {", in: Self.welcomePath))
        let guardSession = try #require(ensure.firstIndex(of: "guard !CloudAuthService.shared.hasSession else { return true }"))
        #expect(Array(ensure[(guardSession + 1)...(guardSession + 7)]) == [
            "let reusable = GoogleCredentialReuseLogic.credentialForNextSignIn(",
            "pendingGoogleCredential, provider: provider, now: Date())",
            "pendingGoogleCredential = nil",
            "do {",
            "try await CloudAuthService.shared.signIn(with: provider, reusingGoogleCredential: reusable)",
            "sessionOpenedHere = true",
            "return true",
        ])
    }

    /// Con Google, primero la credencial y, si no entra, la hoja de siempre: lo peor es lo de antes.
    @Test("el despacho intenta la credencial y cae a la hoja")
    func dispatch_triesTheCredentialThenTheSheet() throws {
        let dispatch = Self.lines(try Self.body(
            of: "reusingGoogleCredential reusable: GoogleSignInCredential? = nil) async throws {", in: Self.authPath))
        #expect(Array(dispatch.prefix(6)) == [
            "switch provider {",
            "case .apple: try await signInWithApple()",
            "case .google:",
            "if let reusable, await signInWithReusedGoogleCredential(reusable) { break }",
            "try await signInWithGoogle()",
            "}",
        ])
    }

    /// Un solo canje para los dos caminos: la época, la marca del adopt, el registro de sesiones y el par de Google no
    /// pueden divergir entre el interactivo y el reusado.
    @Test("los dos caminos canjean por `completeGoogleSignIn`, que es el único sitio del canje de Google")
    func bothPathsShareTheExchange() throws {
        let interactive = Self.lines(try Self.body(of: "func signInWithGoogle() async throws {", in: Self.authPath))
        #expect(interactive.contains("try await completeGoogleSignIn(GoogleSignInCredential("))
        #expect(!interactive.contains { $0.contains("signInWithIdToken(") })
        let reused = Self.lines(try Self.body(
            of: "private func signInWithReusedGoogleCredential(_ credential: GoogleSignInCredential) async -> Bool {",
            in: Self.authPath))
        #expect(reused.contains("try await completeGoogleSignIn(credential)"))
        let exchange = Self.lines(try Self.body(
            of: "private func completeGoogleSignIn(_ credential: GoogleSignInCredential) async throws {", in: Self.authPath))
        #expect(exchange.contains { $0.contains("signInWithIdToken(") })
        #expect(exchange.last == "lastGoogleCredential = currentUserID.map { (credential, $0) }",
                "se guarda al final, con la sesión ya abierta y atada a su `sub`")
    }

    /// La credencial no sobrevive a lo que la invalida: otro inicio de sesión (Apple o la hoja de Google), el cierre de
    /// sesión —también sin backend, antes de su `guard`— y la propia recogida.
    @Test("se olvida al empezar otro inicio de sesión, al cerrar sesión y al recogerla")
    func credentialIsForgottenWhereItMustBe() throws {
        let file = Self.lines(try Self.source(Self.authPath))
        #expect(file.filter { $0 == "lastGoogleCredential = nil" }.count == 3)
        #expect(file.filter { $0 == "defer { lastGoogleCredential = nil }" }.count == 1)
        let apple = Self.lines(try Self.body(of: "func signInWithApple() async throws {", in: Self.authPath))
        #expect(apple.contains("lastGoogleCredential = nil"))
        let google = Self.lines(try Self.body(of: "func signInWithGoogle() async throws {", in: Self.authPath))
        #expect(google.contains("lastGoogleCredential = nil"))
        let signOut = Self.lines(try Self.body(
            of: "func signOut(returningToPreviousAccount: Bool = false) async -> Bool {", in: Self.authPath))
        let clear = try #require(signOut.firstIndex(of: "lastGoogleCredential = nil"))
        let guardClient = try #require(signOut.firstIndex(of: "guard let client else { return storedSessionIsGone }"))
        #expect(clear < guardClient)
        let take = Self.lines(try Self.body(
            of: "func takeGoogleCredentialForReuse(now: Date = Date()) -> GoogleSignInCredential? {", in: Self.authPath))
        #expect(take.first == "defer { lastGoogleCredential = nil }")
        #expect(take.contains("stored.credential, boundToSub: stored.sub, liveSub: currentUserID, now: now)"))
    }
}
