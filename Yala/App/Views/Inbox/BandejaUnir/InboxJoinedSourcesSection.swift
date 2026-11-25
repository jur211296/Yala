//
//  InboxJoinedSourcesSection.swift
//  Yala
//
//  Bandeja sin duplicados, lote 2: en el editor de un borrador pendiente que la Bandeja unió al llegar, de qué fuentes
//  viene y «Separar», que las devuelve como pendientes aparte (`InboxArrivalJoin.separate`). Solo sale con un registro de
//  unión que se entiende (Paso 0, D7 y D8). Los nombres son los de la fila de la lista (lote 3).
//

import SwiftUI

struct InboxJoinedSourcesSection: View {
    /// El nombre de cada fuente, como en la fila de la Bandeja («Apple Pay», «Aviso de BCP», «Correo»; lote 3).
    let names: [String]
    let onSeparate: () -> Void

    @Environment(\.yalaTheme) private var theme

    /// Las fuentes de un borrador, o `nil` si no tiene nada unido que se pueda separar.
    static func sources(of draft: InboxDraft) -> [InboxMatchLogic.Source]? {
        guard draft.status == .pending, case .record(let record) = InboxJoinRecord.read(draft.joinRecordRaw) else {
            return nil
        }
        return InboxJoinLogic.sources(of: record)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            Label {
                Text(L10n.BandejaUnir.resumen(fuentes: names.joined(separator: " · ")))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "square.on.square")
            }
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("inbox_joined_sources")

            Button(L10n.BandejaUnir.separar, action: onSeparate)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(theme.accentText)
                .buttonStyle(.borderless)
                .accessibilityHint(L10n.BandejaUnir.separarPista)
                .accessibilityIdentifier("inbox_joined_separate")
        }
    }
}
