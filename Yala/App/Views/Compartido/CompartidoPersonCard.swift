//
//  CompartidoPersonCard.swift
//  Yala
//
//  La tarjeta de una persona en el chip «Personas» de Compartido (lote 1, 26-nov-2026). Copia la de grupo
//  (`GroupCardView`): círculo, nombre y, donde el grupo dice «3 miembros activos», dónde compartes con ella; debajo, una
//  fila por moneda con el neto, en los mismos textos y colores que la tarjeta de grupo («Ana te debe» en verde, «Le debes
//  a Ana» en el rosa de marca). Una liquidada lleva solo la cabecera. No se toca: el detalle de persona es el lote 2.
//

import SwiftUI

struct CompartidoPersonCard: View {

    let person: CompartidoPersonasLogic.Person

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header
            if !person.isSettled {
                rows
            }
        }
        .listRowCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var header: some View {
        HStack(spacing: DS.ListRow.spacing) {
            CompartidoPersonAvatar(name: person.name, seed: person.id)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(person.name)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            }
            Spacer(minLength: 0)
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(person.rows) { row in
                AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
                    Text(label(row))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                } trailing: {
                    Text(amount(row))
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(row.perspective == .iOwe ? Color.groupOweAmount : Color.groupOwedAmount)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }

    private var subtitle: String {
        person.isSettled
            ? L10n.Compartido.settledSubtitle(groups: person.groupNames)
            : L10n.Compartido.inGroups(person.groupNames)
    }

    private func label(_ row: GroupsViewModel.DebtRow) -> String {
        row.perspective == .iOwe ? L10n.Groups.Card.youOwe(person.name) : L10n.Groups.Card.theyOweYou(person.name)
    }

    private func amount(_ row: GroupsViewModel.DebtRow) -> String {
        appPreferences.currency(row.amount, currencyCode: row.currencyCode, forceFullPrecision: true)
    }

    private var accessibilityText: String {
        var parts = [person.name, subtitle]
        for row in person.rows { parts.append("\(label(row)) \(amount(row))") }
        return parts.joined(separator: ", ")
    }
}

/// El círculo de la persona: sus iniciales sobre un color fijo para ella (el de las personas de «Dividir una boleta»).
struct CompartidoPersonAvatar: View {
    let name: String
    let seed: String

    var body: some View {
        Text(DividirBoletaImageBuilder.initials(name))
            .font(DS.Typography.label)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
            .background(Circle().fill(Color(hex: DividirBoletaPalette.avatar(at: CompartidoPersonAvatar.index(for: seed)))))
            .accessibilityHidden(true)
    }

    /// Un índice estable para la persona: la suma de los bytes de su clave (el `hashValue` cambia en cada arranque).
    static func index(for seed: String) -> Int {
        seed.utf8.reduce(0) { ($0 &+ Int($1)) & 0xFFFF }
    }
}
