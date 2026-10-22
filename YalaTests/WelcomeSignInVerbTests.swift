//
//  WelcomeSignInVerbTests.swift
//  YalaTests
//
//  W4 (decisiones del owner 2026-08-11, puntos 15 y 16 de MODO-NUBE-REVISION-FLUJOS-NOTAS): en el Welcome,
//  el ALTA y la RE-ENTRADA comparten pantalla y hasta hoy compartían también el verbo del botón («Continuar
//  con Google» / «Iniciar sesión con Apple») y la nota de debajo. Ahora el alta dice CREAR y la re-entrada
//  INICIAR SESIÓN, y cada una lleva su nota; Ajustes/migración y Grupos conservan el verbo neutro.
//
//  **Lo que se prueba aquí es QUIÉN pasa qué, y eso no lo ve ningún test de comportamiento**: los dos
//  botones son `UIViewRepresentable`/`View` sin salida asertable, y el flujo que disparan es idéntico en
//  las cuatro superficies — un call-site con el verbo equivocado compila, corre y pasa la suite entera. Es
//  la misma familia que `AttestWiringTests`, y por eso el pin es un source-scan CON CONTEO: sin él, un
//  escáner roto o una clase renombrada pasarían en verde sin comprobar nada.
//
//  La otra mitad son las traducciones, y el riesgo real ahí no es que falte una key —eso lo caza la
//  paridad— sino que alguien rellene las tres con el MISMO texto: el cableado quedaría perfecto y el verbo
//  no cambiaría en pantalla. De ahí las aserciones de DISTINCIÓN por locale.
//

import Foundation
import Testing

@testable import Yala

@Suite("W4 · cada contexto dice su verbo y su nota")
struct WelcomeSignInVerbTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Solo el CÓDIGO: los docblocks nombran a propósito los verbos de las otras superficies, así que un
    /// `contains` sobre el fichero crudo se cumpliría leyendo prosa.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Cuerpo de un miembro del tipo: desde su declaración hasta el siguiente `private` al mismo nivel.
    /// Acotar importa — sobre el fichero entero, «el alta usa `.signUp`» se cumpliría con el `.signUp` de
    /// la re-entrada de al lado (lección de `TestProcessGuardTests`: un rango ancho comprueba que el
    /// símbolo EXISTE, no que este sitio lo use).
    private static func member(_ declaration: String, in source: String) throws -> String {
        let start = try #require(source.range(of: declaration))
        let rest = source[start.upperBound...]
        let end = rest.range(of: "\n    private ")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    private static let welcomePath = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
    private static let storagePath = "Yala/App/Views/Settings/StorageSignInChooserView.swift"
    private static let groupsPath = "Yala/App/Views/Groups/GroupsSignInView.swift"

    // MARK: - Punto 15 · el verbo por contexto

    @Test("el alta pide CREAR cuenta en los dos botones")
    func bornCloudIntro_usesTheSignUpVerb() throws {
        let intro = try Self.member("private var bornCloudIntro: some View {",
                                    in: try Self.code(Self.welcomePath))
        #expect(intro.contains("AppleSignInButton(type: .signUp)"))
        #expect(intro.contains("GoogleSignInButton(variant: .light, purpose: .signUp)"))
    }

    @Test("la re-entrada pide INICIAR SESIÓN en los dos botones")
    func reentryIntro_usesTheSignInVerb() throws {
        let intro = try Self.member("private var reentryIntro: some View {",
                                    in: try Self.code(Self.welcomePath))
        #expect(intro.contains("AppleSignInButton(type: .signIn)"))
        #expect(intro.contains("GoogleSignInButton(variant: .light, purpose: .signIn)"))
    }

    /// Ajustes/migración se quedó fuera del cambio de verbo por decisión del owner. Pasa a DECLARAR
    /// `.continue` porque el `purpose` no tiene default —esa es su gracia—, pero el texto que ve el usuario
    /// es el mismo de siempre: ahí entra tanto quien ya tiene cuenta como quien la estrena al migrar.
    @Test("Ajustes/migración conserva el verbo neutro")
    func settings_keepsTheNeutralVerb() throws {
        let src = try Self.code(Self.storagePath)
        #expect(src.contains("purpose: .continue"), "\(Self.storagePath) dejó de declarar el verbo neutro")
        #expect(!src.contains("purpose: .signUp"))
        #expect(!src.contains("purpose: .signIn"))
    }

    /// **G3 (2026-08-11) sacó a Grupos del neutro.** W4 lo dejó en `.continue` cuando su única entrada era
    /// el invitado por link; con la rama ORGANIZADOR del Welcome, quien llega aquí está CREANDO su cuenta
    /// para estrenar Grupos. Y las dos entradas coinciden en eso: nadie alcanza este sheet con una sesión
    /// viva —el `onAppear` la cierra si la hay, y el productor lo garantiza—, así que el verbo del alta es
    /// el correcto para ambas.
    @Test("Grupos pide CREAR cuenta: sus dos entradas son altas")
    func groups_usesTheSignUpVerb() throws {
        let src = try Self.code(Self.groupsPath)
        #expect(src.contains("purpose: .signUp"), "\(Self.groupsPath) dejó de declarar el verbo del alta")
        #expect(!src.contains("purpose: .continue"))
        #expect(!src.contains("purpose: .signIn"))
    }

    /// El conteo es lo que convierte esto en una red: una superficie NUEVA que se cuele sin decidir su
    /// verbo cae aquí, y el compilador no la caza porque `purpose` es obligatorio pero cualquiera de los
    /// tres valores compila. **Eran cuatro hasta el paso 6**, que añadió las DOS de la pantalla de
    /// mismatch —una por salida, cada una con su verbo: lo fija el test de abajo—.
    @Test("las seis construcciones de producción declaran su verbo, y son seis")
    func productionCallSites_declareTheirVerb_andAreSix() throws {
        var total = 0
        for path in [Self.welcomePath, Self.storagePath, Self.groupsPath] {
            let src = try Self.code(path)
            let constructions = src.components(separatedBy: "GoogleSignInButton(").count - 1
            let declared = src.components(separatedBy: "purpose: .").count - 1
            #expect(constructions == declared,
                    "\(path): \(constructions) botones de Google y \(declared) verbos declarados")
            total += constructions
        }
        #expect(total == 6, "se esperaban 6 construcciones de producción, hay \(total)")
    }

    /// **Paso 6 · el mismatch dice DOS verbos, uno por salida, y emparejados.** Con un `contains` suelto un
    /// SWAP pasaría en verde (los cuatro literales seguirían ahí); por eso se corta la pantalla por sus dos
    /// `switch` y, dentro de cada uno, por sus dos `case`: cada botón tiene que ser el de SU marca y con el verbo
    /// de SU salida. Que la acción tome el método de `exits` lo fija el test siguiente, aparte para que un
    /// mutante no tape al otro (lente C de la review).
    @Test("mismatch: entrar con el método del faro dice INICIAR SESIÓN y crear con el usado dice CREAR")
    func providerMismatch_pairsEachExitWithItsVerb() throws {
        let screen = try Self.member(
            "private func providerMismatchContent(_ exits: ProviderMismatchLogic.Exits) -> some View {",
            in: try Self.code(Self.welcomePath))
        let halves = screen.components(separatedBy: "switch exits.createWith {")
        try #require(halves.count == 2, "la pantalla dejó de tener sus dos `switch` (hay \(halves.count - 1))")
        let signIn = try #require(halves.first?.components(separatedBy: "switch exits.signInWith {").last)
        let create = halves[1]

        for (mitad, verbo) in [(signIn, ".signIn"), (create, ".signUp")] {
            let casos = mitad.components(separatedBy: "case .google:")
            try #require(casos.count == 2, "cada `switch` tiene un `case .apple:` y un `case .google:`")
            let apple = casos[0], google = casos[1]
            #expect(apple.contains("case .apple:"))
            #expect(apple.contains("AppleSignInButton(type: \(verbo))"), "la marca de Apple con el verbo \(verbo)")
            #expect(!apple.contains("GoogleSignInButton("))
            #expect(google.contains("GoogleSignInButton(variant: .light, purpose: \(verbo))"))
            #expect(!google.contains("AppleSignInButton("))
        }
        #expect(!signIn.contains(".signUp"), "la salida de ENTRAR dice crear")
        #expect(!signIn.contains("switchToSignUp("), "la salida de ENTRAR lleva al alta")
        #expect(!create.contains(".signIn"), "la salida de CREAR dice iniciar sesión")
        #expect(!create.contains("signInWithAccountMethod("), "la salida de CREAR entra a una cuenta")
    }

    /// La otra mitad del emparejamiento, en su propio test para que un mutante no tape al de arriba: la acción de
    /// CADA botón toma el método de `exits`. Con un literal por `case`, un botón podría pintar Apple y firmar con
    /// Google, que devuelve al mismo mismatch del que se quería salir.
    @Test("mismatch: la acción de cada botón toma el método de `exits`, no un literal")
    func providerMismatch_eachButtonActsWithItsExitMethod() throws {
        let screen = try Self.member(
            "private func providerMismatchContent(_ exits: ProviderMismatchLogic.Exits) -> some View {",
            in: try Self.code(Self.welcomePath))
        let halves = screen.components(separatedBy: "switch exits.createWith {")
        try #require(halves.count == 2)
        let signIn = try #require(halves.first?.components(separatedBy: "switch exits.signInWith {").last)
        for (mitad, accion) in [(signIn, "signInWithAccountMethod(exits.signInWith, from: exits)"),
                                (halves[1], "switchToSignUp(with: exits.createWith)")] {
            let casos = mitad.components(separatedBy: "case .google:")
            try #require(casos.count == 2)
            #expect(casos[0].contains(accion), "el botón de Apple no actúa con «\(accion)»")
            #expect(casos[1].contains(accion), "el botón de Google no actúa con «\(accion)»")
        }
    }

    // MARK: - Punto 16 · la nota por contexto

    @Test("cada intro lleva SU nota, y la del alta no es la de la re-entrada")
    func eachIntro_carriesItsOwnProviderNote() throws {
        let src = try Self.code(Self.welcomePath)
        let born = try Self.member("private var bornCloudIntro: some View {", in: src)
        let reentry = try Self.member("private var reentryIntro: some View {", in: src)
        #expect(born.contains("L10n.Welcome.BornCloud.providerNote"))
        #expect(!born.contains("L10n.Welcome.Cloud.providerNote"),
                "el alta volvió a la nota de la re-entrada: «entra con el mismo método que usaste» no dice nada a quien no ha usado ninguno")
        #expect(reentry.contains("L10n.Welcome.Cloud.providerNote"))
    }

    // MARK: - Las traducciones

    @Test("los tres verbos del botón de Google son distintos entre sí en los 16 locales")
    func googleVerbs_differPerLocale() {
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            let neutral = strings["auth.googleButton"] ?? ""
            let signUp = strings["auth.googleButtonSignUp"] ?? ""
            let signIn = strings["auth.googleButtonSignIn"] ?? ""
            #expect(!signUp.isEmpty && !signIn.isEmpty, "falta un verbo en \(locale.code)")
            #expect(signUp != signIn, "alta y re-entrada dicen lo mismo en \(locale.code)")
            #expect(signUp != neutral, "el alta dice el verbo neutro en \(locale.code)")
            #expect(signIn != neutral, "la re-entrada dice el verbo neutro en \(locale.code)")
        }
        #expect(scanned == 16, "se esperaban 16 locales con strings, se leyeron \(scanned)")
    }

    @Test("las dos notas de método son distintas en los 16 locales")
    func providerNotes_differPerLocale() {
        var scanned = 0
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            guard !strings.isEmpty else { continue }
            scanned += 1
            let reentry = strings["welcome.cloud.providerNote"] ?? ""
            let born = strings["welcome.bornCloud.providerNote"] ?? ""
            #expect(!born.isEmpty, "falta la nota del alta en \(locale.code)")
            #expect(born != reentry,
                    "las dos notas volvieron a ser la misma en \(locale.code): el punto 16 se deshizo en la traducción")
        }
        #expect(scanned == 16, "se esperaban 16 locales con strings, se leyeron \(scanned)")
    }
}
