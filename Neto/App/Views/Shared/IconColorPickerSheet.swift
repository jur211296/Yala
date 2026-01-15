//
//  IconColorPickerSheet.swift
//  Neto
//
//  Componente reutilizable para seleccionar icono SF Symbol y color.
//

import SwiftUI

struct IconColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedIconName: String
    @Binding var selectedColorHex: String

    var supportsColorPicking: Bool

    // Local state for editing (allows cancelling)
    @State private var tempIconName: String
    @State private var tempColorHex: String

    // Custom color state
    @State private var customColor: Color
    @State private var showingColorPicker = false

    init(
        selectedIconName: Binding<String>, selectedColorHex: Binding<String>,
        supportsColorPicking: Bool = true
    ) {
        self._selectedIconName = selectedIconName
        self._selectedColorHex = selectedColorHex
        self.supportsColorPicking = supportsColorPicking

        // Initialize local state with current values
        self._tempIconName = State(initialValue: selectedIconName.wrappedValue)
        self._tempColorHex = State(initialValue: selectedColorHex.wrappedValue)
        self._customColor = State(initialValue: Color(hex: selectedColorHex.wrappedValue))
    }

    // ... (colors code) ...
    // Note: The original code had colors array here, we keep the imports but updating body methods.

    // We need to re-declare the arrays if we are replacing the whole struct or just part of it.
    // Since I am essentially rewriting the state management and body, it's safer to make targeted edits if possible,
    // but the state usage is pervasive.
    // However, replace_file_content works on chunks. I will target the init and state first, then the body.
    // Instead of replacing everything, let's do it in logical chunks.

    // Chunk 1: State and Init

    // ... iconCategories ... (Unchanged, so I shouldn't need to encompass it if I can avoid it)
    // But the body uses the state variables. So I need to update the body.

    // Let's replace from init to the end of body to be safe and consistent.

    // 15 preset colors (the 16th slot is the custom picker)
    private let presetColors: [String] = [
        "#22C55E", "#16A34A",  // Greens
        "#F59E0B", "#EAB308",  // Yellows/Oranges
        "#0EA5E9", "#3B82F6",  // Blues
        "#6366F1", "#8B5CF6",  // Indigos/Purples
        "#A855F7", "#D946EF",  // Purples/Magentas
        "#FF0080", "#EC4899",  // Pinks
        "#EF4444", "#F97316",  // Reds/Oranges
        "#475569",  // Gray
    ]

    // Data model for icon categories
    private struct IconCategory: Hashable {
        let name: String
        let icons: [String]
    }

    // Comprehensive SF Symbol collection organized by category
    private let iconCategories: [IconCategory] = [
        IconCategory(
            name: L10n.IconPicker.shopping,
            icons: [
                "cart.fill", "cart", "bag.fill", "bag", "basket.fill", "creditcard.fill",
                "creditcard", "dollarsign.circle.fill", "dollarsign.circle", "giftcard.fill",
                "gift.fill", "gift", "tag.fill", "tag", "barcode", "qrcode",
            ]),
        IconCategory(
            name: L10n.IconPicker.food,
            icons: [
                "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
                "wineglass.fill", "wineglass", "mug.fill", "birthday.cake.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.transport,
            icons: [
                "car.fill", "car", "car.side.fill", "bus.fill", "bus", "tram.fill",
                "airplane", "bicycle", "scooter", "fuelpump.fill", "parkingsign.circle.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.finance,
            icons: [
                "banknote.fill", "banknote", "building.columns.fill", "building.2.fill",
                "briefcase.fill", "case.fill", "chart.line.uptrend.xyaxis", "chart.bar.fill",
                "chart.pie.fill", "percent", "arrow.up.right", "arrow.down.left",
            ]),
        IconCategory(
            name: L10n.IconPicker.home,
            icons: [
                "house.fill", "house", "key.fill", "key", "lock.fill", "bed.double.fill",
                "sofa.fill", "lamp.desk.fill", "lightbulb.fill", "fan.fill",
                "washer.fill", "refrigerator.fill", "tv.fill", "wifi",
            ]),
        IconCategory(
            name: L10n.IconPicker.services,
            icons: [
                "bolt.fill", "bolt", "drop.fill", "flame.fill", "thermometer.medium",
                "antenna.radiowaves.left.and.right", "phone.fill", "envelope.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.entertainment,
            icons: [
                "sparkles", "star.fill", "star", "heart.fill", "heart",
                "gamecontroller.fill", "gamecontroller", "play.tv.fill", "film.fill",
                "music.note", "headphones", "ticket.fill", "party.popper.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.sports,
            icons: [
                "figure.run", "figure.walk", "figure.hiking", "sportscourt.fill",
                "tennisball.fill", "basketball.fill", "football.fill", "dumbbell.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.health,
            icons: [
                "heart.text.square.fill", "stethoscope", "pill.fill", "cross.case.fill",
                "cross.vial.fill", "bandage.fill", "medical.thermometer.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.personalCare,
            icons: [
                "comb.fill", "scissors", "sparkle", "wand.and.stars",
            ]),
        IconCategory(
            name: L10n.IconPicker.education,
            icons: [
                "book.fill", "book", "books.vertical.fill", "graduationcap.fill",
                "pencil", "highlighter", "ruler.fill", "backpack.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.work,
            icons: [
                "doc.text.fill", "doc.on.clipboard.fill", "folder.fill", "archivebox.fill",
                "tray.fill", "paperclip", "calendar", "clock.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.pets,
            icons: [
                "pawprint.fill", "pawprint", "hare.fill", "tortoise.fill",
                "bird.fill", "fish.fill", "ant.fill", "ladybug.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.nature,
            icons: [
                "leaf.fill", "leaf", "tree.fill", "globe.americas.fill",
                "sun.max.fill", "moon.fill", "cloud.fill", "snowflake",
            ]),
        IconCategory(
            name: L10n.IconPicker.tech,
            icons: [
                "laptopcomputer", "desktopcomputer", "iphone", "ipad",
                "applewatch", "airpodspro", "headphones.circle.fill", "printer.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.travel,
            icons: [
                "suitcase.fill", "suitcase.cart.fill", "map.fill", "mappin.circle.fill",
                "building.fill", "tent.fill", "beach.umbrella.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.communication,
            icons: [
                "message.fill", "bubble.left.fill", "video.fill", "phone.bubble.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.tools,
            icons: [
                "wrench.fill", "wrench.and.screwdriver.fill", "hammer.fill", "screwdriver.fill",
                "paintbrush.fill", "paintpalette.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.security,
            icons: [
                "shield.fill", "shield.checkered", "hand.raised.fill",
                "exclamationmark.triangle.fill", "checkmark.seal.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.symbols,
            icons: [
                "flag.fill", "bell.fill", "megaphone.fill", "pin.fill",
                "bookmark.fill", "rosette", "crown.fill", "trophy.fill",
                "app.badge.fill", "ellipsis.circle.fill", "questionmark.circle.fill",
                "info.circle.fill", "plus.circle.fill", "minus.circle.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.direction,
            icons: [
                "arrow.down.circle.fill", "arrow.up.circle.fill",
                "arrow.uturn.backward.circle.fill", "arrow.2.circlepath.circle.fill",
            ]),
        IconCategory(
            name: L10n.IconPicker.other,
            icons: [
                "hand.thumbsup.fill", "hand.thumbsdown.fill", "hands.clap.fill",
                "figure.2.arms.open", "person.fill", "person.2.fill", "person.3.fill",
            ]),
    ]

    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 8)
    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    /// True if user has made any changes to icon or color
    private var hasChanges: Bool {
        tempIconName != selectedIconName || tempColorHex != selectedColorHex
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    previewSection

                    // Color Section (first)
                    if supportsColorPicking {
                        colorSection
                    }

                    // Icon Section
                    iconSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.netoBackground)
            .navigationTitle("Personalizar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "chevron.left") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton(
                        action: {
                            // Commit changes
                            selectedIconName = tempIconName
                            selectedColorHex = tempColorHex
                            dismiss()
                        },
                        isDisabled: !hasChanges
                    )
                }
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color(hex: tempColorHex))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: tempIconName)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color(hex: tempColorHex).opacity(0.4), radius: 8, x: 0, y: 4)

            Text(L10n.IconPicker.preview)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Color Section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Common.color)
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(columns: colorColumns, spacing: 12) {
                // Preset colors
                ForEach(presetColors, id: \.self) { colorHex in
                    colorButton(hex: colorHex)
                }

                // Custom color picker (last slot)
                customColorButton
            }
        }
    }

    private func colorButton(hex: String) -> some View {
        Button {
            tempColorHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: tempColorHex == hex ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
                .shadow(
                    color: tempColorHex == hex ? Color(hex: hex).opacity(0.5) : .clear,
                    radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var customColorButton: some View {
        ColorPicker("", selection: $customColor, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 36, height: 36)
            .onChange(of: customColor) { _, newColor in
                tempColorHex = newColor.toHex()
            }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(iconCategories, id: \.name) { category in
                VStack(alignment: .leading, spacing: 12) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    LazyVGrid(columns: iconColumns, spacing: 12) {
                        ForEach(category.icons, id: \.self) { iconName in
                            iconButton(name: iconName)
                        }
                    }
                }
            }
        }
    }

    private func iconButton(name: String) -> some View {
        Button {
            tempIconName = name
        } label: {
            ZStack {
                Circle()
                    .fill(
                        tempIconName == name
                            ? Color(hex: tempColorHex).opacity(0.2)
                            : Color.gray.opacity(0.1)
                    )
                    .frame(width: 48, height: 48)

                Image(systemName: name)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        tempIconName == name
                            ? Color(hex: tempColorHex)
                            : .primary)

                if tempIconName == name {
                    Circle()
                        .stroke(Color(hex: tempColorHex), lineWidth: 2)
                        .frame(width: 48, height: 48)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// MARK: - Color to Hex Extension

extension Color {
    func toHex() -> String {
        #if canImport(UIKit)
            let uiColor = UIColor(self)
            guard let components = uiColor.cgColor.components else {
                return "#000000"
            }
            let r = components.count > 0 ? components[0] : 0
            let g = components.count > 1 ? components[1] : 0
            let b = components.count > 2 ? components[2] : 0

            return String(
                format: "#%02X%02X%02X",
                Int(r * 255),
                Int(g * 255),
                Int(b * 255))
        #elseif canImport(AppKit)
            let nsColor = NSColor(self)
            guard let components = nsColor.cgColor.components else {
                return "#000000"
            }
            let r = components.count > 0 ? components[0] : 0
            let g = components.count > 1 ? components[1] : 0
            let b = components.count > 2 ? components[2] : 0

            return String(
                format: "#%02X%02X%02X",
                Int(r * 255),
                Int(g * 255),
                Int(b * 255))
        #else
            return "#000000"
        #endif
    }
}

#Preview {
    IconColorPickerSheet(
        selectedIconName: .constant("cart.fill"),
        selectedColorHex: .constant("#22C55E")
    )
}
