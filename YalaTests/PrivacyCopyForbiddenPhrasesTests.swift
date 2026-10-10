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
//  Desde el ticket `in-app-ai-privacy-claims-need-a-policy-check` también caza lo que la app
//  prometía sobre la IA sin que la política lo dijera: que es «segura», que «no comparte ni
//  almacena datos sensibles» y que «solo manda datos resumidos a OpenAI». Las tres eran falsas
//  para la foto de un recibo, que es un gasto individual y pasa entera por nuestro servidor.
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

        // IA: «no comparten ni almacenan datos sensibles» (`onboarding.privacyNoSharing`)
        "no comparten ni almacenan", "don't share or store", "teilen oder speichern keine",
        "ne partagent ni ne stockent", "non condividono né archiviano", "共有・保存しません",
        "delen of bewaren geen", "nie udostępniają ani nie zapisują", "não partilham nem armazenam",
        "不分享或存储敏感数据",
        // IA: «solo se envían datos resumidos a OpenAI» (`insights.activateAIDisclaimer`)
        "solo se envían datos resumidos", "only summarized data", "nur zusammengefasste daten",
        "seules des données résumées", "solo dati riassuntivi", "集計データのみ", "alleen samengevatte gegevens",
        "tylko zagregowane dane", "apenas dados resumidos", "只有汇总数据",
        // IA: «IA segura» en ja y zh-Hans. Van aquí y no en `forbiddenWholePhrases` porque sin espacios
        // entre palabras el límite de letra no existe: «より安全な AI» llevaría un kanji pegado delante.
        "安全な ai", "安全 ai",
    ]

    /// Frases prohibidas que solo cuentan como frase ENTERA: sin letra justo antes ni justo después.
    /// Son cortas y por subcadena cazarían textos verdaderos («copia segura» contiene «ia segura»).
    /// Son los títulos de la tarjeta «IA segura» del onboarding (`onboarding.privacyNoSharingShort`).
    static let forbiddenWholePhrases: [String] = [
        "ia segura", "safe ai", "sichere ki", "ia sécurisée", "ia sicura", "veilige ai", "bezpieczna si",
    ]

    /// `true` si `phrase` aparece en `value` sin una letra pegada a ninguno de sus dos lados.
    static func containsWholePhrase(_ value: String, _ phrase: String) -> Bool {
        var searchStart = value.startIndex
        while let range = value.range(of: phrase, range: searchStart..<value.endIndex) {
            let before = range.lowerBound == value.startIndex ? nil : value[value.index(before: range.lowerBound)]
            let after = range.upperBound == value.endIndex ? nil : value[range.upperBound]
            if !(before?.isLetter ?? false), !(after?.isLetter ?? false) { return true }
            searchStart = value.index(after: range.lowerBound)
        }
        return false
    }

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
            for phrase in forbiddenWholePhrases where containsWholePhrase(value, phrase) {
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
            "Textos que prometen algo que 2.1 no cumple (datos fuera del dispositivo o la IA): \(violations.prefix(10).map { "\($0.0) \($0.1) («\($0.2)»)" })"
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

    /// Las promesas sobre la IA que había hasta 2.1, tal cual estaban, en varios idiomas.
    @Test(arguments: [
        #""onboarding.privacyNoSharingShort" = "IA segura";"#,
        #""onboarding.privacyNoSharingShort" = "Safe AI";"#,
        #""onboarding.privacyNoSharingShort" = "Sichere KI";"#,
        #""onboarding.privacyNoSharingShort" = "Bezpieczna SI";"#,
        #""onboarding.privacyNoSharingShort" = "安全な AI";"#,
        #""onboarding.privacyNoSharingShort" = "安全 AI";"#,
        #""onboarding.privacyNoSharing" = "Las funciones de IA no comparten ni almacenan datos sensibles";"#,
        #""onboarding.privacyNoSharing" = "AI features don't share or store sensitive data";"#,
        #""onboarding.privacyNoSharing" = "Funkcje AI nie udostępniają ani nie zapisują wrażliwych danych";"#,
        #""insights.activateAIDisclaimer" = "Solo se envían datos resumidos a OpenAI (totales, porcentajes, tendencias).";"#,
        #""insights.activateAIDisclaimer" = "Only summarized data is sent to OpenAI (totals, percentages, trends).";"#,
        #""insights.activateAIDisclaimer" = "Nur zusammengefasste Daten werden an OpenAI gesendet.";"#,
    ])
    func scanner_catchesTheOldAIPromises(line: String) {
        #expect(!Self.violations(in: line, file: "fixture").isEmpty)
    }

    /// Lo que sí es verdad en 2.1 no se caza.
    @Test(arguments: [
        #""groups.consent.point2" = "Solo se comparte lo mínimo: tu alias y los gastos del grupo. Tu correo no sale de tu dispositivo.";"#,
        #""groups.consent.point2" = "Only the minimum is shared: your alias and the group's expenses. Your email never leaves your device.";"#,
        #""profile.privacyTitle" = "Dónde viven tus datos";"#,
        #""onboarding.privacyAIShort" = "IA a través de nuestro servidor";"#,
        #""onboarding.privacyAIShort" = "AI through our server";"#,
        // «ia segura» como subcadena de otra palabra no es la promesa: la frase entera sí.
        #""backup.hint" = "Haz una copia segura de tus datos";"#,
        #""backup.hint" = "Faça uma cópia segura dos seus dados";"#,
    ])
    func scanner_ignoresTruthfulCopy(line: String) {
        #expect(Self.violations(in: line, file: "fixture").isEmpty)
    }
}
