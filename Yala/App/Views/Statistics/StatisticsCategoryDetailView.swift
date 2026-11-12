//
//  StatisticsCategoryDetailView.swift
//  Yala
//
//  Decisión 25 de la revisión 2.3 (B1, 9-nov): tocar una categoría en Distribución abre esta pantalla —lo gastado y su
//  comparación, sus subcategorías y sus últimos registros, con «Ver en Registros»— y «atrás» vuelve a Distribución
//  como estaba. No escribe ningún filtro; el único gesto que filtra es «Ver en Registros», que lo dice.
//

import SwiftData
import SwiftUI

struct StatisticsCategoryDetailView: View {
    let detail: StatisticsCategoryDetail
    let currencyCode: String
    /// Qué es la cifra: «Gastado», «Ingresos» o «Total», según la naturaleza elegida en Distribución.
    let amountTitle: String
    let period: DetailPeriod
    let customRange: DateInterval?
    let comparisonMode: ComparisonMode
    /// Variaciones encendidas y con comparación (no en «Todo el tiempo»): lo mismo que decide la fila de Distribución.
    let showsVariation: Bool
    let onSeeInRecords: () -> Void
    let onOpenRecord: (TransactionItem) -> Void

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        return f
    }()

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                heroCard
                subcategoriesSection
                recordsSection
            }
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xxl)
            .readableColumn()
        }
        .scrollViewGlassEdges()
        .yalaScreenBackground()
        .navigationTitle(detail.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Lo gastado y su comparación

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color(hex: detail.colorHex))
                        .frame(width: 40, height: 40)
                    Image(systemName: detail.iconName ?? "tag.fill")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                Text(detail.name)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
            }

            PieChartVariationHeader(
                title: amountTitle,
                totalAmount: detail.amount,
                previousAmount: showsVariation ? detail.previousAmount : nil,
                currencyCode: currencyCode,
                period: period,
                customRange: customRange,
                comparisonMode: comparisonMode
            )

            Text("\(formattedPercentage(detail.percentage)) \(L10n.Statistics.ofExpense)")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
        // Un id en un contenedor pisa los de dentro (`testing.md`): este marca la pantalla, y lo de dentro no lleva.
        .accessibilityIdentifier("stats_category_detail")
    }

    // MARK: - Subcategorías

    @ViewBuilder
    private var subcategoriesSection: some View {
        if let maxAmount = detail.subcategories.first?.amount {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.ListViewType.subcategories)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(detail.subcategories) { summary in
                        SubcategoryRowView(
                            summary: summary,
                            maxAmount: maxAmount,
                            currencyCode: currencyCode,
                            showVariation: showsVariation
                        )
                    }
                }
                .padding(.bottom, DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .panelCard()
            }
            .accessibilityIdentifier("stats_category_detail_subcategories")
        }
    }

    // MARK: - Últimos registros

    @ViewBuilder
    private var recordsSection: some View {
        if !detail.latestRecords.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.Statistics.latestRecords)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Button(action: onSeeInRecords) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(L10n.Statistics.categoryDetailSeeInRecords)
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.labelSmall)
                                .accessibilityHidden(true)
                        }
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.thAccentText)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stats_category_detail_see_in_records")
                }

                // Cada fila ya es su tarjeta, como en Registros.
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(detail.latestRecords, id: \.persistentModelID) { record in
                        RecordRowView(
                            record: record,
                            currencyCode: currencyCode,
                            isSelectionMode: false,
                            isSelected: false,
                            onTap: { onOpenRecord(record) },
                            onToggleSelection: {}
                        )
                    }
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
