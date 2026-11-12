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
//  Segunda decisión del mismo día (15:19): «Preferiría no decir literalmente OpenAI a menos que sea 100% necesario».
//  Desde ahí el nombre tampoco sale en Ajustes › Privacidad de la IA, Datos personales ni en los permisos de cámara,
//  micrófono y fotos. `noVisibleString_namesTheAIProvider` lee TODAS las cadenas visibles —`Localizable.strings` e
//  `InfoPlist.strings` de la app y del widget, y los `Info.plist`— y solo deja pasar las claves de
//  `allowedProviderMentions`, cada una con su porqué. Hoy no hay ninguna.
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

    /// Este escáner solo mira `aiConsent.*` (y cuenta esas claves para no pasar en vacío). El resto de cadenas lo cubre
    /// `noVisibleString_namesTheAIProvider`.
    @Test func scanner_onlyLooksAtConsentKeys() {
        let line = #""aiPrivacy.footerHint" = "Tus datos llegan a OpenAI a través de nuestro servidor.";"#
        let result = Self.violations(in: line)
        #expect(result.found.isEmpty)
        #expect(result.keys == 0)
    }

    // MARK: - Cualquier cadena visible (decisión del 2026-10-17, 15:19)

    /// Claves que pueden nombrar al proveedor, con el porqué. Una clave nueva aquí tiene que ser 100 % necesaria (la
    /// decisión de Jürgen) y decir por qué; el sitio del nombre es la Política de privacidad, que la app enlaza.
    static let allowedProviderMentions: [String: String] = [:]

    /// El proveedor que nombra `value` (en minúsculas), o `nil`: los de `providerNames` o «gpt» como palabra suelta.
    static func namesProvider(_ value: String) -> String? {
        if let name = providerNames.first(where: { value.contains($0) }) { return name }
        var searchStart = value.startIndex
        while let range = value.range(of: "gpt", range: searchStart..<value.endIndex) {
            let before = range.lowerBound == value.startIndex ? nil : value[value.index(before: range.lowerBound)]
            let after = range.upperBound == value.endIndex ? nil : value[range.upperBound]
            let glued = (before.map { $0.isLetter || $0.isNumber } ?? false) || (after?.isLetter ?? false)
            if !glued { return "gpt" }
            searchStart = range.upperBound
        }
        return nil
    }

    /// `(clave, nombre)` por cada valor de un `.strings` que nombra a un proveedor y no está en `allowed`, y cuántas
    /// claves leyó.
    static func visibleViolations(
        in content: String, allowed: [String: String] = allowedProviderMentions
    ) -> (found: [(String, String)], keys: Int) {
        let linePattern = #/^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;/#
        var found: [(String, String)] = []
        var keys = 0
        for line in content.split(separator: "\n") {
            guard let match = line.firstMatch(of: linePattern) else { continue }
            keys += 1
            let key = String(match.1)
            guard allowed[key] == nil, let name = namesProvider(String(match.2).lowercased()) else { continue }
            found.append((key, name))
        }
        return (found, keys)
    }

    /// Todos los valores de texto de un plist, con su clave.
    static func plistStrings(_ object: Any, key: String = "") -> [(String, String)] {
        if let string = object as? String { return [(key, string)] }
        if let dict = object as? [String: Any] { return dict.flatMap { plistStrings($0.value, key: $0.key) } }
        if let array = object as? [Any] { return array.flatMap { plistStrings($0, key: key) } }
        return []
    }

    @Test func noVisibleString_namesTheAIProvider() throws {
        let fm = FileManager.default
        var counts: [String: Int] = [:]
        var violations: [String] = []
        for root in ["Yala/Resources", "YalaWidgets/Resources"] {
            let rootURL = Self.repoRoot.appendingPathComponent(root)
            let lprojs = try fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "lproj" }
            for lproj in lprojs {
                for file in ["Localizable.strings", "InfoPlist.strings"] {
                    let url = lproj.appendingPathComponent(file)
                    guard fm.fileExists(atPath: url.path) else { continue }
                    let result = Self.visibleViolations(in: try String(contentsOf: url, encoding: .utf8))
                    #expect(result.keys > 0, "\(root)/\(lproj.lastPathComponent)/\(file) sin claves — ¿cambió el formato?")
                    counts["\(root)/\(file)", default: 0] += 1
                    violations += result.found.map { "\(root)/\(lproj.lastPathComponent)/\(file) \($0.0) («\($0.1)»)" }
                }
            }
        }
        // 16 idiomas en la app (textos y permisos) y en el widget: si una ruta se rompe, el test no pasa en vacío.
        #expect(counts["Yala/Resources/Localizable.strings", default: 0] >= 16, "\(counts)")
        #expect(counts["Yala/Resources/InfoPlist.strings", default: 0] >= 16, "\(counts)")
        #expect(counts["YalaWidgets/Resources/Localizable.strings", default: 0] >= 16, "\(counts)")

        // Los `Info.plist` llevan el texto base de los permisos (el que sale si falta el idioma).
        for path in ["Yala/Resources/Info.plist", "YalaWidgets/Info.plist", "YalaShare/Info.plist"] {
            let data = try Data(contentsOf: Self.repoRoot.appendingPathComponent(path))
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            for (key, value) in Self.plistStrings(plist) where Self.allowedProviderMentions[key] == nil {
                if let name = Self.namesProvider(value.lowercased()) { violations.append("\(path) \(key) («\(name)»)") }
            }
        }
        #expect(violations.isEmpty, "Cadenas visibles que nombran al proveedor de IA: \(violations.prefix(10))")
    }

    /// El escáner caza las cadenas tal cual estaban antes del 2026-10-17 (tarde): si no, el test de arriba pasaría en
    /// vacío.
    @Test(arguments: [
        #""aiPrivacy.footerHint" = "Tus datos llegan a OpenAI a través de nuestro servidor.";"#,
        #""profile.privacyDesc" = "…what you send them goes through our server to OpenAI, which processes it.";"#,
        #""NSMicrophoneUsageDescription" = "Yala 使用麦克风录制你的语音以创建支出。音频将发送到 OpenAI 进行转录。";"#,
        #""insights.aiCaption" = "OpenAI analiza tus datos agregados para generar análisis personalizados.";"#,
        #""chat.footer" = "Respuestas generadas con GPT-4o.";"#,
        #""chat.footer" = "Funciona con ChatGPT.";"#,
        #""chat.footer" = "Powered by GPT.";"#,
    ])
    func visibleScanner_catchesTheOldCopy(line: String) {
        #expect(!Self.visibleViolations(in: line).found.isEmpty)
    }

    /// «un servicio de IA» y las palabras que contienen «gpt» por dentro no cuentan; una clave de la lista de
    /// excepciones, tampoco.
    @Test func visibleScanner_ignoresTheNewCopyAndTheExceptions() {
        #expect(Self.visibleViolations(in: #""aiPrivacy.footerHint" = "…y llegan a un servicio de IA a través de nuestro servidor.";"#).found.isEmpty)
        #expect(Self.visibleViolations(in: #""x.y" = "Plantilla sgpt2 y lgpt";"#).found.isEmpty)
        let allowed = ["legal.provider": "fixture"]
        #expect(Self.visibleViolations(in: #""legal.provider" = "OpenAI";"#, allowed: allowed).found.isEmpty)
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
