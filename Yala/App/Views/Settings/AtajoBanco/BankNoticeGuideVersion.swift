//
//  BankNoticeGuideVersion.swift
//  Yala
//
//  Barrido de la build 8 (24-nov-2026): en iOS 27 la app Atajos cambió de forma y la guía de «Avisos del banco» describía
//  la de iOS 26. «Automatización» pasó a ser una fila de la Biblioteca, el «+» está abajo al centro y abre «Nuevo atajo»,
//  el disparador se elige en la pestaña «Automatización» de la hoja de acciones y queda en línea con la acción. Ya no hay
//  «Ejecutar inmediatamente», «Siguiente», «Nueva automatización en blanco» ni «Agregar acción», y se borra con una
//  pulsación larga. Recorrido medido en el iPhone 14 con iOS 27.2.1.
//
//  iOS 26 sigue soportado (el target mínimo es 26.0): allí la guía se queda como estaba.
//

import Foundation

/// Qué guía de Atajos enseña «Avisos del banco», según la versión del sistema.
enum BankNoticeGuideVersion: Equatable {
    /// iOS 26: pestaña «Automatización» abajo, «+» arriba a la derecha y pasos con «Siguiente».
    case ios26
    /// iOS 27 o posterior: «+» abajo al centro y el disparador en la hoja de acciones.
    case ios27

    static func forSystem(_ version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion) -> Self {
        version.majorVersion >= 27 ? .ios27 : .ios26
    }

    typealias Texts = L10n.CapturaAtajoParte2.Bank

    var step2Detail: String { self == .ios27 ? Texts.guide27Step2Detail : Texts.guideStep2Detail }
    func step3Detail(_ app: String) -> String { self == .ios27 ? Texts.guide27Step3Detail(app) : Texts.guideStep3Detail(app) }
    var step4Detail: String { self == .ios27 ? Texts.guide27Step4Detail : Texts.guideStep4Detail }
    func step5Detail(_ bankValue: String) -> String {
        self == .ios27 ? Texts.guide27Step5Detail(bankValue) : Texts.guideStep5Detail(bankValue)
    }
    func removeStep1(_ bank: String) -> String { self == .ios27 ? Texts.remove27Step1(bank) : Texts.removeStep1(bank) }
    var removeStep2: String { self == .ios27 ? Texts.remove27Step2 : Texts.removeStep2 }
}
