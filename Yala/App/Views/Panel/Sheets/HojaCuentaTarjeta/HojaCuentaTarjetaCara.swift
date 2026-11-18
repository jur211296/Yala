//
//  HojaCuentaTarjetaCara.swift
//  Yala
//
//  La tarjeta de la cuenta tal como la personalizó la persona, grande y arriba en su hoja (pedido de Jürgen del
//  17-nov-2026, variante A «Wallet»). Es la cara de la tarjeta del carrusel SIN el saldo, que la hoja pinta debajo en
//  grande: ícono y nombre, chip, tipo · divisas y «•••• 1234». Se compone con las piezas de siempre
//  (`AccountCardView.look(for:)`, `CardBackgroundView`, `CardIconBadge`, `CardChipView`, `CardFaceText`), sin tocarlas.
//
//  Entra subiendo y creciendo un poco con un resorte suave al abrirse la hoja; con Reducir movimiento, sin animación.
//  Para VoiceOver es una sola pieza: nombre, tipo y «terminada en…».
//

import SwiftUI

struct HojaCuentaTarjetaCara: View {
    let account: Account
    /// «Tarjeta de crédito · PEN · USD».
    let subtitulo: String

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.amountsHidden) private var amountsHidden
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var entrada: HojaCuentaTarjetaLogica.Entrada?
    /// El ancho que le tocó a la tarjeta: de él sale su alto mínimo, en proporción de tarjeta bancaria.
    @State private var ancho: CGFloat = 0

    var body: some View {
        let look = AccountCardView.look(for: account, storedDesigns: appPreferences.accountCardDesigns)
        let principal = Color(card: look.foreground)
        let secundario = principal.opacity(CardLook.secondaryOpacity)
        let estado = entrada ?? HojaCuentaTarjetaLogica.entradaInicial(reducirMovimiento: reduceMotion)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                CardIconBadge(iconName: look.iconName, foreground: principal)
                Text(account.name)
                    .font(DS.Typography.headline)
                    .foregroundStyle(principal)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            if look.showsChip {
                CardChipView(silver: look.silverChip)
            }

            Spacer(minLength: 0)

            pie(look: look, secundario: secundario)
        }
        .padding(DS.Spacing.lg)
        // Proporción de tarjeta como alto MÍNIMO: con letra grande crece y no recorta.
        // Con texto de accesibilidad, todo el ancho: con el tope, el tipo y las divisas se cortaban.
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : HojaCuentaTarjetaLogica.anchoMaximoTarjeta,
               alignment: .leading)
        .frame(minHeight: HojaCuentaTarjetaLogica.altoTarjeta(ancho: ancho))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { ancho = $0 }
        .background { CardBackgroundView(look: look) }
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        .offset(y: estado.desplazamiento)
        .scaleEffect(estado.escala)
        .opacity(estado.opacidad)
        .onAppear {
            guard entrada == nil else { return }
            entrada = HojaCuentaTarjetaLogica.entradaInicial(reducirMovimiento: reduceMotion)
            // En una hoja `withAnimation` sí anima (el apagado de `ContentView` no llega a las hojas, `swiftui-ds.md`).
            dsWithAnimation(reduceMotion, .spring(response: 0.55, dampingFraction: 0.82).delay(0.05)) {
                entrada = HojaCuentaTarjetaLogica.entradaFinal
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(resumenAccesible(look: look))
        .accessibilityIdentifier("hoja_cuenta_tarjeta")
    }

    /// Abajo: el tipo y las divisas a la izquierda, los últimos 4 a la derecha. Con texto de accesibilidad, uno bajo
    /// el otro.
    @ViewBuilder
    private func pie(look: CardLook, secundario: Color) -> some View {
        let tipo = Text(verbatim: subtitulo)
            .font(DS.Typography.caption)
            .fontWeight(.semibold)
            .foregroundStyle(secundario)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
        if let digitos = look.lastFour {
            let numero = Text(verbatim: CardFaceText.maskedDigits(digitos, hidden: amountsHidden))
                .font(DS.Typography.subheadline.monospacedDigit())
                .foregroundStyle(secundario)
                .lineLimit(1)
                .fixedSize()
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.sm) {
                    tipo
                    Spacer(minLength: DS.Spacing.sm)
                    numero
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    tipo
                    numero
                }
            }
        } else {
            tipo
        }
    }

    private func resumenAccesible(look: CardLook) -> String {
        CardFaceText.spokenSummary("\(account.name). \(subtitulo)", lastFour: look.lastFour, hidden: amountsHidden)
    }
}
