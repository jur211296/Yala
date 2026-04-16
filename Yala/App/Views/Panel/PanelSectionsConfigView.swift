//
//  PanelSectionsConfigView.swift
//  Yala
//
//  Sheet to toggle visibility of full Panel sections (macro-level config).
//  Persists to AppPreferences.panelSectionsHidden — synced via iCloud KV.
//
//  Per-widget config inside a section lives in WidgetPreferencesView (P20-03
//  will introduce per-section sheets for ordering within a section).
//

import SwiftUI

struct PanelSectionsConfigView: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(PanelSectionKind.toggleableSections, id: \.self) { kind in
                        row(for: kind)
                    }
                } footer: {
                    Text(L10n.Panel.SectionsConfig.footer)
                }
            }
            .navigationTitle(L10n.Panel.SectionsConfig.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.done) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for kind: PanelSectionKind) -> some View {
        let binding = Binding<Bool>(
            get: { !appPreferences.panelSectionsHidden.contains(kind.rawValue) },
            set: { isVisible in
                var set = Set(appPreferences.panelSectionsHidden)
                if isVisible { set.remove(kind.rawValue) } else { set.insert(kind.rawValue) }
                appPreferences.panelSectionsHidden = Array(set)
            }
        )

        Toggle(isOn: binding) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: kind.iconName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                Text(kind.localizedTitle)
                    .font(DS.Typography.body)
            }
        }
        .accessibilityLabel(L10n.Accessibility.toggleSection(kind.localizedTitle))
    }
}

#if DEBUG
#Preview {
    PanelSectionsConfigView()
        .environment(AppPreferences(defaults: .standard))
}
#endif
