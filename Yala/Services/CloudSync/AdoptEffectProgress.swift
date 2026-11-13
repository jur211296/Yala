//
//  AdoptEffectProgress.swift
//  Yala
//
//  Card jxbp (13-nov, Jürgen en el iPhone 14): «Conectando con tu cuenta» pasaba de 0 % a 60 % y de ahí a «lista». El 60 %
//  era una constante (`CloudMigrationUIStateDeriver.adoptEffectFraction`) para TODO el efecto del adopt, que es justo donde
//  está el trabajo: medido ese día con la cuenta de staging, ~40 s leyendo la cuenta por páginas de 500 filas, más el
//  Merkle, la prueba de que los datos son de la cuenta y la preparación del teléfono.
//
//  Este tipo dice en qué paso REAL va el efecto, y cuántas filas de la cuenta lleva leídas de cuántas tiene (el Merkle lo
//  sabe antes de empezar). Lo escribe el ejecutor en cada paso, lo reenvía el runner y lo copia el controller en
//  `refresh()`, igual que la cifra de la subida de la ida. Ningún paso es simulado: si no hay cifra, la barra no se mueve
//  dentro del paso.
//

import Foundation

nonisolated struct AdoptEffectProgress: Equatable, Sendable {

    /// Los pasos del efecto del adopt, en el orden en que `MigrationWorkExecutor.runAdoptFlow` los hace.
    enum Stage: Int, Equatable, Sendable, CaseIterable {
        /// Leer lo que hay en este teléfono y esperar a que iCloud, si está, termine de traer lo suyo.
        case checkingDevice
        /// Leer la cuenta del servidor, página a página.
        case readingAccount
        /// Comprobar contra el Merkle que la lectura salió entera.
        case verifyingAccount
        /// Comparar con lo del teléfono y probar que es de esta cuenta.
        case matchingDevice
        /// Subir lo que la cuenta todavía no tiene.
        case uploading
        /// Dejar el teléfono apuntando a la cuenta.
        case finishing
    }

    var stage: Stage
    /// Filas de la cuenta leídas en `readingAccount`, borradas incluidas.
    var rowsRead: Int = 0
    /// Filas vivas que el Merkle dice que tiene la cuenta. `nil` = el Merkle no contestó: la lectura no tiene cifra.
    var rowsExpected: Int?

    /// Dónde empieza el efecto en la barra: justo después del claim (22 %).
    static let startFraction = 0.25

    /// Tramos de la barra por paso. La lectura de la cuenta se lleva el tramo grande porque es lo que tarda.
    static let readingStart = 0.28
    static let readingEnd = 0.75

    /// La fracción de la barra, siempre dentro del tramo del efecto (25 %…95 %): «lista» la pone el terminal de éxito.
    var fraction: Double {
        switch stage {
        case .checkingDevice:
            return Self.startFraction
        case .readingAccount:
            guard let rowsExpected, rowsExpected > 0 else { return Self.readingStart }
            let done = min(1, Double(max(0, rowsRead)) / Double(rowsExpected))
            return Self.readingStart + (Self.readingEnd - Self.readingStart) * done
        case .verifyingAccount:
            return 0.8
        case .matchingDevice:
            return 0.85
        case .uploading:
            return 0.9
        case .finishing:
            return 0.95
        }
    }

    /// Total de filas vivas del Merkle, la cifra de `rowsExpected`.
    static func expectedRows(merkleCounts: [Int]) -> Int {
        merkleCounts.reduce(0) { $0 + max(0, $1) }
    }

    /// **La barra no retrocede.** Un reintento del efecto vuelve a empezar por `checkingDevice`, y la pantalla ya había
    /// pintado más: se queda donde estaba hasta que el trabajo nuevo la pase. Lo que avanza sí se ve.
    static func displayed(previous: Double?, next: Double) -> Double {
        guard let previous else { return next }
        return max(previous, next)
    }
}
