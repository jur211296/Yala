//
//  GroupsInformalRegisterTests.swift
//  YalaTests
//
//  Card «Francés y alemán: Nuevo gasto de Grupos mezcla tú y usted» (2026-11-02): en fr y de, casi todas las cadenas
//  `groups.*` tuteaban, pero unas cuantas hablaban de usted («Vous avez payé», «%1$@ vous doit %2$@», «Sie haben
//  bezahlt»). Esta suite fija un solo tratamiento, TÚ, en todas las cadenas `groups.*` de los dos idiomas, tanto en
//  `Localizable.strings` como en las variantes de plural de `Localizable.stringsdict`.
//
//  Lee los ficheros del árbol del repo (molde: `GroupPushNoticeTests`), no los del bundle, para que el test mire lo
//  mismo que se edita.
//

import Foundation
import Testing

@Suite("Grupos · fr y de tutean")
struct GroupsInformalRegisterTests {

    // MARK: - Excepciones explícitas

    /// Claves alemanas donde «Sie» abre frase y significa «ella/ellos» (la Ausgabe, la Gruppe, los cambios, las
    /// personas invitadas), no «usted». En alemán el «Sie» de tercera persona y el de cortesía se escriben igual al
    /// inicio de frase, así que solo el contexto los distingue. Una cadena nueva que abra frase con «Sie» tiene que
    /// entrar aquí a propósito, o el test falla. Así no vuelve a colarse un «Sie haben bezahlt».
    static let germanThirdPersonSie: Set<String> = [
        "groups.consent.point1",                            // «Sie leben in der Yala-Cloud»: los grupos
        "groups.d14.onTheWay.message",                      // «Sie erscheint hier»: la Gruppe
        "groups.errors.captureUnfinished",                  // «Sie bleiben auf diesem Gerät»: los cambios
        "groups.errors.groupsChangesFromAnotherAccount",    // ídem
        "groups.errors.noSessionSignOutLoss",               // «Sie lassen sich nur … hochladen»: los cambios
        "groups.errors.noSessionSignOutLossUnknown",        // ídem
        "groups.errors.uploadRetryLater",                   // «Sie bleiben auf diesem Gerät»: los cambios
        "groups.expense.deleteMessage",                     // «Sie wird … gelöscht»: la Ausgabe
        "groups.expense.splitSheet.equalHint",              // «Sie wird zu gleichen Teilen aufgeteilt»: la Ausgabe
        "groups.freshStartPending.lossConfirmBody",         // «Sie werden … gelöscht»: los cambios
        "groups.freshStartPending.lossConfirmBodyNeutral",  // ídem
        "groups.freshStartPending.lossConfirmBodySplit",    // ídem
        "groups.freshStartPending.lossOtherAccount",        // «Sie lassen sich nur hochladen»: los cambios
        "groups.freshStartPending.lossSessionExpired",      // ídem
        "groups.l12.created.message",                       // «Sie bekommen einen Link»: las personas invitadas
        "groups.l19.archive.body",                          // «Sie wandert … zu Archiviert»: la Gruppe
        "groups.l19.delete.body",                           // «Sie verschwindet für alle»: la Gruppe
        "groups.l19.delete.rowBody",                        // ídem
        "groups.l19.unarchive.body",                        // «Sie kommt … zurück»: la Gruppe
    ]

    /// Claves alemanas donde «Ihr» abre frase y es el «vosotros» informal, no el posesivo de cortesía. El presupuesto
    /// es de todo el grupo (en es: «Ya se pasarían por %@»), así que el plural es real y ya es tuteo.
    static let germanInformalPluralIhr: Set<String> = [
        "groups.l19.budget.wouldExceed",                    // «Ihr wärt schon %@ drüber»
    ]

    // MARK: - Tests

    @Test func bothLocalesAreReadInFull() throws {
        for locale in ["fr", "de"] {
            let texts = try Self.groupsTexts(locale)
            #expect(texts.stringsKeyCount > 50, "\(locale): solo \(texts.stringsKeyCount) claves groups.* en .strings")
            #expect(texts.pluralKeyCount >= 5, "\(locale): solo \(texts.pluralKeyCount) claves groups.* en .stringsdict")
        }
    }

    @Test func frenchGroupsStringsUseTu() throws {
        let texts = try Self.groupsTexts("fr")
        let formal = try Regex(#"\b(vous|votre|vos)\b"#).ignoresCase().wordBoundaryKind(.simple)
        let offenders = texts.entries.filter { $0.text.contains(formal) }.map { "\($0.key): \($0.text)" }
        #expect(offenders.isEmpty, "fr habla de usted en:\n\(offenders.joined(separator: "\n"))")
    }

    @Test func germanGroupsStringsUseDu() throws {
        let texts = try Self.groupsTexts("de")
        let formalWords = try Regex(#"\b(Ihnen|Ihr|Ihre|Ihren|Ihrem|Ihrer|Ihres|Euch|Euer)\b"#).wordBoundaryKind(.simple)
        let sie = try Regex(#"\bSie\b"#).wordBoundaryKind(.simple)
        var offenders: [String] = []
        for entry in texts.entries {
            if !Self.germanInformalPluralIhr.contains(entry.key), entry.text.contains(formalWords) {
                offenders.append("\(entry.key) [Ihr/Ihnen]: \(entry.text)")
            }
            for match in entry.text.matches(of: sie) {
                if !Self.isSentenceStart(entry.text, before: match.range.lowerBound) {
                    offenders.append("\(entry.key) [«Sie» a mitad de frase]: \(entry.text)")
                } else if !Self.germanThirdPersonSie.contains(entry.key) {
                    offenders.append("\(entry.key) [«Sie» abre frase y no está en las excepciones]: \(entry.text)")
                }
            }
        }
        #expect(offenders.isEmpty, "de habla de usted en:\n\(offenders.joined(separator: "\n"))")
    }

    /// Una excepción que ya no hace falta se retira, o la lista acaba tapando lo que no debe.
    @Test func germanExceptionsAreStillNeeded() throws {
        let texts = try Self.groupsTexts("de")
        let byKey = Dictionary(texts.entries.map { ($0.key, $0.text) }, uniquingKeysWith: { first, _ in first })
        for key in Self.germanThirdPersonSie {
            let text = try #require(byKey[key], "la excepción \(key) ya no existe en de")
            #expect(text.contains("Sie"), "la excepción \(key) ya no lleva «Sie»: \(text)")
        }
        for key in Self.germanInformalPluralIhr {
            let text = try #require(byKey[key], "la excepción \(key) ya no existe en de")
            #expect(text.contains("Ihr"), "la excepción \(key) ya no lleva «Ihr»: \(text)")
        }
    }

    // MARK: - Lectura del árbol

    struct GroupsTexts {
        var entries: [(key: String, text: String)] = []
        var stringsKeyCount = 0
        var pluralKeyCount = 0
    }

    static func groupsTexts(_ locale: String) throws -> GroupsTexts {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let dir = root.appendingPathComponent("Yala/Resources/\(locale).lproj")
        var result = GroupsTexts()

        let stringsURL = dir.appendingPathComponent("Localizable.strings")
        let strings = try #require(NSDictionary(contentsOf: stringsURL) as? [String: String], "\(locale): .strings ilegible")
        for (key, value) in strings where key.hasPrefix("groups.") {
            result.entries.append((key, value))
            result.stringsKeyCount += 1
        }

        let pluralsData = try Data(contentsOf: dir.appendingPathComponent("Localizable.stringsdict"))
        let plist = try PropertyListSerialization.propertyList(from: pluralsData, options: [], format: nil)
        let plurals = try #require(plist as? [String: Any], "\(locale): .stringsdict no es un diccionario")
        for (key, value) in plurals where key.hasPrefix("groups.") {
            for text in variantTexts(value) { result.entries.append((key, text)) }
            result.pluralKeyCount += 1
        }
        return result
    }

    /// Los textos de las variantes (`one`, `other`…) de una entrada de stringsdict. Las claves `NSString…` son
    /// metadatos del formato (`%#@count@`, `NSStringPluralRuleType`, `d`), no texto que lea nadie.
    static func variantTexts(_ value: Any) -> [String] {
        if let text = value as? String { return [text] }
        guard let dict = value as? [String: Any] else { return [] }
        return dict.filter { !$0.key.hasPrefix("NSString") }.flatMap { variantTexts($0.value) }
    }

    /// Inicio de frase: el principio del texto o tras `.`, `!`, `?` o `:` (en alemán, tras dos puntos que abren una
    /// frase completa va mayúscula: «Es geht nichts verloren: Sie bleiben hier»).
    static func isSentenceStart(_ text: String, before index: String.Index) -> Bool {
        let preceding = text[..<index].trimmingCharacters(in: .whitespaces)
        guard let last = preceding.last else { return true }
        return ".!?:".contains(last)
    }
}
