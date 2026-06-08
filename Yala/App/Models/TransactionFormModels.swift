//
//  TransactionFormModels.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import Foundation
import SwiftUI

// MARK: - Transaction Type

/// Tipo de transacción para el formulario de nuevo registro
enum TransactionType: String, CaseIterable, Identifiable {
    case expense
    case income
    case transfer

    var id: String { rawValue }

    /// Localized display name
    var displayName: String {
        switch self {
        case .expense: return L10n.Transaction.TransactionType.expense
        case .income: return L10n.Transaction.TransactionType.income
        case .transfer: return L10n.Transaction.TransactionType.transfer
        }
    }

    /// Color principal del tipo (para monto y acentos)
    var color: Color {
        switch self {
        case .expense: return .hotPink
        case .income: return .electricIndigo
        case .transfer: return Color(.secondaryLabel)
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

// MARK: - Split Type

/// Tipo de división para el split calculator
enum SplitType: String, CaseIterable, Identifiable {
    case percentage  // primero en allCases (orden del menú); el default real del sistema es .equal
    case equal
    case exact
    case shares

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .percentage: return L10n.Split.typePercentage
        case .equal: return L10n.Split.typeEqual
        case .exact: return L10n.Split.typeExact
        case .shares: return L10n.Split.typeShares
        }
    }

    var iconName: String {
        switch self {
        case .percentage: return "percent"
        case .equal: return "person.2"
        case .exact: return "number"
        case .shares: return "chart.pie"
        }
    }

    var hintText: String {
        switch self {
        case .percentage: return L10n.Split.tipPercentage
        case .equal: return L10n.Split.tipEqual
        case .exact: return L10n.Split.tipExact
        case .shares: return L10n.Split.tipShares
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
