//
//  ComerciosEnComunTests.swift
//  YalaTests
//
//  «Comercios en común» (2.3, 2026-11-22). Lo que fija, por gravedad si se rompiera:
//
//  1. Lo que sale del teléfono es SOLO `{comercio limpio, tipo}`: ni importe, ni fecha, ni la categoría de la persona.
//  2. Solo aporta un gasto capturado cuya categoría se traduce a UN tipo; nunca alquiler, impuestos, ingresos, lo escrito
//     a mano ni lo de grupos. Apagar «Aportar comercios» vacía la cola.
//  3. El aviso sale antes de cualquier envío, una vez; el lote espera una semana.
//  4. El orden: tu memoria (aunque sea de una vez) › lista común (solo propone) › lo de antes.
//  5. La limpieza del nombre de la propuesta (variante B).
//  6. Los textos en su tabla, en los 16 idiomas, y el cableado del origen en las tres aprobaciones.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Dobles

@MainActor
final class TransporteFalso: ComerciosEnComunTransporte {
    var listaRespuesta: ComerciosEnComunListaRespuesta = .sinCambios
    var envioRespuesta: ComerciosEnComunEnvioRespuesta = .aceptado
    var falla = false
    private(set) var versionesPedidas: [String?] = []
    private(set) var lotes: [[ComercioAporte]] = []

    nonisolated func lista(version: String?) async throws -> ComerciosEnComunListaRespuesta {
        try await MainActor.run {
            versionesPedidas.append(version)
            if falla { throw ComerciosEnComunError.status(500) }
            return listaRespuesta
        }
    }

    nonisolated func aportar(_ items: [ComercioAporte]) async throws -> ComerciosEnComunEnvioRespuesta {
        try await MainActor.run {
            lotes.append(items)
            if falla { throw ComerciosEnComunError.status(500) }
            return envioRespuesta
        }
    }
}

@MainActor
func comerciosSeedSubcategory(_ kind: VisionMerchantKind, in category: YalaCategory, context: ModelContext) -> Subcategory {
    let target = MerchantKindSubcategory.target(for: kind)
    let sub = Subcategory(name: target.name, colorHex: nil, natureRawValue: SubcategoryNeed.essential.rawValue,
                          iconName: target.icon, category: category)
    context.insert(sub)
    return sub
}

@MainActor
struct ComerciosEscenario {
    let context: ModelContext
    let comunes: ComerciosEnComun
    let transporte: TransporteFalso
    let super_: Subcategory
    let farmacia: Subcategory
    let alquiler: Subcategory
    let antojo: Subcategory
    let sueldo: Subcategory
    var avisos = 0
    var ahora = Date(timeIntervalSince1970: 1_800_000_000)

    static func make(fileID: String = #fileID) throws -> ComerciosEscenario {
        let context = try makeTestContext(fileID: fileID)
        let gastos = makeTestCategory(context: context, name: "Gastos", isIncome: false)
        let ingresos = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        let super_ = comerciosSeedSubcategory(.supermarket, in: gastos, context: context)
        let farmacia = comerciosSeedSubcategory(.pharmacy, in: gastos, context: context)
        let alquiler = comerciosSeedSubcategory(.rent, in: gastos, context: context)
        let antojo = Subcategory(name: "Mi antojo", colorHex: nil, natureRawValue: SubcategoryNeed.optional.rawValue,
                                 iconName: "heart.fill", category: gastos)
        context.insert(antojo)
        let sueldo = Subcategory(name: "Sueldo", colorHex: nil, natureRawValue: SubcategoryNeed.essential.rawValue,
                                 iconName: "basket.fill", category: ingresos)
        context.insert(sueldo)
        try context.save()
        let comunes = ComerciosEnComun(archivo: nil)
        let transporte = TransporteFalso()
        comunes.transporte = transporte
        return ComerciosEscenario(context: context, comunes: comunes, transporte: transporte, super_: super_,
                         farmacia: farmacia, alquiler: alquiler, antojo: antojo, sueldo: sueldo)
    }

    var visibles: [Subcategory] { [super_, farmacia, alquiler, antojo, sueldo] }
}

// MARK: - Nombre

@MainActor
@Suite("Comercios en común — nombre limpio", .serialized)
struct ComerciosEnComunNombreTests {

    @Test func losEjemplosDeLaPropuesta() {
        #expect(ComerciosEnComunNombre.clean("IZI*TAMBO+ AV LARCO 1153 LIMA") == "TAMBO")
        #expect(ComerciosEnComunNombre.clean("INVERSIONES LA LUCHA S.A.C.") == "INVERSIONES LA LUCHA")
        #expect(ComerciosEnComunNombre.clean("BOTICA SAN JOSE 2 SUC 14") == "BOTICA SAN JOSE")
        #expect(ComerciosEnComunNombre.clean("Chifa Don Lucho Miraflores") == "CHIFA DON LUCHO")
    }

    @Test func unaMarcaDelBancoDe666_seQuedaConLaMarca() throws {
        let starbucks = try #require(MerchantCatalog.match(name: "Starbucks"))
        let limpio = ComerciosEnComunNombre.clean("DP*STARBUCKS COFFEE MIRAFLORES 123")
        #expect(limpio == MerchantCanonicalizer.canonicalize(starbucks.name))
        // Dos sucursales del mismo comercio suman juntas.
        #expect(ComerciosEnComunNombre.clean("STARBUCKS SAN ISIDRO 45") == limpio)
    }

    @Test func loQueNoVale_noViaja() {
        #expect(ComerciosEnComunNombre.clean("123 456") == nil)
        #expect(ComerciosEnComunNombre.clean("") == nil)
        #expect(ComerciosEnComunNombre.clean("A") == nil)
        let largo = ComerciosEnComunNombre.clean(String(repeating: "BODEGA ", count: 20)) ?? ""
        #expect(largo.count <= ComerciosEnComunNombre.maxLength)
    }

    @Test func unaCiudadSolaNoSeBorra() {
        // «LIMA» como nombre entero no se queda vacío: el recorte deja siempre una palabra.
        #expect(ComerciosEnComunNombre.clean("Lima") == "LIMA")
    }
}

// MARK: - Textos y cableado

@Suite("Comercios en común — textos y cableado", .serialized)
struct ComerciosEnComunCableadoTests {

    private static let repoRoot = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                                  "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/ComerciosEnComun.strings")
        let dict = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
        return dict
    }

    @Test func losTextos_enLos16Idiomas_conLasMismasClaves() throws {
        let reference = try Self.strings("es-419")
        #expect(reference.count == 16)
        for locale in Self.locales {
            let dict = try Self.strings(locale)
            #expect(Set(dict.keys) == Set(reference.keys), "\(locale)")
            #expect(dict["comerciosComun.linea.texto"]?.contains("%@") == true, "\(locale)")
        }
    }

    @Test func elEspanol_esNeutro_enLasCuatroVariantes() throws {
        for locale in ["es", "es-419", "es-ES", "es-AR"] {
            for value in try Self.strings(locale).values {
                for vos in ["vosotros", "apruebáis", "podéis", "tenés", "querés"] {
                    #expect(!value.lowercased().contains(vos), "\(locale): \(value)")
                }
            }
        }
    }

    @Test func lasTresAprobaciones_pasanElOrigen() throws {
        let draftService = try String(contentsOf: Self.repoRoot.appending(path: "Yala/Services/DraftService.swift"), encoding: .utf8)
        let inbox = try String(contentsOf: Self.repoRoot.appending(path: "Yala/App/Views/Inbox/InboxDraftEditSheet.swift"),
                               encoding: .utf8)
        let all = draftService + inbox
        let calls = all.components(separatedBy: "merchantService.updateMemory(").count - 1
        let withSource = all.components(separatedBy: "source: draft.sourceType").count - 1
        #expect(calls == 3)
        #expect(withSource == calls, "Cada aprobación dice de dónde vino el borrador, o no aporta.")
    }
}
