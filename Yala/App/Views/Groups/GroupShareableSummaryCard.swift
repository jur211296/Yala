//
//  GroupShareableSummaryCard.swift
//  Yala
//
//  La tarjeta que se convierte en la imagen del «cierre del viaje». No se navega a ella: se
//  rasteriza con `ImageRenderer` y lo que sale se manda por el share sheet.
//
//  DOS REGLAS QUE NO SON ESTÉTICA, SON LO QUE HACE QUE ESTO NO SE CAIGA:
//
//  1. **Ni un solo `@Environment` aquí dentro.** `ImageRenderer` hostea su contenido FUERA del árbol
//     de la app, igual que las `.annotation` de Swift Charts: una sub-vista que lea
//     `@Environment(AppPreferences.self)` —`AmountText`, sin ir más lejos— no lo resuelve y dispara
//     `SIGTRAP` en `EnvironmentValues.subscript.getter`, sin crash log claro (ver
//     `.claude/rules/swiftui-ds.md`, causa del crash del chip de Estadísticas). Por eso la tarjeta
//     recibe los importes YA FORMATEADOS como `String`: quien la construye está en el árbol, tiene
//     las preferencias y formatea allí. Aquí solo se pinta.
//
//  2. **Colores fijos, no tokens de tema.** Esta imagen sale de la app y acaba en un chat: no puede
//     depender del tema ni del modo oscuro del device que la generó, o el mismo grupo recibiría
//     resúmenes distintos según quién lo mande. Va siempre en claro, con contraste medido sobre
//     blanco. El único color libre es el del grupo, y se usa solo como superficie (el círculo del
//     icono), nunca como texto —la paleta no llega a AA de 4,5 sobre blanco—.
//

import SwiftUI

// MARK: - Modelo de render (strings ya formateados)

/// Lo que la tarjeta necesita para pintarse. Todos los importes son `String` a propósito: ver la
/// regla 1 de la cabecera. Lo arma `GroupShareableSummarySheet`, que sí tiene las preferencias.
struct GroupShareableSummaryRenderModel: Equatable {

    struct MemberRow: Identifiable, Equatable {
        let id: String
        let name: String
        let paid: String
        let owed: String
    }

    struct PaymentRow: Identifiable, Equatable {
        let id: String
        let fromName: String
        let toName: String
        let amount: String
    }

    struct Block: Identifiable, Equatable {
        let id: String
        let currencyCode: String
        /// `nil` cuando esta divisa no tiene gasto propio: entonces la tarjeta no pinta el total.
        /// Un «Total gastado 0,00» sobre una lista de transferencias reales se lee como un error.
        let total: String?
        let members: [MemberRow]
        let payments: [PaymentRow]
        /// `false` cuando las deudas de esta divisa se están contando en el bloque de otra (grupo con
        /// «ver deudas en una sola moneda»): entonces aquí no va ni la lista ni el «todo saldado».
        let showsPayments: Bool
    }

    let groupName: String
    let iconName: String
    let colorHex: String
    let dateText: String
    let blocks: [Block]
}

// MARK: - Tarjeta

struct GroupShareableSummaryCard: View {

    let model: GroupShareableSummaryRenderModel

    /// Ancho del lienzo en puntos. A escala 3 salen 2160 px de ancho: nítido en cualquier chat y
    /// muy por debajo del límite que cualquier app de mensajería recomprime.
    static let canvasWidth: CGFloat = 720

    // Medidas del lienzo. Son de la IMAGEN, no de una pantalla: no hay Dynamic Type que respetar
    // (nadie amplía una foto recibida por WhatsApp), así que van en puntos fijos para que el
    // resultado sea idéntico en todos los devices.
    // A11Y-DT: lienzo de tamaño fijo — es un asset exportado, no una vista de la app.
    private let horizontalPadding: CGFloat = 40
    private let nameColumnWidth: CGFloat = 240
    private let amountColumnWidth: CGFloat = 180

    // A11Y-DM: la imagen se comparte fuera de la app y no puede seguir el tema del device.
    private let ink = Color(hex: "#111827")          // texto principal, 16,1:1 sobre blanco
    private let inkSecondary = Color(hex: "#6B7280") // texto de apoyo, 5,0:1
    private let hairline = Color(hex: "#E5E7EB")
    private let surface = Color.white
    private let settledGreen = Color(hex: "#0F7A5F") // 5,3:1 — «todo saldado»

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            header

            ForEach(model.blocks) { block in
                blockView(block)
            }

            footer
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 44)
        .frame(width: Self.canvasWidth, alignment: .leading)
        .background(surface)
        .environment(\.colorScheme, .light)
    }

    // MARK: Cabecera

    private var header: some View {
        HStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color(hex: model.colorHex))
                    .frame(width: 56, height: 56) // A11Y-DT: asset exportado

                Image(systemName: model.iconName)
                    .font(.system(size: 26, weight: .semibold)) // A11Y-DT: asset exportado
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(model.groupName)
                    .font(.system(size: 30, weight: .bold)) // A11Y-DT: asset exportado
                    .foregroundStyle(ink)
                    .lineLimit(2)

                Text(model.dateText)
                    .font(.system(size: 15)) // A11Y-DT: asset exportado
                    .foregroundStyle(inkSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Un bloque = una moneda

    @ViewBuilder
    private func blockView(_ block: GroupShareableSummaryRenderModel.Block) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // El código de la divisa solo se rotula cuando hay más de una: con una sola, el símbolo
            // que ya llevan los importes lo dice todo y el rótulo sería ruido.
            if model.blocks.count > 1 {
                Text(block.currencyCode)
                    .font(.system(size: 13, weight: .bold)) // A11Y-DT: asset exportado
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Capsule().fill(inkSecondary))
            }

            if let total = block.total {
                totalRow(total)
            }

            if !block.members.isEmpty {
                membersTable(block.members)
            }

            if block.showsPayments {
                paymentsSection(block.payments)
            }
        }
        .padding(.top, DS.Spacing.sm)
    }

    private func totalRow(_ total: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(L10n.Groups.ShareableSummary.totalSpent.uppercased())
                .font(.system(size: 13, weight: .semibold)) // A11Y-DT: asset exportado
                .tracking(0.8)
                .foregroundStyle(inkSecondary)

            Text(total)
                .font(.system(size: 38, weight: .bold)) // A11Y-DT: asset exportado
                .foregroundStyle(ink)
        }
    }

    private func membersTable(_ rows: [GroupShareableSummaryRenderModel.MemberRow]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionTitle(L10n.Groups.ShareableSummary.whoPaid)

            VStack(spacing: DS.Spacing.none) {
                // Cabecera de columnas: sin ella, dos importes seguidos en la misma fila no dicen
                // cuál es cuál.
                HStack(spacing: DS.Spacing.none) {
                    Spacer().frame(width: nameColumnWidth, alignment: .leading)
                    columnHeader(L10n.Groups.ShareableSummary.paidLabel)
                    columnHeader(L10n.Groups.ShareableSummary.owedLabel)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, DS.Spacing.xs)

                ForEach(rows) { row in
                    HStack(spacing: DS.Spacing.none) {
                        Text(row.name)
                            .font(.system(size: 17)) // A11Y-DT: asset exportado
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: nameColumnWidth, alignment: .leading)

                        // `minimumScaleFactor` y no elipsis: un importe cortado con «…» en una
                        // imagen que ya está en el chat es un dato incorrecto congelado. Encoge, que
                        // se sigue leyendo. Hace falta con divisas de denominación alta (COP, CLP,
                        // IDR) y el formato de moneda por CÓDIGO en vez de por símbolo.
                        Text(row.paid)
                            .font(.system(size: 17, weight: .semibold)) // A11Y-DT: asset exportado
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: amountColumnWidth, alignment: .trailing)

                        Text(row.owed)
                            .font(.system(size: 17)) // A11Y-DT: asset exportado
                            .foregroundStyle(inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: amountColumnWidth, alignment: .trailing)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, DS.Spacing.sm)

                    if row.id != rows.last?.id {
                        Rectangle()
                            .fill(hairline)
                            .frame(height: 1) // A11Y-DT: asset exportado
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func paymentsSection(_ rows: [GroupShareableSummaryRenderModel.PaymentRow]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionTitle(L10n.Groups.ShareableSummary.settleUp)

            if rows.isEmpty {
                // Que el resumen diga «no hay nada pendiente» es la mitad del valor de mandarlo.
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20)) // A11Y-DT: asset exportado
                        .foregroundStyle(settledGreen)

                    Text(L10n.Groups.ShareableSummary.allSettled)
                        .font(.system(size: 17, weight: .semibold)) // A11Y-DT: asset exportado
                        .foregroundStyle(settledGreen)
                }
                .padding(.vertical, DS.Spacing.sm)
            } else {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(rows) { row in
                        HStack(spacing: DS.Spacing.sm) {
                            Text(row.fromName)
                                .font(.system(size: 17, weight: .semibold)) // A11Y-DT: asset exportado
                                .foregroundStyle(ink)
                                .lineLimit(1)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .semibold)) // A11Y-DT: asset exportado
                                .foregroundStyle(inkSecondary)

                            Text(row.toName)
                                .font(.system(size: 17)) // A11Y-DT: asset exportado
                                .foregroundStyle(ink)
                                .lineLimit(1)

                            Spacer(minLength: DS.Spacing.md)

                            // `layoutPriority` alto: aquí los tres textos son flexibles y, con dos
                            // nombres largos, SwiftUI repartiría el truncado sin saber que el
                            // importe es el único dato de la fila que no se puede perder.
                            Text(row.amount)
                                .font(.system(size: 19, weight: .bold)) // A11Y-DT: asset exportado
                                .foregroundStyle(ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .layoutPriority(1)
                        }
                        .padding(.vertical, DS.Spacing.sm)

                        if row.id != rows.last?.id {
                            Rectangle()
                                .fill(hairline)
                                .frame(height: 1) // A11Y-DT: asset exportado
                        }
                    }
                }
            }
        }
    }

    // MARK: Piezas menores

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold)) // A11Y-DT: asset exportado
            .foregroundStyle(ink)
    }

    private func columnHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold)) // A11Y-DT: asset exportado
            .tracking(0.6)
            .foregroundStyle(inkSecondary)
            .lineLimit(1)
            .frame(width: amountColumnWidth, alignment: .trailing)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Rectangle()
                .fill(hairline)
                .frame(height: 1) // A11Y-DT: asset exportado

            Text(L10n.Groups.ShareableSummary.footer)
                .font(.system(size: 13)) // A11Y-DT: asset exportado
                .foregroundStyle(inkSecondary)
        }
    }
}

#Preview("Resumen compartible") {
    GroupShareableSummaryCard(
        model: GroupShareableSummaryRenderModel(
            groupName: "Viaje a Cusco",
            iconName: "airplane",
            colorHex: "#8B5CF6",
            dateText: "7 de septiembre de 2026",
            blocks: [
                .init(
                    id: "PEN",
                    currencyCode: "PEN",
                    total: "S/ 1,250.00",
                    members: [
                        .init(id: "1", name: "Ana", paid: "S/ 800.00", owed: "S/ 416.67"),
                        .init(id: "2", name: "Beto", paid: "S/ 450.00", owed: "S/ 416.67"),
                        .init(id: "3", name: "Carla", paid: "S/ 0.00", owed: "S/ 416.66")
                    ],
                    payments: [
                        .init(id: "3-1", fromName: "Carla", toName: "Ana", amount: "S/ 416.66"),
                        .init(id: "2-1", fromName: "Beto", toName: "Ana", amount: "S/ 33.33")
                    ],
                    showsPayments: true
                )
            ]
        )
    )
}
