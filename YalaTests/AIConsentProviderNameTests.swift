//
//  AIConsentProviderNameTests.swift
//  YalaTests
//
//  Decisión de Jürgen del 2026-10-17: los avisos y las pistas de consentimiento de IA no nombran al proveedor. Dicen
//  «un servicio de IA», y el nombre queda en la Política de privacidad, que cada aviso enlaza. Así un cambio de
//  proveedor no obliga a reescribir 16 idiomas, y el aviso habla de lo que la persona gana, no de una marca.
//
//  Este test lee las `Localizable.strings` FUENTE de la app (vía `#filePath`) y falla si «OpenAI» vuelve a cualquier
//  valor `aiConsent.*` en cualquiera de los 16 idiomas. Comprueba además que los tres avisos siguen ofreciendo el botón
//  de la política, que es donde vive ahora el nombre.
//

import Foundation
import Testing

struct AIConsentProviderNameTests {

    /// Nombres de proveedor que no pueden aparecer en un aviso de consentimiento. En minúsculas: se compara así.
    static let providerNames = ["openai", "chatgpt", "gpt-"]

    /// Devuelve `(clave, nombre)` por cada valor `aiConsent.*` que nombra a un proveedor, y cuántas claves `aiConsent.*`
    /// leyó (para que un fichero sin claves no pase en vacío).
    static func violations(in content: String) -> (found: [(String, String)], keys: Int) {
        let linePattern = #/^\s*"(aiConsent\.(?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;/#
        var found: [(String, String)] = []
        var keys = 0
        for line in content.split(separator: "\n") {
            guard let match = line.firstMatch(of: linePattern) else { continue }
            keys += 1
            let value = String(match.2).lowercased()
            for name in providerNames where value.contains(name) {
                found.append((String(match.1), name))
            }
        }
        return (found, keys)
    }

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
    }

    @Test func noConsentString_namesTheAIProvider() throws {
        let resources = Self.repoRoot.appendingPathComponent("Yala/Resources")
        let lprojs = try FileManager.default.contentsOfDirectory(at: resources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "lproj" }
            .sorted { $0.path < $1.path }
        var scanned = 0
        var violations: [String] = []
        for lproj in lprojs {
            let url = lproj.appendingPathComponent("Localizable.strings")
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let content = try String(contentsOf: url, encoding: .utf8)
            let result = Self.violations(in: content)
            scanned += 1
            // Hoy son 15 claves `aiConsent.*` por idioma. Con menos de 10 el patrón ya no las está leyendo.
            #expect(result.keys >= 10, "\(lproj.lastPathComponent): solo \(result.keys) claves aiConsent.* — ¿cambió el formato?")
            violations += result.found.map { "\(lproj.lastPathComponent) \($0.0) («\($0.1)»)" }
        }
        #expect(scanned >= 16, "Solo se leyeron \(scanned) Localizable.strings — ¿cambió la ruta?")
        #expect(violations.isEmpty, "Avisos de IA que nombran al proveedor: \(violations.prefix(10))")
    }

    /// El escáner caza los textos tal cual estaban antes del 2026-10-17: si no, el test de arriba pasaría en vacío.
    @Test(arguments: [
        #""aiConsent.processingMessage" = "Dictas o eliges una foto del recibo y Yala apunta el gasto. Para eso envía el audio o la foto a un servicio de IA (OpenAI), solo en ese momento. No se usan para entrenar a la IA.";"#,
        #""aiConsent.insightsMessage" = "This feature sends OpenAI a summary of your finances —totals and trends by category, budgets, and recurring payments— to generate your analysis.";"#,
        #""aiConsent.inlineHintMultiple" = "多项 AI 功能使用 OpenAI 处理你的数据,不会被永久存储。";"#,
    ])
    func scanner_catchesTheOldConsentCopy(line: String) {
        #expect(!Self.violations(in: line).found.isEmpty)
    }

    /// Fuera de `aiConsent.*` el nombre sigue permitido: la política y la pantalla de privacidad de la IA lo dan.
    @Test func scanner_onlyLooksAtConsentKeys() {
        let line = #""aiPrivacy.footerHint" = "Tus datos llegan a OpenAI a través de nuestro servidor.";"#
        let result = Self.violations(in: line)
        #expect(result.found.isEmpty)
        #expect(result.keys == 0)
    }

    /// Cada aviso de consentimiento (voz y foto, chat, resumen inteligente) ofrece la Política de privacidad, que es
    /// donde está ahora el nombre del proveedor.
    @Test func everyConsentAlert_keepsThePrivacyPolicyButton() throws {
        let url = Self.repoRoot.appendingPathComponent("Yala/App/Theme/ViewModifiers.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        for modifier in ["AIConsentAlertModifier", "ChatConsentAlertModifier", "InsightsConsentAlertModifier"] {
            let body = try #require(Self.structBody(named: modifier, in: source), "No encuentro \(modifier)")
            #expect(body.contains("Button(L10n.AIConsent.privacyPolicy)"), "\(modifier) ya no ofrece la política")
            #expect(body.contains("openURL(AppConstants.privacyURL)"), "\(modifier) no abre la política")
        }
    }

    /// El cuerpo de `struct <name>` hasta el siguiente `struct ` o `extension ` de primer nivel.
    static func structBody(named name: String, in source: String) -> String? {
        guard let start = source.range(of: "struct \(name):") else { return nil }
        let rest = source[start.upperBound...]
        let end = [rest.range(of: "\nstruct "), rest.range(of: "\nextension ")]
            .compactMap { $0?.lowerBound }
            .min() ?? rest.endIndex
        return String(rest[..<end])
    }
}
