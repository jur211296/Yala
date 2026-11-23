//
//  ConectaTuIADemo.swift
//  Yala
//
//  SOLO DEBUG. Con `-uitest-conecta-tu-ia-demo`, Ajustes › Tu IA habla con un conector de mentira con Claude y ChatGPT
//  conectados (y «Desconectar» funciona), y da los datos por estar en la cuenta de Yala: para capturar y revisar la
//  pantalla en el simulador, donde no hay sesión de la nube. No toca la red. En Release no existe.
//

#if DEBUG
import Foundation

nonisolated enum ConectaTuIADemo {
    static let argument = "-uitest-conecta-tu-ia-demo"

    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains(argument) }

    @MainActor
    static func client() -> ConectaTuIAClient {
        ConectaTuIAClient(baseURL: URL(string: "https://demo.invalid"), tokenProvider: { "demo" }, urlSession: DemoSession())
    }

    private final class DemoSession: SyncHTTPSession, @unchecked Sendable {
        private let lock = NSLock()
        private var rows: [[String: Any]] = {
            let now = Date().timeIntervalSince1970
            return [
                ["id": "demoClaude01", "ia": "Claude", "vuelta": "claude.ai", "local": false, "conectadaEl": now - 3 * 86_400],
                ["id": "demoChatGPT1", "ia": "ChatGPT", "vuelta": "chatgpt.com", "local": false, "conectadaEl": now - 12 * 86_400],
            ]
        }()

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            let url = request.url ?? URL(fileURLWithPath: "/")
            let status: Int
            let body: Data
            if request.httpMethod == "DELETE" {
                let id = url.lastPathComponent
                let removed: Bool = lock.withLock {
                    let before = rows.count
                    rows.removeAll { ($0["id"] as? String) == id }
                    return rows.count < before
                }
                (status, body) = removed ? (204, Data()) : (404, Data(#"{"error":"not_found"}"#.utf8))
            } else {
                let snapshot = lock.withLock { rows }
                do {
                    body = try JSONSerialization.data(withJSONObject: ["conexiones": snapshot])
                } catch {
                    print("ConectaTuIADemo: Error: \(error)")
                    return (Data(), HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil) ?? URLResponse())
                }
                status = 200
            }
            return (body, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) ?? URLResponse())
        }
    }
}
#endif
