//
//  WidgetConfigOptions.swift
//  YalaWidgets
//
//  Shared configuration options for widget customization.
//  Includes theme selection and display mode options.
//

import AppIntents

// MARK: - Theme Option

/// Theme option for widget background
enum WidgetThemeOption: String, AppEnum {
    case yala      // yalaCard background (current default)
    case system    // Transparent background (adopts wallpaper)

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.theme.type")
    }

    static var caseDisplayRepresentations: [WidgetThemeOption: DisplayRepresentation] {
        [
            .yala: DisplayRepresentation(title: "widget.theme.yala"),
            .system: DisplayRepresentation(title: "widget.theme.system")
        ]
    }
}

// MARK: - Selection Mode Option

/// Selection mode for list-based widgets (Budgets, Scheduled Payments)
enum SelectionModeOption: String, AppEnum {
    case automatic  // Default logic (top 3 by critical/date)
    case custom     // User selects specific items

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.selection.mode.type")
    }

    static var caseDisplayRepresentations: [SelectionModeOption: DisplayRepresentation] {
        [
            .automatic: DisplayRepresentation(title: "widget.selection.automatic"),
            .custom: DisplayRepresentation(title: "widget.selection.custom")
        ]
    }
}
