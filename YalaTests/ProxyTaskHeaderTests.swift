//
//  ProxyTaskHeaderTests.swift
//  YalaTests
//
//  Sesión 2 del gateway de IA: cada llamada dice qué tarea pide (`X-Yala-Task`), y con eso el gateway elige modelo,
//  parámetros y cubo de cuota. Lo que fija, con la petición que sale DE VERDAD por el SDK (una `URLSession` con un
//  `URLProtocol` que la captura en vez de mandarla):
//
//  1. Cada servicio manda SU tarea y el cubo de esa tarea.
//  2. La foto sube reducida al lado mayor que aprovecha el modelo (paso 6), con su prompt de divisas (paso 6 bis).
//  3. La voz manda el idioma elegido.
//  4. Ningún servicio se quedó con la factoría vieja (`category:`): lo cubre un escaneo del código.
//

import Foundation
import OpenAI
import SwiftData
import Testing
import UIKit
@testable import Yala

/// Captura cada petición y contesta como el gateway: transcripción con texto, chat con un JSON vacío.
final class CapturingURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var captured: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [Data] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        captured = []
        bodies = []
    }

    static func snapshot() -> [(request: URLRequest, body: Data)] {
        lock.lock(); defer { lock.unlock() }
        return Array(zip(captured, bodies))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }
                body.append(buffer, count: n)
            }
            stream.close()
        }
        Self.lock.lock()
        Self.captured.append(request)
        Self.bodies.append(body)
        Self.lock.unlock()

        let isAudio = request.url?.path.hasSuffix("/audio/transcriptions") ?? false
        let json = isAudio
            ? #"{"text":"taxi doce soles"}"#
            : #"{"id":"x","object":"chat.completion","created":1,"model":"stub","choices":[{"index":0,"message":{"role":"assistant","content":"{}"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}"#
        let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct ProxyTaskHeaderTests {

    private static func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Corre `body` con el transporte de prueba y devuelve las peticiones que salieron. Los servicios llaman con
    /// `try?` a propósito: la respuesta de prueba es un JSON vacío que su parser rechaza, y lo que se mira es la PETICIÓN.
    private func capture(_ body: () async -> Void) async -> [(request: URLRequest, body: Data)] {
        CapturingURLProtocol.reset()
        ProxyClientFactory.testTransport = ("test-token", Self.stubSession())
        defer { ProxyClientFactory.testTransport = nil }
        await body()
        return CapturingURLProtocol.snapshot()
    }

    private func expectTask(_ sent: [(request: URLRequest, body: Data)], _ task: ProxyTask, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(!sent.isEmpty, "no salió ninguna petición", sourceLocation: sourceLocation)
        for item in sent {
            #expect(item.request.value(forHTTPHeaderField: "X-Yala-Task") == task.rawValue, sourceLocation: sourceLocation)
            #expect(item.request.value(forHTTPHeaderField: "X-Yala-Category") == task.category.rawValue, sourceLocation: sourceLocation)
            #expect(item.request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token", sourceLocation: sourceLocation)
        }
    }

    // MARK: - El contrato con el gateway

    @Test("los nombres de tarea son los de TASKS del gateway, y cada una con su cubo")
    func taskNamesMatchTheGateway() throws {
        let tasksTS = try String(contentsOf: repoURL("gateway/src/ai/tasks.ts"), encoding: .utf8)
        for task in ProxyTask.allCases {
            // `"photo.read": { category: "vision", …`
            let line = try #require(tasksTS.components(separatedBy: "\n").first { $0.contains("\"\(task.rawValue)\": {") }, "\(task.rawValue) no está en TASKS")
            #expect(line.contains("category: \"\(task.category.rawValue)\""), "\(task.rawValue): el cubo de la app no es el del gateway")
            #expect(!line.contains("deducedOnly"), "\(task.rawValue) solo la deduce el gateway: con cabecera se ignoraría")
        }
        #expect(ProxyTask.allCases.count == 11)
    }

    @Test("cada tarea sale por el SDK con su X-Yala-Task, su cubo y el token")
    func everyTaskLeavesWithItsHeader() async throws {
        for task in ProxyTask.allCases {
            let sent = await capture {
                do {
                    let client = try await ProxyClientFactory.makeOpenAI(task: task)
                    if task == .voiceTranscribe {
                        _ = try await client.audioTranscriptions(query: .init(file: Data([1, 2, 3]), fileType: .m4a, model: .whisper_1))
                    } else {
                        _ = try await client.chats(query: .init(messages: [.user(.init(content: .string("hola")))], model: .gpt4_1_mini))
                    }
                } catch {
                    Issue.record("\(task.rawValue): \(error)")
                }
            }
            expectTask(sent, task)
        }
    }

    // MARK: - Servicio a servicio

    @Test("foto: photo.read, reducida al lado mayor del gateway y con la regla del «$» del usuario")
    func photoRead() async throws {
        // Una «foto» de 4032×3024 px, como la cámara de un iPhone.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 4032, height: 3024), format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4032, height: 3024))
        }
        let sent = await capture {
            _ = try? await ImageVisionService().analyze(image: photo, currency: VisionCurrencyContext(mainCurrency: "MXN", accountCurrencies: ["MXN"]))
        }
        expectTask(sent, .photoRead)
        let body = try #require(sent.first?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let messages = try #require(json["messages"] as? [[String: Any]])
        let system = try #require(messages.first?["content"] as? String)
        #expect(system.contains("\"$\" symbol alone → \"MXN\""))
        let parts = try #require(messages.last?["content"] as? [[String: Any]])
        let url = try #require((parts.first { $0["type"] as? String == "image_url" }?["image_url"] as? [String: Any])?["url"] as? String)
        let b64 = try #require(url.components(separatedBy: "base64,").last)
        let jpeg = try #require(Data(base64Encoded: b64))
        let image = try #require(UIImage(data: jpeg))
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        #expect(longest == CGFloat(PhotoUploadSizing.defaultMaxEdge), "la foto subió a \(longest) px")
    }

    @Test("leer una nota: text.parse")
    func textParse() async {
        let sent = await capture {
            _ = try? await TranscriptionParserService().parseMultiple(text: "taxi 12", expenseSubcategories: ["Taxi"], incomeSubcategories: [])
        }
        expectTask(sent, .textParse)
    }

    @Test("transcribir: voice.transcribe con el idioma elegido")
    func voiceTranscribe() async throws {
        let sent = await capture {
            _ = try? await VoiceTranscriptionService().transcribe(audioData: Data([1, 2, 3]), language: .japanese, keywords: ["ローソン", "Suica"])
        }
        expectTask(sent, .voiceTranscribe)
        let multipart = String(decoding: try #require(sent.first?.body), as: UTF8.self)
        #expect(multipart.contains("name=\"language\"\r\n\r\nja"))
        // Los términos del usuario viajan en `prompt`, uno por línea; el gateway decide si el modelo los usa.
        #expect(multipart.contains("name=\"prompt\"\r\n\r\nローソン\nSuica"))
    }

    @Test("clasificar el mensaje del chat: chat.intent")
    func chatIntent() async throws {
        try #require(NetworkMonitor.shared.isConnected, "sin red el clasificador no llama: va por regex")
        let sent = await capture {
            _ = await ChatIntentClassifierService.shared.classify(text: "ayer gasté 45 en el mercado")
        }
        expectTask(sent, .chatIntent)
    }

    @Test("reescribir sugerencias: chat.rewrite")
    func chatRewrite() async throws {
        try #require(NetworkMonitor.shared.isConnected)
        // «Starbucks» no está en la lista del usuario: la sugerencia es inválida y se manda a reescribir.
        let invalid = ChatSuggestion(text: "¿Cuánto gasté en Starbucks?", icon: "cup.and.saucer", type: .topMerchant)
        let whitelist = SuggestionsRewriterService.Whitelist(categories: ["Comida"], subcategories: [], budgets: [], tags: [], merchants: [])
        let sent = await capture {
            _ = try? await SuggestionsRewriterService.shared.process(suggestions: [invalid], whitelist: whitelist, language: "es-PE", minItems: 1)
        }
        expectTask(sent, .chatRewrite)
    }

    @Test("tarjetas de Insights: insights.cards")
    func insightsCards() async {
        let sent = await capture {
            _ = try? await InsightsLLMService().generateInsights(aggregatedData: ["locale": "es"], cacheKey: "test-\(UUID().uuidString)")
        }
        expectTask(sent, .insightsCards)
    }

    @Test("comentario del flujo de caja: insights.cashflow")
    func insightsCashflow() async {
        let projection = CashFlowProjection(months: [], startingBalance: 100, totalProjectedIncome: 50, totalProjectedExpense: 20, totalProjectedNet: 30)
        let sent = await capture {
            _ = try? await InsightsLLMService().generateCashFlowInsight(projection: projection, currencyCode: "PEN")
        }
        expectTask(sent, .insightsCashflow)
    }

    @Test("comentario de desviaciones: insights.deviation")
    func insightsDeviation() async {
        let sent = await capture {
            _ = try? await InsightsLLMService().generateDeviationInsight(deviations: [(name: "Comida", planned: 100, actual: 150, excess: 50)], currencyCode: "PEN")
        }
        expectTask(sent, .insightsDeviation)
    }

    // MARK: - Ningún servicio con la factoría vieja

    /// Las tres llamadas que no se pueden lanzar sin montar media app (el chat con su contexto, las sugerencias con su
    /// caché del día y Tendencias con su entrada) se fijan aquí por su cuerpo: cada función pide SU tarea. Y nadie más
    /// llama a la factoría sin tarea.
    @Test("cada función pide su tarea (y nadie usa ya `category:`)")
    func everyCallSiteNamesItsTask() throws {
        let expected: [(file: String, function: String, task: String)] = [
            ("Yala/App/Services/ImageVision/ImageVisionService.swift", "func analyze(", ".photoRead"),
            ("Yala/Services/Chat/ChatIntentClassifierService.swift", "func classify(", ".chatIntent"),
            ("Yala/App/Services/ChatSuggestionsLLMService.swift", "private func generate(", ".chatSuggestions"),
            ("Yala/Services/ChatAssistantService.swift", "func processQuestion(", ".chatAnswer"),
            ("Yala/App/Services/SuggestionsRewriterService.swift", "func process(", ".chatRewrite"),
            ("Yala/Services/TranscriptionParserService.swift", "func parseMultiple(", ".textParse"),
            ("Yala/Services/VoiceTranscriptionService.swift", "func transcribe(", ".voiceTranscribe"),
            ("Yala/Services/InsightsLLMService.swift", "func generateInsights(", ".insightsCards"),
            ("Yala/Services/InsightsLLMService.swift", "func generateCashFlowInsight(", ".insightsCashflow"),
            ("Yala/Services/InsightsLLMService.swift", "func generateDeviationInsight(", ".insightsDeviation"),
            ("Yala/Services/TrendsAIService.swift", "func generate(", ".trendsSummary"),
        ]
        for item in expected {
            let source = try String(contentsOf: repoURL(item.file), encoding: .utf8)
            let start = try #require(source.range(of: item.function), "\(item.file): no encuentro \(item.function)")
            // El cuerpo hasta la siguiente función: la llamada a la factoría tiene que caer dentro.
            let rest = source[start.upperBound...]
            let next = rest.range(of: "\n    func ") ?? rest.range(of: "\n    private func ") ?? rest.range(of: "\n    static func ")
            let body = next.map { rest[..<$0.lowerBound] } ?? rest
            #expect(body.contains("ProxyClientFactory.makeOpenAI(task: \(item.task))"), "\(item.function) en \(item.file) no pide \(item.task)")
        }
        let roots = ["Yala", "YalaShare", "YalaWidgets"]
        var offenders: [String] = []
        let fm = FileManager.default
        for root in roots {
            guard let walker = fm.enumerator(at: repoURL(root), includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let text = try String(contentsOf: url, encoding: .utf8)
                if text.contains("makeOpenAI(category:") { offenders.append(url.lastPathComponent) }
            }
        }
        #expect(offenders.isEmpty, "siguen con la factoría sin tarea: \(offenders)")
    }

    private func repoURL(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relative)
    }
}
