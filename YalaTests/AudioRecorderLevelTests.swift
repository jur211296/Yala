//
//  AudioRecorderLevelTests.swift
//  YalaTests
//
//  El nivel de voz que pinta el panel de dictado de Yala IA: la potencia del micro (dBFS) pasada a 0…1.
//  Lógica pura, sin grabador ni sesión de audio.
//

import Testing

@testable import Yala

@Suite("Nivel de voz del dictado")
struct AudioRecorderLevelTests {

    private func level(_ decibels: Float) -> Double {
        AudioRecorderService.normalizedLevel(decibels: decibels)
    }

    @Test func silenceAndRoomNoise_areZero() {
        #expect(level(-160) == 0)
        #expect(level(-50) == 0)
    }

    @Test func fullScale_isOne_andNeverMore() {
        #expect(level(0) == 1)
        #expect(level(3) == 1)
    }

    @Test func normalSpeech_landsInTheMiddle_andGrowsWithVolume() {
        #expect(level(-25) == 0.5)
        #expect(level(-40) < level(-25))
        #expect(level(-25) < level(-10))
    }
}
