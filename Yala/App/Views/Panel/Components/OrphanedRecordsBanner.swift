//
//  OrphanedRecordsBanner.swift
//  Yala
//
//  Aviso del Panel: hay movimientos sin cuenta, que no suman en el saldo ni en los gastos.
//  Card `tablero-los-movimientos-que-quedaron-sin-cuenta-sovw` (decisión de Jürgen del 2026-10-15).
//

import SwiftUI

/// Sin botón de cerrar, a propósito: no es una novedad sino dinero que falta en las cifras, y su única salida es darles
/// una cuenta. Se va solo cuando no queda ninguno. La cifra va en una cápsula y no dentro de la frase, para no depender
/// de plurales en los 16 idiomas.
struct OrphanedRecordsBanner: View {

    @Environment(\.yalaTheme) private var theme

    let count: Int
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(DS.Typography.title)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.OrphanedRecords.bannerTitle)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.thPrimaryText)
                        Text("\(count)")
                            .font(DS.Typography.labelSmall.monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.xs)
                            .background(theme.accent, in: Capsule())
                            .accessibilityIdentifier("orphaned_records_banner_count")
                    }
                    Text(L10n.OrphanedRecords.bannerMessage)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.OrphanedRecords.bannerAction)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(theme.accent)
                        .padding(.top, DS.Spacing.xxs)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("orphaned_records_banner")
    }
}

#Preview {
    OrphanedRecordsBanner(count: 2, onChoose: {})
        .padding()
}

/// El aviso con su condición: algo que mover y el import quieto (`OrphanedRecordsLogic.showsNotice`).
///
/// La quietud del import no es observable entera: su ventana es de tiempo (8 s sin importar) y en la nube lee un flag del
/// motor. Por eso, mientras haya huérfanos, la condición se relee cada pocos segundos con un `TimelineView`; sin
/// huérfanos no hay reloj.
struct OrphanedRecordsNotice: View {

    let count: Int
    let onChoose: () -> Void

    var body: some View {
        if count > 0 {
            TimelineView(.periodic(from: .now, by: 3)) { _ in
                if OrphanedRecordsLogic.showsNotice(
                    orphanCount: count,
                    importIsQuiescent: SyncQuiescenceCoordinator.shared.isImportQuiescent
                ) {
                    OrphanedRecordsBanner(count: count, onChoose: onChoose)
                }
            }
        }
    }
}
