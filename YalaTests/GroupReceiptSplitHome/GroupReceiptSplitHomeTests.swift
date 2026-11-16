//
//  GroupReceiptSplitHomeTests.swift
//  YalaTests
//
//  Voz y Foto de Grupos (ticket `group-receipt-split-home-buttons`, Jürgen 2026-11-14): los botones viven en el inicio de
//  Grupos y bajo el saldo de un grupo, no en Nuevo gasto; y el cupo es propio y diario (5 recibos Free, 50 Pro), sin
//  candado y sin gastar la prueba de voz y foto de personal.
//

import Foundation
import Testing
@testable import Yala

@Suite("Voz y Foto de Grupos: el cupo de recibos")
struct GroupReceiptSplitQuotaTests {

    @Test("cupo del día agotado en Free: se le ofrece Yala Pro")
    func dailyLimitFree() {
        let error = ReceiptSplitError.network(ProxyErrorMapper.quotaResponse(type: "yala_quota_daily"))
        #expect(GroupReceiptSplitView.failure(for: error, source: .image, isConnected: true, isPro: false) == .dailyLimitFree)
        #expect(GroupReceiptSplitView.failure(for: error, source: .voice, isConnected: true, isPro: false) == .dailyLimitFree)
    }

    @Test("cupo del día agotado en Pro: vuelve mañana, sin ofrecer Pro")
    func dailyLimitPro() {
        let error = ReceiptSplitError.network(ProxyErrorMapper.quotaResponse(type: "yala_quota_daily"))
        #expect(GroupReceiptSplitView.failure(for: error, source: .image, isConnected: true, isPro: true) == .dailyLimit)
    }

    @Test("la nota que se transcribe y no llega por el cupo también lo dice")
    func dailyLimitOnTranscription() {
        let error = TranscriptionError.networkError(ProxyErrorMapper.quotaResponse(type: "yala_quota_daily"))
        #expect(GroupReceiptSplitView.failure(for: error, source: .voice, isConnected: true, isPro: false) == .dailyLimitFree)
    }

    @Test("la ráfaga sigue siendo «espera un momento», no el cupo del día")
    func burstIsNotTheDailyLimit() {
        let error = ReceiptSplitError.network(ProxyErrorMapper.quotaResponse(type: "yala_quota_burst"))
        #expect(GroupReceiptSplitView.failure(for: error, source: .image, isConnected: true, isPro: false) == .busy)
    }

    @Test("un gateway sin desplegar aún contesta prueba agotada: se sigue entendiendo")
    func oldGatewayTrial() {
        let error = ReceiptSplitError.network(ProxyErrorMapper.trialExhaustedResponse())
        #expect(GroupReceiptSplitView.failure(for: error, source: .image, isConnected: true, isPro: false) == .trialPhotos)
        #expect(GroupReceiptSplitView.failure(for: error, source: .voice, isConnected: true, isPro: false) == .trialVoice)
    }

    @Test("las tres tareas del recibo cuentan en el cubo `receipt`, no en las fotos y notas de personal")
    func receiptTasksUseTheirOwnBucket() {
        #expect(ProxyTask.receiptPhoto.category == .receipt)
        #expect(ProxyTask.receiptVoice.category == .receipt)
        #expect(ProxyTask.receiptTranscribe.category == .receipt)
        #expect(ProxyTask.photoRead.category == .vision)
        #expect(ProxyTask.voiceTranscribe.category == .voice)
    }
}

@Suite("Voz y Foto de Grupos: dónde están los botones")
struct GroupReceiptSplitHomeWiringTests {

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test("Nuevo gasto ya no lleva «Desde un recibo»: un solo camino, como en personal")
    func formHasNoReceiptPill() throws {
        let form = try source("Yala/App/Views/Groups/GroupExpenseFormView.swift")
        #expect(!form.contains("group_expense_from_receipt"))
        #expect(!form.contains("GroupReceiptSplitView("))
        // Y aplica el reparto que llega de los botones.
        #expect(form.contains("applyReceiptSplit(receiptSplit)"))
    }

    @Test("el inicio de Grupos pinta la fila de personal y «Nuevo grupo» va en la barra")
    func groupsHomeHasTheRow() throws {
        let home = try source("Yala/App/Views/Groups/GroupsContainerView.swift")
        let start = try #require(home.range(of: "private var topActions: some View {"))
        let block = home[start.upperBound...].prefix(900)
        #expect(block.contains("GroupQuickActionsRow(identifierPrefix: \"groups\""))
        #expect(home.contains("\"groups_toolbar_new_group\""))
        #expect(home.contains(".groupReceiptSplitFlow("))
    }

    @Test("la fila es Nuevo gasto, Voz, Foto y Yala IA, en ese orden")
    func rowOrder() throws {
        let entry = try source("Yala/App/Views/Groups/GroupReceiptEntry.swift")
        let row = try #require(entry.range(of: "private var row: some View {"))
        let rowBody = entry[row.upperBound...].prefix(200)
        let newExpense = try #require(rowBody.range(of: "newExpensePill"))
        let ai = try #require(rowBody.range(of: "aiPills"))
        #expect(newExpense.lowerBound < ai.lowerBound)
        let pills = try #require(entry.range(of: "private var aiPills: some View {"))
        let pillsBody = entry[pills.upperBound...].prefix(400)
        let voice = try #require(pillsBody.range(of: "kind: .voice"))
        let photo = try #require(pillsBody.range(of: "kind: .photo"))
        let gold = try #require(pillsBody.range(of: "aiPill"))
        #expect(voice.lowerBound < photo.lowerBound && photo.lowerBound < gold.lowerBound)
        #expect(entry.contains("onReceipt(.text)"))
    }

    @Test("dentro del grupo, la fila bajo el saldo y también con el grupo vacío, sin «Nuevo grupo»")
    func groupDetailHasTheRow() throws {
        let records = try source("Yala/App/Views/Groups/GroupRecordsView.swift")
        #expect(records.contains("GroupQuickActionsRow(identifierPrefix: \"group_detail\""))
        #expect(!records.contains("newGroup"))
        let hero = try #require(records.range(of: "GroupBalanceHero("))
        let row = try #require(records.range(of: "quickActions\n                    .padding(.bottom"))
        #expect(hero.lowerBound < row.lowerBound, "La fila va debajo del saldo")
        let detail = try source("Yala/App/Views/Groups/GroupDetailView.swift")
        #expect(detail.contains("viewModel.canCurrentUserParticipate && !group.isMigratedFrozen"))
    }

    @Test("sin candado: los botones de Grupos no miran si eres Pro")
    func noProGate() throws {
        let entry = try source("Yala/App/Views/Groups/GroupReceiptEntry.swift")
        #expect(!entry.contains("FeatureGateService"))
        #expect(!entry.contains("lock.fill"))
    }

    @Test("Voz abre la hoja escuchando; Yala IA, para escribir el gasto")
    func entryModes() throws {
        let sheet = try source("Yala/App/Views/Groups/GroupReceiptSplitView.swift")
        #expect(sheet.contains("if startsWith == .voice { requestRead(.voice) }"))
        #expect(sheet.contains("if startsWith == .text {\n            textCaptureView"))
        // Lo escrito va como nota ya transcrita: gasta un recibo del día, no la prueba de personal.
        let read = try #require(sheet.range(of: "private func readText() {"))
        #expect(sheet[read.upperBound...].prefix(700).contains("ReceiptSplitService.shared.readNote(text: note"))
    }
}
