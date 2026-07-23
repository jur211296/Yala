//
//  CloudKitGroupsSchemaParityTests.swift
//  YalaTests
//
//  Paridad código ↔ schema del container de GRUPOS (iCloud.com.jurgenschmidt.yala.groups).
//
//  El sim corre grupos sin CloudKit, así que un campo nuevo en CKConstants/CKRecordTranslator no se
//  autocrea NI en Development; en Production el server RECHAZA todo save del record type y
//  CKSyncEngine descarta el record de su cola en silencio (incidente `isOpeningBalance`,
//  27-jun→1-jul: sync de grupos muerto bidireccional 4 días). Este test convierte la regla de
//  proceso ("campo nuevo ⇒ deploy del schema + actualizar Cloudkit Schemas/groups-production.ckdb en el
//  mismo PR") en un gate ejecutable: parsea los field keys REALES del código fuente
//  (CloudKitConstants.swift, vía #filePath — mismo patrón que LocalizationParityTests) y los
//  cruza contra el snapshot del schema desplegado (`Cloudkit Schemas/groups-production.ckdb`).
//
//  El .ckdb es un CONTRATO: solo se actualiza cuando el schema real se despliega a Production.
//

import Foundation
import Testing

@Suite("CloudKit Groups Schema Parity")
struct CloudKitGroupsSchemaParityTests {

    /// Enum de campos en CloudKitConstants.swift → record type de CloudKit.
    private static let fieldEnumToRecordType: [String: String] = [
        "GroupMetaField": "GroupMeta",
        "ExpenseField": "SplitExpense",
        "MemberField": "SplitMember",
        "ShareField": "SplitShare",
        "SettlementField": "SplitSettlement",
    ]

    // MARK: - Paths (vía #filePath — el runner de tests no empaqueta estos archivos como resources)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static var constantsURL: URL {
        repoRoot.appendingPathComponent("Yala/Services/Groups/CloudKitConstants.swift")
    }

    private static var schemaURL: URL {
        // 2026-07-10: los snapshots-contrato viven en `Cloudkit Schemas/` (carpeta del owner con la
        // última versión desplegada de CADA container/entorno; reemplazó a los .ckdb sueltos de la raíz).
        // 2026-07-23: renombrados a la convención por sufijo de container — `groups-*.ckdb` (`.groups`,
        // prod) y `groups_dev-*.ckdb` (`.groups.dev`). Este contrato es el del container PROD (`.groups`).
        repoRoot.appendingPathComponent("Cloudkit Schemas/groups-production.ckdb")
    }

    // MARK: - Parsers

    /// Extrae `enumName → Set(valores de `static let x = "valor"`)` de CloudKitConstants.swift.
    /// Parseo por líneas: los enums de campos son planos (sin anidación interna).
    private static func parseFieldEnums(source: String) throws -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        var currentEnum: String?
        let enumRegex = try NSRegularExpression(pattern: #"enum\s+(\w+)\s*\{"#)
        let letRegex = try NSRegularExpression(pattern: #"static\s+let\s+\w+\s*=\s*"([^"]+)""#)

        for line in source.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            if let match = enumRegex.firstMatch(in: line, range: range),
               let nameRange = Range(match.range(at: 1), in: line) {
                let name = String(line[nameRange])
                currentEnum = fieldEnumToRecordType.keys.contains(name) ? name : nil
                continue
            }
            guard let enumName = currentEnum else { continue }
            // hasPrefix, no ==: un `} // comentario` dejaría el enum abierto y atribuiría los
            // `static let` siguientes (p.ej. zonePrefix) al enum equivocado.
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("}") {
                currentEnum = nil
                continue
            }
            if let match = letRegex.firstMatch(in: line, range: range),
               let valueRange = Range(match.range(at: 1), in: line) {
                result[enumName, default: []].insert(String(line[valueRange]))
            }
        }
        return result
    }

    /// Extrae `recordType → Set(fieldName)` de un export `.ckdb` (`DEFINE SCHEMA`).
    /// Formato por línea: `RECORD TYPE Nombre (` abre bloque; dentro, el primer token es el nombre
    /// del campo (con o sin comillas); `GRANT ...` y `);` no son campos.
    private static func parseSchema(_ text: String) throws -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        var currentType: String?
        let typeRegex = try NSRegularExpression(pattern: #"RECORD\s+TYPE\s+"?([\w.]+)"?\s*\("#)

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let range = NSRange(line.startIndex..., in: line)
            if let match = typeRegex.firstMatch(in: line, range: range),
               let nameRange = Range(match.range(at: 1), in: line) {
                currentType = String(line[nameRange])
                result[currentType!] = []
                continue
            }
            guard let type = currentType else { continue }
            if line.hasPrefix(")") { currentType = nil; continue }
            if line.hasPrefix("GRANT") || line.isEmpty { continue }
            guard let firstToken = line.split(separator: " ").first else { continue }
            let fieldName = firstToken.trimmingCharacters(in: CharacterSet(charactersIn: "\","))
            guard !fieldName.isEmpty else { continue }
            result[type, default: []].insert(fieldName)
        }
        return result
    }

    // MARK: - Tests

    @Test func everyCodeFieldKey_existsInDeployedSchema() throws {
        let source = try String(contentsOf: Self.constantsURL, encoding: .utf8)
        let schemaText = try String(contentsOf: Self.schemaURL, encoding: .utf8)

        let codeFields = try Self.parseFieldEnums(source: source)
        let schema = try Self.parseSchema(schemaText)

        // Guards anti-regresión del parseo: un refactor de formato que vacíe los sets convertiría
        // el test en un falso verde silencioso.
        #expect(codeFields.count == Self.fieldEnumToRecordType.count,
                "Parseo de CloudKitConstants.swift incompleto — enums encontrados: \(codeFields.keys.sorted())")
        for (enumName, fields) in codeFields {
            #expect(!fields.isEmpty, "Enum \(enumName) parseado sin campos — revisar el parser o el formato del archivo")
        }

        for (enumName, recordType) in Self.fieldEnumToRecordType {
            let expected = codeFields[enumName] ?? []
            guard let deployed = schema[recordType] else {
                Issue.record("Record type \(recordType) NO existe en cloudkit-groups-production.ckdb")
                continue
            }
            let missing = expected.subtracting(deployed).sorted()
            #expect(missing.isEmpty, """
            Campos de \(recordType) (\(enumName)) que el código escribe pero NO están en \
            cloudkit-groups-production.ckdb: \(missing). ⇒ Desplegar el schema del container de \
            grupos a Production (CloudKit Console) Y actualizar el .ckdb del repo en el MISMO PR \
            (regla CLAUDE.md — el server rechaza saves con campos desconocidos y CKSyncEngine los \
            descarta en silencio; incidente isOpeningBalance 27-jun→1-jul).
            """)
        }
    }

    @Test func schemaSnapshot_hasAllGroupRecordTypes() throws {
        let schemaText = try String(contentsOf: Self.schemaURL, encoding: .utf8)
        let schema = try Self.parseSchema(schemaText)
        for recordType in Self.fieldEnumToRecordType.values {
            #expect(schema[recordType]?.isEmpty == false,
                    "Record type \(recordType) ausente o vacío en cloudkit-groups-production.ckdb")
        }
    }
}
