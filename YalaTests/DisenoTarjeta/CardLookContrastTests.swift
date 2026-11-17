//
//  CardLookContrastTests.swift
//  YalaTests
//
//  Tarjetas de cuenta personalizables (2026-11-16): el saldo se lee siempre. Para cada plantilla, cada patrón y una
//  barrida de colores propios, el texto de la tarjeta (principal, secundario y los decimales del importe) llega al mínimo
//  de contraste de WCAG sobre todo el fondo, con el patrón y el brillo encima. Y el catálogo tiene lo prometido.
//

import Foundation
import Testing
import UIKit

@testable import Yala

@MainActor
@Suite("Diseño de tarjeta · contraste y catálogo")
struct CardLookContrastTests {

    /// El peor contraste del texto sobre el fondo de una tarjeta, normalizado (≥ 1 = pasa los tres mínimos).
    private func worst(_ look: CardLook) -> Double {
        look.stops.map {
            CardLookLogic.worstScore(stop: $0, foreground: look.foreground, finish: look.finish, pattern: look.pattern)
        }.min() ?? 0
    }

    // MARK: - Contraste

    @Test("Todas las plantillas, con todos los patrones y en todos los tipos de cuenta, se leen")
    func everyTemplateIsReadable() {
        for template in CardTemplateCatalog.all {
            for pattern in [nil] + CardPattern.allCases.map(Optional.some) {
                for type in AccountType.allCases {
                    let design = CardDesign(templateID: template.id, pattern: pattern, showsChip: true)
                    let look = CardLookLogic.look(for: design, type: type, accountColorHex: "#6366F1",
                                                  accountIconName: "creditcard")
                    #expect(worst(look) >= 1, "«\(template.id)» con \(String(describing: pattern)) no se lee.")
                }
            }
        }
    }

    @Test("Con cualquier color propio, en cualquier plantilla, el texto llega al mínimo")
    func anyCustomColorIsReadable() {
        let steps = stride(from: 0, through: 255, by: 51).map { $0 }
        for red in steps {
            for green in steps {
                for blue in steps {
                    let hex = String(format: "#%02X%02X%02X", red, green, blue)
                    for template in CardTemplateCatalog.all {
                        let design = CardDesign(templateID: template.id, colorHex: hex, showsChip: false)
                        let look = CardLookLogic.look(for: design, type: .checking, accountColorHex: hex,
                                                      accountIconName: "creditcard")
                        #expect(worst(look) >= 1, "«\(template.id)» con \(hex) no se lee.")
                    }
                }
            }
        }
    }

    @Test("Los colores de las cuentas de siempre, como «Tu color», se leen (la tarjeta por defecto)")
    func defaultCardsOfTheFormColorsAreReadable() {
        let formColors = ["#FF0080", "#D62246", "#FF7F11", "#4CB963", "#6366F1", "#1B065E", "#0F172A"]
        for hex in formColors {
            for type in AccountType.allCases {
                let look = CardLookLogic.look(for: CardDesignLogic.defaultDesign(type: type), type: type,
                                              accountColorHex: hex, accountIconName: "creditcard")
                #expect(worst(look) >= 1, "La tarjeta por defecto de una cuenta \(hex) no se lee.")
            }
        }
    }

    @Test("El contraste se mide con WCAG: blanco sobre negro es 21, y un mismo color 1")
    func wcagContrastIsRight() {
        #expect(abs(CardRGB.white.contrast(with: .black) - 21) < 0.01)
        #expect(abs(CardRGB.white.contrast(with: .white) - 1) < 0.0001)
        // #767676 sobre blanco es el gris de 4,54:1 de las guías.
        let gray = CardRGB(hex: "#767676")!
        #expect(abs(gray.contrast(with: .white) - 4.54) < 0.02)
    }

    @Test("Un fondo que no llega se corrige: el control sin corregir no pasa")
    func readabilityAdjustsWhatFails() {
        // Un rosa medio con texto blanco no llega a 4,5 sin oscurecerse (control del ajuste).
        let pink = CardRGB(hex: "#FF4DA6")!
        #expect(CardLookLogic.worstScore(stop: pink, foreground: .white, finish: .glow, pattern: .grid) < 1)
        let fixed = CardLookLogic.readableStops([pink, pink.lightened(0.2)], finish: .glow, pattern: .grid)
        for stop in fixed.stops {
            #expect(CardLookLogic.worstScore(stop: stop, foreground: fixed.foreground, finish: .glow, pattern: .grid) >= 1)
        }
    }

    @Test("La tarjeta «Grupos» va en grafito neutro, sin chip ni dígitos, y se lee")
    func systemCardIsNeutral() {
        let look = CardLookLogic.systemLook(iconName: "person.2")
        #expect(!look.showsChip && look.lastFour == nil && look.pattern == .none)
        #expect(worst(look) >= 1)
    }

    // MARK: - Catálogo

    @Test("Al menos 20 plantillas, con ids únicos, «Tu color» primero y todos los grupos con alguna")
    func catalogHasWhatWasPromised() {
        let all = CardTemplateCatalog.all
        #expect(all.count >= 20)
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(all.first?.id == CardTemplateCatalog.accountColorID)
        #expect(all.first?.usesAccountColor == true)
        for category in CardTemplateCategory.allCases {
            #expect(!CardTemplateCatalog.templates(in: category).isEmpty, "El grupo \(category) está vacío.")
        }
        for template in all {
            #expect(template.stops.count >= 2, "«\(template.id)» tiene un color mal escrito.")
        }
        // Lo que pidió Jürgen: cuadrícula, ondas, líneas, puntos y topográfico entre los patrones de las plantillas.
        let patterns = Set(all.map(\.pattern))
        for wanted in [CardPattern.grid, .waves, .lines, .dots, .topographic] {
            #expect(patterns.contains(wanted))
        }
    }

    @Test("Cada ícono del editor existe en SF Symbols")
    func everyIconExists() {
        for symbol in CardTemplateCatalog.icons {
            #expect(UIImage(systemName: symbol) != nil, "«\(symbol)» no es un símbolo.")
        }
        #expect(CardTemplateCatalog.swatches.allSatisfy { CardRGB(hex: $0) != nil })
    }

    @Test("Cada plantilla, patrón y grupo tiene su nombre traducido")
    func everyNameIsLocalized() {
        for template in CardTemplateCatalog.all {
            #expect(L10n.DisenoTarjeta.template(template.id) != "cardDesign.template.\(template.id)")
        }
        for pattern in CardPattern.allCases {
            #expect(L10n.DisenoTarjeta.pattern(pattern) != "cardDesign.pattern.\(pattern.rawValue)")
        }
        for category in CardTemplateCategory.allCases {
            #expect(L10n.DisenoTarjeta.category(category) != "cardDesign.category.\(category.rawValue)")
        }
    }
}

// MARK: - Últimos 4 dígitos

@MainActor
@Suite("Diseño de tarjeta · solo 4 dígitos")
struct CardLastFourTests {

    @Test("Solo se guardan exactamente 4 números")
    func onlyFourDigits() {
        #expect(CardDesignLogic.sanitizedLastFour("1256") == "1256")
        #expect(CardDesignLogic.sanitizedLastFour(" 1256 ") == "1256")
        #expect(CardDesignLogic.sanitizedLastFour("125") == nil)
        #expect(CardDesignLogic.sanitizedLastFour("12567") == nil)
        #expect(CardDesignLogic.sanitizedLastFour("4111111111111111") == nil, "El número completo no se guarda.")
        #expect(CardDesignLogic.sanitizedLastFour("12a6") == nil)
        #expect(CardDesignLogic.sanitizedLastFour("١٢٣٤") == nil, "Solo números ASCII.")
        #expect(CardDesignLogic.sanitizedLastFour("") == nil)
        #expect(CardDesignLogic.sanitizedLastFour(nil) == nil)
    }

    @Test("Mientras se escribe, el campo deja solo números y como mucho 4")
    func typingFilter() {
        #expect(CardDesignLogic.typedLastFour("12") == "12")
        #expect(CardDesignLogic.typedLastFour("12-56") == "1256")
        #expect(CardDesignLogic.typedLastFour("4111 1111 1111 1111") == "4111")
        #expect(CardDesignLogic.typedLastFour("abc") == "")
    }

    @Test("Guardar con dígitos a medias no guarda dígitos")
    func partialDigitsAreNotStored() {
        let id = UUID()
        let design = CardDesign(templateID: "gold", showsChip: true, lastFour: "12")
        let stored = CardDesignLogic.setting(design, for: id, type: .creditCard, in: "")
        #expect(CardDesignLogic.design(for: id, type: .creditCard, in: stored).lastFour == nil)
        #expect(!stored.contains("\"d\""))
    }

    @Test("El borrador del editor solo pinta los dígitos cuando son 4")
    func draftResolvesDigits() {
        let draft = CardDesignDraft(design: CardDesignLogic.defaultDesign(type: .creditCard), accountType: .creditCard)
        draft.lastFourText = "125"
        #expect(draft.resolvedDesign.lastFour == nil)
        draft.lastFourText = "1256"
        #expect(draft.resolvedDesign.lastFour == "1256")
        draft.resetToDefault()
        #expect(draft.lastFourText == "" && draft.resolvedDesign == CardDesignLogic.defaultDesign(type: .creditCard))
    }

    @Test("Elegir una plantilla no arrastra el color ni el patrón de la anterior, y sí el ícono, el chip y los dígitos")
    func choosingATemplateResetsItsColors() throws {
        let draft = CardDesignDraft(
            design: CardDesign(templateID: "gold", colorHex: "#0EA5E9", pattern: .dots, iconName: "airplane",
                               showsChip: true, lastFour: "1256"),
            accountType: .creditCard)
        let forest = try #require(CardTemplateCatalog.all.first { $0.id == "forest" })
        draft.choose(template: forest)
        #expect(draft.design.templateID == "forest" && draft.design.colorHex == nil && draft.design.pattern == nil)
        #expect(draft.design.iconName == "airplane" && draft.design.showsChip && draft.resolvedDesign.lastFour == "1256")
    }

    @Test("VoiceOver lee «terminada en 1256» y nada del adorno; con «Ocultar montos», ni los dígitos")
    func spokenSummary() {
        let base = "Viajes. Saldo: 850,00 €"
        let spoken = CardFaceText.spokenSummary(base, lastFour: "1256", hidden: false)
        #expect(spoken.hasPrefix(base))
        #expect(spoken.contains(L10n.DisenoTarjeta.endingIn("1256")))
        #expect(spoken.contains("1256"))
        #expect(CardFaceText.spokenSummary(base, lastFour: "1256", hidden: true) == base)
        #expect(CardFaceText.spokenSummary(base, lastFour: nil, hidden: false) == base)
        for word in ["Aurora", "chip", "Cuadrícula", "patrón"] {
            #expect(!spoken.contains(word))
        }
        #expect(CardFaceText.maskedDigits("1256", hidden: false) == "•••• 1256")
        #expect(!CardFaceText.maskedDigits("1256", hidden: true).contains("1256"))
    }

    @Test("La tarjeta lee el diseño y VoiceOver con los dígitos (cableado)")
    func cardWiring() throws {
        let source = try String(contentsOf: CardDesignStoreTests.repoFile("Yala/App/Views/Panel/AccountCardView.swift"),
                                encoding: .utf8)
        #expect(source.contains("CardFaceText.spokenSummary(amountsAccessibilitySummary"))
        #expect(source.contains("appPreferences.accountCardDesigns"))
        #expect(source.contains("CardBackgroundView(look: look)"))
    }
}
