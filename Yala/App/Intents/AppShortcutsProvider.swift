//
//  AppShortcutsProvider.swift
//  Yala
//
//  Provides App Shortcuts for the Shortcuts app and Siri.
//
//  Las frases de abajo son las CLAVES. Cada idioma las recibe tal cual (español e inglés, en los 16) salvo donde
//  `AppShortcuts.xcstrings` las traduce: hoy, portugués (pt, pt-BR, pt-PT). Lo que Siri entrena por idioma se ve en el
//  bundle compilado, `Metadata.appintents/root.ssu.yaml`, y lo fija `SiriPhrasesPortugueseTests`. Los otros siete
//  idiomas esperan decisión (L15-5).
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
                // Spanish. La primera es la que enseña Ajustes › Siri (`siriShortcuts.phrase.image`)
                // desde que la entrada se llama «Registrar con foto o archivo» (2026-10-12); las de
                // «imagen» se quedan como sinónimos para quien ya las dice.
                "Registra con foto o archivo en \(.applicationName)",
                "Registra con imagen en \(.applicationName)",
                "Entrada por imagen en \(.applicationName)",
                "Escanear gasto en \(.applicationName)",
                // English
                "Record with photo or file in \(.applicationName)",
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

        // NOTA: Apple App Intents NO permite parámetros String en phrases (solo AppEntity/AppEnum).
        // Por eso las phrases son sin slot — siempre 2 turnos: frase de invocación, luego pregunta del texto.
        AppShortcut(
            intent: SiriNaturalEntryIntent(),
            phrases: [
                // Spanish
                "Anota un gasto en \(.applicationName)",
                "Apunta un gasto en \(.applicationName)",
                "Registra con Siri en \(.applicationName)",
                // English
                "Note an expense in \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Record with Siri in \(.applicationName)"
            ],
            shortTitle: "shortcut.siriNatural.shortTitle",
            systemImageName: "text.bubble.fill"
        )

        // Preguntas que Siri contesta sin abrir la app (`SiriQueryIntents.swift`). Sin frase con el período a propósito:
        // Atajos pinta entonces una tarjeta por período con el período suelto («este mes»), y su título propio
        // (`ParameterPresentation`) no se puede comprobar en el simulador. Por voz es este mes; el período se elige en Atajos.
        AppShortcut(
            intent: SpendingQueryIntent(),
            phrases: [
                // Spanish
                "Cuánto gasté en \(.applicationName)",
                "Cuánto llevo gastado en \(.applicationName)",
                // English
                "How much did I spend in \(.applicationName)",
                "My spending in \(.applicationName)"
            ],
            shortTitle: "shortcut.spending.shortTitle",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: BalanceQueryIntent(),
            phrases: [
                // Spanish
                "Cuánto tengo en \(.applicationName)",
                "Mi saldo en \(.applicationName)",
                // English
                "How much do I have in \(.applicationName)",
                "My balance in \(.applicationName)"
            ],
            shortTitle: "shortcut.balance.shortTitle",
            systemImageName: "banknote.fill"
        )

    }

    static var shortcutTileColor: ShortcutTileColor {
        .purple
    }
}
