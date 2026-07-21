//
//  ProfileDestination.swift
//  Yala
//
//  Navigation destinations for ProfileView NavigationStack.
//

import Foundation

/// Destinations for Profile NavigationStack.
/// Extracted to its own file so other modules (e.g. SessionState) can reference it
/// without depending on ProfileView.
enum ProfileDestination: Hashable {
    case accounts
    case categories
    case tags
    case themes
    case personalization
    case currency
    case appIcon
    case notifications
    case favorites
    case budgets
    case planned
    case userDataReset
    case faceIDProtectionGuide
    case subscription
    case tips
    case faq
    case iCloudSync
    case siriShortcuts
    case aiPrivacy
    /// Modo Nube (I14): elección/gestión de almacenamiento (iCloud privado ↔ nube). Solo visible si
    /// `CloudBackendConfig.isConfigured` (staging/DEV; prod placeholder sin cambios).
    case storageMode
    /// "Tu cuenta de Yala" (§3.3.5): mapa/explainer del enlace privado ↔ nube (método, dónde viven los
    /// datos, desenlaces). Solo con sesión backend viva (DARK hoy).
    case yalaAccount
}
