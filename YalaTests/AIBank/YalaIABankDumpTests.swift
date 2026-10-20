//
//  YalaIABankDumpTests.swift
//  YalaTests
//
//  El banco de preguntas de Yala IA (`qa/ai-bank/questions.json`, revisión del 2026-10-20). Siembra la semilla
//  `realista` y escribe, por cada pregunta, la petición EXACTA que la app manda al gateway —contexto del
//  `FullFinancialContextBuilder` real y prompt de `ChatAssistantService.makeAskQuery`—, más la ruta que decide el
//  teléfono y una hoja de cifras de la app para corregir las respuestas. `gateway/scripts/yala-ia-bank.ts` las repite
//  contra staging.
//
//  Apagado salvo con `TEST_RUNNER_YALA_AI_BANK_DIR=<carpeta>` en el entorno de `xcodebuild`: escribe ficheros fuera
//  del repo y no comprueba nada que deba fallar en el CI.
//

import Foundation
import OpenAI
import SwiftData
import Testing

@testable import Yala

#if DEBUG

private let bankOutputDir = ProcessInfo.processInfo.environment["YALA_AI_BANK_DIR"]

@Suite("Banco de Yala IA · volcado de peticiones", .serialized, .enabled(if: bankOutputDir != nil))
@MainActor
struct YalaIABankDumpTests {

    private struct BankFile: Decodable {
        struct Turn: Decodable { let q: String; let a: String }
        struct Question: Decodable {
            let id: String
            let kind: String
            let lang: String
            let expect: String
            let q: String
            let turns: [Turn]?
        }
        let questions: [Question]
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test func dumpRequests() async throws {
        let outDir = URL(fileURLWithPath: try #require(bankOutputDir))
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let bankURL = Self.repoRoot.appendingPathComponent("qa/ai-bank/questions.json")
        let bank = try JSONDecoder().decode(BankFile.self, from: Data(contentsOf: bankURL))

        // La semilla nombra cuentas y categorías con el idioma de la app: español, como la persona del banco.
        let langDefaults = LanguageManager.sharedDefaults
        let previousLanguage = langDefaults.string(forKey: LanguageManager.overrideKey)
        langDefaults.set("es-419", forKey: LanguageManager.overrideKey)
        defer {
            if let previousLanguage {
                langDefaults.set(previousLanguage, forKey: LanguageManager.overrideKey)
            } else {
                langDefaults.removeObject(forKey: LanguageManager.overrideKey)
            }
        }

        // El centinela de la semilla de categorías vive en `UserDefaults.standard` y sobrevive entre corridas: puesto, la
        // semilla sale sin categorías y el banco mediría un libro sin gastos (medido en la segunda corrida). Se baja para
        // sembrar y se devuelve como estaba.
        let sentinelKey = CategorySeedSentinel.currentKey
        let previousSentinel = UserDefaults.standard.object(forKey: sentinelKey)
        UserDefaults.standard.removeObject(forKey: sentinelKey)
        defer { UserDefaults.standard.set(previousSentinel, forKey: sentinelKey) }

        let context = try makeTestContext()
        await DevSeedService().seed(in: context, profile: .realista)
        #expect(try context.fetchCount(FetchDescriptor<Yala.Category>()) > 0, "la semilla salió sin categorías")
        let converter = CurrencyConverter()
        converter.setContext(context)

        let now = Date.now
        let currency = "PEN"
        let builder = FullFinancialContextBuilder()
        let service = ChatAssistantService.shared

        var lines: [String] = []
        var contextJSON = ""
        for question in bank.questions {
            builder.invalidateCache()
            let financial = builder.build(
                modelContext: context,
                currencyCode: currency,
                currencyDisplay: "S/",
                converter: converter,
                language: question.lang,
                country: "PE",
                includeAnomalies: AnomalyKeywords.matches(question.q),
                includeGroupsInTotal: true,
                includeGroupTransactionsInStats: true,
                now: now
            )
            if contextJSON.isEmpty { contextJSON = try financial.toJSONString() }
            let turns = (question.turns ?? []).map {
                QAPair(question: $0.q, response: $0.a, timestamp: now, messageID: nil, attachments: nil)
            }
            let query = try service.makeAskQuery(
                context: financial,
                turns: turns,
                question: question.q,
                language: question.lang,
                country: "PE",
                currencyCode: currency,
                currencyDisplay: "S/",
                now: now
            )
            let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(query))
            let line: [String: Any] = [
                "id": question.id,
                "kind": question.kind,
                "lang": question.lang,
                "expect": question.expect,
                "q": question.q,
                "route": ChatIntentClassifierService.preRoute(question.q).map(\.rawValue) ?? "classify",
                "askBody": body,
            ]
            let data = try JSONSerialization.data(withJSONObject: line, options: [.sortedKeys])
            lines.append(String(decoding: data, as: UTF8.self))
        }
        try lines.joined(separator: "\n").write(to: outDir.appendingPathComponent("requests.jsonl"), atomically: true, encoding: .utf8)
        try contextJSON.write(to: outDir.appendingPathComponent("context.json"), atomically: true, encoding: .utf8)

        let truth = try truthSheet(context: context, converter: converter, currency: currency, now: now)
        let truthData = try JSONSerialization.data(withJSONObject: truth, options: [.prettyPrinted, .sortedKeys])
        try truthData.write(to: outDir.appendingPathComponent("truth.json"))
        #expect(lines.count == bank.questions.count)
    }

    // MARK: - Las cifras de la app, para corregir

    /// Lo que la app enseña con sus propios calculadores, sobre TODO el libro (sin la ventana del contexto): el saldo
    /// del Panel, el de cada cuenta y gasto/ingreso de cada mes, por categoría y por comercio.
    private func truthSheet(
        context: ModelContext, converter: CurrencyConverter, currency: String, now: Date
    ) throws -> [String: Any] {
        let calendar = Calendar.current
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let all = try context.fetch(FetchDescriptor<TransactionItem>())
        let countable = PanelTotalAccountsLogic.countableAccounts(accounts)
        let total = LiveBalanceCalculator.liveBalance(
            accounts: countable, transactions: all, preferredCurrencyCode: currency, asOf: now, converter: converter
        )
        var accountRows: [[String: Any]] = []
        for account in countable {
            let native = AccountBalanceCalculator.currentBalance(for: account, allTransactions: all, asOf: now)
            accountRows.append(["name": account.name, "currency": account.currencyCode, "balance": (native as NSDecimalNumber).doubleValue])
        }

        let stats = all.filter { $0.balanceAdjustmentType == nil && $0.account?.excludeFromStatistics != true }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        var months: [[String: Any]] = []
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        for back in 0...14 {
            guard let start = calendar.date(byAdding: .month, value: -back, to: monthStart),
                  let next = calendar.date(byAdding: .month, value: 1, to: start) else { continue }
            let end = back == 0 ? now : (calendar.date(byAdding: .second, value: -1, to: next) ?? next)
            let interval = DateInterval(start: start, end: end)
            let monthTx = stats.filter { interval.contains($0.date) }
            let cash = CashFlowCalculator.calculateCashFlow(
                transactions: monthTx, interval: interval, grouping: .day, currencyCode: currency, converter: converter
            )
            var byCategory: [String: Double] = [:]
            var byMerchant: [String: Double] = [:]
            for tx in monthTx where tx.category?.isIncome == false {
                let amount = tx.chatAmount(in: currency, converter: converter)
                byCategory[tx.category?.name ?? "?", default: 0] += amount
                if let sub = tx.subcategory?.name { byCategory["\(tx.category?.name ?? "?") › \(sub)", default: 0] += amount }
                if let note = tx.note, !note.isEmpty { byMerchant[MerchantCanonicalizer.canonicalize(note), default: 0] += amount }
            }
            var incomeBySub: [String: Double] = [:]
            for tx in monthTx where tx.category?.isIncome == true {
                incomeBySub[tx.subcategory?.name ?? tx.category?.name ?? "?", default: 0] += tx.chatAmount(in: currency, converter: converter)
            }
            months.append([
                "month": fmt.string(from: start),
                "income": cash.totalIncome.rounded(),
                "expense": cash.totalExpense.rounded(),
                "byCategory": byCategory.mapValues { $0.rounded() },
                "byMerchant": byMerchant.filter { $0.value >= 1 }.mapValues { $0.rounded() },
                "incomeBySubcategory": incomeBySub.mapValues { $0.rounded() },
            ])
        }
        return [
            "now": ISO8601DateFormatter().string(from: now),
            "totalBalance": total.rounded(),
            "accounts": accountRows,
            "months": months,
        ]
    }
}

#endif
