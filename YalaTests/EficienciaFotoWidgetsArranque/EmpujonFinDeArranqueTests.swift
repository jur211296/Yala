//
//  EmpujonFinDeArranqueTests.swift
//  YalaTests / EficienciaFotoWidgetsArranque
//
//  Lote 7 de eficiencia (27-nov-2026). El arranque en frío hacía dos cálculos completos del Panel seguidos (~16 s con
//  16.004 movimientos en el iPhone 14): el segundo lo pedía la subida de `dataVersion` del final del arranque, que es un
//  empujón para Grupos y no trae datos. Ahora el Panel no recalcula por ese empujón si nada cambió desde su carga, y sí
//  recalcula si cambió algo: un guardado, un cambio de la nube, otra subida de `dataVersion`, cambios sin guardar o el día.
//
//  Se fija: (1) la decisión, caso a caso; (2) con el Panel cargado, el empujón no pide otro cálculo y volver al Panel no
//  recarga; (3) llegado a mitad de la carga, sale UN cálculo; (4) los controles: con un guardado, con otra subida o con un
//  aviso de la nube, recalcula como siempre.
//

import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Eficiencia 7 · el empujón del final del arranque no recalcula el Panel sin datos nuevos", .serialized)
@MainActor
struct EmpujonFinDeArranqueTests {

    private let dia = Date(timeIntervalSince1970: 1_781_000_000)

    private func firma(_ dv: Int, guardados: Int = 10, remotos: Int = 3, dia: Date? = nil) -> EmpujonFinDeArranque.Firma {
        EmpujonFinDeArranque.Firma(dataVersion: dv, guardados: guardados, cambiosRemotos: remotos, dia: dia ?? self.dia)
    }

    // MARK: - 1. La decisión

    @Test("Solo el empujón y nada más: no recarga")
    func soloElEmpujon() {
        #expect(EmpujonFinDeArranque.esSoloElEmpujon(
            desde: firma(4), ahora: firma(5), dataVersionTrasEmpujon: 5, hayCambiosSinGuardar: false))
    }

    @Test("Lo que el segundo cálculo corregía: cualquiera de estas cosas recarga")
    func cualquierOtraSenal_recarga() {
        let casos: [(String, EmpujonFinDeArranque.Firma?, EmpujonFinDeArranque.Firma, Int?, Bool)] = [
            ("sin carga previa", nil, firma(5), 5, false),
            ("sin empujón en este proceso", firma(4), firma(5), nil, false),
            ("otra subida después del empujón", firma(4), firma(6), 5, false),
            ("otra subida antes del empujón", firma(3), firma(5), 5, false),
            ("un guardado", firma(4), firma(5, guardados: 11), 5, false),
            ("un cambio de la nube", firma(4), firma(5, remotos: 4), 5, false),
            ("otro día", firma(4), firma(5, dia: dia.addingTimeInterval(86_400)), 5, false),
            ("cambios sin guardar", firma(4), firma(5), 5, true),
        ]
        for (nombre, desde, ahora, empujon, sinGuardar) in casos {
            #expect(!EmpujonFinDeArranque.esSoloElEmpujon(
                desde: desde, ahora: ahora, dataVersionTrasEmpujon: empujon, hayCambiosSinGuardar: sinGuardar),
                "\(nombre): tenía que recargar")
        }
    }

    // MARK: - 2-4. El Panel

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private func makePanel(movimientos: Int = 40) async throws -> (PanelViewModel, ModelContext) {
        let context = try makeTestContext()
        let cuenta = Account(name: "A", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        context.insert(cuenta)
        for i in 0..<movimientos {
            let tx = TransactionItem(date: dia.addingTimeInterval(-Double(i) * 3_600), amount: -10 - Double(i % 7),
                                     currencyCode: "PEN", account: cuenta, amountInPreferredCurrency: -10 - Double(i % 7))
            tx.createdAt = tx.date
            context.insert(tx)
        }
        try context.save()
        // El eco del guardado (`.NSPersistentStoreRemoteChange`, en otro hilo) llega a los pocos ms: que caiga antes de
        // la firma de la primera carga, o el control parecería un cambio de la nube (regla de `testing.md`).
        try await Task.sleep(for: .milliseconds(300))
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return (viewModel, context)
    }

    private func waitForCompleted(_ viewModel: PanelViewModel, reaching target: Int) async throws {
        for _ in 0..<250 where viewModel.debugCalculationRuns < target {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func settle(_ viewModel: PanelViewModel) async throws {
        let before = viewModel.debugCalculationRuns
        viewModel.reloadAndRecalculate()
        try await waitForCompleted(viewModel, reaching: before + 1)
        try #require(viewModel.debugCalculationRuns == before + 1)
        try await Task.sleep(for: .milliseconds(250))
    }

    /// Lo que hace el arranque (paso 19) y lo que oye el Panel (`PanelDataObservers`).
    private func empujon(_ viewModel: PanelViewModel) {
        EmpujonFinDeArranque.subir(session)
        viewModel.dataVersionDidChange()
    }

    @Test("Con el Panel cargado, el empujón no pide otro cálculo y volver al Panel no recarga")
    func panelCargado_elEmpujonNoRecalcula() async throws {
        let (viewModel, _) = try await makePanel()
        try await settle(viewModel)
        let empezados = viewModel.debugCalculationsStarted
        let absorbidos = viewModel.debugEmpujonesAbsorbidos

        empujon(viewModel)
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.debugEmpujonesAbsorbidos == absorbidos + 1)
        #expect(viewModel.debugCalculationsStarted == empezados, "el empujón sin datos pidió otro cálculo completo")
        // La firma quedó al día: volver al Panel tampoco recarga.
        #expect(!viewModel.refreshIfStale())
    }

    @Test("Llegado a mitad de la carga por tramos, el arranque hace UN cálculo")
    func aMitadDeLaCarga_unSoloCalculo() async throws {
        // Varios tramos de lectura (`transactionSliceSize`), para que la carga dure y el empujón caiga dentro.
        let (viewModel, _) = try await makePanel(movimientos: PanelViewModel.transactionSliceSize * 3 + 10)
        let empezados = viewModel.debugCalculationsStarted
        let terminados = viewModel.debugCalculationRuns

        viewModel.reloadAndRecalculate()
        for _ in 0..<500 where !viewModel.debugHayCargaEnCurso {
            try await Task.sleep(for: .milliseconds(1))
        }
        try #require(viewModel.debugHayCargaEnCurso, "la carga por tramos no llegó a empezar")
        empujon(viewModel)
        try await waitForCompleted(viewModel, reaching: terminados + 1)
        try await Task.sleep(for: .milliseconds(500))

        #expect(viewModel.debugCalculationRuns == terminados + 1)
        #expect(viewModel.debugCalculationsStarted == empezados + 1, "el empujón a mitad de la carga pidió un segundo cálculo")
        #expect(!viewModel.refreshIfStale(), "la carga terminó con la firma al día")
    }

    @Test("Control: con un guardado desde la carga, el empujón recalcula como siempre")
    func conUnGuardado_recalcula() async throws {
        let (viewModel, context) = try await makePanel()
        try await settle(viewModel)
        let terminados = viewModel.debugCalculationRuns
        let cuenta = try #require(try context.fetch(FetchDescriptor<Account>()).first)
        context.insert(TransactionItem(date: dia, amount: -99, currencyCode: "PEN", account: cuenta,
                                       amountInPreferredCurrency: -99))
        try context.save()

        empujon(viewModel)
        try await waitForCompleted(viewModel, reaching: terminados + 1)
        #expect(viewModel.debugCalculationRuns == terminados + 1, "con un guardado, el empujón tiene que recargar")
    }

    @Test("Control: con otra subida de dataVersion (p. ej. un borrado con «Deshacer»), recalcula")
    func conOtraSubida_recalcula() async throws {
        let (viewModel, _) = try await makePanel()
        try await settle(viewModel)
        let terminados = viewModel.debugCalculationRuns

        session.incrementDataVersion()
        empujon(viewModel)
        try await waitForCompleted(viewModel, reaching: terminados + 1)
        #expect(viewModel.debugCalculationRuns == terminados + 1)
    }

    @Test("Control: con un cambio de la nube desde la carga, recalcula")
    func conUnCambioDeLaNube_recalcula() async throws {
        let (viewModel, _) = try await makePanel()
        try await settle(viewModel)
        let terminados = viewModel.debugCalculationRuns
        let remotos = StoreRemoteChangeCounter.shared.count

        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        for _ in 0..<100 where StoreRemoteChangeCounter.shared.count == remotos {
            try await Task.sleep(for: .milliseconds(5))
        }
        empujon(viewModel)
        try await waitForCompleted(viewModel, reaching: terminados + 1)
        #expect(viewModel.debugCalculationRuns == terminados + 1)
    }
}
