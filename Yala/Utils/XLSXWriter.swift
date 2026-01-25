//
//  XLSXWriter.swift
//  Yala
//
//  Escritor de archivos Excel (.xlsx) para exportación de transacciones.
//  Genera archivos XLSX manualmente usando ZIPFoundation (dependencia de CoreXLSX).
//  XLSX es simplemente un archivo ZIP con XMLs estructurados.
//

import Foundation
import ZIPFoundation

// MARK: - XLSX Writer

enum XLSXWriter {

    // MARK: - Errors

    enum XLSXWriteError: LocalizedError {
        case cannotCreateArchive
        case cannotWriteFile

        var errorDescription: String? {
            switch self {
            case .cannotCreateArchive:
                return "No se pudo crear el archivo XLSX."
            case .cannotWriteFile:
                return "No se pudo escribir el archivo."
            }
        }
    }

    // MARK: - Public API

    /// Escribe un archivo XLSX con los datos proporcionados.
    ///
    /// - Parameters:
    ///   - url: URL donde guardar el archivo.
    ///   - headers: Array de nombres de columnas.
    ///   - rows: Array de filas, cada fila es un array de valores string.
    static func write(to url: URL, headers: [String], rows: [[String]]) throws {
        // Crear archivo temporal
        let tempDir = FileManager.default.temporaryDirectory
        let workDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: workDir)
        }

        // Crear estructura de directorios XLSX
        let xlDir = workDir.appendingPathComponent("xl")
        let relsDir = workDir.appendingPathComponent("_rels")
        let xlRelsDir = xlDir.appendingPathComponent("_rels")
        let worksheetsDir = xlDir.appendingPathComponent("worksheets")

        try FileManager.default.createDirectory(at: xlDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: xlRelsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worksheetsDir, withIntermediateDirectories: true)

        // Escribir archivos XML
        try writeContentTypes(to: workDir.appendingPathComponent("[Content_Types].xml"))
        try writeRootRels(to: relsDir.appendingPathComponent(".rels"))
        try writeWorkbookRels(to: xlRelsDir.appendingPathComponent("workbook.xml.rels"))
        try writeWorkbook(to: xlDir.appendingPathComponent("workbook.xml"))
        try writeStyles(to: xlDir.appendingPathComponent("styles.xml"))
        try writeSharedStrings(to: xlDir.appendingPathComponent("sharedStrings.xml"), headers: headers, rows: rows)
        try writeWorksheet(to: worksheetsDir.appendingPathComponent("sheet1.xml"), headers: headers, rows: rows)

        // Crear archivo ZIP
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .create)
        } catch {
            throw XLSXWriteError.cannotCreateArchive
        }

        // Agregar todos los archivos al ZIP
        try addToArchive(archive, directory: workDir, relativeTo: workDir)
    }

    /// Genera una plantilla XLSX vacía con solo los encabezados.
    static func writeTemplate(to url: URL, headers: [String]) throws {
        try write(to: url, headers: headers, rows: [])
    }

    // MARK: - Private XML Generators

    private static func writeContentTypes(to url: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
            <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeRootRels(to url: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeWorkbookRels(to url: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeWorkbook(to url: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <sheets>
                <sheet name="Transacciones" sheetId="1" r:id="rId1"/>
            </sheets>
        </workbook>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeStyles(to url: URL) throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <fonts count="2">
                <font><sz val="11"/><name val="Calibri"/></font>
                <font><b/><sz val="11"/><name val="Calibri"/></font>
            </fonts>
            <fills count="2">
                <fill><patternFill patternType="none"/></fill>
                <fill><patternFill patternType="gray125"/></fill>
            </fills>
            <borders count="1">
                <border><left/><right/><top/><bottom/><diagonal/></border>
            </borders>
            <cellStyleXfs count="1">
                <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
            </cellStyleXfs>
            <cellXfs count="2">
                <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
                <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
            </cellXfs>
        </styleSheet>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeSharedStrings(to url: URL, headers: [String], rows: [[String]]) throws {
        var allStrings: [String] = []
        allStrings.append(contentsOf: headers)
        for row in rows {
            allStrings.append(contentsOf: row)
        }

        var siElements = ""
        for str in allStrings {
            let escaped = escapeXML(str)
            siElements += "<si><t>\(escaped)</t></si>"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(allStrings.count)" uniqueCount="\(allStrings.count)">
        \(siElements)
        </sst>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func writeWorksheet(to url: URL, headers: [String], rows: [[String]]) throws {
        var sheetData = ""
        var stringIndex = 0

        // Header row
        sheetData += "<row r=\"1\">"
        for (colIndex, _) in headers.enumerated() {
            let colLetter = columnLetter(colIndex)
            // Use style 1 (bold) for headers, type "s" for shared string
            sheetData += "<c r=\"\(colLetter)1\" t=\"s\" s=\"1\"><v>\(stringIndex)</v></c>"
            stringIndex += 1
        }
        sheetData += "</row>"

        // Data rows
        for (rowIndex, row) in rows.enumerated() {
            let excelRow = rowIndex + 2 // Excel rows are 1-based, +1 for header
            sheetData += "<row r=\"\(excelRow)\">"
            for (colIndex, _) in row.enumerated() {
                if colIndex < headers.count {
                    let colLetter = columnLetter(colIndex)
                    sheetData += "<c r=\"\(colLetter)\(excelRow)\" t=\"s\"><v>\(stringIndex)</v></c>"
                    stringIndex += 1
                }
            }
            sheetData += "</row>"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
            \(sheetData)
            </sheetData>
        </worksheet>
        """
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private static func columnLetter(_ index: Int) -> String {
        var result = ""
        var num = index
        while num >= 0 {
            result = String(UnicodeScalar(65 + (num % 26))!) + result
            num = num / 26 - 1
        }
        return result
    }

    private static func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }

    private static func addToArchive(_ archive: Archive, directory: URL, relativeTo baseURL: URL) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

        for item in contents {
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory)

            let relativePath = item.path.replacingOccurrences(of: baseURL.path + "/", with: "")

            if isDirectory.boolValue {
                try addToArchive(archive, directory: item, relativeTo: baseURL)
            } else {
                try archive.addEntry(with: relativePath, relativeTo: baseURL)
            }
        }
    }
}
