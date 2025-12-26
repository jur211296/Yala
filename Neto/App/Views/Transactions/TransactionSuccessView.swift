//
//  TransactionSuccessView.swift
//  Neto
//
//  Created by Neto - Success confirmation screen after transaction registration.
//

import SwiftUI

// MARK: - Transaction Success Data

/// Data structure holding the saved transaction details for display
struct TransactionSuccessData {
    let transactionType: TransactionType
    let date: Date
    let accountName: String
    let accountColorHex: String
    let note: String
    let amount: Decimal
    let currencyCode: String
    let subcategoryName: String?
    let subcategoryColorHex: String?
    let categoryName: String?
    let categoryColorHex: String?
    let tags: [(name: String, colorHex: String)]

    // For transfers
    let isTransfer: Bool
    let destinationAccountName: String?
    let destinationAccountColorHex: String?
    let destinationAmount: Decimal?
    let destinationCurrencyCode: String?
}

// MARK: - Transaction Success View

struct TransactionSuccessView: View {
    let data: TransactionSuccessData
    let onAccept: () -> Void
    let onCreateAnother: () -> Void
    let onEdit: () -> Void

    var body: some View {
        ZStack {
            Color.netoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Edit button at top right - native iOS style (inverted)
                HStack {
                    Spacer()
                    Button("Editar", action: onEdit)
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Success icon and title
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(data.transactionType.color.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(data.transactionType.color)
                    }

                    Text("¡Registro exitoso!")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .padding(.bottom, 32)

                // Transaction details
                detailsSection
                    .padding(.horizontal, 20)

                Spacer()

                // Action buttons - native iOS style
                VStack(spacing: 12) {
                    // Primary: Accept
                    Button(action: onAccept) {
                        Text("Aceptar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.electricIndigo)
                    .controlSize(.large)

                    // Secondary: Create another
                    Button(action: onCreateAnother) {
                        Text("Crear otra transacción")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.electricIndigo)
                    .controlSize(.large)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 0) {
            // Amount (prominent)
            amountRow

            // Transaction type
            typeRow

            // Date
            detailRow(
                icon: "calendar",
                label: "Fecha",
                value: formattedDate
            )

            // Account(s)
            if data.isTransfer {
                transferAccountsRow
            } else {
                accountRow
            }

            // Subcategory & Category (only for non-transfers)
            if !data.isTransfer {
                if data.subcategoryName != nil || data.categoryName != nil {
                    categoryRow
                }
            }

            // Note
            if !data.note.isEmpty {
                detailRow(
                    icon: "text.alignleft",
                    label: "Nota",
                    value: data.note
                )
            }

            // Tags
            if !data.tags.isEmpty {
                tagsRow
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.netoCard)
        )
    }

    // MARK: - Row Components

    private var amountRow: some View {
        HStack {
            Text("Total")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(
                NetoFormatter.currency(
                    value: NSDecimalNumber(decimal: data.amount).doubleValue,
                    currencyCode: data.currencyCode)
            )
            .font(.title.weight(.bold))
            .foregroundStyle(data.transactionType.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var typeRow: some View {
        HStack(spacing: 12) {
            Image(systemName: data.transactionType.iconName)
                .font(.subheadline)
                .foregroundStyle(data.transactionType.color)
                .frame(width: 20)

            Text("Tipo")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(data.transactionType.rawValue)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(data.transactionType.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = Locale(identifier: "es")
        return formatter.string(from: data.date)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var accountRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text("Cuenta")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: data.accountColorHex))
                    .frame(width: 8, height: 8)
                Text(data.accountName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var transferAccountsRow: some View {
        VStack(spacing: 0) {
            // Source account
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.hotPink)
                    .frame(width: 20)

                Text("Origen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: data.accountColorHex))
                        .frame(width: 8, height: 8)
                    Text(data.accountName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            // Destination account
            if let destName = data.destinationAccountName,
                let destColor = data.destinationAccountColorHex
            {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.electricIndigo)
                        .frame(width: 20)

                    Text("Destino")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: destColor))
                            .frame(width: 8, height: 8)
                        Text(destName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        if let destAmount = data.destinationAmount,
                            let destCurrency = data.destinationCurrencyCode,
                            destCurrency != data.currencyCode
                        {
                            Text(
                                "(\(NetoFormatter.currency(value: NSDecimalNumber(decimal: destAmount).doubleValue, currencyCode: destCurrency)))"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private var categoryRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text("Categoría")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let subcatName = data.subcategoryName {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                Color(
                                    hex: data.subcategoryColorHex ?? data.categoryColorHex
                                        ?? "6366F1")
                            )
                            .frame(width: 8, height: 8)
                        Text(subcatName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }
                if let catName = data.categoryName {
                    Text(catName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var tagsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "number")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text("Etiquetas")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Tags as chips - right aligned
            HStack(spacing: 6) {
                ForEach(data.tags, id: \.name) { tag in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: tag.colorHex))
                            .frame(width: 6, height: 6)
                        Text(tag.name)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(UIColor.label).opacity(0.08))
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    TransactionSuccessView(
        data: TransactionSuccessData(
            transactionType: .expense,
            date: Date(),
            accountName: "Soles",
            accountColorHex: "FF6B6B",
            note: "Compra en supermercado",
            amount: 125.50,
            currencyCode: "PEN",
            subcategoryName: "Alimentación",
            subcategoryColorHex: "4CAF50",
            categoryName: "Hogar",
            categoryColorHex: "4CAF50",
            tags: [
                (name: "Necesario", colorHex: "2196F3"),
                (name: "Mensual", colorHex: "9C27B0"),
            ],
            isTransfer: false,
            destinationAccountName: nil,
            destinationAccountColorHex: nil,
            destinationAmount: nil,
            destinationCurrencyCode: nil
        ),
        onAccept: {},
        onCreateAnother: {},
        onEdit: {}
    )
}
