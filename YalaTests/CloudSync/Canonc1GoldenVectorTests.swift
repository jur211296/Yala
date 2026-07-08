//
//  Canonc1GoldenVectorTests.swift
//  YalaTests
//
//  Corre el codec real `Canonc1Codec.encode` contra `golden_vectors.json` (raíz del repo). Los `expected`
//  se derivaron A MANO desde las reglas de §d.7 (bloque S2) — los ejemplos difíciles de HALF_EVEN se
//  confirmaron byte-a-byte con la ruta exacta-desde-binario (0.12345→0.1235 arriba, 0.12355→0.1235 par,
//  como dice la propia spec) — y se materializaron con un escritor JSON para eliminar riesgo de
//  transcripción. Este archivo es el gate cross-plataforma: los 4 codecs (Swift/TS/Kotlin/Worker) DEBEN
//  reproducir cada `expected` byte a byte. Carga el JSON vía `#filePath` (patrón HLCConformanceVectorTests:
//  el runner no empaqueta el JSON como resource).
//

import Foundation
import Testing

@testable import Yala

@Suite("Canon c1 Golden Vectors")
struct Canonc1GoldenVectorTests {

    // MARK: - Carga

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func loadGolden() throws -> Golden {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("golden_vectors.json"))
        return try JSONDecoder().decode(Golden.self, from: data)
    }

    // MARK: - DTOs del archivo

    private struct Golden: Decodable {
        let canon_version: String
        let vectors: [Vector]
        let errorVectors: [ErrorVector]
    }
    private struct Vector: Decodable {
        let id: String
        let description: String
        let fields: [String: FieldVal]
        let expected: String
    }
    private struct ErrorVector: Decodable {
        let id: String
        let description: String
        let fields: [String: FieldVal]
        let expectedError: String
    }

    /// Representación serializable de un `CanonValue` en el golden (tagged por `t`).
    private struct FieldVal: Decodable {
        let t: String
        let double: String?
        let unixMs: Int64?
        let unixSeconds: Double?
        let value: String?
        let values: [String]?
        let bool: Bool?
        let isNull: Bool?
        let int: Int?
        let json: String?
    }

    /// Traduce la representación tagged a `CanonValue`. Falla el test si el tag o su payload es inválido.
    private func canonValue(_ f: FieldVal, _ vectorID: String) throws -> CanonValue {
        switch f.t {
        case "money":
            return .money(try requireDouble(f.double, vectorID))
        case "rate":
            return .rate(try requireDouble(f.double, vectorID))
        case "timestamp":
            return .timestamp(try requireDate(f, vectorID))
        case "localDay":
            return .localDay(try requireDate(f, vectorID))
        case "uuid":
            return .uuid(try requireUUID(f.value, vectorID))
        case "uuidArray":
            let raw = f.values ?? []
            return .uuidArray(try raw.map { try requireUUID($0, vectorID) })
        case "string":
            return .string(try require(f.value, "value", vectorID))
        case "bool":
            if f.isNull == true { return .bool(nil) }
            return .bool(try require(f.bool, "bool", vectorID))
        case "int":
            return .int(try require(f.int, "int", vectorID))
        case "dataJSON":
            let json = try require(f.json, "json", vectorID)
            return .dataJSON(Data(json.utf8))
        case "null":
            return .null
        default:
            Issue.record("[\(vectorID)] tag desconocido: \(f.t)")
            throw CocoaError(.coderValueNotFound)
        }
    }

    private func require<T>(_ v: T?, _ name: String, _ id: String) throws -> T {
        guard let v else { Issue.record("[\(id)] falta '\(name)'"); throw CocoaError(.coderValueNotFound) }
        return v
    }
    private func requireDouble(_ s: String?, _ id: String) throws -> Double {
        // El literal viaja como STRING para preservar `-0.0`, `nan`, `inf` de forma portable
        // (string→double IEEE round-to-nearest, determinista cross-lenguaje).
        let raw = try require(s, "double", id)
        guard let d = Double(raw) else { Issue.record("[\(id)] double inválido: \(raw)"); throw CocoaError(.coderValueNotFound) }
        return d
    }
    private func requireUUID(_ s: String?, _ id: String) throws -> UUID {
        let raw = try require(s, "uuid", id)
        guard let u = UUID(uuidString: raw) else { Issue.record("[\(id)] uuid inválido: \(raw)"); throw CocoaError(.coderValueNotFound) }
        return u
    }
    private func requireDate(_ f: FieldVal, _ id: String) throws -> Date {
        if let ms = f.unixMs { return Date(timeIntervalSince1970: Double(ms) / 1000) }
        if let sec = f.unixSeconds { return Date(timeIntervalSince1970: sec) }
        Issue.record("[\(id)] falta unixMs/unixSeconds")
        throw CocoaError(.coderValueNotFound)
    }

    private func decodeFields(_ raw: [String: FieldVal], _ id: String) throws -> [String: CanonValue] {
        var out: [String: CanonValue] = [:]
        for (key, val) in raw { out[key] = try canonValue(val, id) }
        return out
    }

    // MARK: - Tests

    @Test func metadata_isC1() throws {
        let golden = try Self.loadGolden()
        #expect(golden.canon_version == "c1")
        #expect(!golden.vectors.isEmpty)
        #expect(!golden.errorVectors.isEmpty)
    }

    @Test func allVectors_encodeToExpectedBytes() throws {
        let golden = try Self.loadGolden()
        for vector in golden.vectors {
            let fields = try decodeFields(vector.fields, vector.id)
            let got = try Canonc1Codec.encode(fields)
            #expect(got == vector.expected,
                    "[\(vector.id)] \(vector.description)\n  esperado: \(vector.expected)\n  obtenido: \(got)")
        }
    }

    @Test func allErrorVectors_throwExpectedError() throws {
        let golden = try Self.loadGolden()
        for vector in golden.errorVectors {
            let fields = try decodeFields(vector.fields, vector.id)
            do {
                let got = try Canonc1Codec.encode(fields)
                Issue.record("[\(vector.id)] se esperaba error '\(vector.expectedError)' pero devolvió \(got)")
            } catch {
                assertErrorMatches(error, expected: vector.expectedError, vector.id)
            }
        }
    }

    /// Empareja el error lanzado con la etiqueta del golden.
    private func assertErrorMatches(_ error: any Error, expected: String, _ id: String) {
        switch expected {
        case "nonFiniteNumber":
            if case Canonc1Error.nonFiniteNumber = error { return }
        case "numericOutOfRange":
            if case Canonc1Error.numericOutOfRange = error { return }
        case "serverAuthoredKey":
            if case Canonc1Error.serverAuthoredKey = error { return }
        case "malformedBlobJSON":
            if case Canonc1Error.malformedBlobJSON = error { return }
        case "yearOutOfRange":
            if case CanonicalTimeError.yearOutOfRange = error { return }
        default:
            break
        }
        Issue.record("[\(id)] error \(error) no coincide con esperado '\(expected)'")
    }
}
