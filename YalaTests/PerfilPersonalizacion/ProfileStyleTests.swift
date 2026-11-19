//
//  ProfileStyleTests.swift
//  YalaTests
//
//  Perfil con personalización de verdad (2026-11-18): cómo se guarda y se lee el estilo del perfil, la migración de
//  quien ya tenía un símbolo, las caídas del avatar, las iniciales, los emojis, los catálogos, el contraste de la tarjeta
//  y que la preferencia viaje por el canal de siempre. Los textos, en los 16 idiomas.
//

import Foundation
import Testing
import UIKit

@testable import Yala

// MARK: - Guardar y leer

@Suite("Perfil · guardar y leer el estilo")
struct ProfileStyleStoreTests {

    @Test func elDeSiempre_seGuardaVacio_yVacioEsElDeSiempre() {
        #expect(ProfileStyleLogic.encode(.standard) == "")
        #expect(ProfileStyleLogic.decode("") == .standard)
    }

    @Test func idaYVuelta_conservaTodo() {
        let style = ProfileStyle(kind: .emoji, emoji: "🦊", avatarColorHex: "#FF0080", cardTemplateID: "aurora")
        let stored = ProfileStyleLogic.encode(style)
        #expect(ProfileStyleLogic.decode(stored) == style)
    }

    /// El mismo estilo da siempre el mismo texto: la sincronización no ve un cambio donde no lo hay.
    @Test func elTexto_esEstable_yCorto() {
        let style = ProfileStyle(kind: .initials, avatarColorHex: "#4CB963", cardTemplateID: "gold")
        #expect(ProfileStyleLogic.encode(style) == ##"{"a":"#4CB963","k":"initials","t":"gold"}"##)
        #expect(ProfileStyleLogic.encode(style) == ProfileStyleLogic.encode(style))
    }

    @Test func loQueNoSeEntiende_seIgnora_sinPerderElResto() {
        let raw = #"{"k":"sticker","e":"a","a":"rojo","t":"inventada","x":1}"#
        #expect(ProfileStyleLogic.decode(raw) == .standard)
        let mixto = #"{"k":"emoji","e":"🐼","a":"zz","t":"forest"}"#
        #expect(ProfileStyleLogic.decode(mixto) == ProfileStyle(kind: .emoji, emoji: "🐼", cardTemplateID: "forest"))
    }

    @Test func unTextoQueNoEsJSON_esElDeSiempre() {
        #expect(ProfileStyleLogic.decode("star.fill") == .standard)
        #expect(ProfileStyleLogic.decode("{") == .standard)
    }

    @Test func elColor_seNormaliza() {
        let style = ProfileStyleLogic.decode(#"{"k":"symbol","a":"ff0080"}"#)
        #expect(style.avatarColorHex == "#FF0080")
    }
}

// MARK: - Migración y caídas del avatar

@Suite("Perfil · migración y lo que lleva el avatar")
struct ProfileAvatarContentTests {

    /// Quien ya tenía un símbolo y nunca abre la personalización ve lo de antes: su símbolo y los colores del tema.
    @Test func quienYaTeniaUnSimbolo_loSigueViendo() {
        let style = ProfileStyleLogic.decode("")
        #expect(ProfileStyleLogic.content(style: style, symbol: "star.fill", name: "Ana", defaultName: "Usuario")
            == .symbol("star.fill"))
        #expect(style.avatarColorHex == nil)
        #expect(style.cardTemplateID == nil)
    }

    @Test func sinSimbolo_esElMuñecoDeSiempre() {
        #expect(ProfileStyleLogic.content(style: .standard, symbol: "", name: "", defaultName: "Usuario")
            == .symbol("person.fill"))
    }

    @Test func emojiSinEmoji_vuelveAlSimbolo() {
        let style = ProfileStyle(kind: .emoji)
        #expect(ProfileStyleLogic.content(style: style, symbol: "moon.fill", name: "Ana", defaultName: "Usuario")
            == .symbol("moon.fill"))
    }

    @Test func emoji_seEnseña() {
        let style = ProfileStyle(kind: .emoji, emoji: "🚀")
        #expect(ProfileStyleLogic.content(style: style, symbol: "moon.fill", name: "Ana", defaultName: "Usuario")
            == .emoji("🚀"))
    }

    @Test func inicialesSinNombre_vuelvenAlSimbolo() {
        let style = ProfileStyle(kind: .initials)
        #expect(ProfileStyleLogic.content(style: style, symbol: "", name: "Usuario", defaultName: "Usuario")
            == .symbol("person.fill"))
        #expect(ProfileStyleLogic.content(style: style, symbol: "", name: "Jürgen Schmidt", defaultName: "Usuario")
            == .initials("JS"))
    }
}

// MARK: - Iniciales y emojis

@Suite("Perfil · iniciales y emojis")
struct ProfileInitialsAndEmojiTests {

    @Test(arguments: [
        ("Jürgen Schmidt", "JS"),
        ("jürgen", "J"),
        ("María José López", "ML"),
        ("Ana-Lucía", "AL"),
        ("  Lu  ", "L"),
        ("Óscar Ñúñez", "ÓÑ"),
        ("123 Pepe", "P"),
        ("", ""),
        ("   ", ""),
        ("Usuario", ""),
    ])
    func iniciales(_ caso: (String, String)) {
        #expect(ProfileStyleLogic.initials(from: caso.0, defaultName: "Usuario", locale: Locale(identifier: "es"))
            == caso.1)
    }

    @Test(arguments: [
        ("🦊", "🦊"), ("⚡️", "⚡️"), ("👍🏽", "👍🏽"), ("🇵🇪", "🇵🇪"), ("🦊🐼", "🦊"), (" 🐸 ", "🐸"),
    ])
    func unEmoji_seQueda(_ caso: (String, String)) {
        #expect(ProfileStyleLogic.sanitizedEmoji(caso.0) == caso.1)
    }

    @Test(arguments: ["a", "1", "#", "*", "", "   ", "Jürgen"])
    func loQueNoEsEmoji_seDescarta(_ texto: String) {
        #expect(ProfileStyleLogic.sanitizedEmoji(texto) == nil)
    }
}

// MARK: - Catálogos y contraste

@MainActor
@Suite("Perfil · catálogos y contraste")
struct ProfileCatalogTests {

    @Test func losDoceDeAntes_vanPrimero_yEnSuOrden() {
        #expect(Array(ProfileStyleLogic.symbols.prefix(12)) == ProfileStyleLogic.legacySymbols)
        #expect(ProfileStyleLogic.symbols.count == 36)
        #expect(Set(ProfileStyleLogic.symbols).count == 36)
    }

    @Test func cadaSimbolo_existeEnElSistema() {
        for name in ProfileStyleLogic.symbols {
            #expect(UIImage(systemName: name) != nil, "No existe el símbolo \(name)")
        }
    }

    @Test func cadaEmoji_esUnEmoji_yNoSeRepite() {
        #expect(ProfileStyleLogic.emojis.count == 36)
        #expect(Set(ProfileStyleLogic.emojis).count == 36)
        for emoji in ProfileStyleLogic.emojis {
            #expect(ProfileStyleLogic.sanitizedEmoji(emoji) == emoji, "\(emoji) no pasa por emoji")
        }
    }

    /// El nombre de la tarjeta se lee con cualquier fondo y cualquier color de avatar: el contraste lo corrige
    /// `CardLookLogic`, también con el tema claro y el oscuro.
    @Test func elNombre_seLeeConCualquierFondoYColor() {
        let colores: [String?] = [nil] + ProfileStyleLogic.avatarColors
        for accent in ["#6366F1", "#818CF8", "#00C2CB", "#FF4DA6", "#FFFFFF", "#000000"] {
            for template in CardTemplateCatalog.all {
                for color in colores {
                    let style = ProfileStyle(avatarColorHex: color, cardTemplateID: template.id)
                    let look = ProfileStyleLogic.cardLook(style: style, themeAccentHex: accent)
                    for stop in look.stops {
                        let score = CardLookLogic.worstScore(
                            stop: stop, foreground: look.foreground, finish: look.finish, pattern: look.pattern)
                        #expect(score >= 1, "\(template.id) · \(color ?? "tema") · \(accent)")
                    }
                    #expect(!look.showsChip)
                    #expect(look.lastFour == nil)
                }
            }
        }
    }

    @Test func elGlifoDelAvatar_seLeeSobreSuColor() throws {
        for hex in ProfileStyleLogic.avatarColors {
            let fill = try #require(CardRGB(hex: hex))
            let glyph = ProfileStyleLogic.foreground(onFill: hex)
            #expect(fill.contrast(with: glyph) >= 3, "\(hex)")
        }
    }

    @Test func tuColor_seTiñeConElAvatar_oConElTema() {
        let conTema = ProfileStyleLogic.cardLook(style: .standard, themeAccentHex: "#00C2CB")
        let conAvatar = ProfileStyleLogic.cardLook(style: ProfileStyle(avatarColorHex: "#00C2CB"),
                                                   themeAccentHex: "#6366F1")
        #expect(conTema.stops == conAvatar.stops)
        let otra = ProfileStyleLogic.cardLook(style: .standard, themeAccentHex: "#6366F1")
        #expect(otra.stops != conTema.stops)
    }
}

// MARK: - La preferencia

@MainActor
@Suite("Perfil · la preferencia sincronizada")
struct ProfileStylePreferenceTests {

    @Test func viajaPorElCanalDeSiempre_yVolverAlDeSiempreTambien() {
        #expect(PrefSyncKey.userProfileStyle.rawValue == AppPreferences.Keys.userProfileStyle)
        #expect(PrefSyncKey.userProfileStyle.family == .panelPresenceEmptyValid)
        #expect(PrefSyncKey.userProfileStyle.kind == .string)
    }

    @Test func seGuarda_yVuelveAlReabrir() throws {
        let defaults = try #require(testDefaults(suiteName: "ProfileStylePreferenceTests.\(UUID().uuidString)"))
        let prefs = AppPreferences(defaults: defaults)
        let stored = ProfileStyleLogic.encode(ProfileStyle(kind: .emoji, emoji: "🦊"))
        prefs.userProfileStyle = stored
        #expect(AppPreferences(defaults: defaults).userProfileStyle == stored)
    }

    @Test func elReinicioDeFabrica_loDeja_enElDeSiempre() throws {
        let defaults = try #require(testDefaults(suiteName: "ProfileStylePreferenceTests.\(UUID().uuidString)"))
        let prefs = AppPreferences(defaults: defaults)
        prefs.userProfileStyle = ProfileStyleLogic.encode(ProfileStyle(kind: .initials))
        prefs.resetSyncedMirrorToFactoryDefaults()
        #expect(prefs.userProfileStyle == "")
    }

    /// «Vaciar mis datos» la borra con las demás del perfil (scan: la lista de `DataWipeService` es explícita).
    @Test func vaciarMisDatos_laBorra() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Yala/Utils/DataWipeService.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("defaults.removeObject(forKey: AppPreferences.Keys.userProfileStyle)"))
    }
}

// MARK: - Textos

@MainActor
@Suite("Perfil · los textos en los 16 idiomas")
struct PerfilPersonalizacionStringsTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/PerfilPersonalizacion.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    private static func placeholders(_ text: String) -> [String] {
        let regex = /%(\d+\$)?[@d]/
        return text.matches(of: regex).map { String($0.output.0) }.sorted()
    }

    @Test(arguments: locales)
    func cadaIdioma_tieneCadaClave_conTexto_yLosMismosHuecos(_ locale: String) throws {
        let referencia = try Self.table("es")
        let textos = try Self.table(locale)
        #expect(Set(textos.keys) == Set(referencia.keys), "\(locale): claves distintas de es.")
        for (clave, valor) in textos {
            #expect(!valor.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(clave) vacía.")
            #expect(Self.placeholders(valor) == Self.placeholders(referencia[clave] ?? ""),
                    "\(locale): \(clave) no tiene los mismos huecos que en español.")
        }
    }

    @Test func alias_copianSuReferencia() throws {
        #expect(try Self.table("es-419") == Self.table("es"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test func variantes_hablanASuManera() throws {
        #expect(try Self.table("es-AR")["perfil.initials.needName"]?.hasPrefix("Escribí") == true)
        #expect(try Self.table("pt-PT")["perfil.initials.needName"]?.hasPrefix("Escreve") == true)
        #expect(try Self.table("en-GB")["perfil.section.color"] == "Avatar colour")
    }

    /// Cada clave que lee la app existe en español (una errata en el código devolvería la clave cruda).
    @Test func cadaClaveDelCodigo_existe() throws {
        let es = try Self.table("es")
        let t = L10n.PerfilPersonalizacion.self
        let leidas = [
            t.cardLabel, t.avatarMenu, t.avatarSection, t.kindPicker, t.kindSymbol, t.kindEmoji, t.kindInitials,
            t.kindPhoto, t.symbolNumbered(13), t.initialsDetail, t.initialsNeedName, t.photoChoose, t.photoChange,
            t.photoRemove, t.photoDetail, t.colorSection, t.colorTheme, t.colorNumbered(2), t.colorCustom,
            t.cardSection, t.reset,
        ] + ProfileAvatarKind.allCases.map { t.kind($0) }
        for texto in leidas {
            #expect(!texto.hasPrefix("perfil."), "Clave sin texto: \(texto)")
        }
        #expect(es.count == 21)
    }

    @Test(arguments: locales)
    func laApp_resuelveLaTabla(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let texto = L10n.PerfilPersonalizacion.string("perfil.section.avatar", resolution: resolution)
        #expect(texto == (try Self.table(locale)["perfil.section.avatar"]))
    }
}
