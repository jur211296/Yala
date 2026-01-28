//
//  AppShortcutsProvider.swift
//  Yala
//
//  Provides App Shortcuts for the Shortcuts app and Siri.
//

import AppIntents

@available(iOS 16.0, *)
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
            systemImageName: "plus.circle.fill"
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
            systemImageName: "mic.fill"
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
            systemImageName: "photo.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor {
        .purple
    }
}
