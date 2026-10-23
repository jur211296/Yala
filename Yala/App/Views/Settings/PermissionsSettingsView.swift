//
//  PermissionsSettingsView.swift
//  Yala
//
//  «Permisos de Yala» (UX 2.2 · L16-14, opción B de Jürgen): qué puede usar Yala del iPhone, con el estado de cada
//  permiso y un botón por permiso a Configuración. Antes la fila «Permisos» saltaba a Configuración de iOS sin avisar,
//  y en el simulador caía en la raíz, sin la página de Yala.
//
//  Face ID (L16-14, opción A de Jürgen, 2026-10-23): fila sin estado y con «Ver cómo», que abre la guía «Proteger con
//  Face ID». Yala no pide permiso de Face ID —la protección es «Requerir Face ID» de iOS, que no le dice a la app si está
//  puesta, y en Configuración no hay interruptor de Face ID para Yala—, así que no hay estado que enseñar ni página a la
//  que llevar; sí hay quien lo busca entre los permisos.
//

import AVFoundation
import Photos
import SwiftUI
import UserNotifications

struct PermissionsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var notifications: PermissionState = .notAsked
    @State private var camera: PermissionState = .notAsked
    @State private var microphone: PermissionState = .notAsked
    @State private var photos: PermissionState = .notAsked

    /// Los permisos que salen, en orden. El de notificaciones abre su propia página de Configuración.
    private enum Kind: String, CaseIterable, Identifiable {
        case notifications, camera, microphone, photos
        var id: String { rawValue }
    }

    var body: some View {
        YalaSettingsList {
            YalaSettingsSection {
                ForEach(Kind.allCases) { kind in
                    row(kind)
                }
                faceIDRow
            } footer: {
                Text(L10n.UXL15.permissionsFooter)
            }
        }
        .navigationTitle(L10n.UXL15.permissionsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .yalaScreenBackground(.subtle)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
        }
        .task { await refresh() }
        // Al volver de Configuración, el estado puede haber cambiado.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }

    // MARK: - Fila

    private func row(_ kind: Kind) -> some View {
        let state = state(of: kind)
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                Image(systemName: icon(of: kind))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title(of: kind))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(detail(of: kind))
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text(statusText(state))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(state == .denied ? DS.Semantic.errorForeground : Color(uiColor: .secondaryLabel))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("permission_status_\(kind.rawValue)")
            }
            if state.offersSettingsButton {
                Button(L10n.UXL15.permissionsChangeInSettings) {
                    openSettings(for: kind)
                }
                .font(DS.Typography.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .padding(.leading, 24 + DS.Spacing.md)
                .accessibilityIdentifier("permission_open_settings_\(kind.rawValue)")
            } else {
                Text(L10n.UXL15.permissionsNotAskedHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(.leading, 24 + DS.Spacing.md)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        // Sin `accessibilityIdentifier` en el contenedor: pisaría el de su estado y su botón (`testing.md`).
    }

    /// Sin estado: iOS no le cuenta a Yala si «Requerir Face ID» está puesto. El destino lo registran las dos pilas de
    /// Ajustes (`ProfileView.settingsContainer`), así que empuja la guía en compacta y en la columna de detalle.
    private var faceIDRow: some View {
        NavigationLink(value: ProfileDestination.faceIDProtectionGuide) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                Image(systemName: "faceid")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.PJ22.permissionFaceID)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(L10n.PJ22.permissionFaceIDDetail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text(L10n.PJ22.permissionFaceIDSeeHow)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("permission_faceid_see_how")
    }

    // MARK: - Datos

    private func state(of kind: Kind) -> PermissionState {
        switch kind {
        case .notifications: notifications
        case .camera: camera
        case .microphone: microphone
        case .photos: photos
        }
    }

    private func title(of kind: Kind) -> String {
        switch kind {
        case .notifications: L10n.UXL15.permissionNotifications
        case .camera: L10n.UXL15.permissionCamera
        case .microphone: L10n.UXL15.permissionMicrophone
        case .photos: L10n.UXL15.permissionPhotos
        }
    }

    private func detail(of kind: Kind) -> String {
        switch kind {
        case .notifications: L10n.UXL15.permissionNotificationsDetail
        case .camera: L10n.UXL15.permissionCameraDetail
        case .microphone: L10n.UXL15.permissionMicrophoneDetail
        case .photos: L10n.UXL15.permissionPhotosDetail
        }
    }

    private func icon(of kind: Kind) -> String {
        switch kind {
        case .notifications: "bell.fill"
        case .camera: "camera.fill"
        case .microphone: "mic.fill"
        case .photos: "photo.fill"
        }
    }

    private func statusText(_ state: PermissionState) -> String {
        switch state {
        case .allowed: L10n.UXL15.permissionAllowed
        case .limited: L10n.UXL15.permissionLimited
        case .saveOnly: L10n.UXL15.permissionSaveOnly
        case .denied: L10n.UXL15.permissionDenied
        case .notAsked: L10n.UXL15.permissionNotAsked
        }
    }

    private func openSettings(for kind: Kind) {
        let raw = kind == .notifications ? UIApplication.openNotificationSettingsURLString : UIApplication.openSettingsURLString
        guard let url = URL(string: raw) else { return }
        openURL(url)
    }

    private func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifications = .notifications(settings.authorizationStatus)
        camera = .camera(AVCaptureDevice.authorizationStatus(for: .video))
        microphone = .microphone(AVAudioApplication.shared.recordPermission)
        photos = .photos(
            readWrite: PHPhotoLibrary.authorizationStatus(for: .readWrite),
            addOnly: PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }
}
