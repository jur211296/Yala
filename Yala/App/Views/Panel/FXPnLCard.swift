//
//  FXPnLCard.swift
//  Yala
//
//  Card del Panel que pone número a algo que el usuario multi-divisa ya nota pero no entiende: su
//  saldo no cuadra con lo que recuerda haber ingresado, y la diferencia es el tipo de cambio.
//
//  Card suelta y condicional (patrón `SetupChecklistCard`): **se monta siempre y decide por dentro
//  si se pinta**, en lugar de colgar de un `if` en el callsite. Dos razones medidas, no estética:
//
//   · Con la condición fuera, cruzar el umbral mientras el usuario lee el detalle destruye la card,
//     su `@State` y su `.sheet` — y la hoja se cierra sola en su cara. Un recálculo de sync basta.
//   · `PanelView.mainContent` es el body pesado que `PanelShell` existe para no re-evaluar. Leer
//     ahí una propiedad `@Observable` que cambia con cada gasto invalidaba el `NavigationStack`
//     entero; leyéndola aquí, la invalidación se queda en esta hoja.
//

import SwiftUI

struct FXPnLCard: View {
    let viewModel: PanelViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// El resumen que está mirando la hoja de detalle. Se captura al abrirla y **no** se refresca
    /// desde el modelo: si el saldo cambia mientras el usuario lee, la hoja sigue mostrando el
    /// desglose coherente que abrió, en vez de mutar bajo sus ojos o desaparecer.
    @State private var sheetSummary: FXPnLLogic.Summary?

    private var summary: FXPnLLogic.Summary? {
        guard let s = viewModel.fxPnLSummary, FXPnLLogic.shouldPresent(s) else { return nil }
        return s
    }

    var body: some View {
        Group {
            if let summary {
                card(summary)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.97).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: summary)
        .sheet(item: $sheetSummary) { snapshot in
            FXPnLDetailSheet(summary: snapshot)
        }
    }

    // MARK: - Card

    private func card(_ summary: FXPnLLogic.Summary) -> some View {
        let isGain = summary.totalPnL >= 0
        return Button {
            sheetSummary = summary
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: isGain ? "arrow.up.right" : "arrow.down.right")
                    .font(DS.Typography.headline)
                    .foregroundStyle(isGain ? Color.incomeAmount : Color.secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        (isGain ? Color.incomeAmount : Color.secondary).opacity(0.12), in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(isGain ? L10n.Panel.FXPnL.titleGain : L10n.Panel.FXPnL.titleLoss)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)

                    AmountText(
                        value: (summary.totalPnL as NSDecimalNumber).doubleValue,
                        currencyCode: summary.preferredCurrencyCode,
                        font: DS.Typography.headline,
                        secondaryFont: DS.Typography.caption,
                        // La ganancia lleva `Color.incomeAmount` (#0F7A80, contraste 5,1) y no el
                        // token de ingreso del tema: sobre tarjeta blanca ninguno de los tonos de
                        // la paleta llega al AA de 4,5, y `AmountText` pinta símbolo y decimales
                        // al 60 % encima. La pérdida usa `.primary`, la jerarquía normal del
                        // texto — **nunca el rojo del DS**: perder por tipo de cambio no es un
                        // error del usuario ni algo que deba alarmarle.
                        tint: isGain ? .color(Color.incomeAmount) : .primary,
                        forceSign: true,
                        isEstimate: summary.isApproximate
                    )

                    if let sentence = Self.dominantSentence(summary) {
                        Text(sentence)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.thSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, DS.Spacing.xs)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .solidCard(padding: DS.Spacing.lg, radius: DS.Radius.lg)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        // Sin `.accessibilityElement(children: .combine)`: un Button ya expone su contenido
        // unificado, y añadir el modificador encima lo sobrescribe con `.contain` y hace que
        // VoiceOver navegue Text por Text (nota del repo en `AccountsSettingsListView`).
        .accessibilityHint(L10n.Panel.FXPnL.openDetail)
        .accessibilityIdentifier("panel_fx_pnl_card")
    }

    // MARK: - Copy

    /// La frase habla de la divisa que **explica el número** (`dominant`, elegida por `|pnl|`).
    ///
    /// Cuatro variantes, y no es adorno: **un saldo negativo es una deuda**, y a quien debe dólares
    /// no se le puede decir «tus dólares valen más» cuando el tipo de cambio sube — para él eso es
    /// exactamente la mala noticia. Por eso el posesivo se cambia por «tu deuda en …» y el verbo
    /// pasa de «valer» a «costar». La dirección la marca el TC (`rateVariation`), no el signo del
    /// P&L: son cosas distintas y en una deuda apuntan al revés.
    static func dominantSentence(_ summary: FXPnLLogic.Summary) -> String? {
        guard let row = summary.dominant else { return nil }
        guard let percent = percentString(abs(row.rateVariation)) else { return nil }

        let name = currencyName(for: row.code)
        let rateRose = row.rateVariation >= 0
        let isDebt = row.nativeBalance < 0

        switch (isDebt, rateRose) {
        case (false, true):
            return L10n.Panel.FXPnL.sentenceHoldingUpFormat(name, percent)
        case (false, false):
            return L10n.Panel.FXPnL.sentenceHoldingDownFormat(name, percent)
        case (true, true):
            return L10n.Panel.FXPnL.sentenceDebtUpFormat(name, percent)
        case (true, false):
            return L10n.Panel.FXPnL.sentenceDebtDownFormat(name, percent)
        }
    }

    /// Nombre en plural de la divisa («dólares», «euros») para que la frase suene a persona.
    ///
    /// Si el código no está en el catálogo se devuelve **el código tal cual**. Nada de `?? .pen`:
    /// caer a una divisa por defecto es cómo se acaba enseñando el nombre equivocado sobre el
    /// dinero de alguien (ver `fx-unknown-currency-code-collapses-to-usd`).
    static func currencyName(for code: String) -> String {
        CurrencyCode(rawValue: code)?.shortPluralName ?? code
    }

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()

    /// Formatea un tanto por uno como porcentaje localizado, desde `Decimal` sin pasar por `Double`.
    static func percentString(_ value: Decimal) -> String? {
        percentFormatter.string(from: value as NSDecimalNumber)
    }
}
