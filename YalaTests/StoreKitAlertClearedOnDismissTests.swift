//
//  StoreKitAlertClearedOnDismissTests.swift
//  YalaTests
//
//  Lote 12.7 · card `tablero-bug-el-aviso-de-error-de-storekit-no-se-y5zz` (ticket
//  `paywall-storekit-alert-is-never-cleared`). Las vistas que enseñan el aviso de StoreKit lo abren en el
//  `onChange(of: store.errorMessage)`: si no lo vacían al cerrarlo, el mismo error otra vez no avisa y un
//  `alertTitle` viejo titula el error siguiente. El lote 06 lo arregló en «Función Pro»; aquí se fija en TODAS.
//
//  Es un source-scan porque el aviso lo presenta SwiftUI: el estado que importa es lo que hace el botón.
//  Recorre `Yala/` entero, así que una cuarta vista que copie el `.alert(store.alertTitle …` entra sola.
//

import Foundation
import Testing

@Suite("StoreKit · el aviso se vacía al cerrarlo")
struct StoreKitAlertClearedOnDismissTests {

    private static let alertMarker = ".alert(store.alertTitle"

    /// Las tres que lo enseñan hoy. Si baja, el escáner dejó de ver alguna; si sube, entra una nueva y se revisa.
    private static let expectedViews: Set<String> = [
        "UpgradePromptSheet.swift",
        "SubscriptionView.swift",
        "ProTrialOfferSheet.swift",
    ]

    @Test func everyStoreAlertClearsItsMessageAndTitleOnDismiss() throws {
        let files = try Self.swiftFiles(under: Self.repoRoot().appendingPathComponent("Yala"))
        var found: Set<String> = []
        for url in files {
            let source = try String(contentsOf: url, encoding: .utf8)
            guard source.contains(Self.alertMarker) else { continue }
            let name = url.lastPathComponent
            found.insert(name)

            // El botón del aviso llama a `clearStoreAlert()`.
            let start = try #require(source.range(of: Self.alertMarker), "\(name)")
            let tail = source[start.upperBound...]
            let messageStart = try #require(tail.range(of: "} message: {"), "\(name): el aviso no tiene message")
            let buttons = String(tail[..<messageStart.lowerBound])
            #expect(buttons.contains("{ clearStoreAlert() }"), "\(name): el botón del aviso no lo vacía")

            // Y `clearStoreAlert()` vacía los dos campos, no solo el mensaje.
            let bodyStart = try #require(source.range(of: "private func clearStoreAlert() {"),
                                         "\(name): falta clearStoreAlert()")
            let afterBody = source[bodyStart.upperBound...]
            let bodyEnd = try #require(afterBody.range(of: "\n    }"), "\(name)")
            let body = afterBody[..<bodyEnd.lowerBound]
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            #expect(body == ["store.errorMessage = nil", "store.alertTitle = nil"], "\(name): \(body)")
        }
        #expect(found == Self.expectedViews)
    }

    // MARK: - Helpers

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func swiftFiles(under root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}
