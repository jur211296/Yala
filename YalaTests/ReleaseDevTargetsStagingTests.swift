//
//  ReleaseDevTargetsStagingTests.swift
//  YalaTests
//
//  Lote 12.7 · card `tablero-release-dev-habla-con-el-gateway-de-prod-xel3`. `ProxyConfig.baseURL` y
//  `CloudBackendConfig` eligen staging o producción por `DEV_BUILD`. El bundle `.dev` atesta en `development` y
//  producción solo acepta el bundle de producción en `production`: un build `.dev` sin `DEV_BUILD` habla con
//  producción y no obtiene sesión nunca. Hasta el 2026-10-25 le pasaba al archive de `Yala Dev` (Release-Dev).
//
//  Fija que TODA configuración cuyo target app use el bundle `.dev` compila con `DEV_BUILD` en su nivel de
//  proyecto (de donde lo heredan app, widgets y share).
//

import Foundation
import Testing

@Suite("Release-Dev · el bundle .dev va a staging")
struct ReleaseDevTargetsStagingTests {

    @Test func everyDevBundleConfigurationCompilesWithDevBuild() throws {
        let pbx = try String(contentsOf: Self.repoRoot().appendingPathComponent("Yala.xcodeproj/project.pbxproj"),
                             encoding: .utf8)
        let blocks = Self.buildConfigurations(in: pbx)

        // Las configuraciones cuyo target lleva el bundle `.dev`.
        let devNames = Set(blocks.filter { $0.body.contains("PRODUCT_BUNDLE_IDENTIFIER = com.jurgenschmidt.yala.dev;") }
            .map(\.name))
        #expect(devNames == ["Debug-Dev", "Release-Dev"])

        // El nivel de proyecto (el único bloque con `ALWAYS_SEARCH_USER_PATHS`) de cada una define `DEV_BUILD`.
        for name in devNames {
            let project = blocks.filter { $0.name == name && $0.body.contains("ALWAYS_SEARCH_USER_PATHS") }
            #expect(project.count == 1, "\(name)")
            let conditions = project.first.flatMap { Self.setting("SWIFT_ACTIVE_COMPILATION_CONDITIONS", in: $0.body) }
            #expect(conditions?.split(separator: " ").contains("DEV_BUILD") == true, "\(name): \(conditions ?? "nil")")
        }

        // Y ninguna configuración del bundle de producción lo define: ese sí habla con producción.
        for block in blocks where block.body.contains("ALWAYS_SEARCH_USER_PATHS") && !devNames.contains(block.name) {
            let conditions = Self.setting("SWIFT_ACTIVE_COMPILATION_CONDITIONS", in: block.body) ?? ""
            #expect(!conditions.contains("DEV_BUILD"), "\(block.name)")
        }
    }

    // MARK: - Helpers

    private struct Block { let name: String; let body: String }

    private static func buildConfigurations(in pbx: String) -> [Block] {
        var result: [Block] = []
        var remaining = pbx[...]
        while let start = remaining.range(of: "isa = XCBuildConfiguration;") {
            let after = remaining[start.upperBound...]
            guard let nameRange = after.range(of: "\n\t\t\tname = ") else { break }
            let body = String(after[..<nameRange.lowerBound])
            let lineEnd = after[nameRange.upperBound...].firstIndex(of: ";") ?? after.endIndex
            let name = after[nameRange.upperBound..<lineEnd].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            result.append(Block(name: name, body: body))
            remaining = after[lineEnd...]
        }
        return result
    }

    private static func setting(_ key: String, in body: String) -> String? {
        for line in body.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key) = ") else { continue }
            return String(trimmed.dropFirst(key.count + 3)).trimmingCharacters(in: CharacterSet(charactersIn: "\";"))
        }
        return nil
    }

    private static func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
}
