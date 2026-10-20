//
//  ChatAssistantService.swift
//  Yala
//
//  Pipeline LLM for Yala IA chat assistant — context-rich (Opción B).
//  Single-step: build FullFinancialContext + 1 LLM call. No function calling en la app.
//  El system prompt incluye TODA la data financiera del user en JSON, así que
//  el LLM no necesita clasificar intent ni llamar tools.
//
//  Modo nube con el flag encendido (`YalaIAChatRouting`): la MISMA petición sale como `chat.explore`, y el gateway le
//  da al modelo herramientas que leen las tablas del usuario. La app no ejecuta nada: solo cambia la tarea, añade dos
//  cabeceras y espera más. En privado, nada de esto se toca.
//

import Foundation
import OpenAI
import SwiftData

@MainActor
@Observable
final class ChatAssistantService {

    // MARK: - Singleton

    static let shared = ChatAssistantService()
    private init() {}

    // MARK: - Context Builder (caché 60s vive aquí)

    @ObservationIgnored
    private let contextBuilder = FullFinancialContextBuilder()

    // MARK: - Rate Limiting

    @ObservationIgnored
    private var lastCallTime: Date?

    private static let rateLimitInterval: TimeInterval = 5
    static let dailyLimit = 75
    private static let maxQuestionLength = 500
    // El tiempo de espera de la respuesta lo da la ruta (`YalaIAChatRoute.timeout`): 20 s el de siempre, 30 s el camino
    // ampliado de la nube.

    // MARK: - Daily Counter

    var questionsToday: Int {
        let lastDate = UserDefaults.standard.string(forKey: "chatLastQuestionDate") ?? ""
        let todayStr = Self.todayString()
        if lastDate != todayStr { return 0 }
        return UserDefaults.standard.integer(forKey: "chatQuestionsToday")
    }

    private func incrementDailyCounter() {
        let todayStr = Self.todayString()
        let lastDate = UserDefaults.standard.string(forKey: "chatLastQuestionDate") ?? ""
        if lastDate != todayStr {
            UserDefaults.standard.set(todayStr, forKey: "chatLastQuestionDate")
            UserDefaults.standard.set(1, forKey: "chatQuestionsToday")
        } else {
            let current = UserDefaults.standard.integer(forKey: "chatQuestionsToday")
            UserDefaults.standard.set(current + 1, forKey: "chatQuestionsToday")
        }
    }

    private static func todayString() -> String {
        DayKeyFormatter.string(from: Date.now)
    }

    // MARK: - Main Entry Point

    /// Pipeline orquestador. Aplica guards comunes (daily limit, rate limit, validación
    /// de texto), clasifica el intent y ramifica al sub-flow correspondiente.
    ///
    /// - `forceIntent`: si está presente, salta el classifier (usado por quick-reply
    ///   chips de ambiguous para no reclasificar el mismo texto retórico).
    /// - `includeGroupsInTotal`: el ajuste «Grupos en el total» del Panel; el saldo total del contexto lo sigue.
    ///
    /// Retorna `ChatAssistantResponse` con `text` + `attachments` opcionales (drafts
    /// para `register`, quick-replies para `ambiguous`).
    func processQuestion(
        question: String,
        turns: [QAPair],
        modelContext: ModelContext,
        currencyCode: String,
        converter: CurrencyConverting,
        includeGroupsInTotal: Bool,
        forceIntent: ChatIntent? = nil
    ) async throws -> ChatAssistantResponse {
        // === Common guards (apply to all 3 paths) ===
        // Por qué camino sale la pregunta: en privado, siempre `chat.answer` (ni se mira el flag ni la sesión).
        let route = await YalaIAChatRouting.resolve()
        let client: OpenAI
        do {
            switch route {
            case .standard:
                client = try await ProxyClientFactory.makeOpenAI(task: .chatAnswer)
            case .cloudExplore:
                client = try await ProxyClientFactory.makeOpenAI(
                    task: .chatExplore,
                    extraHeaders: route.extraHeaders,
                    timeout: route.timeout
                )
            }
        } catch {
            throw ChatAssistantError.networkError(error)
        }
        guard NetworkMonitor.shared.isConnected else { throw ChatAssistantError.offline }
        guard questionsToday < Self.dailyLimit else { throw ChatAssistantError.dailyLimitReached }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChatAssistantError.emptyQuestion }
        guard question.count <= Self.maxQuestionLength else { throw ChatAssistantError.questionTooLong }

        if let last = lastCallTime, Date.now.timeIntervalSince(last) < Self.rateLimitInterval {
            throw ChatAssistantError.rateLimited
        }
        lastCallTime = Date.now
        incrementDailyCounter()

        // === Intent resolution ===
        // Una pregunta que se reconoce en el teléfono no pasa por el clasificador (~1,4 s menos, banco del 2026-10-20).
        let intent: ChatIntent
        if let forced = forceIntent {
            intent = forced
        } else if let routed = ChatIntentClassifierService.preRoute(trimmed) {
            intent = routed
        } else {
            let classification = await ChatIntentClassifierService.shared.classify(text: trimmed)
            intent = classification.intent
        }

        // === Branch ===
        switch intent {
        case .ask:
            let text = try await runAskFlow(
                question: trimmed,
                turns: turns,
                modelContext: modelContext,
                currencyCode: currencyCode,
                converter: converter,
                includeGroupsInTotal: includeGroupsInTotal,
                client: client,
                timeout: route.timeout
            )
            return ChatAssistantResponse(text: text, attachments: nil, intent: .ask)

        case .register:
            return try await runRegisterFlow(
                question: trimmed,
                modelContext: modelContext,
                currencyCode: currencyCode
            )

        case .ambiguous:
            return runAmbiguousFlow(question: trimmed)
        }
    }

    // MARK: - Ask flow (existing context-rich pipeline)

    private func runAskFlow(
        question: String,
        turns: [QAPair],
        modelContext: ModelContext,
        currencyCode: String,
        converter: CurrencyConverting,
        includeGroupsInTotal: Bool,
        client: OpenAI,
        timeout: TimeInterval
    ) async throws -> String {
        let needsAnomalies = AnomalyKeywords.matches(question)

        // Idioma de la UI vía AppLocale (override in-app → Locale.preferredLanguages → en).
        // NUNCA Locale.current.identifier: refleja la región de formato (AppleLocale, ej.
        // "es_PE") aunque la app corra localizada en otro idioma — el LLM respondería en
        // el idioma de la región, no en el de la interfaz.
        // BCP-47 completo (e.g. "es-AR", "pt-BR") — el LLM entiende variantes regionales y
        // ajusta tono (voseo argentino, registro coloquial brasileño, etc.) si se le pasa.
        let language = AppLocale.current.identifier
        let country = Locale.current.region?.identifier ?? "US"
        let currencyDisplay = CurrencyCode(rawValue: currencyCode)?.symbol ?? currencyCode

        let context = contextBuilder.build(
            modelContext: modelContext,
            currencyCode: currencyCode,
            currencyDisplay: currencyDisplay,
            converter: converter,
            language: language,
            country: country,
            includeAnomalies: needsAnomalies,
            includeGroupsInTotal: includeGroupsInTotal,
            // El interruptor «Incluir gastos de grupo en estadísticas», leído como las sugerencias del chat y
            // el Panel (default ON): apagado, los movimientos de grupo no cuentan en lo que ve Yala IA.
            includeGroupTransactionsInStats: (UserDefaults.standard.object(
                forKey: AppPreferences.Keys.includeGroupTransactionsInStats
            ) as? Bool) ?? true
        )

        // Un contexto que no se puede preparar es un error, no «no hay datos»: sin llamar al modelo.
        let query: ChatQuery
        do {
            query = try makeAskQuery(
                context: context,
                turns: turns,
                question: question,
                language: language,
                country: country,
                currencyCode: currencyCode,
                currencyDisplay: currencyDisplay
            )
        } catch {
            #if DEBUG
            print("ChatAssistantService: el contexto no se pudo preparar: \(error)")
            #endif
            throw ChatAssistantError.parseFailed
        }

        let result = try await callWithTimeout(query, client: client, timeout: timeout)
        guard let content = result.choices.first?.message.content else {
            throw ChatAssistantError.parseFailed
        }
        return content
    }

    /// La petición EXACTA de una pregunta del chat: system prompt (reglas + datos) + turnos + la pregunta. La usa
    /// `runAskFlow` y la usa el banco de preguntas (`YalaIABankDumpTests`), para que lo que se mide sea lo que sale.
    func makeAskQuery(
        context: FullFinancialContext,
        turns: [QAPair],
        question: String,
        language: String,
        country: String,
        currencyCode: String,
        currencyDisplay: String,
        now: Date = .now
    ) throws -> ChatQuery {
        let systemPrompt = try buildSystemPrompt(
            context: context,
            language: language,
            country: country,
            currencyCode: currencyCode,
            currencyDisplay: currencyDisplay,
            now: now
        )
        let messages = buildMessages(systemPrompt: systemPrompt, turns: turns, currentQuestion: question)
        return ChatQuery(
            messages: messages,
            model: .gpt4_1_mini,
            temperature: 0.4,
            stream: false
        )
    }

    // MARK: - Register flow

    /// Multi-tx cap: si el parser devuelve >5 transacciones, tomamos las primeras 5
    /// y avisamos al user inline en el `text` del response.
    static let maxDraftsPerMessage = 5

    private func runRegisterFlow(
        question: String,
        modelContext: ModelContext,
        currencyCode: String
    ) async throws -> ChatAssistantResponse {
        // Verificar que hay al menos una cuenta — sin cuentas no se puede registrar.
        // Un fetch fallido NO debe caer al guard (respondería "no hay cuentas" siendo falso):
        // se propaga y el VM lo muestra como error genérico.
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { !$0.isArchived }
        )
        let accounts: [Account]
        do {
            accounts = try modelContext.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("ChatAssistantService: fetch de cuentas falló: \(error)")
            #endif
            throw error
        }
        guard !accounts.isEmpty else {
            return ChatAssistantResponse(
                text: noAccountsText(),
                attachments: nil,
                intent: .register
            )
        }

        let (expenseNames, incomeNames) = DraftBuilder.fetchVisibleSubcategoryNames(context: modelContext)

        // Parse multi. Si falla por red/API/parse, propaga como error tipado en vez
        // de caer a ambiguous (sería confuso: el user dijo claramente "registra X"
        // y vería la repregunta de aclaración). Que el VM lo muestre como banner.
        let parsed: [ParsedTransaction]
        do {
            parsed = try await TranscriptionParserService.shared.parseMultiple(
                text: question,
                expenseSubcategories: expenseNames,
                incomeSubcategories: incomeNames,
                currency: ParserCurrencyContext(
                    mainCurrency: currencyCode,
                    accountCurrencies: accounts.filter { !$0.isSystemAccount }.map(\.currencyCode)
                )
            )
        } catch let parserError as ParserError {
            switch parserError {
            case .noAPIKey: throw ChatAssistantError.noAPIKey
            case .networkError(let err): throw ChatAssistantError.networkError(err)
            case .invalidResponse, .parsingFailed: throw ChatAssistantError.parseFailed
            case .emptyText: throw ChatAssistantError.emptyQuestion
            }
        } catch {
            throw ChatAssistantError.networkError(error)
        }

        // Filtrar transacciones con monto válido (>0, finito)
        let valid = parsed.filter {
            guard let amount = $0.amount else { return false }
            let dbl = NSDecimalNumber(decimal: amount).doubleValue
            return dbl.isFinite && dbl > 0 && dbl < 1_000_000
        }

        guard !valid.isEmpty else {
            return runAmbiguousFlow(question: question)
        }

        // Cap a 5
        let cropped = Array(valid.prefix(Self.maxDraftsPerMessage))
        // El modo «solo gastos» se lee como en Siri: del App Group, donde lo escribe `AppPreferences`.
        let expensesOnlyMode = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?
            .bool(forKey: AppPreferences.Keys.expensesOnlyMode) ?? false
        let drafts = cropped.map {
            DraftBuilder.build(
                parsed: $0, defaultCurrency: currencyCode, context: modelContext, expensesOnlyMode: expensesOnlyMode)
        }

        let exceededCap = valid.count > Self.maxDraftsPerMessage
        let text = exceededCap
            ? overflowText(detected: valid.count, kept: Self.maxDraftsPerMessage)
            : registerConfirmText(count: drafts.count)

        return ChatAssistantResponse(
            text: text,
            attachments: [.drafts(drafts)],
            intent: .register
        )
    }

    // MARK: - Ambiguous flow

    private func runAmbiguousFlow(question: String) -> ChatAssistantResponse {
        let canned = ambiguousCannedText()
        let chips: [QuickReply] = [
            QuickReply(
                label: ambiguousChipRegisterLabel(),
                triggerText: question,
                forceIntent: .register
            ),
            QuickReply(
                label: ambiguousChipAskLabel(),
                triggerText: question,
                forceIntent: .ask
            ),
        ]
        return ChatAssistantResponse(
            text: canned,
            attachments: [.ambiguous(canned: canned, choices: chips)],
            intent: .ambiguous
        )
    }

    // MARK: - Localized text helpers

    private func noAccountsText() -> String { L10n.Chat.Draft.noAccountsBlocking }

    private func registerConfirmText(count: Int) -> String {
        count == 1 ? L10n.Chat.Draft.confirmRegisterSingular : L10n.Chat.Draft.confirmRegisterPlural
    }

    private func overflowText(detected: Int, kept: Int) -> String {
        L10n.Chat.Draft.overflowFormat(detected, kept)
    }

    private func ambiguousCannedText() -> String { L10n.Chat.Draft.ambiguousCanned }

    private func ambiguousChipRegisterLabel() -> String { L10n.Chat.Draft.ambiguousChipRegister }

    private func ambiguousChipAskLabel() -> String { L10n.Chat.Draft.ambiguousChipAsk }

    // MARK: - Helpers

    private func callWithTimeout(_ query: ChatQuery, client: OpenAI, timeout: TimeInterval) async throws -> ChatResult {
        try await withThrowingTaskGroup(of: ChatResult.self) { group in
            group.addTask { try await client.chats(query: query) }
            group.addTask {
                try await Task.sleep(for: .seconds(timeout))
                throw ChatAssistantError.timeout
            }
            guard let first = try await group.next() else {
                throw ChatAssistantError.timeout
            }
            group.cancelAll()
            return first
        }
    }

    /// Construye los messages para OpenAI: system prompt + todos los turnos del día
    /// (Q+A only) + la pregunta nueva. NO se manda toolResultJSON (siempre nil tras refactor).
    private func buildMessages(
        systemPrompt: String,
        turns: [QAPair],
        currentQuestion: String
    ) -> [ChatQuery.ChatCompletionMessageParam] {
        var messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: systemPrompt)
        ].compactMap { $0 }

        for turn in turns {
            if let userMsg = ChatQuery.ChatCompletionMessageParam(role: .user, content: turn.question) {
                messages.append(userMsg)
            }
            if let assistantMsg = ChatQuery.ChatCompletionMessageParam(role: .assistant, content: turn.response) {
                messages.append(assistantMsg)
            }
        }
        if let userMsg = ChatQuery.ChatCompletionMessageParam(role: .user, content: currentQuestion) {
            messages.append(userMsg)
        }
        return messages
    }

    // MARK: - System Prompt (split static + dynamic for prompt caching)

    private func buildSystemPrompt(
        context: FullFinancialContext,
        language: String,
        country: String,
        currencyCode: String,
        currencyDisplay: String,
        now: Date
    ) throws -> String {
        let staticPart = buildSystemPromptStatic(
            language: language,
            country: country,
            currencyCode: currencyCode,
            currencyDisplay: currencyDisplay
        )
        let dynamicPart = try buildSystemPromptDynamic(context: context, now: now)

        // STATIC primero para que OpenAI cache el prefix estable.
        return staticPart + "\n\n" + dynamicPart
    }

    /// Bloque estable (cacheable): identidad, reglas, tono, focus, few-shot.
    /// Cambia solo cuando el user cambia tono/focus/idioma.
    private func buildSystemPromptStatic(
        language: String,
        country: String,
        currencyCode: String,
        currencyDisplay: String
    ) -> String {
        // Tone (shared with Insights)
        let tone = InsightTone.current
        let toneInstruction: String
        switch tone {
        case .normal: toneInstruction = ""
        case .considerate: toneInstruction = "Sé amable y empático. Suaviza datos negativos con contexto positivo."
        case .sarcastic: toneInstruction = "Sé directo y con humor sutil, como un amigo cercano que tiene confianza."
        }

        let focus = InsightFocus.current
        let focusInstruction: String
        switch focus {
        case .balanced: focusInstruction = ""
        case .saver: focusInstruction = "Enfatiza oportunidades de ahorro y señala gastos potencialmente innecesarios."
        case .cautious: focusInstruction = "Prioriza alertas tempranas de riesgo: presupuestos cerca del límite, gastos inusuales, tendencias al alza."
        }

        // El trato sale del idioma BASE (es-ES, es-419, pt-BR y en-GB caían al «informal you» por llevar región) y es-AR
        // pide voseo (BRAND-VOICE §9.4). Ticket `chat-register-misses-regional-variants`.
        let register = AIPromptLanguage.chatRegister(for: language)

        return """
        Eres el asistente financiero de Yala. Ayudas al usuario a entender sus finanzas respondiendo preguntas sobre gastos, ingresos, presupuestos, cuentas, patrones y proyecciones.

        REGLAS CRÍTICAS:
        1. SOLO usa los datos del JSON \"DATOS DEL USUARIO\" que recibes al final del system prompt. NUNCA inventes cifras ni nombres de categorías/budgets/merchants que no aparezcan en el JSON.
        2. Si la pregunta requiere data que no está en el JSON, dilo honestamente. Antes de decir que no tienes un dato, búscalo también en `monthly_history`, `income_categories`, `recurring.active`, `fx_rates` y `total_current_year`.
        3. Responde en el idioma del usuario: \(language).
        4. Usa el formato de moneda del usuario: \(currencyDisplay) antes del monto.
        5. Negritas para cifras importantes (**\(currencyDisplay)45.50**).
        6. Máximo 3-4 oraciones. Sé conciso pero informativo.
        7. Si mencionas variaciones o comparaciones, SIEMPRE aclara: qué cantidad cambió, contra qué periodo, y si subió o bajó. Ejemplo: \"Gastaste **\(currencyDisplay)118** en Combustible, un **20% más** que el mes pasado (antes \(currencyDisplay)98)\". NUNCA digas solo un porcentaje sin explicar qué significa.
        7b. MES EN CURSO: `periods.current_month` y los `total_current_month` cubren solo lo que va de este mes. Para compararlos con el mes pasado usa `periods.last_month_to_date` y los `total_last_month_to_date`, que son el mes pasado hasta el mismo día (las `variation_percent_vs_last_month_to_date` ya están calculadas contra ellos), y aclara que comparas hasta el mismo día del mes pasado. `periods.last_month` y `total_last_month` son el mes pasado ENTERO: úsalos cuando pregunten por el mes pasado en sí, nunca para decir si este mes se gasta más o menos.
        7c. MESES ANTERIORES: `monthly_history` trae cada uno de los 12 meses cerrados antes del actual (`month` = AAAA-MM), con ingresos, gastos, `balance` (ingresos − gastos) y lo que más pesó (`top_categories` y `top_subcategories` de gasto, `top_income` de ingreso). Úsalo para un mes concreto («¿cuánto gasté en mayo?»: un mes sin año es el más reciente que ya terminó), para el mismo mes del año pasado (`periods.same_month_last_year`, el mes ENTERO: compara lo que va de este mes con él y dilo) y para el ahorro de cada mes. Para «¿qué mes gasté más/menos?», las medias y el total de un año (`by_year`, con cuántos meses trae) usa `monthly_history_summary`, que ya los trae calculados. `metadata.period_months` dice qué mes es cada período: «hace tres meses» es `three_months_ago`. Si una subcategoría no sale en el top de ese mes, di que no está entre lo que más pesó y no inventes su cifra. Si el mes pedido es anterior al más antiguo de la lista, di desde qué mes tienes datos. Lo que va del año está en `periods.current_year` y en los `total_current_year`.
        8. NUNCA des consejos de inversión ni recomendaciones de productos financieros.
        9. Registro: \(register).
        10. Si la pregunta NO es sobre finanzas personales, responde amablemente que solo puedes ayudar con temas financieros.
        11. Usa los nombres EXACTOS de categorías, subcategorías, budgets, tags y merchants tal como aparecen en el JSON. Si el user dice un sinónimo (ej: \"gasolina\"), resuélvelo a la subcategoría/categoría correcta del JSON (ej: \"Combustible\"). En tu respuesta, SIEMPRE usa los nombres reales del JSON, NUNCA sinónimos ni generalizaciones inventadas. Un presupuesto se nombra por su `name`, no por su categoría.
        12. PRIORIDAD SUBCATEGORÍA: Si la pregunta es sobre una subcategoría (ej: \"Bus\", \"Gasolina\"), centra la respuesta en ESA subcategoría usando los datos de `categories[].subcategories[]` del JSON. NUNCA respondas con datos de la categoría padre cuando el user pregunta por la subcategoría.
        13. SAMPLE SIZE en patrones de día de semana: el campo `weekday_pattern_30_days[].sample_size` indica cuántas tx hay en ese weekday durante los 30 días. Si el sample_size es bajo (1-2 tx), advierte al user que el dato puede estar dominado por gastos puntuales y no reflejar un patrón real. NUNCA presentes un weekday total como \"patrón\" si solo se basa en 1-2 tx.
        14. SUMA INCLUYE TODO: si te preguntan por \"gastos recurrentes pagados este mes\", usa `recurring.paid_this_month` (lista con fechas y montos). Para pendientes, usa `recurring.pending_next_30_days` (los de `is_income` en `true` son ingresos que esperas, no pagos). Para «¿qué suscripciones pago?» o «¿cuándo me toca pagar X?», usa `recurring.active`: cada pago programado activo con su importe, `type`, frecuencia y `next_date`.
        13b. HOY Y AYER: `periods.today` es hoy y `periods.yesterday` es ayer; no los mezcles. `categories` viene ordenado de mayor a menor gasto del mes en curso: la primera es en la que más gastas este mes.
        14b. INGRESOS: `income_categories` trae lo que entró por categoría y subcategoría (este mes, el mes pasado y lo que va del año).
        15. MONTOS APROXIMADOS: los campos `income_is_approximate`, `expense_is_approximate` y `balance_is_approximate` de `periods` y `weeks` valen `true` cuando una parte apreciable de ese total se convirtió desde otra divisa con una tasa que no era la del día. Cuando uses una cifra con su flag en `true`, di que es aproximada (ej: \"unos **\(currencyDisplay)1200**\" o \"aproximadamente\"). Con el flag en `false` NUNCA añadas esa salvedad: una advertencia que sale siempre deja de significar nada. Los flags NO cambian el número, solo cómo lo presentas.
        15b. SALDO TOTAL: `balances.total_balance` es el saldo total que el usuario ve en el Panel. Con `balances.total_includes_groups` en `false` el usuario apagó el ajuste «Incluir grupos en saldo total»: las cuentas de `balances.accounts` con `type` \"system\" (las de Grupos) aparecen en la lista pero NO están sumadas en el total; dilo si las mencionas y NUNCA las sumes tú. Con `true` sí están sumadas. Si ninguna cuenta tiene `type` \"system\", no hay cuentas de Grupos en los datos: no digas que el total incluye grupos, y si te preguntan por grupos, di que no ves gastos de grupos en tus datos.
        15d. OTRA DIVISA: una cuenta en otra divisa trae `balance_in_main_currency`, su saldo en \(currencyDisplay) con la tasa más reciente. `fx_rates` dice cuánto vale 1 unidad de cada divisa en \(currencyDisplay): úsalo para convertir un importe que te den en otra divisa. Con `balance_in_main_currency_is_approximate` o `is_approximate` en `true`, di que es aproximado.
        15e. ¿SUBIÓ O BAJÓ MI SALDO?: el `balance` de un período es ingresos − gastos, lo que tu dinero subió (positivo) o bajó (negativo) en ese tiempo. No es el saldo de tus cuentas, que está en `balances`.
        15f. ¿PUEDO GASTAR X? / ¿ME ALCANZA?: contesta sí, no o «sí, con cuidado» y enseña la cuenta en una frase, siempre con cifras. Parte de `balances.total_balance` (el dinero de hoy) y resta los pagos que vencen antes de ese gasto: para este mes, `month_outlook.pending_payments_until_month_end` (ya sumado); más adelante, los de `recurring.pending_next_30_days`. Lo que ya gastaste ya está descontado del saldo: nunca lo restes otra vez. Si el gasto cae en una categoría con presupuesto, di cuánto le queda a ESE presupuesto (`limit` − `spent`) y si se pasaría. Si el importe viene en otra divisa, conviértelo con `fx_rates`. Para «¿cuánto puedo gastar por día hasta fin de mes?», divide `month_outlook.all_budgets_remaining` (lo que queda de TODOS los presupuestos mensuales juntos, ya sumado; para un presupuesto solo, su `limit` − `spent`) entre `month_outlook.days_left` (cuenta hoy); sin presupuestos, usa ingresos − gastos del mes − `month_outlook.pending_payments_until_month_end`. Di qué base usaste.
        15g. COMERCIOS: los nombres de `merchants_top_20` y de los `merchant` vienen normalizados en MAYÚSCULAS; escríbelos con mayúscula inicial (UBER → Uber).
        15c. TARJETA CON VARIAS DIVISAS: una cuenta de `balances.accounts` con `lines` es UNA sola tarjeta que cobra en varias divisas. Su `balance` y su `currency` son los de la divisa principal de la tarjeta, y cada elemento de `lines` es otra divisa de la MISMA tarjeta, con su saldo en su divisa. `card_total` es la tarjeta entera convertida a \(currencyDisplay) con la tasa más reciente: si `card_total_is_approximate` es `true`, di que es aproximado. Habla de ella como una tarjeta, no como varias cuentas, y NUNCA sumes en crudo saldos de divisas distintas.
        \(toneInstruction.isEmpty ? "" : "16. Tono: \(toneInstruction)")
        \(focusInstruction.isEmpty ? "" : "17. Enfoque: \(focusInstruction)")

        MANEJO DE CONTEXTO MULTI-TURNO:
        - El historial puede tener varios turnos sobre temas distintos. Si la pregunta NUEVA del user no se relaciona con turnos anteriores, IGNORA el contexto previo y responde fresh basándote solo en los datos del JSON actual.
        - Si la pregunta es ambigua (ej: \"¿y eso?\", \"¿cuánto fue?\", \"¿el mayor?\") y hay 3+ temas distintos en los últimos turnos, NO adivines: pide clarificación breve.
        - NUNCA mezcles datos de turnos viejos con la pregunta actual a menos que sea claramente un follow-up.

        EJEMPLOS DE INTERPRETACIÓN (few-shot):

        EJEMPLO 1 — Patrón de día de semana con sample size bajo:
        User: \"¿En qué días gasto más en transporte?\"
        Datos relevantes: weekday_pattern_30_days incluye Sunday con total \(currencyDisplay)3400, sample_size=2, day_occurrences=4.
        Respuesta esperada: \"Los domingos aparece tu mayor total (**\(currencyDisplay)3400**), pero ojo: solo hay 2 tx en domingos del último mes, así que puede estar dominado por un gasto puntual y no reflejar un patrón real.\"

        EJEMPLO 2 — Pregunta sobre subcategoría específica:
        User: \"¿Cómo se comparan mis gastos en bus con meses anteriores?\"
        Datos relevantes: categories incluye \"Transporte\" con subcategories[] que tiene \"Bus\" con total_current_month=120, total_last_month_to_date=150, total_last_month=180, total_two_months_ago=200.
        Respuesta esperada: \"En **Bus** llevas **\(currencyDisplay)120** este mes, **20% menos** que el mes pasado a estas alturas (**\(currencyDisplay)150**); el mes pasado entero cerró en **\(currencyDisplay)180** y hace 2 meses en **\(currencyDisplay)200**.\" — NO mezcles con totales de \"Transporte\".

        EJEMPLO 3 — Recurrentes pagados vs pendientes:
        User: \"¿Cuánto pagué en gastos recurrentes este mes?\"
        Datos relevantes: recurring.paid_this_month incluye 4 entries con amount sumando 280.
        Respuesta esperada: \"Has pagado **\(currencyDisplay)280** en pagos recurrentes este mes, distribuidos en 4 cargos.\" Si pregunta por pendientes, usa pending_next_30_days.

        EJEMPLO 4 — Pregunta no-financiera (redirección):
        User: \"¿Cuál es la capital de Francia?\"
        Respuesta esperada: \"Solo puedo ayudarte con tus finanzas personales — gastos, ingresos, presupuestos, patrones, etc. ¿Algo de eso?\"

        BRAND VOICE:
        - Trato: \(register). Cercano pero respetuoso.
        - NUNCA regañar, juzgar o culpar al user por gastar.
        - Lidera con el dato, opinión después.
        - Usa "gasto"/"ingreso", NO "transacción" (excepto contexto técnico).
        """
    }

    /// Bloque dinámico: JSON con TODA la data financiera + DateContext.
    /// Cambia cada llamada (o cada 60s con caché del builder).
    /// Lanza si el JSON no se puede preparar: sin él, el modelo recibía `{}` y contestaba con seguridad que no había
    /// datos (ticket `chat-context-encoding-failure-is-silent`). `runAskFlow` lo convierte en `.parseFailed` y no llama
    /// al modelo.
    private func buildSystemPromptDynamic(context: FullFinancialContext, now: Date) throws -> String {
        let dateContext = DateContextProvider.buildDateContext(now: now)
        return try """
        DATOS DEL USUARIO (JSON):
        \(context.toJSONString())

        CONTEXTO DE FECHA:
        \(dateContext)
        """
    }
}
