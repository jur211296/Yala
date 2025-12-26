//
//  TransactionFormModels.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import Foundation
import SwiftUI

// MARK: - Transaction Type

/// Tipo de transacción para el formulario de nuevo registro
enum TransactionType: String, CaseIterable, Identifiable {
    case expense = "Gasto"
    case income = "Ingreso"
    case transfer = "Transferencia"

    var id: String { rawValue }

    /// Color principal del tipo (para monto y acentos)
    var color: Color {
        switch self {
        case .expense: return .hotPink
        case .income: return .electricIndigo
        case .transfer: return .transferColor
        }
    }

    /// Ícono SF Symbol del tipo
    var iconName: String {
        switch self {
        case .expense: return "arrow.down.circle.fill"
        case .income: return "arrow.up.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    /// Indica si el monto debe ser negativo internamente
    var isNegative: Bool {
        switch self {
        case .expense: return true
        case .income: return false
        case .transfer: return false  // Las transferencias manejan signos por separado
        }
    }
}

// MARK: - Capture Mode

/// Modo de captura para el registro (Manual activo, resto próximamente)
enum CaptureMode: String, CaseIterable, Identifiable {
    case manual = "Manual"
    case screenshot = "Screenshot"
    case smartAudio = "Smart Audio"
    case receipt = "Recibo"

    var id: String { rawValue }

    /// Indica si el modo está disponible (solo Manual por ahora)
    var isAvailable: Bool {
        self == .manual
    }

    /// Ícono SF Symbol del modo
    var iconName: String {
        switch self {
        case .manual: return "pencil.line"
        case .screenshot: return "camera.viewfinder"
        case .smartAudio: return "waveform"
        case .receipt: return "doc.text.viewfinder"
        }
    }
}

// MARK: - Form Field Validation

/// Estado de validación de un campo del formulario
enum FieldValidationState {
    case valid
    case invalid(message: String)
    case empty

    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .invalid(let message) = self {
            return message
        }
        return nil
    }
}
