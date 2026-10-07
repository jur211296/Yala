//
//  ImageEntryFlowLogic.swift
//  Yala
//
//  Lo que el registro por imagen decide sin vista (propuesta C, 2026-10-04): qué le contamos al usuario cuando una foto
//  no sale y qué hace la hoja cuando unas fotos se leen y otras no. Puro, para probarlo sin simulador.
//

import Foundation

/// Por qué no salió el registro, contado como lo vive el usuario. Nunca se le enseña `localizedDescription`: los errores
/// de la pasarela vienen en técnico, y antes un fallo del servicio se leía como «No se detectaron transacciones».
enum ImageEntryFailure: Equatable {
    case noConnection
    /// La foto se leyó y no trae ningún importe.
    case noAmount
    /// La foto no se pudo abrir o convertir (archivo dañado, PDF vacío).
    case unreadable
    case cameraPermission
    /// El servicio de imagen no está disponible en esta versión (sin clave).
    case serviceUnavailable
    case saveFailed
    /// La foto está bien y falló la lectura (timeout, pasarela, respuesta rota).
    case generic
    /// Un ARCHIVO que no se pudo abrir: un PDF vacío o protegido, o una imagen dañada, soltados sobre Yala en el iPad o
    /// elegidos desde Archivo. Es `.unreadable` con su copy: «esta imagen» no vale para un PDF.
    case unreadableFile

    /// Si tiene sentido volver a mandar las MISMAS fotos. Sin importe o ilegible, la foto es el problema; sin servicio,
    /// repetir falla igual. Sin conexión sí: a diferencia de la voz, la foto no se repite, y al volver la red basta con
    /// reintentarla.
    var retriesSamePhotos: Bool {
        switch self {
        case .generic, .saveFailed, .noConnection: true
        case .noAmount, .unreadable, .unreadableFile, .cameraPermission, .serviceUnavailable: false
        }
    }
}

/// Cómo terminó la lectura de UNA foto.
enum ImageReadOutcome: Equatable {
    /// Se leyó y salieron registros.
    case read
    case failed(ImageEntryFailure)
}

/// Qué enseña la hoja al acabar de leer todas las fotos.
enum ImageEntryResult: Equatable {
    /// Hay registros: se revisan, y las fotos que fallaron se avisan aparte para reintentarlas.
    case review(failedPhotos: Int)
    /// Ninguna foto dio registros.
    case failure(ImageEntryFailure)
}

enum ImageEntryFlowLogic {

    // MARK: - Fallos

    static func failure(for error: VisionError, isConnected: Bool) -> ImageEntryFailure {
        switch error {
        case .noAPIKey: .serviceUnavailable
        case .imageEncodingFailed: .unreadable
        case .networkError: isConnected ? .generic : .noConnection
        case .invalidResponse: .generic
        case .noTransactionsFound: .noAmount
        }
    }

    /// Cualquier otro error: sin conexión es lo único que el usuario puede arreglar; lo demás es «inténtalo otra vez».
    static func failure(forUnknownErrorWhenConnected isConnected: Bool) -> ImageEntryFailure {
        isConnected ? .generic : .noConnection
    }

    // MARK: - Resultado

    /// Con algún registro, se revisa lo leído aunque otras fotos fallaran. Sin ninguno, manda el fallo que el usuario
    /// puede arreglar antes que el que no: sin conexión (o el servicio) pesa más que «sin importe», porque con una foto
    /// sin importe y otra caída por red, repetir la foto buena tiene sentido; elegir otra, no.
    static func result(for outcomes: [ImageReadOutcome]) -> ImageEntryResult {
        let failures = outcomes.compactMap { outcome -> ImageEntryFailure? in
            if case .failed(let failure) = outcome { return failure }
            return nil
        }
        if failures.count < outcomes.count {
            return .review(failedPhotos: failures.count)
        }
        let priority: [ImageEntryFailure] = [
            .noConnection, .serviceUnavailable, .generic, .saveFailed, .noAmount, .unreadable, .unreadableFile,
            .cameraPermission
        ]
        let worst = priority.first { failures.contains($0) } ?? .generic
        return .failure(worst)
    }
}
