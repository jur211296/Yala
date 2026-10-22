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
    /// El plan free ya usó su cupo de prueba de fotos: la salida es Yala Pro (no se repone esperando).
    case trialUsedUp

    /// Si tiene sentido volver a mandar las MISMAS fotos. Sin importe o ilegible, la foto es el problema; sin servicio,
    /// repetir falla igual. Sin conexión sí: a diferencia de la voz, la foto no se repite, y al volver la red basta con
    /// reintentarla.
    var retriesSamePhotos: Bool {
        switch self {
        case .generic, .saveFailed, .noConnection: true
        case .noAmount, .unreadable, .unreadableFile, .cameraPermission, .serviceUnavailable, .trialUsedUp: false
        }
    }
}

/// Cómo terminó la lectura de UNA foto.
enum ImageReadOutcome: Equatable {
    /// Se leyó y salieron registros.
    case read
    /// Una página de PDF que no trae movimientos (portada, condiciones). No es un fallo que avisar: solo cuenta como «sin
    /// importe» si ninguna otra foto dio registros (decisión de Jürgen del 2026-10-08).
    case empty
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
        case .networkError(let inner): ProxyErrorMapper.isTrialExhausted(inner) ? .trialUsedUp : (isConnected ? .generic : .noConnection)
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
        if outcomes.contains(.read) {
            return .review(failedPhotos: failures.count)
        }
        // Nada leído: las páginas vacías cuentan como lo que son, fotos sin importe.
        let emptyPages = outcomes.filter { $0 == .empty }.map { _ in ImageEntryFailure.noAmount }
        return .failure(worstFailure(failures + emptyPages))
    }

    /// Qué dice el aviso de las fotos que no se leyeron, con lo leído a la vista. Si alguna se quedó sin leer porque se
    /// acabó el cupo de prueba, reintentar no sirve: el aviso lo dice y ofrece Yala Pro (decisión de Jürgen del
    /// 2026-10-08). `nil` si no falló ninguna.
    enum FailedPhotosNotice: Equatable {
        case retry(count: Int)
        case trialUsedUp(count: Int)
    }

    static func failedPhotosNotice(for failures: [ImageEntryFailure]) -> FailedPhotosNotice? {
        guard !failures.isEmpty else { return nil }
        return failures.contains(.trialUsedUp) ? .trialUsedUp(count: failures.count) : .retry(count: failures.count)
    }

    /// Con el cupo de prueba agotado en una foto, las siguientes de la tanda fallarían igual: no se piden.
    static func skipsRemainingReads(after failure: ImageEntryFailure) -> Bool {
        failure == .trialUsedUp
    }

    private static func worstFailure(_ failures: [ImageEntryFailure]) -> ImageEntryFailure {
        // El cupo agotado va primero: si una foto lo agotó, las siguientes también fallarán, y lo único que lo arregla
        // es Yala Pro.
        let priority: [ImageEntryFailure] = [
            .trialUsedUp, .noConnection, .serviceUnavailable, .generic, .saveFailed, .noAmount, .unreadable, .unreadableFile,
            .cameraPermission
        ]
        return priority.first { failures.contains($0) } ?? .generic
    }
}
