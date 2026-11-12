//
//  ControlCenterNewRecordWiringTests.swift
//  YalaTests
//
//  El control «Nuevo registro» del Centro de Control (tanda 3 del rediseño de los widgets, S35f2). Su intent vive en
//  `Yala/Shared/ControlCenterIntents.swift`, que solo compila la extensión, así que la red es leer las fuentes: cada
//  acción que un intent deja en `pendingControlAction` tiene su caso en `AppBootstrapper.checkForPendingControlAction`
//  (una acción sin caso se borraba sin hacer nada, que es como habría quedado «new-transaction»), y el control está
//  registrado en el bundle.
//

import Foundation
import Testing

struct ControlCenterNewRecordWiringTests {

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }

    /// El cuerpo de `checkForPendingControlAction`, hasta la función siguiente.
    private static func controlActionHandler() throws -> String {
        let boot = try source("Yala/App/AppBootstrapper.swift")
        let start = try #require(boot.range(of: "private func checkForPendingControlAction() {"))
        let end = try #require(boot.range(of: "\n    private func ", range: start.upperBound..<boot.endIndex))
        return String(boot[start.upperBound..<end.lowerBound])
    }

    /// Cada valor que un intent del Centro de Control escribe en la clave tiene su `case` en la app.
    @Test func cadaAccionDelCentroDeControlTieneSuCasoEnLaApp() throws {
        let intents = try Self.source("Yala/Shared/ControlCenterIntents.swift")
        let written = intents.matches(of: /defaults\.set\("([a-z-]+)", forKey: "pendingControlAction"\)/)
            .map { String($0.output.1) }
        #expect(Set(written) == ["new-transaction", "voice-entry", "image-entry"], "Intents: \(written)")

        let handler = try Self.controlActionHandler()
        for action in written {
            #expect(handler.contains("case \"\(action)\":"), "La app no atiende «\(action)» del Centro de Control.")
        }
    }

    /// «new-transaction» abre el formulario por el mismo camino que el widget y el atajo (`executeAction`, que lleva al
    /// Panel y respeta la sesión solo grupos), no con una presentación propia.
    @Test func nuevoRegistroVaPorElCaminoDelWidget() throws {
        let handler = try Self.controlActionHandler()
        let caseRange = try #require(handler.range(of: "case \"new-transaction\":"))
        let next = handler.range(of: "case \"", range: caseRange.upperBound..<handler.endIndex)?.lowerBound ?? handler.endIndex
        #expect(handler[caseRange.upperBound..<next].contains("executeAction(.newTransaction)"))
    }

    /// El control existe, abre la app con su intent y está en el bundle.
    @Test func elControlEstaRegistrado() throws {
        let controls = try Self.source("YalaWidgets/ControlWidgets.swift")
        #expect(controls.contains("struct NewRecordControl: ControlWidget"))
        #expect(controls.contains("ControlWidgetButton(action: OpenNewTransactionIntent())"))
        let intents = try Self.source("Yala/Shared/ControlCenterIntents.swift")
        let intent = try #require(intents.range(of: "struct OpenNewTransactionIntent: AppIntent {"))
        #expect(intents[intent.upperBound...].contains("static var openAppWhenRun: Bool = true"))
        let bundle = try Self.source("YalaWidgets/YalaWidgetsBundle.swift")
        #expect(bundle.contains("NewRecordControl()"))
    }

    /// Sus dos textos están en los 16 idiomas del widget.
    @Test func susTextosEstanEnTodosLosIdiomas() throws {
        let resources = Self.root.appending(path: "YalaWidgets/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: resources.path).filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let strings = try Self.source("YalaWidgets/Resources/\(locale)/Localizable.strings")
            for key in ["widget.control.newRecord", "widget.control.newRecord.desc"] {
                #expect(strings.contains("\"\(key)\" = \""), "\(locale) no tiene \(key)")
            }
        }
    }
}
