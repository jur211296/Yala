//
//  DosNombresDeSitioTests.swift
//  YalaTests
//
//  Decisión 51 de la revisión 2.3 (9-nov-2026, opción T1, con la bienvenida): para decir dónde viven los datos, la app
//  usa SOLO dos nombres de sitio, «En tu iCloud» y «En tu cuenta de Yala», y los verbos dicen el destino: «Pasar a tu
//  cuenta de Yala» y «Volver a tu iCloud». Hasta entonces eran nueve nombres («iCloud privado», «modo privado», «la nube
//  de Yala», «tu cuenta en la nube», «tu cuenta de la nube»…) y seis verbos («Migrar», «Activar la nube»…).
//
//  Tres redes, en los 16 idiomas:
//  1. Los títulos de los dos sitios (Ajustes, «Dónde viven tus datos», la bienvenida, la tarjeta del carrusel y la hoja de
//     borrado) dicen exactamente la pareja del idioma, y los dos botones dicen el verbo del idioma.
//  2. Ningún texto del catálogo trae los nombres VIEJOS de los títulos y botones de ese idioma.
//  3. En español, ningún texto usa un nombre retirado como sitio. «La nube» y «los servidores de Yala» siguen permitidos
//     como explicación; «Sincronización iCloud» (otra fila, decisión 54) y el avatar «Nube» quedan fuera a propósito.
//

import Foundation
import Testing

@Suite("Dos nombres de sitio: «En tu iCloud» y «En tu cuenta de Yala» (decisión 51 de 2.3)")
struct DosNombresDeSitioTests {

    // MARK: - Catálogo

    private static func repoFile(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    private static func catalog(_ language: String) throws -> [String: String] {
        let text = try repoFile("Yala/Resources/\(language).lproj/Localizable.strings")
        var entries: [String: String] = [:]
        let pattern = try NSRegularExpression(pattern: #"^"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";"#, options: .anchorsMatchLines)
        let range = NSRange(text.startIndex..., in: text)
        for match in pattern.matches(in: text, range: range) {
            guard let key = Range(match.range(at: 1), in: text), let value = Range(match.range(at: 2), in: text) else { continue }
            entries[String(text[key])] = String(text[value])
        }
        return entries
    }

    /// La pareja de cada idioma: sitio iCloud, sitio cuenta, botón de ida, botón de vuelta.
    private struct Names {
        let icloud: String
        let account: String
        let moveTo: String
        let backTo: String
    }

    private static let spanish = Names(icloud: "En tu iCloud", account: "En tu cuenta de Yala",
                                       moveTo: "Pasar a tu cuenta de Yala", backTo: "Volver a tu iCloud")
    private static let english = Names(icloud: "In your iCloud", account: "In your Yala account",
                                       moveTo: "Move to your Yala account", backTo: "Go back to your iCloud")
    private static let brazilian = Names(icloud: "No seu iCloud", account: "Na sua conta do Yala",
                                         moveTo: "Passar para a sua conta do Yala", backTo: "Voltar para o seu iCloud")

    private static let names: [String: Names] = [
        "es": spanish, "es-419": spanish, "es-AR": spanish, "es-ES": spanish,
        "en": english, "en-GB": english,
        "de": Names(icloud: "In deiner iCloud", account: "In deinem Yala-Konto",
                    moveTo: "Zu deinem Yala-Konto wechseln", backTo: "Zurück zu deiner iCloud"),
        "fr": Names(icloud: "Dans ton iCloud", account: "Dans ton compte Yala",
                    moveTo: "Passer à ton compte Yala", backTo: "Revenir à ton iCloud"),
        "it": Names(icloud: "Nel tuo iCloud", account: "Nel tuo account Yala",
                    moveTo: "Passa al tuo account Yala", backTo: "Torna al tuo iCloud"),
        "ja": Names(icloud: "あなたの iCloud", account: "あなたの Yala アカウント",
                    moveTo: "Yala アカウントに移す", backTo: "iCloud に戻す"),
        "nl": Names(icloud: "In je iCloud", account: "In je Yala-account",
                    moveTo: "Overstappen naar je Yala-account", backTo: "Terug naar je iCloud"),
        "pl": Names(icloud: "W Twoim iCloud", account: "Na Twoim koncie Yala",
                    moveTo: "Przejdź na konto Yala", backTo: "Wróć do swojego iCloud"),
        "pt-BR": brazilian, "pt": brazilian,
        "pt-PT": Names(icloud: "No teu iCloud", account: "Na tua conta Yala",
                       moveTo: "Passar para a tua conta Yala", backTo: "Voltar ao teu iCloud"),
        "zh-Hans": Names(icloud: "在你的 iCloud 中", account: "在你的 Yala 账户中",
                         moveTo: "转到你的 Yala 账户", backTo: "返回你的 iCloud"),
    ]

    /// Los nombres que la decisión retiró: el título del sitio iCloud, el de la cuenta y los dos de la ida, tal como los
    /// traía cada idioma antes del cambio.
    private static let retired: [String: [String]] = [
        "es": ["iCloud privado", "Tu cuenta en la nube", "Activar la nube", "Migrar a la nube"],
        "es-419": ["iCloud privado", "Tu cuenta en la nube", "Activar la nube", "Migrar a la nube"],
        "es-AR": ["iCloud privado", "Tu cuenta en la nube", "Activar la nube", "Migrar a la nube"],
        "es-ES": ["iCloud privado", "Tu cuenta en la nube", "Activar la nube", "Migrar a la nube"],
        "en": ["Private iCloud", "Your cloud account", "Turn on the cloud", "Move to the cloud"],
        "en-GB": ["Private iCloud", "Your cloud account", "Turn on the cloud", "Move to the cloud"],
        "de": ["Privates iCloud", "Dein Cloud-Konto", "Cloud aktivieren", "In die Cloud wechseln"],
        "fr": ["iCloud privé", "Ton compte cloud", "Activer le cloud", "Passer au cloud"],
        "it": ["iCloud privato", "Il tuo account nel cloud", "Attiva il cloud", "Passa al cloud"],
        "ja": ["プライベート iCloud", "クラウドアカウント", "クラウドを有効化", "クラウドへ移行"],
        "nl": ["Privé-iCloud", "Je cloud-account", "Cloud inschakelen", "Overstappen naar de cloud"],
        "pl": ["Prywatny iCloud", "Twoje konto w chmurze", "Włącz chmurę", "Przenieś do chmury"],
        "pt-BR": ["iCloud privado", "Sua conta na nuvem", "Ativar a nuvem", "Migrar para a nuvem"],
        "pt": ["iCloud privado", "Sua conta na nuvem", "Ativar a nuvem", "Migrar para a nuvem"],
        "pt-PT": ["iCloud privado", "A tua conta na nuvem", "Ativar a nuvem", "Migrar para a nuvem"],
        "zh-Hans": ["私有 iCloud", "你的云端账户", "启用云端", "迁移到云端"],
    ]

    /// Fuera a propósito: otra fila (decisión 54 la funde) y el nombre de un avatar.
    private static let outOfScope: Set<String> = ["icloud.title", "profile.icon.cloud"]

    private static let icloudTitleKeys = [
        "storage.status.icloudTitle", "welcome.new.privateTitle", "settings.dataLocationSubtitleICloud",
        "welcome.hero.cards.icloud.title", "settings.scopeICloudLabel",
    ]
    private static let accountTitleKeys = [
        "storage.status.cloudTitle", "welcome.new.cloudTitle", "settings.dataLocationSubtitleCloud",
        "settings.scopeCloudAccountLabel",
    ]

    // MARK: - 1. Títulos y botones

    @Test("los títulos de los dos sitios dicen la pareja del idioma, en los 16", arguments: names.keys.sorted())
    func titlesUseThePair(language: String) throws {
        let strings = try Self.catalog(language)
        let pair = try #require(Self.names[language])
        for key in Self.icloudTitleKeys {
            #expect(strings[key] == pair.icloud, "\(language) · \(key) = «\(strings[key] ?? "—")», no «\(pair.icloud)»")
        }
        for key in Self.accountTitleKeys {
            #expect(strings[key] == pair.account, "\(language) · \(key) = «\(strings[key] ?? "—")», no «\(pair.account)»")
        }
    }

    @Test("los botones dicen el destino: «Pasar a…» y «Volver a…», en los 16", arguments: names.keys.sorted())
    func buttonsSayTheDestination(language: String) throws {
        let strings = try Self.catalog(language)
        let pair = try #require(Self.names[language])
        #expect(strings["storage.migrate.button"] == pair.moveTo, "\(language): el botón de ida no dice «\(pair.moveTo)»")
        #expect(strings["storage.migrate.title"] == pair.moveTo, "\(language): el título de la ida no dice «\(pair.moveTo)»")
        #expect(strings["storage.revert.button"] == pair.backTo, "\(language): el botón de vuelta no dice «\(pair.backTo)»")
        #expect(strings["storage.revert.title"] == pair.backTo, "\(language): el título de la vuelta no dice «\(pair.backTo)»")
        #expect(strings["settings.yalaAccountReturnICloud"] == pair.backTo,
                "\(language): «Volver» de la pantalla de la cuenta no dice «\(pair.backTo)»")
    }

    // MARK: - 2. Los nombres viejos, en ningún texto

    @Test("ningún texto trae los nombres retirados de su idioma", arguments: retired.keys.sorted())
    func noRetiredNames(language: String) throws {
        let strings = try Self.catalog(language)
        let old = try #require(Self.retired[language])
        let offenders = strings
            .filter { key, value in
                !Self.outOfScope.contains(key)
                    && old.contains { value.range(of: $0, options: [.caseInsensitive]) != nil }
            }
            .keys.sorted()
        #expect(offenders.isEmpty, "\(language) aún dice un nombre retirado en: \(offenders.joined(separator: ", "))")
    }

    // MARK: - 3. En español, ningún nombre retirado como sitio

    @Test("en español, ningún texto usa un nombre retirado como sitio",
          arguments: ["es", "es-419", "es-AR", "es-ES"])
    func spanishHasNoRetiredPlaceName(language: String) throws {
        let strings = try Self.catalog(language)
        let forbidden = try NSRegularExpression(
            pattern: #"iCloud privado|modo privado|modo nube|nube de Yala|cuenta (en|de) la nube|cuenta Yala en la nube|\bmigr(ar|aría)\b|activar la nube|(sigue|sigues|seguir|seguirás) (usando )?(en )?la nube|desvincular tu cuenta"#,
            options: [.caseInsensitive])
        let offenders = strings
            .filter { key, value in
                !Self.outOfScope.contains(key)
                    && forbidden.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) != nil
            }
            .keys.sorted()
        #expect(offenders.isEmpty, "\(language) usa un nombre de sitio retirado en: \(offenders.joined(separator: ", "))")
    }
}
