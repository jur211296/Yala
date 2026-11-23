//
//  ComerciosEnComunAjustesView.swift
//  Yala
//
//  Perfil › Comercios en común (2.3, 2026-11-22): la salida permanente de aportar, y qué se envía. Recibir las
//  sugerencias no se apaga: no envía nada. Ver `ComerciosEnComun`.
//

import SwiftUI

struct ComerciosEnComunAjustesView: View {
    @State private var aporta = ComerciosEnComun.shared.aporta

    var body: some View {
        YalaSettingsList {
            YalaSettingsSection {
                YalaSettingsToggleRow(L10n.ComerciosEnComun.aportar, isOn: $aporta)
                    .accessibilityIdentifier("comercios_comun_aportar")
            } footer: {
                Text(L10n.ComerciosEnComun.aportarPie)
            }
            YalaSettingsSection(L10n.ComerciosEnComun.queSeEnviaTitulo) {
                fila(L10n.ComerciosEnComun.queSeEnviaNombre, icono: "storefront")
                fila(L10n.ComerciosEnComun.queSeEnviaTipo, icono: "tag")
                fila(L10n.ComerciosEnComun.queSeEnviaNunca, icono: "nosign")
            }
            YalaSettingsSection(L10n.ComerciosEnComun.comoFuncionaTitulo) {
                fila(L10n.ComerciosEnComun.comoFuncionaSemana, icono: "calendar")
                fila(L10n.ComerciosEnComun.comoFuncionaVarios, icono: "person.3")
                fila(L10n.ComerciosEnComun.comoFuncionaLocal, icono: "iphone")
                fila(L10n.ComerciosEnComun.comoFuncionaManda, icono: "hand.raised")
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.ComerciosEnComun.titulo)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: aporta) { _, nuevo in ComerciosEnComun.shared.aporta = nuevo }
    }

    private func fila(_ texto: String, icono: String) -> some View {
        Label {
            Text(texto)
                .font(DS.Typography.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icono)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}
