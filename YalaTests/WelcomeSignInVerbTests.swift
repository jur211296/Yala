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

    /// El owner las dejó explícitamente fuera del cambio de verbo. Pasan a DECLARAR `.continue` porque el
    /// `purpose` no tiene default —esa es su gracia—, pero el texto que ven es el mismo de siempre.
    @Test("Ajustes/migración y Grupos conservan el verbo neutro")
    func settingsAndGroups_keepTheNeutralVerb() throws {
        for path in [Self.storagePath, Self.groupsPath] {
            let src = try Self.code(path)
            #expect(src.contains("purpose: .continue"), "\(path) dejó de declarar el verbo neutro")
            #expect(!src.contains("purpose: .signUp"))
            #expect(!src.contains("purpose: .signIn"))
        }
    }

    /// El conteo es lo que convierte esto en una red: una superficie NUEVA que se cuele sin decidir su
    /// verbo cae aquí, y el compilador no la caza porque `purpose` es obligatorio pero cualquiera de los
    /// tres valores compila.
    @Test("las cuatro construcciones de producción declaran su verbo, y son cuatro")
    func productionCallSites_declareTheirVerb_andAreFour() throws {
        var total = 0
        for path in [Self.welcomePath, Self.storagePath, Self.groupsPath] {
            let src = try Self.code(path)
            let constructions = src.components(separatedBy: "GoogleSignInButton(").count - 1
            let declared = src.components(separatedBy: "purpose: .").count - 1
            #expect(constructions == declared,
                    "\(path): \(constructions) botones de Google y \(declared) verbos declarados")
            total += constructions
        }
        #expect(total == 4, "se esperaban 4 construcciones de producción, hay \(total)")
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
