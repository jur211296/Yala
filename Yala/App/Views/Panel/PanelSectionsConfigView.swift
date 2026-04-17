//
//  PanelSectionsConfigView.swift
//  Yala
//
//  Sheet to toggle visibility of full Panel sections (macro-level config).
//  Persists to AppPreferences.panelSectionsHidden — synced via iCloud KV.
//
//  Per-widget config inside a section lives in `PanelSectionPreferencesSheet`
//  (P20-03). This sheet also surfaces a "Restore widgets" affordance for any
//  multi-widget section whose widgets are all individually hidden — the only
//  way the user can recover from that state once the section auto-disappears
//  from the Panel.
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

        let isEmpty = appPreferences.isSectionEffectivelyEmpty(kind)

        Toggle(isOn: binding) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: kind.iconName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(kind.localizedTitle)
                        .font(DS.Typography.body)
                    if isEmpty {
                        Text(L10n.Panel.SectionsConfig.emptySection)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if isEmpty {
                    Spacer(minLength: 0)
                    Button {
                        // Clears per-section Order + Hidden so `activeWidgets(in:)`
                        // falls back to the epic's default set (reappears in Panel).
                        appPreferences.setOrder([], for: kind)
                        appPreferences.setHidden([], for: kind)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(DS.Typography.body)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        L10n.Panel.SectionsConfig.restoreWidgets(kind.localizedTitle)
                    )
                }
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
