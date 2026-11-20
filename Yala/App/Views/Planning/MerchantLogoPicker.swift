//
//  MerchantLogoPicker.swift
//  Yala
//
//  Elegir a mano el logo de un pago planificado (card `scheduled-payments-real-brand-logos`, 2.3). Con cientos de
//  comercios el menú de antes no se podía usar: hoja con buscador sobre todo el banco (nombre y formas de escribirlo),
//  y arriba las dos salidas de siempre, automático y sin logo. Sin textos nuevos: reusa los de la fila «Logo» y el
//  buscador del sistema.
//
//  Logo propio (encargo del 2026-11-20): una sección con la foto de la galería (`PhotosPicker`). Elegir la foto pone
//  `brandLogoID` en «sin logo», para que una versión vieja enseñe el icono por defecto; elegir cualquier otra opción
//  quita la foto. Una sola fila: la foto elegida con «Cambiar» a su derecha, nunca un botón debajo de otro.
//

import PhotosUI
import SwiftUI

struct MerchantLogoPickerSheet: View {
    /// Lo que guarda el pago: `nil` = automático, `SubscriptionBrandCatalog.noneID` = sin logo, o el id elegido.
    @Binding var brandLogoID: String?
    /// El logo propio del pago (`ScheduledPayment.customLogoData`): `nil` = sin foto.
    @Binding var customLogoData: Data?
    let paymentName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @State private var query = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoUnreadable = false

    private var automatic: PaymentLogo? { PaymentLogoResolver.automatic(name: paymentName) }

    private var results: [Merchant] {
        MerchantLogoSearch.filter(MerchantCatalog.sortedForPicking, query: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    ownPhotoSection
                    Section {
                        choiceRow(id: "scheduled_logo_option_auto", isSelected: customLogoData == nil && brandLogoID == nil) {
                            customLogoData = nil
                            brandLogoID = nil
                        } label: {
                            if let automatic {
                                SubscriptionBrandBadge(logo: automatic, diameter: DS.Icon.badgeSmall, isDecorative: true)
                                Text(L10n.Scheduled.logoAutoNamed(automatic.name))
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .frame(width: DS.Icon.badgeSmall)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(L10n.Scheduled.logoAuto)
                            }
                        }
                        choiceRow(id: "scheduled_logo_option_none",
                                  isSelected: customLogoData == nil && brandLogoID == SubscriptionBrandCatalog.noneID) {
                            customLogoData = nil
                            brandLogoID = SubscriptionBrandCatalog.noneID
                        } label: {
                            Image(systemName: "circle.slash")
                                .frame(width: DS.Icon.badgeSmall)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(L10n.Scheduled.logoNone)
                        }
                    }
                }
                Section {
                    ForEach(results) { merchant in
                        choiceRow(id: "scheduled_logo_option_\(merchant.id)",
                                  isSelected: customLogoData == nil && brandLogoID == merchant.id) {
                            customLogoData = nil
                            brandLogoID = merchant.id
                        } label: {
                            SubscriptionBrandBadge(logo: PaymentLogo(merchant: merchant), diameter: DS.Icon.badgeSmall,
                                                   isDecorative: true)
                            Text(verbatim: merchant.name)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(L10n.Scheduled.logoTitle)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
            .onChange(of: photoItem) { _, item in loadPhoto(item) }
            .alert(PagoLogoPropioText.unreadable, isPresented: $photoUnreadable) {
                Button(L10n.Common.ok, role: .cancel) {}
            }
        }
        .yalaScreenBackground(.subtle)
    }

    // MARK: - Logo propio

    /// La foto del pago: sin foto, «Usar una foto»; con foto, la foto elegida y «Cambiar» en la misma fila.
    private var ownPhotoSection: some View {
        Section {
            if let data = customLogoData, let image = PhotoIntake.image(from: data, maxEdge: PagoLogoPropioFoto.lado) {
                HStack(spacing: DS.Spacing.md) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
                        .accessibilityHidden(true)
                    Text(PagoLogoPropioText.yourPhoto)
                        .foregroundStyle(Color(.label))
                    Image(systemName: "checkmark")
                        .font(DS.Typography.label)
                        .foregroundStyle(theme.accentText)
                        .accessibilityHidden(true)
                    Spacer(minLength: DS.Spacing.sm)
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        Text(PagoLogoPropioText.change)
                            .foregroundStyle(theme.accentText)
                    }
                    // Estilo propio: dos controles en una fila de `List` no pueden compartir la zona de toque.
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("scheduled_logo_photo_change")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("scheduled_logo_option_photo")
                .accessibilityAddTraits(.isSelected)
            } else {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "photo.on.rectangle")
                            .frame(width: DS.Icon.badgeSmall)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(PagoLogoPropioText.usePhoto)
                            .foregroundStyle(Color(.label))
                        Spacer(minLength: DS.Spacing.sm)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("scheduled_logo_option_use_photo")
            }
        } header: {
            Text(PagoLogoPropioText.section)
        } footer: {
            Text(PagoLogoPropioText.footer)
        }
    }

    /// Lee la foto elegida fuera del hilo principal, la deja en 256 × 256 px y la guarda como logo del pago.
    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            var stored: Data?
            do {
                if let raw = try await item.loadTransferable(type: Data.self) {
                    stored = await Self.prepare(raw)
                }
            } catch {
                #if DEBUG
                print("MerchantLogoPickerSheet: Error: \(error)")
                #endif
            }
            photoItem = nil
            guard let stored else {
                photoUnreadable = true
                DS.Haptic.error()
                return
            }
            customLogoData = stored
            brandLogoID = SubscriptionBrandCatalog.noneID
            DS.Haptic.selection()
            dismiss()
        }
    }

    @concurrent
    private static func prepare(_ raw: Data) async -> Data? {
        PagoLogoPropioFoto.datosParaGuardar(desde: raw)
    }

    private func choiceRow<Label: View>(
        id: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            action()
            DS.Haptic.selection()
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                label()
                Spacer(minLength: DS.Spacing.sm)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.label)
                        .foregroundStyle(theme.accentText)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Color(.label))
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}

/// El filtro del buscador: lo escrito, sin mayúsculas ni tildes, dentro del nombre o de una forma de escribirlo.
enum MerchantLogoSearch {
    static func filter(_ merchants: [Merchant], query: String) -> [Merchant] {
        let needle = SubscriptionBrandCatalog.normalize(query)
        guard !needle.isEmpty else { return merchants }
        return merchants.filter { merchant in
            ([merchant.name] + merchant.aliases).contains { SubscriptionBrandCatalog.normalize($0).contains(needle) }
        }
    }
}
