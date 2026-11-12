//
//  AIEntryGatewayLimitTests.swift
//  YalaTests
//
//  La primera foto tras instalar falló al instante con «No pude leerla esta vez» (card vv0k del QA guiado del
//  2026-10-19). El gateway contestaba un 429 de ráfaga —su lista por minuto la llenaba también la sincronización— y la
//  app lo pintaba como «falló la lectura». Desde el 2026-10-21 el gateway cuenta la ráfaga por categoría
//  (`gateway/test/ai.session2.test.ts`) y la app nombra los dos 429 con su texto, en la foto y en la voz.
//
//  Los errores son los EXACTOS que decodifica el SDK (`ProxyErrorMapper.quotaResponse`), no un stub: así un cambio en
//  el sobre del gateway o en el SDK pone rojo esto.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Foto y voz — los 429 del gateway con su texto (vv0k)")
struct AIEntryGatewayLimitTests {

    private struct Stub: Error {}
    private var burst: Error { ProxyErrorMapper.quotaResponse(type: "yala_quota_burst") }
    private var daily: Error { ProxyErrorMapper.quotaResponse(type: "yala_quota_daily") }

    @Test func photo_burstIsBusy_dailyIsDailyLimit_withOrWithoutConnection() {
        for connected in [true, false] {
            #expect(ImageEntryFlowLogic.failure(for: .networkError(burst), isConnected: connected) == .busy)
            #expect(ImageEntryFlowLogic.failure(for: .networkError(daily), isConnected: connected) == .dailyLimit)
        }
        // Control: lo que no es del gateway sigue como antes.
        #expect(ImageEntryFlowLogic.failure(for: .networkError(Stub()), isConnected: true) == .generic)
        #expect(ImageEntryFlowLogic.failure(for: .networkError(ProxyErrorMapper.trialExhaustedResponse()), isConnected: true)
                == .trialUsedUp)
    }

    @Test func voice_burstIsBusy_dailyIsDailyLimit_inBothSteps() {
        #expect(VoiceEntryFlowLogic.failure(for: TranscriptionError.networkError(burst), isConnected: true) == .busy)
        #expect(VoiceEntryFlowLogic.failure(for: TranscriptionError.networkError(daily), isConnected: true) == .dailyLimit)
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.networkError(burst), isConnected: true) == .busy)
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.networkError(daily), isConnected: true) == .dailyLimit)
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.networkError(Stub()), isConnected: true) == .generic)
    }

    /// La ráfaga se cura en un minuto: se ofrece reintentar lo mismo. El cupo del día, no.
    @Test func busyRetries_dailyLimitDoesNot() {
        #expect(ImageEntryFailure.busy.retriesSamePhotos)
        #expect(!ImageEntryFailure.dailyLimit.retriesSamePhotos)
        #expect(VoiceEntryFailure.busy.retriesSameAudio)
        #expect(!VoiceEntryFailure.dailyLimit.retriesSameAudio)
    }

    /// Sin nada leído, el cupo del día manda sobre el resto: reintentar no lo arregla.
    @Test func dailyLimitOutranksBusyAndGeneric() {
        #expect(ImageEntryFlowLogic.result(for: [.failed(.generic), .failed(.dailyLimit), .failed(.busy)])
                == .failure(.dailyLimit))
        #expect(ImageEntryFlowLogic.result(for: [.failed(.generic), .failed(.busy)]) == .failure(.busy))
    }

    /// Una tanda con lo leído a la vista y el cupo del día agotado a mitad (review del 2026-10-21): el aviso lo dice y no
    /// ofrece reintentar, y las fotos que quedaban no se piden.
    @Test func partialBatch_dailyLimit_saysSo_andSkipsTheRest() {
        #expect(ImageEntryFlowLogic.failedPhotosNotice(for: [.dailyLimit, .dailyLimit]) == .dailyLimit(count: 2))
        #expect(ImageEntryFlowLogic.failedPhotosNotice(for: [.busy]) == .retry(count: 1))
        #expect(ImageEntryFlowLogic.failedPhotosNotice(for: [.trialUsedUp, .dailyLimit]) == .trialUsedUp(count: 2))
        #expect(ImageEntryFlowLogic.skipsRemainingReads(after: .dailyLimit))
        #expect(!ImageEntryFlowLogic.skipsRemainingReads(after: .busy))
    }

    /// El canario lleva el tipo del gateway, o la familia local, y nunca habla de lo que no es avería.
    @Test func canaryDetail_namesTheGatewayType_orTheLocalFamily() {
        #expect(ImageEntryFlowLogic.canaryDetail(for: .networkError(burst)) == "photo|yala_quota_burst")
        #expect(ImageEntryFlowLogic.canaryDetail(for: .networkError(URLError(.timedOut))) == "photo|url:-1001")
        #expect(ImageEntryFlowLogic.canaryDetail(for: .networkError(AppAttestError.unavailable)) == "photo|attest")
        #expect(ImageEntryFlowLogic.canaryDetail(for: .invalidResponse) == "photo|invalidResponse")
        #expect(ImageEntryFlowLogic.canaryDetail(for: .noTransactionsFound) == nil)
        #expect(ImageEntryFlowLogic.canaryDetail(for: .noAPIKey) == nil)
        #expect(ImageEntryFlowLogic.canaryDetail(for: .networkError(ProxyErrorMapper.trialExhaustedResponse())) == nil,
                "el cupo de prueba agotado es el desenlace esperado del plan free, no una avería")
        #expect(VoiceEntryFlowLogic.canaryDetail(for: TranscriptionError.networkError(daily)) == "voice-transcribe|yala_quota_daily")
        #expect(VoiceEntryFlowLogic.canaryDetail(for: ParserError.networkError(Stub())) == "voice-parse|other")
        #expect(VoiceEntryFlowLogic.canaryDetail(for: TranscriptionError.emptyAudio) == nil)
    }
}
