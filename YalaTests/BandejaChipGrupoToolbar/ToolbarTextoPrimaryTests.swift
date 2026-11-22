//
//  ToolbarTextoPrimaryTests.swift
//  YalaTests
//
//  El texto de los botones de la barra en primary, en toda la app (decisión de Jürgen del 22-nov-2026): «Editar» de la
//  hoja de cuenta del Panel salía en índigo, porque en la barra un `Button` toma el tinte de la app. Ahora todo botón de
//  texto de la barra es `YalaToolbarTextButton`, que fija el tinte a primary.
//
//  Source-scan sobre `Yala/App`: dentro de un `ToolbarItem` / `ToolbarItemGroup` no hay un `Button` con título de texto
//  ni un `Button { } label: { Text(…) }` crudos. Lo que va dentro de un `Menu` de la barra son filas del menú, no
//  botones de la barra, y no cuenta. Los botones de texto que la barra recibe de un componente propio se fijan aparte.
//

import Foundation
import Testing

@Suite("Barra · texto de los botones en primary (source-scan)")
struct ToolbarTextoPrimaryTests {

    private static let repoRoot: URL = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// El código sin las líneas de comentario, para que documentar el patrón no cuente como usarlo.
    private static func code(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func appFiles() throws -> [URL] {
        let app = repoRoot.appending(path: "Yala/App")
        return try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
    }

    /// El índice del cierre que empareja la apertura en `start` (`(`↔`)` o `{`↔`}`).
    private static func matching(_ chars: [Character], from start: Int) -> Int {
        let open = chars[start]
        let close: Character = open == "(" ? ")" : "}"
        var depth = 0
        var index = start
        while index < chars.count {
            if chars[index] == open { depth += 1 }
            if chars[index] == close {
                depth -= 1
                if depth == 0 { return index }
            }
            index += 1
        }
        return chars.count - 1
    }

    /// Los cuerpos `{ … }` de cada `ToolbarItem(…)` y `ToolbarItemGroup(…)` del fichero, con la línea donde empiezan.
    private static func toolbarItemBodies(_ source: String) -> [(line: Int, body: String)] {
        let chars = Array(source)
        let pattern = try? NSRegularExpression(pattern: #"ToolbarItem(Group)?\s*\("#)
        let ns = source as NSString
        let matches = pattern?.matches(in: source, range: NSRange(location: 0, length: ns.length)) ?? []
        var result: [(Int, String)] = []
        for match in matches {
            // Las posiciones de NSString y de Character difieren con texto no ASCII: se recalculan sobre el prefijo.
            let prefix = ns.substring(to: match.range.location + match.range.length)
            let parenOpen = prefix.count - 1
            let parenClose = matching(chars, from: parenOpen)
            guard let braceOpen = chars[(parenClose + 1)...].firstIndex(of: "{") else { continue }
            let braceClose = matching(chars, from: braceOpen)
            let body = String(chars[braceOpen...braceClose])
            let line = chars[..<parenOpen].filter { $0 == "\n" }.count + 1
            result.append((line, body))
        }
        return result
    }

    /// Quita del cuerpo lo que va dentro de un `Menu { … }`: son filas del menú, no botones de la barra.
    private static func withoutMenuContents(_ body: String) -> String {
        var chars = Array(body)
        var index = 0
        while index + 4 <= chars.count {
            let isToken = String(chars[index..<(index + 4)]) == "Menu"
                && (index == 0 || !(chars[index - 1].isLetter || chars[index - 1].isNumber || chars[index - 1] == "_"))
            guard isToken else {
                index += 1
                continue
            }
            var cursor = index + 4
            while cursor < chars.count, chars[cursor].isWhitespace { cursor += 1 }
            if cursor < chars.count, chars[cursor] == "(" {
                cursor = matching(chars, from: cursor) + 1
                while cursor < chars.count, chars[cursor].isWhitespace { cursor += 1 }
            }
            if cursor < chars.count, chars[cursor] == "{" {
                let close = matching(chars, from: cursor)
                chars.removeSubrange((cursor + 1)..<close)
            }
            index += 4
        }
        return String(chars)
    }

    /// Botones de texto crudos en un cuerpo de `ToolbarItem`.
    private static func rawTextButtons(in body: String) -> [String] {
        let scanned = withoutMenuContents(body)
        let patterns = [
            // `Button(L10n.Action.edit) { … }`, `Button("…")`, `Button(title, action: …)`.
            #"(?<![\w.])Button\s*\(\s*(?!action:|role:|intent:|\)|\{)"#,
            // `Button { … } label: { Text(…) }`.
            #"label:\s*\{\s*Text\("#,
        ]
        let ns = scanned as NSString
        var found: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: scanned, range: NSRange(location: 0, length: ns.length)) {
                let end = min(ns.length, match.range.location + 60)
                found.append(ns.substring(with: NSRange(location: match.range.location, length: end - match.range.location))
                    .replacingOccurrences(of: "\n", with: " "))
            }
        }
        return found
    }

    @Test func ningúnBotónDeTextoDeLaBarra_vaSinElComponente() throws {
        let files = try Self.appFiles()
        #expect(files.count > 100, "El recorrido no encontró las vistas: el scan no estaría mirando nada.")
        var offenders: [String] = []
        var itemsSeen = 0
        for url in files {
            let relative = String(url.path.dropFirst(Self.repoRoot.path.count + 1))
            for item in Self.toolbarItemBodies(try Self.code(url)) {
                itemsSeen += 1
                for hit in Self.rawTextButtons(in: item.body) {
                    offenders.append("\(relative):~\(item.line) \(hit)")
                }
            }
        }
        #expect(itemsSeen > 150, "Pocos ToolbarItem encontrados (\(itemsSeen)): el scan no estaría mirando la app.")
        #expect(offenders.isEmpty, """
            Botón de texto en la barra sin `YalaToolbarTextButton` (saldría con el tinte índigo de la app, no en primary): \
            \(offenders.joined(separator: " · "))
            """)
    }

    /// El escáner caza los dos moldes crudos y deja pasar el componente y las filas de un menú.
    @Test func elEscáner_distingueLoCrudoDeLoBueno() {
        #expect(Self.rawTextButtons(in: "{ Button(L10n.Action.edit) { edit() } }").count == 1)
        #expect(Self.rawTextButtons(in: "{ Button { edit() } label: { Text(L10n.Action.edit) } }").count == 1)
        #expect(Self.rawTextButtons(in: "{ YalaToolbarTextButton(L10n.Action.edit) { edit() } }").isEmpty)
        #expect(Self.rawTextButtons(in: "{ YalaToolbarButton(systemName: \"xmark\", label: L10n.Action.close) { } }").isEmpty)
        #expect(Self.rawTextButtons(in: "{ Button { close() } label: { Image(systemName: \"xmark\") } }").isEmpty)
        #expect(Self.rawTextButtons(in: "{ Menu { Button(L10n.Action.delete) { } } label: { Image(systemName: \"ellipsis\") } }")
            .isEmpty, "Las filas de un menú de la barra no son botones de la barra.")
    }

    /// Los botones de texto que la barra recibe de un componente propio también van en primary.
    @Test func losComponentesDeBarraDeRegistros_vanEnPrimary() throws {
        let source = try Self.code(Self.repoRoot.appending(path: "Yala/App/Views/Records/Components/RecordsSelectionBar.swift"))
        #expect(source.contains("YalaToolbarTextButton(allSelected"), "«Seleccionar todo» de Registros, en primary.")
        let shared = try Self.code(Self.repoRoot.appending(path: "Yala/App/Views/Records/Compartida/RecordsSharedList.swift"))
        #expect(shared.contains(".tint(selectIconOnly ? accent : Color.primary)"),
                "«Seleccionar» de Registros con texto, en primary (el de solo ícono sigue con el acento).")
    }
}
