//
//  AppShortcutsProvider.swift
//  Yala
//
//  Provides App Shortcuts for the Shortcuts app and Siri.
//

import AppIntents

struct YalaShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickExpenseIntent(),
            phrases: [
                // Spanish phrases (neutral: gasto/ingreso)
                "Registra en \(.applicationName)",
                "Nuevo registro en \(.applicationName)",
                "Añade un registro en \(.applicationName)",
                "Registro rápido en \(.applicationName)",
                // English phrases (neutral: expense/income)
                "Record in \(.applicationName)",
                "New entry in \(.applicationName)",
                "Add entry in \(.applicationName)",
                "Quick entry in \(.applicationName)"
            ],
            shortTitle: "shortcut.quickExpense.shortTitle",
            systemImageName: "sparkles"
        )

        AppShortcut(
            intent: VoiceEntryIntent(),
            phrases: [
                // Spanish
                "Registra con voz en \(.applicationName)",
                "Entrada por voz en \(.applicationName)",
                "Dictar gasto en \(.applicationName)",
                // English
                "Record with voice in \(.applicationName)",
                "Voice entry in \(.applicationName)",
                "Dictate expense in \(.applicationName)"
            ],
            shortTitle: "shortcut.voiceEntry.shortTitle",
            systemImageName: "mic.badge.plus"
        )

        AppShortcut(
            intent: ImageEntryIntent(),
            phrases: [
                // Spanish
                "Registra con imagen en \(.applicationName)",
                "Entrada por imagen en \(.applicationName)",
                "Escanear gasto en \(.applicationName)",
                // English
                "Record with image in \(.applicationName)",
                "Image entry in \(.applicationName)",
                "Scan expense in \(.applicationName)"
            ],
            shortTitle: "shortcut.imageEntry.shortTitle",
            systemImageName: "photo.badge.plus"
        )

        AppShortcut(
            intent: ApplePayTransactionIntent(),
            phrases: [
                // Spanish
                "Registra Apple Pay en \(.applicationName)",
                "Pago Apple Pay en \(.applicationName)",
                "Apple Pay en \(.applicationName)",
                // English
                "Record Apple Pay in \(.applicationName)",
                "Apple Pay payment in \(.applicationName)",
                "Apple Pay in \(.applicationName)"
            ],
            shortTitle: "shortcut.applePay.shortTitle",
            systemImageName: "apple.logo"
        )

        AppShortcut(
            intent: AutomationEntryIntent(),
            phrases: [
                // Spanish
                "Registra desde automatización en \(.applicationName)",
                "Entrada automática en \(.applicationName)",
                "Automatización en \(.applicationName)",
                // English
                "Record from automation in \(.applicationName)",
                "Automatic entry in \(.applicationName)",
                "Automation in \(.applicationName)"
            ],
            shortTitle: "shortcut.automation.shortTitle",
            systemImageName: "gearshape.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor {
        .purple
    }
}
