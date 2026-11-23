//
//  ComerciosEnComunCliente.swift
//  Yala
//
//  «Comercios en común»: las dos llamadas al gateway (`gateway/src/comercios-comun/routes.ts`). Van con el token de
//  sesión de App Attest, como los tipos de cambio: no hace falta cuenta y funciona igual con el iCloud privado.
//
//  - `GET  /comercios-comun/lista`   → la lista común entera, con ETag (304 si no cambió).
//  - `POST /comercios-comun/aportes` → el lote semanal: `{ "items": [{ "merchant", "kind" }] }`. Nada más.
//

import Foundation

/// Un aporte: el comercio limpio y su tipo. Es lo ÚNICO que sale del teléfono.
struct ComercioAporte: Codable, Equatable, Hashable {
    let merchant: String
    let kind: String
}

enum ComerciosEnComunListaRespuesta: Equatable {
    /// La lista no cambió desde `version` (304).
    case sinCambios
    case nueva(version: String, items: [String: String])
}

enum ComerciosEnComunEnvioRespuesta: Equatable {
    /// Entró (todo, o lo que cupo en el tope semanal): la cola se vacía de lo enviado.
    case aceptado
    /// El teléfono aún no tiene 7 días de uso: la cola se queda y se reintenta la semana siguiente.
    case telefonoNuevo
}

enum ComerciosEnComunError: Error {
    case invalidURL
    case status(Int)
    case invalidResponse
}

protocol ComerciosEnComunTransporte {
    func lista(version: String?) async throws -> ComerciosEnComunListaRespuesta
    func aportar(_ items: [ComercioAporte]) async throws -> ComerciosEnComunEnvioRespuesta
}

struct ComerciosEnComunCliente: ComerciosEnComunTransporte {
    var session: URLSession = .shared

    private struct ListaDTO: Decodable {
        let version: String
        let items: [[String]]
    }

    private struct EnvioDTO: Decodable {
        let status: String
    }

    func lista(version: String?) async throws -> ComerciosEnComunListaRespuesta {
        var request = try await request(path: "comercios-comun/lista", method: "GET")
        if let version { request.setValue("\"\(version)\"", forHTTPHeaderField: "If-None-Match") }
        let (data, status) = try await send(request)
        if status == 304 { return .sinCambios }
        guard status == 200 else { throw ComerciosEnComunError.status(status) }
        let dto = try JSONDecoder().decode(ListaDTO.self, from: data)
        var items: [String: String] = [:]
        for pair in dto.items where pair.count == 2 {
            items[pair[0]] = pair[1]
        }
        return .nueva(version: dto.version, items: items)
    }

    func aportar(_ items: [ComercioAporte]) async throws -> ComerciosEnComunEnvioRespuesta {
        var request = try await request(path: "comercios-comun/aportes", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["items": items])
        let (data, status) = try await send(request)
        guard status == 200 else { throw ComerciosEnComunError.status(status) }
        let dto = try JSONDecoder().decode(EnvioDTO.self, from: data)
        return dto.status == "too_new" ? .telefonoNuevo : .aceptado
    }

    private func request(path: String, method: String) async throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: ProxyConfig.baseURL.appendingPathComponent("/")) else {
            throw ComerciosEnComunError.invalidURL
        }
        let token = try await AppAttestClient.shared.currentSessionToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ComerciosEnComunError.invalidResponse }
        if http.statusCode == 401 {
            // El token se olvida para que la próxima vez se acuñe otro (como el resto de clientes del gateway).
            let sent = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "")
            AppAttestClient.shared.discardSessionToken(ifEqualTo: sent)
        }
        return (data, http.statusCode)
    }
}
