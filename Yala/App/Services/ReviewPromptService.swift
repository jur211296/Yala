//
//  ReviewPromptService.swift
//  Yala
//
//  Decides cuándo mostrar el prompt nativo de App Store review.
//  Servicio estático — no es @Observable.
//

import Foundation

@MainActor
enum ReviewPromptService {

    // MARK: - UserDefaults Keys

    private static let firstLaunchDateKey = "reviewFirstLaunchDate"
    private static let lastPromptDateKey = "reviewLastPromptDate"
    private static let promptCountKey = "reviewPromptCount"

    // MARK: - Thresholds

    private static let minTransactions = 15
    private static let minDaysSinceInstall = 7
    private static let cooldownDays = 120  // 4 meses entre intentos

    // MARK: - Public API

    /// Registrar primera apertura (llamar en bootstrap, solo la primera vez)
    static func recordFirstLaunchIfNeeded() {
        if UserDefaults.standard.object(forKey: firstLaunchDateKey) == nil {
            UserDefaults.standard.set(Date.now, forKey: firstLaunchDateKey)
        }
    }

    /// Evalúa si se debe mostrar el prompt
    static func shouldPrompt(transactionCount: Int) -> Bool {
        // 1. Engagement mínimo
        guard transactionCount >= minTransactions else { return false }

        // 2. Onboarding completo
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return false }

        // 3. Madurez: 7+ días desde install
        guard let firstLaunch = UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date else {
            return false
        }
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date.now).day ?? 0
        guard daysSinceInstall >= minDaysSinceInstall else { return false }

        // 4. Cooldown: 120+ días desde último prompt
        if let lastPrompt = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date {
            let daysSinceLastPrompt = Calendar.current.dateComponents([.day], from: lastPrompt, to: Date.now).day ?? 0
            guard daysSinceLastPrompt >= cooldownDays else { return false }
        }

        return true
    }

    /// Registrar que se mostró el prompt
    static func recordPromptShown() {
        UserDefaults.standard.set(Date.now, forKey: lastPromptDateKey)
        let count = UserDefaults.standard.integer(forKey: promptCountKey) + 1
        UserDefaults.standard.set(count, forKey: promptCountKey)
    }
}
