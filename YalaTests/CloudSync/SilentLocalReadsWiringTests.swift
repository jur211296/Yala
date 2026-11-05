//
//  SilentLocalReadsWiringTests.swift
//  YalaTests
//
//  Ticket `two-silent-local-reads-leave-a-false-or-no-trace`. Dos de las cinco lecturas no tienen seam alcanzable sin montar
//  el adopt entero o la muestra de la vuelta con su SQLite: el cinturón del marcador del adopt (paso 4 de `runAdoptFlow`)
//  y el fetch tolerado de testigos de `collectReverseUploadPairs`. Sus rastros son `Logger`, que no tiene sink en los
//  tests, así que se fija el cableado: «no pude leer» deja su propio rastro y «no está» conserva el suyo.
//

import Foundation
import Testing

@Suite("Lecturas locales que fallan · rastro propio (source-scan)")
struct SilentLocalReadsWiringTests {

    private func executorSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Yala/Services/CloudSync/MigrationWorkExecutor.swift"),
                          encoding: .utf8)
    }

    /// El cinturón ya no es un `try?` (prohibido por las reglas del repo, y el que convertía «no pude leer» en «el marcador
    /// del líder no llegó»). La rama del fallo deja `localReadFailed`, y la de la ausencia sigue diciendo `marker absent`.
    @Test func markerBelt_separatesAbsentFromUnreadable() throws {
        let src = try executorSource()
        #expect(!src.contains("try? context.fetchCount(FetchDescriptor<CloudMigrationMarker>())"),
                "el cinturón no puede volver a tragarse el fallo de lectura")
        let start = try #require(src.range(of: "if try context.fetchCount(FetchDescriptor<CloudMigrationMarker>()) == 0 {"))
        let tail = String(src[start.lowerBound...].prefix(600))
        let absent = try #require(tail.range(of: "reason: \"marker absent (belt)\""))
        let unreadable = try #require(tail.range(of: "localReadFailed(step: \"adopt-marker-belt\""))
        #expect(absent.lowerBound < unreadable.lowerBound, "la ausencia va en el `do`; el fallo, en el `catch`")
        #expect(tail[absent.upperBound..<unreadable.lowerBound].contains("} catch {"))
    }

    /// El fetch de testigos de la muestra de la vuelta se sigue tolerando, pero deja rastro fuera de `#if DEBUG`.
    @Test func reverseSampleWitnesses_leaveATraceInProduction() throws {
        let src = try executorSource()
        let start = try #require(src.range(of: "private func collectReverseUploadPairs()"))
        let body = String(src[start.lowerBound...].prefix(1400))
        let trace = try #require(body.range(of: "localReadFailed(step: \"reverse-sample-witnesses\""))
        let debug = try #require(body.range(of: "#if DEBUG"))
        #expect(trace.lowerBound < debug.lowerBound, "el rastro va antes del bloque DEBUG, no dentro")
    }
}
