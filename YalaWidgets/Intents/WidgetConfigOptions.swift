//
//  WidgetConfigOptions.swift
//  YalaWidgets
//
//  Shared configuration options for widget customization.
//  Includes display mode options.
//

import AppIntents

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
