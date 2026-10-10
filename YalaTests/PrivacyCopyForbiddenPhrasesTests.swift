//
//  PrivacyCopyForbiddenPhrasesTests.swift
//  YalaTests
//
//  Desde 2.1 no es verdad que los datos «nunca salgan del dispositivo»: la cuenta en la nube
//  y los Grupos viven en los servidores de Yala, y la IA pasa por nuestro gateway hasta
//  OpenAI. Este test lee las `Localizable.strings` FUENTE (app + widget, vía `#filePath`)
//  y falla si vuelve alguna de las frases que lo prometían, en cualquiera de los 16 idiomas.
//
//  Las frases son las que había en 2.0 (ticket
//  `in-app-privacy-copy-says-data-never-leaves-the-device`). Se comparan en minúsculas y
//  por subcadena, contra el VALOR de cada clave. Ojo al añadir una: «Tu correo no sale de
//  tu dispositivo» (`groups.consent.point2`) es verdad y no debe cazarse.
//

import Foundation
import Testing

struct PrivacyCopyForbiddenPhrasesTests {

    /// Frases prohibidas, en minúsculas. Agrupadas por idioma solo para leerlas: se buscan en todos.
    static let forbiddenPhrases: [String] = [
        // es (es-419, es, es-ES, es-AR)
        "nunca salen de tu dispositivo", "sin servidores", "únicamente en tu dispositivo", "100% privado",
        "solo tú accedes", "solo vos accedés",
        // en / en-GB
        "data never leaves", "no servers", "never our servers", "solely on your device", "100% private",
        "only you have access",
        // de
        "verlassen niemals", "keine server", "niemals über unsere server", "nur auf deinem gerät", "100% privat",
        "nur du hast zugriff",
        // fr
        "ne quittent jamais", "sans serveur", "jamais par nos serveurs", "uniquement sur ton appareil", "100% privé",
        // it
        "non lasciano mai", "niente server", "mai sui nostri server", "solo sul tuo dispositivo", "100% privato",
        // ja
        "デバイスの外に出ません", "サーバーなし", "当社のサーバーは通りません", "このデバイス上にのみ", "100%プライベート",
        // nl
        "verlaten je apparaat nooit", "geen servers", "nooit via onze servers", "alleen op je apparaat",
        // pl
        "nigdy nie opuszczają", "bez serwerów", "nigdy przez nasze serwery", "wyłącznie na urządzeniu", "100% prywatne",
        // pt (pt-BR, pt, pt-PT)
        "nunca saem do seu dispositivo", "sem servidores", "nunca pelos nossos servidores", "apenas no seu dispositivo",
        "só você acessa",
        // zh-Hans
        "永远不会离开你的设备", "无服务器", "绝不经过我们的服务器", "仅在你的设备上", "100% 私密",
    ]

    /// Devuelve `(fichero, clave, frase)` por cada valor que contiene una frase prohibida.
    static func violations(in content: String, file: String) -> [(String, String, String)] {
        let linePattern = #/^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;/#
        var found: [(String, String, String)] = []
        for line in content.split(separator: "\n") {
            guard let match = line.firstMatch(of: linePattern) else { continue }
            let value = String(match.2).lowercased()
            for phrase in forbiddenPhrases where value.contains(phrase) {
                found.append((file, String(match.1), phrase))
            }
        }
        return found
    }

    @Test func noLocalizedString_promisesDataNeverLeavesTheDevice() {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
        var scanned = 0
        var violations: [(String, String, String)] = []

        for root in ["Yala/Resources", "YalaWidgets/Resources"] {
            let rootURL = repoRoot.appendingPathComponent(root)
            let lprojs: [URL]
            do {
                lprojs = try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "lproj" }
            } catch {
                Issue.record("No se pudo listar '\(root)': \(error)")
                continue
            }
            for lproj in lprojs.sorted(by: { $0.path < $1.path }) {
                let url = lproj.appendingPathComponent("Localizable.strings")
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    scanned += 1
                    violations += Self.violations(in: content, file: "\(root)/\(lproj.lastPathComponent)")
                } catch {
                    Issue.record("No se pudo leer \(url.path): \(error)")
                }
            }
        }

        // Los 16 idiomas de la app como mínimo: si el path se rompe, el test no puede pasar en vacío.
        #expect(scanned >= 16, "Solo se leyeron \(scanned) Localizable.strings — ¿cambió la ruta?")
        #expect(
            violations.isEmpty,
            "Textos que prometen que los datos no salen del dispositivo: \(violations.prefix(10).map { "\($0.0) \($0.1) («\($0.2)»)" })"
        )
    }

    /// El escáner tiene que cazar las frases de 2.0 tal cual estaban: si no, el test de arriba pasaría en vacío.
    @Test(arguments: [
        #""profile.privacyTitle" = "Tus datos nunca salen de tu dispositivo";"#,
        #""welcome.hero.cards.icloud.body" = "Your data, in your iCloud. No servers.";"#,
        #""welcome.hero.trust" = "100% privado · Tu info siempre contigo";"#,
        #""common.dataPrivacy" = "Deine Daten verlassen niemals dein Gerät";"#,
        #""whatsNew.v20.groups.description" = "Crie grupos… tudo viaja pelo seu iCloud privado, nunca pelos nossos servidores.";"#,
        #""onboarding.privacyIcloudShort" = "Solo tú accedes";"#,
        #""common.dataPrivacy" = "你的数据永远不会离开你的设备";"#,
    ])
    func scanner_catchesThe2_0Phrases(line: String) {
        #expect(!Self.violations(in: line, file: "fixture").isEmpty)
    }

    /// Lo que sí es verdad en 2.1 no se caza.
    @Test(arguments: [
        #""groups.consent.point2" = "Solo se comparte lo mínimo: tu alias y los gastos del grupo. Tu correo no sale de tu dispositivo.";"#,
        #""groups.consent.point2" = "Only the minimum is shared: your alias and the group's expenses. Your email never leaves your device.";"#,
        #""profile.privacyTitle" = "Dónde viven tus datos";"#,
    ])
    func scanner_ignoresTruthfulCopy(line: String) {
        #expect(Self.violations(in: line, file: "fixture").isEmpty)
    }
}
