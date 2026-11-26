//
//  SegundoPlanoCableadoTests.swift
//  YalaTests
//
//  Lote 3 de eficiencia (26-nov-2026): el cableado que la lógica no ve. Tirar para actualizar pasa por la firma del
//  Panel; el cálculo del Panel se parte en etapas cortables; Spotlight lee por tramos en contextos propios, observa el
//  paso a segundo plano y deja de escribir en el índice con la app fuera.
//

import Foundation
import Testing

@Suite("Segundo plano · cableado (source-scan)")
struct SegundoPlanoCableadoTests {

    private static func repoFile(_ path: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    /// Sin comentarios y con los espacios colapsados.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    /// El cuerpo entre la primera llave después de `start` y su pareja.
    private static func block(from start: String.Index, in code: String) -> String {
        guard let open = code[start...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var index = open
        while index < code.endIndex {
            if code[index] == "{" { depth += 1 }
            if code[index] == "}" { depth -= 1; if depth == 0 { return String(code[open...index]) } }
            index = code.index(after: index)
        }
        return ""
    }

    @Test func tirarParaActualizar_pasaPorLaFirma() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Panel/PanelView.swift"))
        let start = try #require(code.range(of: "private func refreshData() async"))
        let body = Self.block(from: start.upperBound, in: code)
        #expect(body.contains("viewModel.refreshIfStale()"))
        #expect(!body.contains("reloadAndRecalculate()"), "tirar para actualizar vuelve a recalcular siempre")
    }

    @Test func elCalculoDelPanel_esPorEtapasCortables() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/ViewModels/PanelViewModel.swift"))
        let start = try #require(code.range(of: "private func performCalculationInStages() async -> Bool"))
        let body = Self.block(from: start.upperBound, in: code)
        let checks = body.components(separatedBy: "guard await continuesAfterStage(context: context) else { return false }")
        #expect(checks.count - 1 >= 4, "el cálculo tiene que ceder el hilo entre sus etapas")
        // El hero, la última etapa, va detrás del último corte.
        let lastCut = try #require(body.range(of: "continuesAfterStage", options: .backwards))
        let hero = try #require(body.range(of: "calculateHeroWidget("))
        #expect(lastCut.lowerBound < hero.lowerBound)

        let gate = try #require(code.range(of: "private func continuesAfterStage(context: ModelContext) async -> Bool"))
        let gateBody = Self.block(from: gate.upperBound, in: code)
        for term in ["Task.isCancelled", "isInBackground", "isApplicationInForeground()", "boundStore.isDetached"] {
            #expect(gateBody.contains(term), "la pausa entre etapas no mira \(term)")
        }
        // El cálculo síncrono de antes no vuelve.
        #expect(!code.contains("private func performCalculation() {"))
    }

    @Test func spotlight_leePorTramosEnContextosPropios() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/Services/Spotlight/SpotlightIndexService.swift"))
        let start = try #require(code.range(of: "static func desiredEntries("))
        let body = Self.block(from: start.upperBound, in: code)
        #expect(body.contains("readSlice(container: container"))
        #expect(body.contains("try await Task.sleep(for: .milliseconds(1))"), "sin pausa entre tramos")
        #expect(body.contains("Task.detached"), "las entradas se arman fuera del hilo principal")
        #expect(!body.contains("context.fetch("), "lee con el contexto de la app, de una vez")

        let slice = try #require(code.range(of: "private static func readSlice("))
        let sliceBody = Self.block(from: slice.upperBound, in: code)
        #expect(sliceBody.contains("ModelContext(container)"))
        #expect(sliceBody.contains("descriptor.fetchLimit = readSliceSize"))
    }

    @Test func spotlight_seCortaEnSegundoPlano() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/Services/Spotlight/SpotlightIndexService.swift"))
        #expect(code.contains("UIApplication.didEnterBackgroundNotification"))
        #expect(code.contains("UIApplication.willEnterForegroundNotification"))
        let schedule = try #require(code.range(of: "static func scheduleReconcile(context: ModelContext"))
        #expect(Self.block(from: schedule.upperBound, in: code).contains("observeLifecycleOnce()"))

        let reconcile = try #require(code.range(of: "private static func reconcile(context: ModelContext)"))
        let body = Self.block(from: reconcile.upperBound, in: code)
        // Cada tramo de escritura mira el freno de segundo plano; cortado, el catch olvida firma y estado.
        #expect(body.components(separatedBy: "ReconcileSuspension.check(suspended: isSuspendedInBackground)").count - 1 == 2)
        #expect(body.contains("ReconcileSuspension.check(cancelled: Task.isCancelled"))

        let enter = try #require(code.range(of: "static func enterBackground()"))
        let enterBody = Self.block(from: enter.upperBound, in: code)
        #expect(enterBody.contains("reconcileTask?.cancel()"))
        #expect(enterBody.contains("SpotlightAlVolver.olvidar()"))
    }
}
