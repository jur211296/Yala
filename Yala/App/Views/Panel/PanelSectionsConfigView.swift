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
//  Chrome adaptativo al detent (mismo patrón que `PanelSectionPreferencesSheet`):
//   - medium → `Form` plain, fondo material glass nativo iOS 26.
//   - large  → `PanelBackgroundView` + `List.solidCard()` (UI-PATTERNS.md).
//

import SwiftUI

struct PanelSectionsConfigView: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDetent: PresentationDetent = .medium

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            Group {
                if isLargeDetent {
                    largeLayout
                } else {
                    mediumLayout
                }
            }
            .navigationTitle(L10n.Panel.SectionsConfig.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: { dismiss() })
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Medium Layout (Form — native iOS 26 glass material)

    private var mediumLayout: some View {
        Form {
            Section {
                ForEach(PanelSectionKind.toggleableSections, id: \.self) { kind in
                    row(for: kind)
                }
            } footer: {
                Text(L10n.Panel.SectionsConfig.footer)
            }
        }
    }

    // MARK: - Large Layout (VStack + Divider + solidCard — altura automática)

    private var largeLayout: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    let sections = PanelSectionKind.toggleableSections

                    VStack(spacing: DS.Spacing.none) {
                        ForEach(Array(sections.enumerated()), id: \.element) { index, kind in
                            row(for: kind)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, DS.Spacing.sm)

                            if index < sections.count - 1 {
                                Divider()
                                    .padding(.leading, DS.Spacing.lg)
                            }
                        }
                    }
                    .padding(.vertical, DS.Chip.paddingV)
                    .solidCard()

                    Text(L10n.Panel.SectionsConfig.footer)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.sm)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Row (compartido entre ambos layouts)

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
                            .font(DS.Typography.body).fontWeight(.medium)
                            .foregroundStyle(.thToolbarIcon)
                    }
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
