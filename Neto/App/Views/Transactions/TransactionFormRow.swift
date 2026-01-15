//
//  TransactionFormRow.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(hasError ? .red : .secondary)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundStyle(hasError ? .red : .primary)

            Spacer()

            trailing()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.netoCard)
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
            HStack(spacing: 12) {
                if let account = account {
                    Circle()
                        .fill(Color(hex: account.colorHex))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: displayIconName(for: account))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        )
                } else {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(hasError ? .red : .secondary)
                        .frame(width: 28)
                }

                Text(title)
                    .font(.body)
                    .foregroundStyle(hasError ? .red : .primary)

                Spacer()

                if let account = account {
                    Text(account.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.Transaction.select)
                        .font(.subheadline)
                        .foregroundStyle(hasError ? .red.opacity(0.8) : .secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.netoCard)
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
            HStack(spacing: 12) {
                if let subcategory = subcategory {
                    Circle()
                        .fill(Color(hex: effectiveColor(for: subcategory)))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "tag.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        )
                } else {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(hasError ? .red : .secondary)
                        .frame(width: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Transaction.subcategory)
                        .font(.body)
                        .foregroundStyle(hasError ? .red : .primary)

                    if let subcategory = subcategory {
                        Text(subcategory.category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let subcategory = subcategory {
                    HStack(spacing: 8) {
                        // Chip de naturaleza
                        NatureChip(nature: subcategory.nature)

                        Text(subcategory.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(L10n.Transaction.select)
                        .font(.subheadline)
                        .foregroundStyle(hasError ? .red.opacity(0.8) : .secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.netoCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func effectiveColor(for subcategory: Subcategory) -> String {
        subcategory.colorHex ?? subcategory.category.colorHex
    }
}

// MARK: - Nature Chip

/// Pequeño chip para mostrar la naturaleza de una subcategoría
struct NatureChip: View {
    let nature: SubcategoryNature

    var body: some View {
        Text(nature.displayName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(nature.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(nature.color.opacity(0.15))
            )
    }
}

// MARK: - Date Form Row

/// Fila para selección de fecha
struct DateFormRow: View {
    @Binding var date: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                Text(L10n.Transaction.date)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.netoCard)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var formattedDate: String {
        if Calendar.current.isDateInToday(date) {
            return L10n.Date.today
        }
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Tags Form Row

/// Fila para mostrar etiquetas seleccionadas
struct TagsFormRow: View {
    let tags: [Tag]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "tag")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                Text(L10n.Transaction.tags)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if tags.isEmpty {
                    Text(L10n.Transaction.addTags)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(tags.prefix(3)) { tag in
                            Text(tag.name)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: tag.colorHex))
                                )
                        }
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.netoCard)
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
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            TextField(L10n.Transaction.notePlaceholder, text: $note)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.netoCard)
    }
}

#Preview {
    VStack(spacing: 0) {
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

        DateFormRow(date: .constant(Date()), action: {})

        SubsectionDivider()

        TagsFormRow(tags: [], action: {})

        SubsectionDivider()

        NoteFormRow(note: .constant(""))
    }
    .background(Color.netoCard)
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .padding()
    .background(Color.netoBackground)
}
