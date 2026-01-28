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
    }

    static var shortcutTileColor: ShortcutTileColor {
        .purple
    }
}
