//
//  PersonalizationSettingsView.swift
//  Neto
//
//  Personalization settings sheet with default period selector.
//

import SwiftUI

struct PersonalizationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var sessionState

    @AppStorage("defaultPeriod") private var defaultPeriodRaw: String = DetailPeriod.allTime
        .rawValue
    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue

    @State private var showingPeriodPicker = false

    private var selectedPeriod: DetailPeriod {
        DetailPeriod(rawValue: defaultPeriodRaw) ?? .thisMonth
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandPrimary)
                            .padding(.bottom, 8)

                        Text("Personalización")
                            .font(.title2.bold())
                            .foregroundStyle(Color.netoPrimaryText)

                        Text("Ajusta cómo funciona Neto según tus preferencias.")
                            .font(.body)
                            .foregroundStyle(Color.netoSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)

                    // Default Period Section - Single Row Style
                    VStack(alignment: .leading, spacing: 8) {
                        // Period Row
                        Button {
                            showingPeriodPicker = true
                        } label: {
                            HStack {
                                Text("Período predeterminado")
                                    .font(.body)
                                    .foregroundStyle(Color.netoPrimaryText)

                                Spacer()

                                Text(selectedPeriod.rawValue)
                                    .font(.body)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.netoCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        // Explanatory text
                        Text(
                            "Este período se aplicará por defecto cada vez que abras la app. Puedes cambiarlo temporalmente desde el selector de período en cualquier momento."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Personalización")
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
        .preferredColorScheme(AppTheme(rawValue: userThemeRaw)?.colorScheme)
        .sheet(isPresented: $showingPeriodPicker) {
            PeriodPickerSheet(
                selectedPeriod: selectedPeriod,
                onSelect: { period in
                    defaultPeriodRaw = period.rawValue
                    sessionState.selectedPeriod = period
                    showingPeriodPicker = false
                }
            )
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Period Picker Sheet

private struct PeriodPickerSheet: View {
    let selectedPeriod: DetailPeriod
    let onSelect: (DetailPeriod) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(DetailPeriod.allCases) { period in
                            periodRow(for: period)
                        }
                    }
                    .background(Color.netoCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .padding()
                }
            }
            .navigationTitle("Período predeterminado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func periodRow(for period: DetailPeriod) -> some View {
        let isSelected = selectedPeriod == period

        Button {
            onSelect(period)
        } label: {
            HStack {
                Text(period.rawValue)
                    .font(.body)
                    .foregroundStyle(Color.netoPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brandPrimary)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if period != DetailPeriod.allCases.last {
            Divider()
                .padding(.leading, 16)
        }
    }
}

#Preview {
    NavigationStack {
        PersonalizationSettingsView()
            .environment(SessionState())
    }
}
