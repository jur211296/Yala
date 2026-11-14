//
//  ConnectedBrowsersDemo.swift
//  Yala
//
//  SOLO DEBUG. Con `-uitest-connected-browsers-demo`, «Navegadores conectados» habla con una web de mentira con tres
//  sesiones (y cerrarlas funciona), para capturar y revisar la pantalla en el simulador, donde no hay sesión de la nube.
//  No toca la red. En Release no existe.
//

#if DEBUG
import Foundation

nonisolated enum ConnectedBrowsersDemo {
    static let argument = "-uitest-connected-browsers-demo"

    static var isActive: Bool { ProcessInfo.processInfo.arguments.contains(argument) }

    /// El cliente de la demo: token fijo y una sesión HTTP de mentira.
    @MainActor
    static func client() -> ConnectedBrowsersClient {
        ConnectedBrowsersClient(
            baseURL: URL(string: "https://demo.invalid"),
            tokenProvider: { "demo" },
            urlSession: DemoSession()
        )
    }

    private final class DemoSession: SyncHTTPSession, @unchecked Sendable {
        private let lock = NSLock()
        private var sessions: [[String: Any]] = {
            let now = Date().timeIntervalSince1970
            return [
                ["id": "demoMacChrom", "navegador": "Chrome", "sistema": "Mac", "ciudad": "Lima", "ultimoUso": now - 30, "equipoCompartido": false],
                ["id": "demoWinEdge0", "navegador": "Edge", "sistema": "Windows", "ciudad": "Arequipa", "ultimoUso": now - 3 * 86_400, "equipoCompartido": true],
                ["id": "demoIpadSafa", "navegador": "Safari", "sistema": "iPad", "ciudad": "Cusco", "ultimoUso": now - 5 * 3_600, "equipoCompartido": false],
            ]
        }()

        private static func closedID(_ raw: Data?) -> String? {
            guard let raw else { return nil }
            do {
                return (try JSONSerialization.jsonObject(with: raw) as? [String: Any])?["id"] as? String
            } catch {
                print("ConnectedBrowsersDemo: Error: \(error)")
                return nil
            }
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            let path = request.url?.path ?? ""
            let closed = Self.closedID(request.httpBody)
            let body: Data = lock.withLock {
                if path.hasSuffix("cerrar-todas") {
                    sessions.removeAll()
                    return Data(#"{"cerradas":1}"#.utf8)
                }
                if path.hasSuffix("cerrar"), let closed {
                    sessions.removeAll { ($0["id"] as? String) == closed }
                    return Data(#"{"cerradas":1}"#.utf8)
                }
                do {
                    return try JSONSerialization.data(withJSONObject: ["sesiones": sessions])
                } catch {
                    print("ConnectedBrowsersDemo: Error: \(error)")
                    return Data(#"{"sesiones":[]}"#.utf8)
                }
            }
            let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: 200, httpVersion: nil, headerFields: nil)
            return (body, response ?? URLResponse())
        }
    }
}
#endif
