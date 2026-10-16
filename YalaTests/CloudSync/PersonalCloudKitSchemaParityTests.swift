//
//  PersonalCloudKitSchemaParityTests.swift
//  YalaTests / CloudSync
//
//  Paridad entre los `@Model` del store PERSONAL y los esquemas de iCloud guardados en
//  `Cloudkit Schemas/` (ticket `personal-cloudkit-schema-snapshot-misses-optional-fields`).
//
//  **Por qué hace falta.** SwiftData espeja el store personal a iCloud con
//  `NSPersistentCloudKitContainer`, y CloudKit en Development crea un campo SOLO cuando se guarda un
//  valor que no es `nil`. Un opcional nuevo que nadie rellenó en Development no llega al esquema, no
//  se despliega a Production, y el primer usuario que lo rellena ve su registro rechazado por iCloud
//  sin ningún error visible. El 2026-10-10 faltaban 14 campos en el snapshot del contenedor de
//  producción y 31 en el de `.dev` (`docs/cloudkit-schema-diff-2.1.md`).
//
//  **Qué se compara.** El esquema ESPERADO no se escribe a mano: sale del `NSManagedObjectModel` que
//  SwiftData genera para los mismos tipos (`makeManagedObjectModel(for:)`), que es el que lee el
//  mirroring de CloudKit. Cada atributo se traduce al tipo de campo que crea el mirroring
//  (`CD_<nombre>`), cada relación a-uno a un `STRING` con el recordName del destino, y las relaciones
//  a-muchos no son campo (las guarda el lado a-uno, o `CDMR` si son muchos-a-muchos).
//
//  **Qué NO se exige.** Que el snapshot no tenga campos de más: un campo que la app dejó de escribir
//  sigue en Production para siempre (CloudKit no deja borrarlo) y las versiones viejas lo siguen usando.
//

import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudKit · el esquema personal del repo cubre cada @Model")
struct PersonalCloudKitSchemaParityTests {

    /// Los 17 tipos de `SwiftDataConfiguration.personalSchema`. `Schema` no expone sus tipos, así que la
    /// lista va aquí y `personalTypes_matchPersonalSchema` obliga a mantenerla al día.
    private static let personalTypes: [any PersistentModel.Type] = [
        Category.self,
        Subcategory.self,
        Tag.self,
        Account.self,
        TransactionItem.self,
        Budget.self,
        ExchangeRate.self,
        FavoritePayment.self,
        ScheduledPayment.self,
        InboxDraft.self,
        MerchantMemory.self,
        NotificationItem.self,
        CashFlowPlan.self,
        CashFlowLine.self,
        CashFlowOverride.self,
        GroupBridgePreference.self,
        CloudMigrationMarker.self,
    ]

    /// Los dos contenedores personales: `iCloud.com.jurgenschmidt.yala` (scheme Yala) y
    /// `iCloud.com.jurgenschmidt.yala.dev` (scheme Yala Dev), cada uno en sus dos entornos.
    static let snapshots = [
        "yala-production.ckdb",
        "yala-development.ckdb",
        "yala_dev-production.ckdb",
        "yala_dev-development.ckdb",
    ]

    /// Tipos que el snapshot declara distinto de lo que escribe la app y que NO se pueden corregir en
    /// el fichero: un tipo de campo no cambia nunca en Production. Cada entrada lleva su porqué, no es
    /// una excepción cómoda.
    ///
    /// **`CD_CashFlowOverride.CD_line` (REFERENCE en el contenedor de producción, confirmado el
    /// 2026-10-12) ya está ARREGLADO en código y la entrada se queda a propósito.** La relación pasó a
    /// `CashFlowOverride.cashFlowLine` (campo `CD_cashFlowLine`, STRING). `line` sigue en el modelo como
    /// legado —es lo único que deja leer los ajustes de antes en cada dispositivo— y por eso este test
    /// todavía lo espera como STRING; la app no lo escribe nunca salvo para vaciarlo
    /// (`CashFlowOverrideLineMigration`), y un registro con el campo vacío no lo trae [inferido: el
    /// espejo no pone en el registro una relación a `nil`; lo comprueba el device-QA del ticket]. Que nadie vuelva a
    /// escribirlo lo fija `CashFlowOverrideLineMigrationTests`. Ticket:
    /// `personal-cloudkit-cashflow-override-line-declared-as-reference`.
    static let knownTypeMismatches: [String: [String: String]] = [
        "yala-production.ckdb": ["CD_CashFlowOverride.CD_line": "REFERENCE"],
        "yala-development.ckdb": ["CD_CashFlowOverride.CD_line": "REFERENCE"],
    ]

    private static var schemasDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
            .appendingPathComponent("Cloudkit Schemas")
    }

    // MARK: - Esquema esperado (del modelo de Core Data que genera SwiftData)

    enum Expected: Equatable {
        case field(String)
        case unmapped(String)
    }

    /// `[recordType: [campo: tipo CloudKit]]`, o `unmapped` para un tipo de atributo que este test no sabe
    /// traducir (falla en `everyAttribute_hasAKnownCloudKitType`, en vez de dar un verde falso).
    static func expectedSchema() throws -> [String: [String: Expected]] {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: personalTypes))
        var result: [String: [String: Expected]] = [:]
        for entity in model.entities {
            guard let name = entity.name else { continue }
            var fields: [String: Expected] = ["CD_entityName": .field("STRING")]
            for (attrName, attr) in entity.attributesByName where !attr.isTransient {
                let key = "CD_\(attrName)"
                switch attr.attributeType {
                case .stringAttributeType, .UUIDAttributeType, .URIAttributeType:
                    fields[key] = .field("STRING")
                case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType,
                     .booleanAttributeType:
                    fields[key] = .field("INT64")
                case .doubleAttributeType, .floatAttributeType:
                    fields[key] = .field("DOUBLE")
                case .dateAttributeType:
                    fields[key] = .field("TIMESTAMP")
                case .binaryDataAttributeType, .transformableAttributeType:
                    fields[key] = .field("BYTES")
                    if attr.allowsExternalBinaryDataStorage {
                        fields["CD_\(attrName)_ckAsset"] = .field("ASSET")
                    }
                default:
                    fields[key] = .unmapped("NSAttributeType(\(attr.attributeType.rawValue))")
                }
            }
            for (relName, rel) in entity.relationshipsByName where !rel.isToMany && !rel.isTransient {
                fields["CD_\(relName)"] = .field("STRING")
            }
            result["CD_\(name)"] = fields
        }
        return result
    }

    // MARK: - Snapshot (.ckdb exportado de la consola o con `cktool export-schema`)

    /// `[recordType: [campo: tipo]]` de un `.ckdb`. Solo los campos `CD_*`: los `___*` son del sistema.
    static func parseSnapshot(_ text: String) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        let typeRegex = /RECORD TYPE "?([\w.]+)"? \((.*?)\n\s*\);/.dotMatchesNewlines()
        let fieldRegex = /^\s+"?(CD_\w+)"?\s+([A-Z_0-9<>]+)/.anchorsMatchLineEndings()
        for match in text.matches(of: typeRegex) {
            var fields: [String: String] = [:]
            for field in String(match.output.2).matches(of: fieldRegex) {
                fields[String(field.output.1)] = String(field.output.2)
            }
            result[String(match.output.1)] = fields
        }
        return result
    }

    private static func snapshot(_ file: String) throws -> [String: [String: String]] {
        let text = try String(contentsOf: schemasDir.appendingPathComponent(file), encoding: .utf8)
        return parseSnapshot(text)
    }

    /// Lo que el snapshot no cubre, una línea por hueco y en orden estable.
    static func gaps(
        expected: [String: [String: Expected]],
        snapshot: [String: [String: String]],
        knownMismatches: [String: String] = [:]
    ) -> [String] {
        var out: [String] = []
        for recordType in expected.keys.sorted() {
            guard let have = snapshot[recordType] else {
                out.append("falta el record type \(recordType)")
                continue
            }
            for (field, want) in expected[recordType, default: [:]].sorted(by: { $0.key < $1.key }) {
                guard case .field(let type) = want else { continue }
                if let other = have[field] {
                    if other != type, knownMismatches["\(recordType).\(field)"] != other {
                        out.append("\(recordType): \(field) es \(other) y la app escribe \(type)")
                    }
                } else {
                    out.append("\(recordType): falta \(field) \(type)")
                }
            }
        }
        return out
    }

    // MARK: - Tests

    @Test func personalTypes_matchPersonalSchema() {
        let listed = Set(Self.personalTypes.map { String(describing: $0) })
        let schema = Set(SwiftDataConfiguration.personalSchema.entities.map(\.name))
        #expect(listed == schema, "Un @Model entró o salió del store personal: actualiza `personalTypes`.")
    }

    @Test func everyAttribute_hasAKnownCloudKitType() throws {
        let unmapped = try Self.expectedSchema().flatMap { recordType, fields in
            fields.compactMap { field, want -> String? in
                if case .unmapped(let why) = want { return "\(recordType).\(field): \(why)" }
                return nil
            }
        }
        #expect(unmapped.isEmpty, "Tipos sin traducir a CloudKit: \(unmapped.sorted())")
    }

    @Test(arguments: snapshots)
    func snapshot_coversEveryFieldTheAppWrites(_ file: String) throws {
        let gaps = Self.gaps(
            expected: try Self.expectedSchema(),
            snapshot: try Self.snapshot(file),
            knownMismatches: Self.knownTypeMismatches[file, default: [:]]
        )
        #expect(
            gaps.isEmpty,
            """
            \(file) no cubre \(gaps.count) campo(s) que la app escribe. Si Production tampoco lo tiene, \
            el registro deja de sincronizar en silencio. Despliega antes de enviar y re-exporta \
            (docs/cloudkit-schema-diff-2.1.md):
            \(gaps.joined(separator: "\n"))
            """
        )
    }

    /// El arreglo de `CD_line`: el ajuste de un mes viaja ahora por `CD_cashFlowLine`, que la app escribe
    /// como STRING (el recordName de la línea) y que los cuatro snapshots declaran STRING. Es lo que hay que
    /// desplegar a Production (`docs/cloudkit-schema-diff-2.1.md`, «El campo nuevo de los ajustes»).
    @Test(arguments: snapshots)
    func cashFlowOverride_travelsByTheNewStringField(_ file: String) throws {
        let expected = try #require(try Self.expectedSchema()["CD_CashFlowOverride"])
        #expect(expected["CD_cashFlowLine"] == .field("STRING"))
        #expect(try Self.snapshot(file)["CD_CashFlowOverride"]?["CD_cashFlowLine"] == "STRING")
    }

    /// El parser es la mitad del test: si dejara de leer RECORD TYPEs o campos, el test de arriba
    /// fallaría por todo; si leyera los `___*` del sistema, ocultaría huecos.
    @Test func parser_readsFieldsTypesAndQuotedNames() {
        let text = """
            DEFINE SCHEMA

                RECORD TYPE CD_Foo (
                    CD_amount       DOUBLE QUERYABLE SORTABLE,
                    "CD_name"       STRING,
                    "___createTime" TIMESTAMP,
                    GRANT READ TO "_world"
                );

                RECORD TYPE "cloudkit.share" (
                    "___etag"       STRING,
                    GRANT READ TO "_world"
                );
            """
        let parsed = Self.parseSnapshot(text)
        #expect(parsed["CD_Foo"] == ["CD_amount": "DOUBLE", "CD_name": "STRING"])
        #expect(parsed["cloudkit.share"] == [:])
    }

    /// Y el comparador: un campo ausente y un tipo distinto son huecos; uno de más no lo es.
    @Test func gaps_reportMissingAndMistypedButNotExtraFields() {
        let expected: [String: [String: Expected]] = [
            "CD_Foo": ["CD_a": .field("STRING"), "CD_b": .field("DOUBLE"), "CD_c": .field("INT64")],
        ]
        let snapshot = ["CD_Foo": ["CD_a": "STRING", "CD_b": "INT64", "CD_old": "BYTES"]]
        #expect(Self.gaps(expected: expected, snapshot: snapshot) == [
            "CD_Foo: CD_b es INT64 y la app escribe DOUBLE",
            "CD_Foo: falta CD_c INT64",
        ])
        // Un desajuste conocido se tolera SOLO con el tipo apuntado: si el snapshot cambia a otro, vuelve a fallar.
        #expect(Self.gaps(expected: expected, snapshot: snapshot, knownMismatches: ["CD_Foo.CD_b": "INT64"]) == [
            "CD_Foo: falta CD_c INT64",
        ])
        #expect(Self.gaps(expected: expected, snapshot: snapshot, knownMismatches: ["CD_Foo.CD_b": "BYTES"]).count == 2)
    }
}
