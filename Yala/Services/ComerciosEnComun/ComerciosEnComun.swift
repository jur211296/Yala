//
//  ComerciosEnComun.swift
//  Yala
//
//  «Comercios en común» (2.3, 2026-11-22; decisión de Jürgen: las opciones recomendadas de la propuesta,
//  `docs/propuestas/2026-11-22-historico-comercios/`). Una lista anónima «comercio → tipo» que se arma cuando varios
//  teléfonos coinciden, y que propone la categoría de un comercio que la persona aún no apuntó.
//
//  Lo que hace esta pieza, y en qué orden lo consulta la app (`MerchantMemoryService`):
//  1. Tu memoria de comercios manda, aunque sea de una sola vez.
//  2. Si no tienes nada de ese comercio, la lista común PROPONE (nunca pone sola) y tu teléfono traduce el tipo a tu
//     categoría, en tu idioma.
//  3. Después, la IA de la foto y el banco de 666 marcas, como antes.
//
//  Aportar: al aprobar un gasto capturado, el comercio limpio y su tipo esperan en una cola local. Una vez por semana
//  salen todos juntos, en orden al azar, sin hora ni importe. Antes del primer envío sale un aviso, una vez, con
//  «No aportar»; la salida permanente está en Perfil › Comercios en común. Recibir no se apaga: no envía nada.
//
//  El estado vive en un JSON en Application Support, no en SwiftData: un `@Model` nuevo sería un campo de CloudKit, y
//  esto no tiene por qué viajar entre teléfonos.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ComerciosEnComun {

    /// Lo que se guarda en disco.
    struct Estado: Codable, Equatable {
        var aporta = true
        var avisoMostrado = false
        /// La lista común: comercio limpio → tipo (`VisionMerchantKind.rawValue`).
        var lista: [String: String] = [:]
        var version: String?
        var listaBajadaEn: Date?
        var cola: [ComercioAporte] = []
        /// Desde cuándo espera lo más viejo de la cola: el lote sale a los 7 días.
        var colaDesde: Date?
        /// Comercios ya aportados (o en cola): no se repiten.
        var aportados: [String] = []
    }

    static let semana: TimeInterval = 7 * 24 * 60 * 60
    static let dia: TimeInterval = 24 * 60 * 60
    /// Lo que cabe en un lote (el servidor no acepta más).
    static let maxLote = 30
    /// Cuántos comercios aportados se recuerdan para no repetirlos.
    static let maxAportados = 5_000

    /// En el host de los tests, en memoria y vacía: la lista bajada de staging no puede cambiar lo que proponen las
    /// pruebas de la memoria de comercios.
    static let shared = ComerciosEnComun(archivo: SwiftDataConfiguration.isRunningTests ? nil : ComerciosEnComun.defaultURL)

    static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "comercios-en-comun.json")
    }

    private(set) var estado: Estado
    private let archivo: URL?
    var transporte: any ComerciosEnComunTransporte = ComerciosEnComunCliente()
    var now: () -> Date = { Date() }
    /// El aviso de una vez. Sustituible en los tests.
    var mostrarAviso: (_ onNoAportar: @escaping @MainActor () -> Void) -> Void = { onNoAportar in
        ComerciosEnComunAviso.show(onNoAportar: onNoAportar)
    }
    private var sincronizando = false
    private var persiste = true

    init(archivo: URL?) {
        self.archivo = archivo
        self.estado = Self.leer(archivo) ?? Estado()
    }

    // MARK: - Aportar o no

    /// «Aportar comercios» de Perfil. Apagarlo vacía la cola: no sale nada más.
    var aporta: Bool {
        get { estado.aporta }
        set {
            estado.aporta = newValue
            if !newValue {
                estado.cola = []
                estado.colaDesde = nil
            }
            guardar()
        }
    }

    // MARK: - Leer la lista común

    /// El tipo que dice la lista común para ese comercio, si lo dice.
    func tipo(paraComercio raw: String) -> VisionMerchantKind? {
        guard !estado.lista.isEmpty, let nombre = ComerciosEnComunNombre.clean(raw),
              let kind = estado.lista[nombre] else { return nil }
        return VisionMerchantKind(rawValue: kind)
    }

    /// La subcategoría de la persona que corresponde a lo que dice la lista común, o `nil`. Solo gastos.
    func subcategoria(paraComercio raw: String, isExpense: Bool, en subcategorias: [Subcategory]) -> Subcategory? {
        guard isExpense, let kind = tipo(paraComercio: raw) else { return nil }
        let candidates = subcategorias.map {
            MerchantKindSubcategory.Candidate(name: $0.name, icon: $0.iconName, isExpense: !$0.safeCategory.isIncome)
        }
        return MerchantKindSubcategory.match(
            target: MerchantKindSubcategory.target(for: kind), isExpense: true, in: candidates
        ).map { subcategorias[$0] }
    }

    // MARK: - Aportar

    /// Al aprobar un borrador: encola `{comercio, tipo}` si se cumplen todas las condiciones. No envía nada.
    /// `visibles` se lee solo si lo anterior deja aportar (un aprobar en lote no paga un fetch por borrador).
    func registrarAporte(
        merchantRaw: String, subcategory: Subcategory, source: DraftSourceType, visibles leer: @autoclosure () -> [Subcategory]
    ) {
        guard estado.aporta, ComerciosEnComunTipo.sourceContributes(source), !subcategory.safeCategory.isIncome,
              let nombre = ComerciosEnComunNombre.clean(merchantRaw), !estado.aportados.contains(nombre)
        else { return }
        let visibles = leer()
        guard let index = visibles.firstIndex(where: { $0.persistentModelID == subcategory.persistentModelID })
        else { return }
        let candidates = visibles.map {
            MerchantKindSubcategory.Candidate(name: $0.name, icon: $0.iconName, isExpense: !$0.safeCategory.isIncome)
        }
        guard let kind = ComerciosEnComunTipo.kind(
            forCandidateAt: index, in: candidates, targets: ComerciosEnComunTipo.allTargets
        ) else { return }

        estado.aportados.append(nombre)
        if estado.aportados.count > Self.maxAportados {
            estado.aportados.removeFirst(estado.aportados.count - Self.maxAportados)
        }
        estado.cola.append(ComercioAporte(merchant: nombre, kind: kind.rawValue))
        if estado.colaDesde == nil { estado.colaDesde = now() }
        guardar()
    }

    // MARK: - Sincronizar

    /// Al volver a primer plano: el aviso si toca, la lista una vez al día y el lote una vez a la semana. Un fallo de red
    /// no cambia nada: se reintenta en el siguiente primer plano.
    func sincronizarSiToca() async {
        guard !sincronizando else { return }
        sincronizando = true
        defer { sincronizando = false }
        mostrarAvisoSiToca()
        await bajarListaSiToca()
        await enviarSiToca()
    }

    func mostrarAvisoSiToca() {
        guard estado.aporta, !estado.avisoMostrado, !estado.cola.isEmpty else { return }
        estado.avisoMostrado = true
        guardar()
        mostrarAviso { [weak self] in self?.aporta = false }
    }

    func bajarListaSiToca() async {
        if let last = estado.listaBajadaEn, now().timeIntervalSince(last) < Self.dia, last <= now() { return }
        do {
            switch try await transporte.lista(version: estado.version) {
            case .sinCambios:
                break
            case let .nueva(version, items):
                estado.version = version
                estado.lista = items
            }
            estado.listaBajadaEn = now()
            guardar()
        } catch {
            #if DEBUG
            print("ComerciosEnComun: Error bajando la lista: \(error)")
            #endif
        }
    }

    func enviarSiToca() async {
        guard estado.aporta, estado.avisoMostrado, !estado.cola.isEmpty, let desde = estado.colaDesde,
              now().timeIntervalSince(desde) >= Self.semana else { return }
        let lote = Array(estado.cola.prefix(Self.maxLote)).shuffled()
        do {
            switch try await transporte.aportar(lote) {
            case .aceptado:
                let enviados = Set(lote)
                estado.cola.removeAll { enviados.contains($0) }
                estado.colaDesde = estado.cola.isEmpty ? nil : now()
            case .telefonoNuevo:
                estado.colaDesde = now()
            }
            guardar()
        } catch {
            #if DEBUG
            print("ComerciosEnComun: Error enviando el lote: \(error)")
            #endif
        }
    }

    // MARK: - Disco

    private static func leer(_ url: URL?) -> Estado? {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(Estado.self, from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("ComerciosEnComun: Error leyendo el estado: \(error)")
            #endif
            return nil
        }
    }

    private func guardar() {
        guard persiste, let archivo else { return }
        do {
            try FileManager.default.createDirectory(
                at: archivo.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(estado).write(to: archivo, options: .atomic)
        } catch {
            #if DEBUG
            print("ComerciosEnComun: Error guardando el estado: \(error)")
            #endif
        }
    }

    // MARK: - Pruebas de interfaz

    #if DEBUG
    /// Bajo XCUITest: estado en memoria, sin disco ni red, con la lista de `-uitest-comercios-comun-lista
    /// TAMBO=supermarket,MIFARMA=pharmacy` (vacía sin el argumento). Así una prueba no hereda la lista de otra.
    func prepararParaUITest(_ spec: String?) {
        persiste = false
        var items: [String: String] = [:]
        for pair in (spec ?? "").split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { items[parts[0]] = parts[1] }
        }
        var nuevo = Estado()
        nuevo.lista = items
        nuevo.version = "uitest"
        nuevo.listaBajadaEn = now()
        nuevo.avisoMostrado = true
        estado = nuevo
    }
    #endif
}
