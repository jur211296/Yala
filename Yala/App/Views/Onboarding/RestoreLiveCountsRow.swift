//
//  RestoreLiveCountsRow.swift
//  Yala
//
//  Las cifras en vivo de lo que va llegando a este teléfono: cuentas, categorías, registros, presupuestos y grupos.
//  Iconos y número, sin rótulos (el icono dice el tipo y VoiceOver lee la cifra con su plural).
//
//  Nació dentro de `RestoreProgressView` y se sacó aquí en la 2.2 (UX 2.2 · L6-13) para enseñarla también al
//  conectar con una cuenta de la nube. Se retiró de allí: el adopt no baja filas y las cifras no subían.
//

import SwiftData
import SwiftUI

struct RestoreLiveCountsRow: View {
    let counts: ICloudAccountSummary?
    /// El color de las cifras: `.secondary` sobre el fondo de la app; blanco atenuado sobre el fondo fijo del Welcome.
    var foreground: Color = .secondary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            countChip("creditcard.fill", counts?.accountsCount ?? 0, L10n.Welcome.Restore.foundAccounts(counts?.accountsCount ?? 0))
            countChip("tag.fill", counts?.categoriesCount ?? 0, "\(counts?.categoriesCount ?? 0)")
            countChip("list.bullet.rectangle.fill", counts?.transactionsCount ?? 0, L10n.Welcome.Restore.foundTransactions(counts?.transactionsCount ?? 0))
            countChip("chart.pie.fill", counts?.budgetsCount ?? 0, L10n.Welcome.Restore.foundBudgets(counts?.budgetsCount ?? 0))
            countChip("person.2.fill", counts?.groupsCount ?? 0, L10n.Welcome.Restore.foundGroups(counts?.groupsCount ?? 0))
        }
        .font(DS.Typography.caption)
        .foregroundStyle(foreground)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: counts)
    }

    @ViewBuilder
    private func countChip(_ icon: String, _ value: Int, _ a11y: String) -> some View {
        if value > 0 {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: icon)
                Text("\(value)").monospacedDigit().contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(a11y)
        }
    }
}

/// Las mismas cifras durante la entrada a una cuenta de la nube (L6-13): cuenta lo que hay en este teléfono cada
/// segundo mientras la pantalla está montada, igual que la espera de Restaurar. **Solo lee**: `fetchCount` sobre el
/// contexto principal, sin escribir nada ni tocar la máquina de migración. El `.task` muere con la vista, así que no
/// sigue contando con la pantalla desmontada (la lección de `RestoreProgressView.refreshTask`).
