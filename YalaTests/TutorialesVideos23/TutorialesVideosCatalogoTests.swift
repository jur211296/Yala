//
//  TutorialesVideosCatalogoTests.swift
//  YalaTests
//
//  Vídeos de Ajustes › Tutoriales regrabados con los flujos de 2.3 (encargo del 27-nov-2026). Cada paso del catálogo
//  tiene su clip en el paquete de la app (o su imagen, en la guía de Apple Pay) y no queda ningún clip
//  `tutorial-*.mp4` que ningún paso enseñe: un clip huérfano pesa en el paquete sin que nadie lo vea, y un paso sin
//  clip enseña una pantalla vacía.
//

import Foundation
import Testing
import UIKit

@testable import Yala

@MainActor
@Suite("Tutoriales 2.3 · cada paso con su clip, ningún clip huérfano")
struct TutorialesVideosCatalogoTests {

    /// Los nombres que el catálogo espera, `tutorial-<tutorial>-step<N>`, de los tutoriales que van en vídeo.
    private var nombresEsperados: Set<String> {
        var nombres = Set<String>()
        for tutorial in Tutorial.allCases where !tutorial.usesStepGuide {
            for indice in tutorial.steps.indices {
                nombres.insert("tutorial-\(tutorial.rawValue)-step\(indice)")
            }
        }
        return nombres
    }

    /// Los clips de tutorial que lleva el paquete, sin la extensión.
    private var clipsEnElPaquete: Set<String> {
        let urls = Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) ?? []
        return Set(urls.map { $0.deletingPathExtension().lastPathComponent }.filter { $0.hasPrefix("tutorial-") })
    }

    @Test("Cada paso de un tutorial en vídeo abre su clip")
    func cadaPasoTieneSuClip() {
        for tutorial in Tutorial.allCases where !tutorial.usesStepGuide {
            #expect(!tutorial.steps.isEmpty, "\(tutorial.rawValue) no tiene pasos.")
            for step in tutorial.steps {
                #expect(step.videoURL != nil, "\(tutorial.rawValue), paso \(step.id): falta su clip en el paquete.")
            }
        }
    }

    @Test("La guía de Apple Pay tiene una imagen por paso")
    func applePayTieneSusImagenes() {
        let tutorial = Tutorial.applePay
        #expect(tutorial.usesStepGuide)
        for step in tutorial.steps {
            #expect(step.screenshotName != nil, "Apple Pay, paso \(step.id): falta su imagen.")
        }
    }

    @Test("Ningún clip tutorial-*.mp4 queda sin un paso que lo enseñe")
    func ningunClipHuerfano() {
        let huerfanos = clipsEnElPaquete.subtracting(nombresEsperados)
        #expect(huerfanos.isEmpty, "Clips sin paso en el catálogo: \(huerfanos.sorted())")
    }

    @Test("El paquete lleva exactamente los clips que pide el catálogo")
    func elPaqueteCasaConElCatalogo() {
        #expect(clipsEnElPaquete == nombresEsperados,
                "Faltan: \(nombresEsperados.subtracting(clipsEnElPaquete).sorted())")
    }
}
