//
//  ChatAvailabilityLogic.swift
//  Yala
//
//  Yala IA sin conexión (decisión 42 de la revisión 2.3, 9-nov, F1 + F3). Lo que el chat y el muro de Pro dicen cuando
//  no hay red, en lógica pura: la fijan `YalaIASinConexionTests` y, en pantalla, `YalaIASinConexionUITests`.
//

import Foundation

/// Qué puede hacer Yala IA ahora.
enum ChatAvailability: Equatable {
    /// Con red y con el servidor contestando.
    case available
    /// El teléfono no tiene conexión: el chat lo dice al abrir y ofrece apuntar a mano (F1).
    case offline
    /// Hay red pero el servidor no contestó: el mensaje de siempre («no está disponible… en unos minutos»).
    case serverDown
}

enum ChatAvailabilityLogic {
    /// Sin conexión manda sobre todo lo demás: aunque las sugerencias del día salgan de la caché, la pregunta fallaría
    /// al enviar, así que se dice al abrir.
    static func state(isConnected: Bool, suggestionsFailed: Bool) -> ChatAvailability {
        guard isConnected else { return .offline }
        return suggestionsFailed ? .serverDown : .available
    }

    /// Al volver la conexión el chat se reactiva solo: vuelve a pedir las sugerencias si no las tiene.
    static func reloadsSuggestionsOnReconnect(isConnected: Bool, hasSuggestions: Bool) -> Bool {
        isConnected && !hasSuggestions
    }
}

/// El muro de Yala IA sin conexión (F3): sin precios no hay compra posible, así que no queda un botón apagado. Dice
/// cuándo se verá el precio y ofrece lo que es gratis hoy.
enum ProGateOfflineLogic {
    /// Solo el muro de Yala IA abierto por la función, sin red y sin precios. Con red, el fallo de precios es de la App
    /// Store y sigue con «No pudimos cargar los precios» y «Reintentar»; con precios, los planes de siempre.
    static func showsOfflineAlternatives(
        feature: ProFeature, context: UpgradeContext, isConnected: Bool, hasOffers: Bool
    ) -> Bool {
        feature == .chatAssistant && context == .proFeature && !isConnected && !hasOffers
    }

    /// «Anotar con Siri» es gratis solo donde Siri lee el dictado con el modelo del propio iPhone (`SiriEntryRoute`).
    static func offersSiri(model: SiriOnDeviceModelState, onDeviceEnabled: Bool) -> Bool {
        SiriEntryRoute.decide(isPro: false, onDeviceEnabled: onDeviceEnabled, model: model) == .onDevice
    }
}
