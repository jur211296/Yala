//
//  VolverSinRecalcularCableadoTests.swift
//  YalaTests
//
//  El cableado del lote 1 de eficiencia, leído del código. Ningún `onChange(of: scenePhase)` de `Yala/App` recarga a
//  pelo (`reloadAndRecalculate()` o `scheduleRecalculate()` sin una firma delante): esa línea, en seis pantallas montadas a
//  la vez, dejaba la app 16-25 s al 100 % en cada vuelta con 16 k movimientos. Las seis pantallas que lo hacían pasan
//  por `VueltaAPrimerPlano.alVolver` con su página visible, y Spotlight solo reconcilia al volver si su firma cambió.
//

import Foundation
import Testing

@Suite("Volver sin recalcular · cableado (source-scan)")
struct VolverSinRecalcularCableadoTests {

    private static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func repoFile(_ path: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// El código sin comentarios, con los espacios colapsados.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n")
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { return "" }
                if let range = trimmed.range(of: " //") { return String(trimmed[..<range.lowerBound]) }
                return trimmed
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// El cuerpo entre llaves que empieza en la primera `{` tras `start`.
    private static func block(from start: String.Index, in code: String) -> String {
        var depth = 0
        var opened = false
        var index = start
        var body = ""
        while index < code.endIndex {
            let char = code[index]
            if char == "{" {
                depth += 1
                opened = true
            } else if char == "}" {
                depth -= 1
                if opened && depth == 0 { break }
            }
            if opened { body.append(char) }
            index = code.index(after: index)
        }
        return body
    }

    /// Lo que hace cada `.onChange(of: scenePhase)` del fichero, siguiendo un `handleScenePhase(_:)` si delega en él.
    private static func scenePhaseHandlers(in code: String) -> [String] {
        var handlers: [String] = []
        var searchFrom = code.startIndex
        while let range = code.range(of: ".onChange(of: scenePhase)", range: searchFrom..<code.endIndex) {
            var body = block(from: range.upperBound, in: code)
            if body.contains("handleScenePhase("),
               let function = code.range(of: "func handleScenePhase(") {
                body += " " + block(from: function.upperBound, in: code)
            }
            handlers.append(body)
            searchFrom = range.upperBound
        }
        return handlers
    }

    /// Las seis pantallas del informe: recargaban en cada vuelta.
    private static let screens = [
        "Yala/App/Views/Panel/PanelView.swift",
        "Yala/App/Views/Statistics/DetailContainerView.swift",
        "Yala/App/Views/Records/RecordsStandaloneView.swift",
        "Yala/App/Views/Groups/GroupsContainerView.swift",
        "Yala/App/Views/Groups/GroupDetailView.swift",
        "Yala/App/Views/Reports/FinancialReportView.swift",
    ]

    /// Una recarga a pelo: la llamada sin una firma que la decida delante.
    private static func bareReloads(in handler: String) -> [String] {
        let guarded = ["if reload { viewModel.reloadAndRecalculate() }", "if reload { reloadAndRecalculate() }"]
        var rest = handler
        for allowed in guarded { rest = rest.replacingOccurrences(of: allowed, with: "") }
        return ["reloadAndRecalculate()", "scheduleRecalculate()"].filter { rest.contains($0) }
    }

    @Test(arguments: screens)
    func cadaPantalla_vuelvePorLaFirma(_ path: String) throws {
        let code = Self.codeOnly(try Self.repoFile(path))
        let handlers = Self.scenePhaseHandlers(in: code)
        try #require(handlers.count == 1, "\(path): esperaba un `onChange(of: scenePhase)`, hay \(handlers.count)")
        let handler = try #require(handlers.first)
        #expect(handler.contains("VueltaAPrimerPlano.alVolver("), "\(path) no vuelve por `VueltaAPrimerPlano`")
        #expect(handler.contains("paginaVisible: isRootPageShown"), "\(path) no mira si su página se ve")
        #expect(Self.bareReloads(in: handler).isEmpty, "\(path) recarga a pelo al volver: \(Self.bareReloads(in: handler))")
    }

    /// Ninguna pantalla de `Yala/App`, de las seis o nueva, recarga a pelo en su `onChange(of: scenePhase)`.
    @Test func ningunScenePhaseDeLaApp_recargaAPelo() throws {
        let appDir = Self.root.appendingPathComponent("Yala/App")
        let enumerator = try #require(FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil))
        var offenders: [String] = []
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            guard text.contains("onChange(of: scenePhase)") else { continue }
            let code = Self.codeOnly(text)
            for handler in Self.scenePhaseHandlers(in: code) {
                scanned += 1
                if !Self.bareReloads(in: handler).isEmpty { offenders.append(url.lastPathComponent) }
            }
        }
        #expect(scanned >= Self.screens.count, "el barrido no encontró los `onChange(of: scenePhase)` (\(scanned))")
        #expect(offenders.isEmpty, "recargan a pelo al volver: \(offenders)")
    }

    @Test func cadaPantallaQueComparaAlVolver_firmaAlIrse() throws {
        for path in ["Yala/App/Views/Records/RecordsStandaloneView.swift",
                     "Yala/App/Views/Groups/GroupsContainerView.swift",
                     "Yala/App/Views/Groups/GroupDetailView.swift"] {
            let code = Self.codeOnly(try Self.repoFile(path))
            var handler = try #require(Self.scenePhaseHandlers(in: code).first)
            // Registros compara en su propia función.
            if handler.contains("reloadIfChangedWhileAway()"),
               let function = code.range(of: "private func reloadIfChangedWhileAway()") {
                handler += " " + Self.block(from: function.upperBound, in: code)
            }
            #expect(handler.contains("case .background, .inactive: frescura.alIrse(currentFirma())"),
                    "\(path) no apunta la firma al irse")
            #expect(handler.contains("frescura.alVolverVisible("), "\(path) no compara la firma al volver")
        }
    }

    @Test func registros_alAparecerTrasUnaVueltaOculta_comparaLaFirma() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/Views/Records/RecordsStandaloneView.swift"))
        #expect(code.contains(".onAppear { dataViewModel.setContext(modelContext) appearAfterSetContext() }"))
        let appear = try #require(code.range(of: "private func appearAfterSetContext()"))
        #expect(Self.block(from: appear.upperBound, in: code).contains("frescura.alAparecer("))
    }

    @Test func spotlight_alVolverSoloReconciliaSiCambio() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/App/AppBootstrapper.swift"))
        let start = try #require(code.range(of: "func handleBecameActive(context: ModelContext)"))
        let body = Self.block(from: start.upperBound, in: code)
        #expect(body.contains(
            "if SpotlightAlVolver.debeReconciliar(ahora: SpotlightIndexService.currentFirma()) { "
                + "SpotlightIndexService.scheduleReconcile(context: context) }"))
        #expect(body.components(separatedBy: "SpotlightIndexService.scheduleReconcile(").count == 2,
                "la vuelta reconcilia Spotlight por otro camino")
        // La firma ve lo que bajó CloudKit: los cambios pendientes se aplican antes.
        let applies = try #require(body.range(of: "sessionState.applyPendingChangesIfNeeded()"))
        let gate = try #require(body.range(of: "SpotlightAlVolver.debeReconciliar("))
        #expect(applies.lowerBound < gate.lowerBound)
    }

    @Test func spotlight_laReconciliacionApuntaLaFirma_yLaOlvidaSiFalla() throws {
        let code = Self.codeOnly(try Self.repoFile("Yala/Services/Spotlight/SpotlightIndexService.swift"))
        let start = try #require(code.range(of: "private static func reconcile(context: ModelContext)"))
        let body = Self.block(from: start.upperBound, in: code)
        let note = try #require(body.range(of: "SpotlightAlVolver.anotarReconciliacion(currentFirma())"))
        let read = try #require(body.range(of: "desiredEntries(context: context)"))
        #expect(note.lowerBound < read.lowerBound, "la firma se toma después de leer")
        #expect(body.components(separatedBy: "SpotlightAlVolver.olvidar()").count == 3,
                "un fallo de lectura o de escritura del índice tiene que olvidar la firma")
    }
}
