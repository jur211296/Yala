//
//  TransactionFormRow.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftUI

// MARK: - Transaction Form Row

/// Fila de formulario estilo Liquid Glass reutilizable
struct TransactionFormRow<Trailing: View>: View {
    let icon: String
    let title: String
    let hasError: Bool
    @ViewBuilder let trailing: () -> Trailing

    init(
        icon: String,
        title: String,
        hasError: Bool = false,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.hasError = hasError
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: DS.FormRow.iconSpacing) {
            Image(systemName: icon)
                .font(DS.Typography.body)
                .foregroundStyle(hasError ? .red : .secondary)
                .frame(width: DS.FormRow.iconWidth)

            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(hasError ? .red : .primary)

            Spacer()

            trailing()

            Image(systemName: "chevron.right")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        .background(.thCard)
        .contentShape(Rectangle())
    }
}

// MARK: - Account Form Row

/// Fila para mostrar una cuenta seleccionada con icono y color
struct AccountFormRow: View {
    let title: String
    let account: Account?
    let hasError: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.FormRow.iconSpacing) {
                if let account = account {
                    Circle()
                        .fill(Color(hex: account.colorHex))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: displayIconName(for: account))
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.white)
                        )
                } else {
                    Image(systemName: "building.columns.fill")
                        .font(DS.Typography.body)
                        .foregroundStyle(hasError ? .red : .secondary)
                        .frame(width: DS.FormRow.iconWidth)
                }

                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(hasError ? .red : .primary)

                Spacer()

                if let account = account {
                    Text(account.name)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.Transaction.select)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(hasError ? .red.opacity(0.8) : .secondary)
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(.thCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subcategory Form Row

/// Fila para mostrar una subcategoría con icono, color y chip de naturaleza
struct SubcategoryFormRow: View {
    let subcategory: Subcategory?
    let hasError: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.FormRow.iconSpacing) {
                if let subcategory = subcategory {
                    Circle()
                        .fill(Color(hex: effectiveColor(for: subcategory)))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "tag.fill")
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.white)
                        )
                } else {
                    Image(systemName: "tag.fill")
                        .font(DS.Typography.body)
                        .foregroundStyle(hasError ? .red : .secondary)
                        .frame(width: DS.FormRow.iconWidth)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Transaction.subcategory)
                        .font(DS.Typography.body)
                        .foregroundStyle(hasError ? .red : .primary)

                    if let subcategory = subcategory {
                        Text(subcategory.safeCategory.name)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let subcategory = subcategory {
                    HStack(spacing: DS.Spacing.sm) {
                        // Chip de naturaleza
                        NeedChip(need: subcategory.need)

                        Text(subcategory.name)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(L10n.Transaction.select)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(hasError ? .red.opacity(0.8) : .secondary)
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(.thCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func effectiveColor(for subcategory: Subcategory) -> String {
        subcategory.colorHex ?? subcategory.safeCategory.colorHex
    }
}

// MARK: - Nature Chip

/// Pequeño chip para mostrar la naturaleza de una subcategoría
struct NeedChip: View {
    let need: SubcategoryNeed

    var body: some View {
        Text(need.displayName)
            .font(DS.Typography.labelTiny)
            .foregroundStyle(need.color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule()
                    .fill(need.color.opacity(0.15))
            )
    }
}

// MARK: - Date Form Row

/// Fila para selección de fecha
struct DateFormRow: View {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    @Binding var date: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.FormRow.iconSpacing) {
                Image(systemName: "calendar")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(width: DS.FormRow.iconWidth)

                Text(L10n.Transaction.date)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                Text(formattedDate)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(.thCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        if Calendar.current.isDateInToday(date) {
            return L10n.Date.today
        }
        return Self.dateFormatter.string(from: date)
    }
}

// MARK: - Tags Form Row

/// Fila para mostrar etiquetas seleccionadas
struct TagsFormRow: View {
    let tags: [Tag]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.FormRow.iconSpacing) {
                Image(systemName: "tag")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(width: DS.FormRow.iconWidth)

                Text(L10n.Transaction.tags)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                if tags.isEmpty {
                    Text(L10n.Transaction.addTags)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: DS.Chip.spacing) {
                        ForEach(tags.prefix(3)) { tag in
                            Text(tag.name)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: tag.colorHex))
                                )
                        }
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(.thCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Note Form Row

/// Fila con campo de texto para la nota
struct NoteFormRow: View {
    @Binding var note: String

    var body: some View {
        HStack(spacing: DS.FormRow.iconSpacing) {
            Image(systemName: "note.text")
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(width: DS.FormRow.iconWidth)

            TextField(L10n.Transaction.notePlaceholder, text: $note)
                .font(DS.Typography.body)
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        .background(.thCard)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.none) {
        AccountFormRow(
            title: "Cuenta",
            account: nil,
            hasError: true,
            action: {}
        )

        SubsectionDivider()

        SubcategoryFormRow(
            subcategory: nil,
            hasError: false,
            action: {}
        )

        SubsectionDivider()

        DateFormRow(date: .constant(Date.now), action: {})

        SubsectionDivider()

        TagsFormRow(tags: [], action: {})

        SubsectionDivider()

        NoteFormRow(note: .constant(""))
    }
    .background(.thCard)
    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
    .padding()
    .background(.thBackground)
}
