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
    case userDataReset
    case faceIDProtectionGuide
    case subscription
    case tips
    case faq
    case iCloudSync
    case siriShortcuts
    case aiPrivacy
    /// «Permisos de Yala» (UX 2.2 · L16-14): estado de cada permiso y un botón por permiso a Configuración.
    case permissions
    /// Modo Nube (I14): elección/gestión de almacenamiento (iCloud privado ↔ nube). Su fila la gobierna
    /// `StorageRowGateLogic`; en producción sigue oculta por el flag remoto (percent 0), no por
    /// `CloudBackendConfig.isConfigured`, que está abierto desde D-R1 paso 1.
    case storageMode
    /// "Tu cuenta de Yala" (§3.3.5): mapa/explainer del enlace privado ↔ nube (método, dónde viven los
    /// datos, desenlaces). Solo con sesión backend viva (DARK hoy).
    case yalaAccount
}
