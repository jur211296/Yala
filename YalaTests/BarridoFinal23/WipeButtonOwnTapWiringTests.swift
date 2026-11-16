//
//  WipeButtonOwnTapWiringTests.swift
//  YalaTests
//
//  Card lplc (barrido final de 2.3, iPhone 14): en Ajustes › Vaciar datos, el centro de «Vaciar mis datos» abría Exportar
//  (3 de 3, con 0 y con 1 registro). Los dos botones van en la misma fila de la lista y «Vaciar mis datos» llevaba el estilo
//  automático, que en una fila de `List` reparte el toque de la fila entera. Con `.borderless` cada botón recibe solo el
//  suyo: medido en el iPhone 14 el 16-nov. El simulador NO lo reproduce (un XCUITest que tocaba el centro por coordenada
//  salió verde también sin el arreglo), así que el pin es este scan y la prueba, la del teléfono.
//

import Foundation
import Testing

@Suite("Barrido final 2.3 · cada botón de Vaciar datos recibe su propio toque")
struct WipeButtonOwnTapWiringTests {

    @Test("«Vaciar mis datos» lleva estilo propio dentro de la fila; «Exportar una copia antes» es `.plain`")
    func bothButtonsOfTheRow_haveTheirOwnStyle() throws {
        let view = try BarridoFinal23Source.code("Yala/App/Views/Settings/UserDataResetView.swift")
        #expect(view.contains("YalaSecondaryButton(L10n.Settings.deleteAllData, isDisabled: isProcessing, destructive: true) "
                              + "{ openWipeScope() } .buttonStyle(.borderless) .accessibilityIdentifier(\"wipe_data_start\")"))
        let buttons = try BarridoFinal23Source.code("Yala/App/Views/Shared/StandardButtons.swift")
        #expect(buttons.contains(".disabled(isDisabled || isLoading) .buttonStyle(.plain)"),
                "El primario ya lleva estilo propio: si lo pierde, la fila vuelve a repartir el toque")
    }
}
