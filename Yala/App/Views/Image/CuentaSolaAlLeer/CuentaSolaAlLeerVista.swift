//
//  CuentaSolaAlLeerVista.swift
//  Yala
//
//  Lo que se ve de la cuenta elegida sola al leer una foto (parte 1, 2026-11-20): el chip con «✦» o «sugerida», la línea
//  de «por qué» y lo que el selector de cuenta pone arriba («Coinciden con «Visa»», o las dos de un choque con su
//  motivo). La hoja de la foto guarda la elección de cada borrador en memoria y la pasa por el entorno: la tarjeta de un
//  borrador (`VoiceDraftReviewCard`), la fila de la hoja de varios (`MultiDraftReviewList`) y el selector
//  (`AccountSelectorSheet`) la leen, y sin ella pintan lo de siempre.
//

import SwiftUI

/// Las elecciones de la hoja de la foto, por borrador (identidad del objeto: el mismo `InboxDraft` antes y después de
/// insertarlo, y vivo mientras la hoja lo enseña).
struct CuentaSolaAlLeerHoja: Equatable {
    var elecciones: [ObjectIdentifier: CuentaSolaAlLeer.Eleccion] = [:]
    /// Los borradores que enseñan la línea de «por qué» (las tres primeras veces por persona).
    var conPorque: Set<ObjectIdentifier> = []

    func eleccion(for draft: InboxDraft) -> CuentaSolaAlLeer.Eleccion? { elecciones[ObjectIdentifier(draft)] }
    func muestraPorque(_ draft: InboxDraft) -> Bool { conPorque.contains(ObjectIdentifier(draft)) }
}

/// Lo que el selector de cuenta pone arriba: un título y las cuentas, cada una con su motivo si lo tiene.
struct CuentaSolaAlLeerSelectorPista: Equatable {
    struct Fila: Equatable {
        let accountID: UUID
        let motivo: String?
    }

    let titulo: String
    let filas: [Fila]

    /// La pista de un resultado que deja la cuenta por elegir, o `nil` si no hay nada que poner arriba.
    @MainActor static func pista(for eleccion: CuentaSolaAlLeer.Eleccion?) -> CuentaSolaAlLeerSelectorPista? {
        guard let eleccion else { return nil }
        switch eleccion.resultado {
        case .varias(let ids):
            let titulo = CuentaSolaAlLeer.palabraCitada(eleccion.mention).map(L10n.CuentaSolaAlLeer.Selector.matches)
                ?? L10n.CuentaSolaAlLeer.Selector.matchesNoWords
            return CuentaSolaAlLeerSelectorPista(titulo: titulo, filas: ids.map { Fila(accountID: $0, motivo: nil) })
        case .choque(let telefono, let ia):
            return CuentaSolaAlLeerSelectorPista(
                titulo: L10n.CuentaSolaAlLeer.Selector.conflict,
                filas: [
                    Fila(accountID: telefono, motivo: L10n.CuentaSolaAlLeer.Selector.reasonImage),
                    Fila(accountID: ia, motivo: L10n.CuentaSolaAlLeer.Selector.reasonAI),
                ])
        case .sola, .sugerida, .ninguna:
            return nil
        }
    }
}

extension EnvironmentValues {
    /// Lo pone la hoja de la foto sobre su lista de borradores.
    @Entry var cuentaSolaAlLeerHoja: CuentaSolaAlLeerHoja = CuentaSolaAlLeerHoja()
    /// Lo pone el chip de cuenta de un borrador sobre el selector que abre.
    @Entry var cuentaSolaAlLeerSelector: CuentaSolaAlLeerSelectorPista? = nil
}

/// Cómo se pinta el chip de cuenta de un borrador leído.
struct CuentaSolaAlLeerChipPresentacion: Equatable {
    enum Estilo: Equatable {
        case normal
        case sugerida
        case falta
    }

    let titulo: String
    let estilo: Estilo
    let accessibilityLabel: String?
    /// La línea de «por qué», si toca enseñarla.
    let porque: String?

    /// `accountName` es el de la cuenta puesta en el borrador, o `nil` sin cuenta. `selectAccount` es el texto de siempre.
    static func make(
        eleccion: CuentaSolaAlLeer.Eleccion?, currentAccountID: UUID?, accountName: String?, muestraPorque: Bool,
        selectAccount: String
    ) -> CuentaSolaAlLeerChipPresentacion {
        let chip = CuentaSolaAlLeer.chip(for: eleccion?.resultado, currentAccountID: currentAccountID)
        switch (chip, accountName) {
        case (.elegida(let motivo), let name?):
            let digits = eleccion?.last4
            if motivo == .last4, let digits {
                return CuentaSolaAlLeerChipPresentacion(
                    titulo: L10n.CuentaSolaAlLeer.Chip.chosen(name), estilo: .normal,
                    accessibilityLabel: L10n.CuentaSolaAlLeer.Accessibility.chosenLast4(name, digits),
                    porque: muestraPorque ? L10n.CuentaSolaAlLeer.Why.last4(name, digits) : nil)
            }
            return CuentaSolaAlLeerChipPresentacion(
                titulo: L10n.CuentaSolaAlLeer.Chip.chosen(name), estilo: .normal,
                accessibilityLabel: L10n.CuentaSolaAlLeer.Accessibility.chosen(name),
                porque: muestraPorque ? L10n.CuentaSolaAlLeer.Why.image(name) : nil)
        case (.sugerida, let name?):
            // La sugerida dice siempre por qué: la eligió la IA y la persona tiene que mirarla.
            return CuentaSolaAlLeerChipPresentacion(
                titulo: L10n.CuentaSolaAlLeer.Chip.suggested(name), estilo: .sugerida,
                accessibilityLabel: L10n.CuentaSolaAlLeer.Accessibility.suggested(name),
                porque: L10n.CuentaSolaAlLeer.Why.suggested(name))
        case (.elige(let count), nil):
            return CuentaSolaAlLeerChipPresentacion(
                titulo: L10n.CuentaSolaAlLeer.Chip.chooseMatching(count), estilo: .falta,
                accessibilityLabel: L10n.CuentaSolaAlLeer.Accessibility.chooseMatching(count), porque: nil)
        default:
            return CuentaSolaAlLeerChipPresentacion(
                titulo: accountName ?? selectAccount, estilo: accountName == nil ? .falta : .normal,
                accessibilityLabel: nil, porque: nil)
        }
    }
}

/// La línea de «por qué» bajo los chips de un borrador.
struct CuentaSolaAlLeerPorqueLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("cuenta_sola_porque")
    }
}

/// El fondo del chip «sugerida»: el acento del tema, suave, para que no se lea como elegida sola ni como falta.
struct CuentaSolaAlLeerSugeridaFondo: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Capsule().fill(theme.accent.opacity(0.16))
            .overlay(Capsule().strokeBorder(theme.accentText.opacity(0.55), lineWidth: 1))
    }
}
