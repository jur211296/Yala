//
//  EstoLeiDeslizarLogicTests.swift
//  YalaTests
//
//  El deslizar de «Esto leí» en grande (encargo del 27-nov-2026): qué acción toca, cómo responde el gesto, qué pasa con la
//  hoja al quitar la última y cuándo se pinta «en grande».
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Yala

@Suite("Esto leí · deslizar")
struct EstoLeiDeslizarLogicTests {

    typealias Logic = EstoLeiDeslizarLogic

    // MARK: Qué acción

    @Test func pendiente_descarta_siSePuede() {
        #expect(Logic.accion(isPending: true, isSaved: false, canDiscard: true, recordDeletable: false) == .descartar)
        #expect(Logic.accion(isPending: true, isSaved: false, canDiscard: false, recordDeletable: true) == nil)
    }

    @Test func guardada_eliminaSuRegistro_soloSiSePuedeBorrar() {
        #expect(Logic.accion(isPending: false, isSaved: true, canDiscard: true, recordDeletable: true) == .eliminar)
        // Un registro de grupo (o ya borrado) no se borra desde aquí.
        #expect(Logic.accion(isPending: false, isSaved: true, canDiscard: true, recordDeletable: false) == nil)
    }

    @Test func rechazada_noSeDesliza() {
        #expect(Logic.accion(isPending: false, isSaved: false, canDiscard: true, recordDeletable: true) == nil)
    }

    // MARK: El gesto

    @Test func noSeMueveHaciaLaDerecha_niMasAllaDelAncho() {
        #expect(Logic.desplazamiento(traslacion: 40, abierto: false, ancho: 300) == 0)
        #expect(Logic.desplazamiento(traslacion: -50, abierto: false, ancho: 300) == -50)
        #expect(Logic.desplazamiento(traslacion: -900, abierto: false, ancho: 300) == -300)
        // Abierta, parte del ancho del botón.
        #expect(Logic.desplazamiento(traslacion: 0, abierto: true, ancho: 300) == -Logic.anchoBoton)
        #expect(Logic.desplazamiento(traslacion: 500, abierto: true, ancho: 300) == 0)
    }

    @Test func alSoltar_cierraAbreOEjecuta() {
        let ancho: CGFloat = 300
        #expect(Logic.alSoltar(traslacion: -20, abierto: false, ancho: ancho) == .cerrar)
        #expect(Logic.alSoltar(traslacion: -(Logic.anchoBoton / 2), abierto: false, ancho: ancho) == .abrir)
        #expect(Logic.alSoltar(traslacion: -100, abierto: false, ancho: ancho) == .abrir)
        #expect(Logic.alSoltar(traslacion: -ancho * Logic.fraccionCompleta, abierto: false, ancho: ancho) == .ejecutar)
        // Abierta: llevarla de vuelta a la derecha la cierra.
        #expect(Logic.alSoltar(traslacion: 80, abierto: true, ancho: ancho) == .cerrar)
        #expect(Logic.alSoltar(traslacion: 0, abierto: true, ancho: ancho) == .abrir)
    }

    @Test func sinAnchoMedido_nuncaEjecutaSolo() {
        #expect(Logic.alSoltar(traslacion: -500, abierto: false, ancho: 0) != .ejecutar)
    }

    // MARK: La hoja tras quitar una fila

    @Test func ultima_cierraLaHoja() {
        #expect(Logic.despuesDeQuitar(filasRestantes: 0, pendientesRestantes: 0) == .cerrarHoja)
    }

    @Test func soloQuedanGuardadas_cierraComoAlGuardar() {
        #expect(Logic.despuesDeQuitar(filasRestantes: 2, pendientesRestantes: 0) == .cerrarComoAlGuardar)
    }

    @Test func quedanPendientes_sigue() {
        #expect(Logic.despuesDeQuitar(filasRestantes: 2, pendientesRestantes: 1) == .seguir)
    }

    // MARK: Cuándo es «en grande»

    @Test func enGrande_porDondeEstaLaHoja() {
        #expect(ImageEntrySheetHeightLogic.isLarge(sheetTop: 55))
        #expect(!ImageEntrySheetHeightLogic.isLarge(sheetTop: 370))
        #expect(!ImageEntrySheetHeightLogic.isLarge(sheetTop: nil))
        #expect(ImageEntrySheetHeightLogic.showsLargePresentation(sheetTop: 370, usesLargeSheets: true))
        #expect(!ImageEntrySheetHeightLogic.showsLargePresentation(sheetTop: 370, usesLargeSheets: false))
    }

    /// La variante del fondo de la hoja NO cambia por verse grande: cambiar de variante rehace la tarjeta al subir el
    /// teclado. El sólido lo pinta una capa aparte (cableado, abajo).
    @Test func laVarianteDelFondoNoCambiaPorVerseGrande() {
        let detents: Set<PresentationDetent> = [ImageEntrySheetHeightLogic.estoLeiPartial, .large]
        #expect(ImageEntrySheetHeightLogic.background(
            detents: detents, selectedDetent: ImageEntrySheetHeightLogic.estoLeiPartial,
            usesLargeSheets: false, sheetTop: 57) == .transparent)
    }

    @Test func radioDeLaTarjeta_esElDelPanelEnGrande() {
        #expect(EstoLeiCardLayout.cornerRadius(large: true) == DS.Panel.widgetRadius)
        #expect(EstoLeiCardLayout.cornerRadius(large: false) == DS.Radius.card)
    }
}

/// El cableado: la hoja de foto pasa el «en grande» y el deslizar, y el vacío de Grupos ancla la fila arriba.
@Suite("Esto leí y Grupos vacío · cableado")
struct PulidoGruposVacioEstoLeiWiringTests {

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test func hojaDeFoto_pasaEnGrandeYDeslizar_aLasDosFormas() throws {
        let s = try source("Yala/App/Views/Image/ImageSelectionView.swift")
        #expect(s.contains(".environment(\\.estoLeiEnGrande, isLargePresentation)"))
        #expect(s.contains(".environment(\\.estoLeiAlDeslizar, swiped)"))
        #expect(s.contains(".estoLeiDeslizable("))
        // El sólido de la hoja vista grande: una capa fija que solo cambia de opacidad.
        #expect(s.contains(".opacity(isLargePresentation ? 1 : 0)"))
        #expect(s.contains("RecordDeleteConfirmationText.title(for: record"))
    }

    @Test func vozSigueSinDeslizar() throws {
        let s = try source("Yala/App/Views/Voice/VoiceRecordingView.swift")
        #expect(!s.contains("estoLeiEnGrande"))
        #expect(!s.contains("estoLeiAlDeslizar"))
    }

    @Test func grupoVacio_anclaArriba_yCentraSoloElVacio() throws {
        let s = try source("Yala/App/Views/Groups/GroupRecordsView.swift")
        let compact = s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        // «Sin gastos» se estira en el alto que sobra y la columna se ancla arriba; si no cabe, se desplaza.
        #expect(compact.contains("action: onInvite ) .frame(maxHeight: .infinity) }"))
        #expect(compact.contains("if dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact {"))
        #expect(compact.contains("ScrollView { emptyColumn .frame(minHeight: proxy.size.height, alignment: .top) }"))
        #expect(compact.contains("} else { emptyColumn .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) }"))
    }
}
