//
//  ImageEntryFlowLogicTests.swift
//  YalaTests
//
//  El registro por imagen (propuesta C): qué fallo se le cuenta al usuario por cada error del servicio y qué enseña la
//  hoja cuando unas fotos se leen y otras no. Lógica pura, sin red ni SwiftData.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Registro por imagen — lógica del flujo")
struct ImageEntryFlowLogicTests {

    private struct Stub: Error {}

    // MARK: - Fallos del servicio

    /// El bug medido en el simulador el 2026-10-04: un fallo de la pasarela salía como «No se detectaron
    /// transacciones», y el usuario culpaba a la foto. Con conexión, un error de red es un «inténtalo otra vez».
    @Test func networkError_whenConnected_isGeneric_notNoAmount() {
        let failure = ImageEntryFlowLogic.failure(for: .networkError(Stub()), isConnected: true)
        #expect(failure == .generic)
        #expect(failure != .noAmount)
    }

    @Test func networkError_whenOffline_isNoConnection() {
        #expect(ImageEntryFlowLogic.failure(for: .networkError(Stub()), isConnected: false) == .noConnection)
    }

    @Test func eachServiceError_mapsToWhatTheUserLives() {
        #expect(ImageEntryFlowLogic.failure(for: .noAPIKey, isConnected: true) == .serviceUnavailable)
        #expect(ImageEntryFlowLogic.failure(for: .imageEncodingFailed, isConnected: true) == .unreadable)
        #expect(ImageEntryFlowLogic.failure(for: .invalidResponse, isConnected: true) == .generic)
        #expect(ImageEntryFlowLogic.failure(for: .noTransactionsFound, isConnected: true) == .noAmount)
    }

    @Test func unknownError_dependsOnlyOnTheConnection() {
        #expect(ImageEntryFlowLogic.failure(forUnknownErrorWhenConnected: true) == .generic)
        #expect(ImageEntryFlowLogic.failure(forUnknownErrorWhenConnected: false) == .noConnection)
    }

    // MARK: - Reintentar con las mismas fotos

    /// La foto no se pierde al fallar: si el problema no es la foto, reintentarla tiene sentido.
    @Test func retriesSamePhotos_onlyWhenThePhotoIsNotTheProblem() {
        #expect(ImageEntryFailure.generic.retriesSamePhotos)
        #expect(ImageEntryFailure.saveFailed.retriesSamePhotos)
        #expect(ImageEntryFailure.noConnection.retriesSamePhotos)
        #expect(!ImageEntryFailure.noAmount.retriesSamePhotos)
        #expect(!ImageEntryFailure.unreadable.retriesSamePhotos)
        #expect(!ImageEntryFailure.serviceUnavailable.retriesSamePhotos)
        #expect(!ImageEntryFailure.cameraPermission.retriesSamePhotos)
    }

    // MARK: - Resultado con varias fotos

    @Test func allRead_reviewsWithNoFailedPhotos() {
        #expect(ImageEntryFlowLogic.result(for: [.read, .read]) == .review(failedPhotos: 0))
    }

    /// El segundo bug medido: con varias fotos, las que fallaban desaparecían sin aviso. Ahora lo leído se revisa y las
    /// que fallaron se cuentan.
    @Test func someFailed_stillReviews_andCountsTheFailedOnes() {
        let outcomes: [ImageReadOutcome] = [.read, .failed(.generic), .failed(.noAmount)]
        #expect(ImageEntryFlowLogic.result(for: outcomes) == .review(failedPhotos: 2))
    }

    @Test func noneRead_isAFailure() {
        #expect(ImageEntryFlowLogic.result(for: [.failed(.noAmount)]) == .failure(.noAmount))
    }

    /// Sin ninguna leída, manda lo que el usuario puede arreglar: con una foto sin importe y otra caída por la red, el
    /// mensaje es la red, porque reintentar puede salvar la segunda.
    @Test func noneRead_connectionOutranksNoAmount() {
        let outcomes: [ImageReadOutcome] = [.failed(.noAmount), .failed(.noConnection)]
        #expect(ImageEntryFlowLogic.result(for: outcomes) == .failure(.noConnection))
    }

    @Test func noneRead_serviceFailureOutranksAPhotoProblem() {
        let outcomes: [ImageReadOutcome] = [.failed(.unreadable), .failed(.generic)]
        #expect(ImageEntryFlowLogic.result(for: outcomes) == .failure(.generic))
    }

    @Test func noPhotos_isGeneric() {
        #expect(ImageEntryFlowLogic.result(for: []) == .failure(.generic))
    }
}
