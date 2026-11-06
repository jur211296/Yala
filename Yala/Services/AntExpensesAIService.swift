//
//  AntExpensesAIService.swift
//  Yala
//
//  La llamada de IA de los gastos hormiga Pro (ticket `insights-ant-expenses-ai-version-for-pro`): qué grupos de compras
//  pequeñas son la misma tienda escrita de otra forma, y un consejo corto. Va por el proxy de Yala con su propia tarea
//  (`ProxyTask.insightsAnts`); modelo y parámetros los elige la fila del gateway. Lo que se envía y cómo se valida la
//  respuesta vive en `AntExpensesAILogic`.
//

import Foundation
import OpenAI

@MainActor
final class AntExpensesAIService {

    static let shared = AntExpensesAIService()

    private var lastCallTime: Date?

    func generate(payload: [String: Any]) async throws -> AntAIResponse {
        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(task: .insightsAnts)
        } catch {
            throw InsightsLLMError.networkError(error)
        }

        if let lastCall = lastCallTime, Date.now.timeIntervalSince(lastCall) < 5 {
            throw InsightsLLMError.rateLimited
        }
        lastCallTime = Date.now

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let language = payload["locale"] as? String ?? AIPromptLanguage.current
        let currencyCode = payload["currency"] as? String ?? ""

        let system = Self.systemPrompt(currencyCode: currencyCode, language: language)
        guard let systemMessage = ChatQuery.ChatCompletionMessageParam(role: .system, content: system),
              let userMessage = ChatQuery.ChatCompletionMessageParam(
                role: .user, content: "Compras pequeñas del período:\n\(jsonString)")
        else { throw InsightsLLMError.parseFailed }

        let query = ChatQuery(
            messages: [systemMessage, userMessage],
            model: .gpt4_1_mini,
            responseFormat: .jsonObject,
            temperature: 0.2
        )

        do {
            let result = try await client.chats(query: query)
            guard let content = result.choices.first?.message.content,
                  let data = content.data(using: .utf8)
            else { throw InsightsLLMError.parseFailed }
            do {
                return try JSONDecoder().decode(AntAIResponse.self, from: data)
            } catch {
                #if DEBUG
                print("AntExpensesAIService: Error: \(error)")
                #endif
                throw InsightsLLMError.parseFailed
            }
        } catch let error as InsightsLLMError {
            throw error
        } catch {
            throw InsightsLLMError.networkError(error)
        }
    }

    /// El prompt de sistema, en el idioma de la app (`language`, BCP-47).
    static func systemPrompt(currencyCode: String, language: String) -> String {
        let currencyDisplay = CurrencyCode(rawValue: currencyCode)?.symbol ?? currencyCode
        let languageLine = InsightsLLMService.languageInstruction(language)
        let register = AIPromptLanguage.informalRegister(forBaseLanguage: AIPromptLanguage.baseCode(of: language))
        return """
        Eres un analista de finanzas personales. Recibes las compras pequeñas de un período, agrupadas por cómo las \
        describió el usuario: cada grupo tiene un id, el nombre tal como lo escribió, cuántas veces y cuánto sumó, y a \
        veces lo mismo del período anterior. Con "detail_level": "full" llegan además las grafías de cada grupo \
        ("spellings"), su subcategoría ("category"), cada compra con fecha e importe ("purchases") y las compras \
        pequeñas del período anterior que hoy no aparecen ("previous_only_groups"): úsalos para juntar con más \
        precisión y para que el consejo sea concreto (días, frecuencia, qué dejó de repetirse).

        Tareas:
        1. JUNTAR: indica qué grupos son el MISMO comercio o la misma compra escrita de otra forma (mayúsculas, \
        abreviaturas, sufijos como "coffee" o "SAC", errores de tipeo, la sucursal). Solo si estás seguro. Dos \
        comercios distintos del mismo tipo (dos cafeterías distintas) NO se juntan. Un grupo va en una sola unión.
        2. CONSEJO: UNA oración (máximo 140 caracteres) sobre el patrón más útil de estas compras pequeñas: qué se \
        repite más, qué subió frente al período anterior o cuánto suman juntas. O null si no hay nada útil.

        \(languageLine)

        REGLAS CRÍTICAS:
        - Usa SOLO los ids del JSON. Nunca inventes ids, nombres, montos ni comercios
        - Las cifras del consejo salen del JSON (sumando grupos si los juntaste)
        - Trato: \(register). Lidera con el dato, nunca regañes ni juzgues, nunca hagas preguntas
        - NUNCA uses "Debes...", "Tienes que...", "Obviamente..."
        - Habla de compras o gastos, nunca de transacciones
        - Usa **negritas** para la cifra clave
        - Montos en \(currencyCode): SIEMPRE \(currencyDisplay) NÚMERO (ej: \(currencyDisplay) 120). Divisa ANTES del número

        JSON: {"merges": [{"ids": ["g1", "g4"]}], "tip": "una oración"}. Sin uniones: "merges": [].
        """
    }
}
