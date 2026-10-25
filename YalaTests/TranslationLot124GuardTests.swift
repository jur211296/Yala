//
//  TranslationLot124GuardTests.swift
//  YalaTests
//
//  Lote 12.4 · Idiomas y traducciones. Fija lo que las cards dejaron arreglado en los catálogos, para que una alta
//  nueva copiada de un texto viejo no lo deshaga:
//  - fr sin las palabras que en francés siempre llevan tilde («Parametres», «Categories», «donnees»…);
//  - pt-BR sin las formas sin acento ni el «Eliminar» de Portugal; pt-PT sin «você» ni vocabulario de Brasil;
//  - es-419 sin peruanismos en las categorías;
//  - los cuatro textos de ayuda que citaban botones y pantallas con otro nombre, contra el nombre real en cada idioma;
//  - «Sin asignar» con tilde, y la búsqueda por nombre que sigue encontrando la del nombre viejo.
//
//  La revisión que produjo los arreglos es `qa/l10n-review/` (Sonnet + comprobaciones deterministas).
//

import Foundation
import Testing
@testable import Yala

struct TranslationLot124GuardTests {

    /// Todos los textos visibles de un idioma: `.strings`, formas de plural del `.stringsdict` y `InfoPlist.strings`.
    private func allTexts(_ code: String) -> [String: String] {
        var out = StringsFileParser.parseStrings(forLocale: code)
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
            return out
        }
        if let url = bundle.url(forResource: "Localizable", withExtension: "stringsdict"),
           let dict = NSDictionary(contentsOf: url) as? [String: Any] {
            for (key, value) in dict {
                guard let entry = value as? [String: Any] else { continue }
                for (variable, spec) in entry {
                    guard let forms = spec as? [String: Any] else { continue }
                    for (form, text) in forms {
                        if let text = text as? String, !form.hasPrefix("NSString") { out["\(key)#\(variable).\(form)"] = text }
                    }
                }
            }
        }
        if let url = bundle.url(forResource: "InfoPlist", withExtension: "strings"),
           let dict = NSDictionary(contentsOf: url) as? [String: String] {
            for (key, text) in dict { out["InfoPlist:\(key)"] = text }
        }
        return out
    }

    private func offenders(_ code: String, _ pattern: String, options: NSRegularExpression.Options = [.caseInsensitive],
                           keys: (String) -> Bool = { _ in true }) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        return allTexts(code).filter { key, text in
            keys(key) && regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }.map { "\($0.key): \($0.value)" }.sorted()
    }

    // MARK: - fr

    @Test func french_hasNoWordsMissingTheirAccent() throws {
        let words = #"\b(categories?|sous-categories?|parametres?|donnees?|depenses?|selectionn\w*|periodes?|deja|apres"#
            + #"|annees?|derniere|premiere|evenements?|reessay\w*|ecrans?|reglages?|systeme|interets?|desactiv\w*"#
            + #"|frequen\w*|etiquettes?|bientot|deconnexion|precedente?s?|reseau|methode|repartition|ecriture|creons"#
            + #"|echoue\w*|echec|telecharg\w*|numero|telephone|economies|epargne|recurrente?s?|generer|elements?"#
            + #"|Edition)\b"#
        let found = try offenders("fr", words)
        #expect(found.isEmpty, "fr sin tilde: \(found.prefix(8))")
    }

    // MARK: - pt-BR y pt-PT

    @Test func brazilianPortuguese_hasNoUnaccentedForms() throws {
        let found = try offenders("pt-BR", #"\b(nao|acao|acoes|transacoes|transacao|possivel|atribuido|voce|serao|historicos?|orcamentos?|estatisticas|informacoes|configuracoes|notificacoes|opcoes|opcao|descricao)\b"#)
        #expect(found.isEmpty, "pt-BR sin acento: \(found.prefix(8))")
    }

    @Test func brazilianPortuguese_categoryTextsSayExcluir() throws {
        let found = try offenders("pt-BR", #"\bEliminar\b|\beliminad"#, options: [],
                                  keys: { $0.hasPrefix("category.") || $0.hasPrefix("subcategory.") })
        #expect(found.isEmpty, "pt-BR con «Eliminar» de Portugal: \(found)")
    }

    @Test func europeanPortuguese_hasNoBrazilianForms() throws {
        // Fuera, las claves que la app empareja por texto con lo guardado (`qa/l10n-review/claves-protegidas.txt`): el
        // texto por defecto de un aviso y los nombres de sistema de Grupos. Cambiarlas pide migrar el nombre guardado.
        let protectedKey: (String) -> Bool = {
            $0 == "notifications.lunchTime.text" || $0.hasPrefix("subcategory.system.") || $0.hasPrefix("category.system.")
        }
        let found = try offenders("pt-PT", #"\b[Vv]ocê\b|\bConfigurações\b|\bcelular\b|\busuári\w*|\bcompartilh\w*"#,
                                  options: [], keys: { !protectedKey($0) })
        #expect(found.isEmpty, "pt-PT con formas de Brasil: \(found.prefix(8))")
        let strings = StringsFileParser.parseStrings(forLocale: "pt-PT")
        #expect(strings["tab.records"] == "Registos")
    }

    @Test func europeanPortuguese_inboxIsTranslated() {
        let pt = StringsFileParser.parseStrings(forLocale: "pt-PT")
        let en = StringsFileParser.parseStrings(forLocale: "en")
        let brand: Set<String> = ["inbox.sourceManual", "inbox.sourceApplePay", "inbox.sourceSiri"]
        let english = pt.filter { $0.key.hasPrefix("inbox.") && !brand.contains($0.key) && $0.value == en[$0.key] }
        #expect(english.isEmpty, "pt-PT en inglés: \(english.keys.sorted())")
    }

    // MARK: - es-419

    @Test func neutralSpanish_categoryNamesHaveNoPeruvianWords() throws {
        for code in ["es-419", "es", "es-ES", "es-AR"] {
            let found = try offenders(code, #"\bbodegas?\b"#)
            #expect(found.isEmpty, "\(code): \(found)")
        }
        #expect(StringsFileParser.parseStrings(forLocale: "es-419")["subcategory.supermarkets"] == "Supermercados y tiendas")
    }

    @Test func netLabel_isNotTheAppName() {
        for locale in SupportedLocale.allCases {
            #expect(StringsFileParser.parseStrings(forLocale: locale.code)["cashFlow.net"] != "Yala", "\(locale.code)")
        }
    }

    // MARK: - Los textos de ayuda citan los nombres reales

    @Test func helpTexts_nameTheRealButtonsAndScreens() {
        for locale in SupportedLocale.allCases {
            let s = StringsFileParser.parseStrings(forLocale: locale.code)
            let code = locale.code
            if let howA = s["panel.widgetInfo.periodComparison.howA"], let p1 = s["comparison.monthShort"],
               let y1 = s["comparison.yearShort"] {
                #expect(howA.contains(p1) && howA.contains(y1), "\(code): «\(howA)» no cita \(p1)/\(y1)")
            }
            if let step = s["tutorials.editPanel.step2.desc"], let reset = s["widget.resetLayout"] {
                #expect(step.contains(reset), "\(code): «\(step)» no cita «\(reset)»")
            }
            if let hint = s["groups.accountIsComplete.settingsHint"], let screen = s["storage.title"] {
                #expect(hint.contains(screen), "\(code): «\(hint)» no cita «\(screen)»")
            }
            if let budgets = s["tutorials.createBudgets.step1.desc"], let weekly = s["budgets.period.weekly"] {
                #expect(budgets.localizedCaseInsensitiveContains(weekly), "\(code): «\(budgets)» no cita «\(weekly)»")
            }
        }
    }

    // MARK: - «Sin asignar»

    @Test func unassigned_keepsFindingTheOldName() {
        #expect(SubcategoryTransferViewModel.isUnassignedName("Não atribuído", current: "Não atribuído"))
        #expect(SubcategoryTransferViewModel.isUnassignedName("Nao atribuido", current: "Não atribuído"))
        #expect(SubcategoryTransferViewModel.isUnassignedName("Non attribue", current: "Non attribué"))
        #expect(!SubcategoryTransferViewModel.isUnassignedName("Mercado", current: "Não atribuído"))
        for code in ["pt-BR", "pt-PT", "pt"] {
            #expect(StringsFileParser.parseStrings(forLocale: code)["subcategory.unassigned"] == "Não atribuído")
        }
        #expect(StringsFileParser.parseStrings(forLocale: "fr")["subcategory.unassigned"] == "Non attribué")
    }
}
