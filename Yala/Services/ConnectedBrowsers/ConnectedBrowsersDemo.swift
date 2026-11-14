//
//  ConnectedBrowsersDemo.swift
//  Yala
//
//  SOLO DEBUG. Con `-uitest-connected-browsers-demo`, «Navegadores conectados» habla con una web de mentira con tres
//  sesiones (y cerrarlas funciona), para capturar y revisar la pantalla en el simulador, donde no hay sesión de la nube.
//  «Vincular un navegador» (lote 2) acepta cualquier código bien escrito y añade un «Safari en Mac» a la lista; el código
//  `ZZZZ-ZZZZ` contesta como caducado.
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

        private static func link(request: URLRequest, sessions add: ([String: Any]) -> Void) -> (Data, URLResponse) {
            let url = request.url ?? URL(fileURLWithPath: "/")
            let queryCode = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "codigo" }?.value
            var bodyCode: String?
            if let raw = request.httpBody {
                do {
                    bodyCode = (try JSONSerialization.jsonObject(with: raw) as? [String: Any])?["codigo"] as? String
                } catch {
                    print("ConnectedBrowsersDemo: Error: \(error)")
                }
            }
            let code = queryCode ?? bodyCode ?? ""
            let now = Date().timeIntervalSince1970
            let status: Int
            let body: String
            if code.uppercased().hasPrefix("ZZZZ") {
                (status, body) = (404, #"{"error":"caducado"}"#)
            } else if request.httpMethod == "POST" {
                add(["id": "demoLinkSafa", "navegador": "Safari", "sistema": "Mac", "ciudad": "Lima", "ultimoUso": now, "equipoCompartido": false])
                (status, body) = (200, #"{"ok":true,"navegador":"Safari","sistema":"Mac"}"#)
            } else {
                (status, body) = (200, #"{"codigo":"K7Q4-MD2X","navegador":"Safari","sistema":"Mac","ciudad":"Lima","creada":\#(now),"expira":\#(now + 120)}"#)
            }
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            return (Data(body.utf8), response ?? URLResponse())
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            let path = request.url?.path ?? ""
            let closed = Self.closedID(request.httpBody)
            if path.hasSuffix("vincular") {
                return Self.link(request: request, sessions: { new in self.lock.withLock { self.sessions.insert(new, at: 0) } })
            }
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
