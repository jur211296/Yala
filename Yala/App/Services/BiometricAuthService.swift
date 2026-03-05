//
//  BiometricAuthService.swift
//  Yala
//
//  Biometric authentication service using LocalAuthentication.
//

import LocalAuthentication
import SwiftUI

/// Lock timeout options for biometric authentication
enum LockTimeout: Int, CaseIterable, Identifiable {
    case tenSeconds = 10
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .tenSeconds:
            return L10n.Biometric.timeoutImmediate
        case .oneMinute:
            return L10n.Biometric.timeoutOneMinute
        case .fiveMinutes:
            return L10n.Biometric.timeoutFiveMinutes
        case .fifteenMinutes:
            return L10n.Biometric.timeoutFifteenMinutes
        }
    }
}

/// Biometric type available on the device
enum BiometricType {
    case faceID
    case touchID
    case none

    var icon: String {
        switch self {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .none: return "lock.fill"
        }
    }

    var displayName: String {
        switch self {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return L10n.Biometric.passcode
        }
    }
}

/// Service for biometric authentication using LocalAuthentication framework
@MainActor @Observable
final class BiometricAuthService {
    static let shared = BiometricAuthService()

    /// Whether the app is currently locked
    private(set) var isLocked: Bool = false

    /// Whether an authentication is currently in progress (prevents re-entrance from scenePhase changes)
    private var isAuthenticating: Bool = false

    /// Whether the app actually went to background (vs just inactive from system dialog)
    private var didEnterBackground: Bool = false

    /// Timestamp when the app entered background
    private var backgroundTimestamp: Date?

    /// The biometric type available on the device
    var biometricType: BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        default: return .none
        }
    }

    /// Whether biometric or passcode authentication is available
    var isAuthAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    // MARK: - Secure Storage (Keychain)

    private let enabledKey = "biometricEnabled"
    private let timeoutKey = "biometricLockTimeout"

    var isEnabled: Bool {
        get { KeychainService.getBool(forKey: enabledKey) }
        set { KeychainService.setBool(newValue, forKey: enabledKey) }
    }

    var lockTimeout: LockTimeout {
        get {
            let raw = KeychainService.getInt(forKey: timeoutKey)
            return LockTimeout(rawValue: raw) ?? .tenSeconds
        }
        set { KeychainService.setInt(newValue.rawValue, forKey: timeoutKey) }
    }

    // MARK: - Lock Management

    /// Call when app enters background
    func appDidEnterBackground() {
        guard isEnabled else { return }
        didEnterBackground = true
        backgroundTimestamp = Date()
    }

    /// Call when app enters foreground. Only locks if we actually went to background.
    func appDidEnterForeground() {
        guard isEnabled, didEnterBackground else { return }
        didEnterBackground = false
        isAuthenticating = false

        if let timestamp = backgroundTimestamp {
            let elapsed = Date().timeIntervalSince(timestamp)
            if elapsed >= Double(lockTimeout.rawValue) {
                isLocked = true
            }
        }
    }

    /// Lock the app on initial launch if biometric is enabled
    func lockOnLaunchIfNeeded() {
        guard isEnabled else { return }
        isLocked = true
    }

    /// Authenticate the user. Uses deviceOwnerAuthentication (biometric + passcode fallback).
    func authenticate() async -> Bool {
        guard !isAuthenticating else { return false }
        isAuthenticating = true

        let context = LAContext()
        context.localizedCancelTitle = L10n.Common.cancel

        let reason = L10n.Biometric.authReason

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            if success {
                isLocked = false
            }
            isAuthenticating = false
            return success
        } catch {
            #if DEBUG
            print("[BiometricAuthService] Auth error: \(error)")
            #endif
            isAuthenticating = false
            return false
        }
    }

    /// Authenticate once to verify before enabling biometric lock
    func authenticateToEnable() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = L10n.Common.cancel

        let reason = L10n.Biometric.enableReason

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch {
            #if DEBUG
            print("[BiometricAuthService] Enable auth error: \(error)")
            #endif
            return false
        }
    }
}
