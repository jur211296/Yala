//
//  YalaIASinConexionTests.swift
//  YalaTests
//
//  Decisión 42 de la revisión 2.3 (9-nov, F1 + F3): Yala IA sin conexión.
//  · F1 · Sin conexión, el chat lo dice al abrir («Necesitas conexión…») y ofrece apuntar a mano; con conexión y el
//    servidor caído, el mensaje de siempre («no está disponible… en unos minutos»).
//  · F3 · Sin Pro y sin conexión, el muro de Yala IA no queda sin salida: dice cuándo se verá el precio y ofrece lo
//    gratis (apuntar a mano; Siri en los teléfonos con el modelo propio listo).
//  El recorrido en pantalla lo fija `YalaIASinConexionUITests`.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite(.serialized)
struct YalaIASinConexionTests {

    // MARK: - F1 · qué dice el chat

    @Test func sinConexion_mandaSobreTodo() {
        #expect(ChatAvailabilityLogic.state(isConnected: false, suggestionsFailed: false) == .offline)
        #expect(ChatAvailabilityLogic.state(isConnected: false, suggestionsFailed: true) == .offline)
    }

    @Test func conConexionYServidorCaido_esElMensajeDeSiempre() {
        #expect(ChatAvailabilityLogic.state(isConnected: true, suggestionsFailed: true) == .serverDown)
        #expect(ChatAvailabilityLogic.state(isConnected: true, suggestionsFailed: false) == .available)
    }

    /// Antes del arreglo el chat solo miraba si fallaron las sugerencias: sin red y con las del día en caché, la caja
    /// seguía activa y la pregunta fallaba al enviar.
    @Test func elChat_sinConexion_noEstaDisponible_aunqueNadaHayaFallado() throws {
        let defaults = makeIsolatedDefaults()
        let vm = ChatAssistantViewModel(defaults: defaults, cloudExploreAvailable: { false }, isConnected: { false })
        #expect(vm.availability == .offline)
        #expect(!vm.isAIAvailable)
    }

    @Test func elChat_conConexion_sigueDisponible() throws {
        let defaults = makeIsolatedDefaults()
        let vm = ChatAssistantViewModel(defaults: defaults, cloudExploreAvailable: { false }, isConnected: { true })
        #expect(vm.availability == .available)
        #expect(vm.isAIAvailable)
    }

    /// Al volver la conexión se reactiva solo: vuelve a pedir las sugerencias si no las tiene. Sin cambio de red, o
    /// con sugerencias ya puestas, no pide nada.
    @Test func alVolverLaConexion_pideLasSugerenciasQueFaltan() {
        #expect(ChatAvailabilityLogic.reloadsSuggestionsOnReconnect(isConnected: true, hasSuggestions: false))
        #expect(!ChatAvailabilityLogic.reloadsSuggestionsOnReconnect(isConnected: true, hasSuggestions: true))
        #expect(!ChatAvailabilityLogic.reloadsSuggestionsOnReconnect(isConnected: false, hasSuggestions: false))
    }

    // MARK: - F3 · el muro de Yala IA sin conexión

    @Test func elMuroDeYalaIA_sinConexionNiPrecios_ofreceLoGratis() {
        #expect(ProGateOfflineLogic.showsOfflineAlternatives(
            feature: .chatAssistant, context: .proFeature, isConnected: false, hasOffers: false))
    }

    /// Con red, el fallo de precios es de la App Store: «No pudimos cargar los precios» y «Reintentar», como siempre.
    /// Con los precios ya cargados, los planes de siempre. Y el resto de muros no cambia.
    @Test func elMuro_conRedOConPrecios_oDeOtraFuncion_seQuedaComoEstaba() {
        #expect(!ProGateOfflineLogic.showsOfflineAlternatives(
            feature: .chatAssistant, context: .proFeature, isConnected: true, hasOffers: false))
        #expect(!ProGateOfflineLogic.showsOfflineAlternatives(
            feature: .chatAssistant, context: .proFeature, isConnected: false, hasOffers: true))
        #expect(!ProGateOfflineLogic.showsOfflineAlternatives(
            feature: .voiceInput, context: .proFeature, isConnected: false, hasOffers: false))
        #expect(!ProGateOfflineLogic.showsOfflineAlternatives(
            feature: .chatAssistant, context: .trialExpired, isConnected: false, hasOffers: false))
    }

    /// «Anotar con Siri» solo donde de verdad es gratis: sin Pro y con el modelo del propio iPhone listo.
    @Test func siri_soloConElModeloDelTelefonoListo() {
        #expect(ProGateOfflineLogic.offersSiri(model: .available, onDeviceEnabled: true))
        for state in SiriOnDeviceModelState.allCases where state != .available {
            #expect(!ProGateOfflineLogic.offersSiri(model: state, onDeviceEnabled: true))
        }
        #expect(!ProGateOfflineLogic.offersSiri(model: .available, onDeviceEnabled: false))
    }

    // MARK: - Textos en los 16 idiomas

    @Test func losTextosNuevos_estanEnLosDieciseisIdiomas() throws {
        let root = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent()
        let resources = root.appending(path: "Yala/Resources")
        let languages = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") && $0 != "Base.lproj" }
        #expect(languages.count == 16)
        for language in languages {
            let source = try String(
                contentsOf: resources.appending(path: "\(language)/Localizable.strings"), encoding: .utf8)
            for key in ["chat.offline.body", "uxpro.gate.offlinePrices", "uxpro.gate.offlineMeanwhile"] {
                #expect(source.contains("\"\(key)\" = \""), "Falta \(key) en \(language)")
            }
        }
    }
}
