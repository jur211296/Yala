//
//  ChatVoiceInputGateLogic.swift
//  Yala
//
//  Qué hace el micrófono del chat de Yala IA al tocarlo.
//
//  Decisión A de Jürgen (2026-10-21, ticket `chat-microphone-sends-audio-with-the-chat-consent`): el micrófono del
//  chat pide también el permiso de voz y foto, como Siri y como los botones de Voz y Foto del Panel. Hasta ese día
//  bastaba con el permiso del chat, que habla de un resumen de tus últimos 13 meses y no de audio, y el audio salía
//  a transcribir igual.
//

import Foundation

nonisolated enum ChatVoiceInputGateLogic {

    enum Action: Equatable {
        /// Ya está grabando: el toque termina la grabación (y manda el audio, que ya tenía permiso al empezar).
        case stop
        /// Falta el permiso de voz y foto: se pide antes de grabar nada.
        case askConsent
        /// Todo en orden: empieza a grabar.
        case start
    }

    static func action(isRecording: Bool, dataConsentAccepted: Bool) -> Action {
        if isRecording { return .stop }
        return dataConsentAccepted ? .start : .askConsent
    }
}
