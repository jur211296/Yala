//
//  CloudActivationSheet.swift
//  Yala
//
//  UX 2.2 · L20-11 (opción C, variante 2) y L20-12 (opción B), decididas por Jürgen el 2026-10-18: **activar la nube
//  desde Ajustes es UNA hoja**. Antes eran cuatro pantallas —consentimiento, «¿Activar la nube?», «¿Seguro?» y «Elige
//  cómo iniciar sesión»— antes de entrar con Apple o Google. Ahora: tres líneas sin jerga, lo que pasa, y los botones
//  de entrar al pie. Tocar uno es aceptar lo que dice la hoja, confirmar y elegir el método, y por eso aquí se
//  REGISTRA el consentimiento (la misma escritura y la misma métrica que `CloudConsentView`).
//
//  Lo que la hoja no esconde: «Ver los detalles» despliega el texto legal entero —incluidas las fotos de los
//  recibos, que no viajan—, y «Exportar una copia antes» exporta todos los registros sin asistente (el molde de
//  L20-8) en vez de escribir la ruta de Ajustes. El contrato no cambió: `CloudConsentText.version` no sube.
//
//  Pura respecto a la migración: no la arranca. `onContinue` comunica la elección y el caller (`StorageSettingsView`)
//  baja la hoja y arranca desde su `onDismiss` (regla 4 de presentaciones; Google resuelve su presenter con el
//  anchor estable).
//
//  Solo Ajustes › Dónde viven tus datos (migrar y «activar en este dispositivo»). El consentimiento del Welcome y el
//  de Yala completo siguen en `CloudConsentView` (L6-4).
//

import AuthenticationServices
import SwiftData
import SwiftUI

struct CloudActivationSheet: View {

    /// Qué abrió la hoja: «Migrar» (`.migration`) o «Activar en este dispositivo» (`.adopt`). Va a la telemetría.
    let path: CloudMigrationController.ConsentPath
    /// La decisión de sesión, leída viva por el caller al presentar. Con sesión viva no se elige método (C-7).
    let decision: StorageMigrationSignInLogic.Decision
    /// Lo que pasaría a la nube. `nil` en el adopt: la cuenta ya tiene sus datos y no se mueve nada de aquí.
    let preview: MigrationDryRunPreview?
    /// La persona tocó un botón de entrar: `.authenticateWith(proveedor)` o `.reuseLiveSession`. El caller baja la hoja.
    var onContinue: (CloudMigrationController.SignInPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var showsDetails = false
    @State private var isExporting = false
    @State private var exportedFile: ExportedFile?
    @State private var exportErrorMessage = ""
    @State private var showExportError = false
    /// Alto natural de lo de arriba y del pie, medidos: la hoja mide lo que su contenido (la variante elegida es una hoja
    /// a media pantalla, no una pantalla completa con un hueco). Crece si se abren los detalles; si no cabe, se desplaza.
    @State private var contentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    /// `.large` hasta que se mide; después, el alto del contenido (y `.large` para quien la estire).
    private var detents: Set<PresentationDetent> {
        guard contentHeight > 0, footerHeight > 0 else { return [.large] }
        return [.height(contentHeight + footerHeight + DS.Spacing.lg), .large]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text(L10n.UXL20N.sheetTitle)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("storage_activation_sheet")

                row(icon: "iphone.and.arrow.forward", tint: .electricIndigo,
                    title: L10n.UXL20N.anyPhoneTitle, detail: L10n.UXL20N.anyPhoneDetail)
                row(icon: "eye", tint: DS.Semantic.warningForeground,
                    title: L10n.UXL20N.seesTitle, detail: L10n.UXL20N.seesDetail)
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    row(icon: "key", tint: .secondary,
                        title: L10n.UXL20N.accessTitle, detail: L10n.UXL20N.accessDetail)
                    exportCopyButton
                        .padding(.leading, Self.iconSize + DS.Spacing.md)
                }

                detailsDisclosure

                if let previewLine {
                    Text(previewLine)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("storage_activation_preview")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.lg)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        // Los botones de entrar, siempre a la vista: con «Ver los detalles» abierto o el texto grande, lo de arriba se
        // desplaza y esto no se va de la pantalla.
        .safeAreaInset(edge: .bottom) {
            footer
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { footerHeight = $0 }
        }
        .yalaScreenBackground(.partialSheet)
        .yalaSheetDetents(detents)
        .presentationDragIndicator(.visible)
        .overlay {
            if isExporting {
                ProgressView()
                    .controlSize(.large)
                    .padding(DS.Spacing.lg)
                    .glassEffect()
                    .accessibilityIdentifier("storage_activation_export_progress")
            }
        }
        .sheet(item: $exportedFile) { file in
            ShareSheet(activityItems: file.urls)
                .yalaSheetDetents([.medium, .large])
        }
        .alert(L10n.Export.exportError, isPresented: $showExportError) {
            Button(L10n.Common.ok, role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
    }

    // MARK: - Las tres líneas

    private static let iconSize: CGFloat = 36

    private func row(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.headline)
                .foregroundStyle(tint)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .background(tint.opacity(0.18), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    /// «Exportar una copia antes» (L20-12): el botón en vez de la ruta escrita. Todos los registros, en Excel, sin
    /// asistente — el mismo archivo que «Exportar antes» de cerrar sesión o eliminar la cuenta (L20-8).
    private var exportCopyButton: some View {
        Button {
            exportEverything()
        } label: {
            Label(L10n.UXL20N.exportCopy, systemImage: "square.and.arrow.up")
                .font(DS.Typography.subheadline.weight(.medium))
                .foregroundStyle(DS.Semantic.infoForeground)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .accessibilityIdentifier("storage_activation_export")
    }

    // MARK: - Ver los detalles

    /// El texto legal entero, a un toque (L20-12). Es el contrato de siempre (`storage.consent.*`), con lo que la hoja
    /// resume: quién lee los datos, las fotos que no viajan, cómo se entra y que se puede volver.
    private var detailsDisclosure: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showsDetails.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(showsDetails ? L10n.UXL20N.hideDetails : L10n.UXL20N.details)
                    Image(systemName: showsDetails ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .font(DS.Typography.subheadline.weight(.medium))
                .foregroundStyle(DS.Semantic.infoForeground)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("storage_activation_details")

            if showsDetails {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    detail(L10n.UXLote6.consentServersTitle, L10n.Storage.Consent.pointServers)
                    detail(L10n.UXLote6.consentPhotosTitle, L10n.Storage.Consent.pointPhotos)
                    detail(L10n.UXLote6.consentAccessTitle, L10n.UXL20N.detailsAccess)
                    Text(L10n.Storage.Consent.footer)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
                .transition(.opacity)
                .accessibilityIdentifier("storage_activation_details_text")
            }
        }
    }

    private func detail(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    /// «Pasarán 32 registros, 2 cuentas y 6 presupuestos.» — en letra normal, no en gris monoespaciado (L20-11). Sin
    /// cifras si no se dejaron contar: un cero sería inventado.
    private var previewLine: String? {
        switch preview {
        case let .counts(transactions, _, accounts, budgets):
            return L10n.UXL20N.willMove(records: transactions, accounts: accounts, budgets: budgets)
        case .unreadable:
            return L10n.Storage.Migrate.previewUnreadable
        case nil:
            return nil
        }
    }

    // MARK: - El pie: entrar

    private var footer: some View {
        VStack(spacing: DS.Spacing.md) {
            switch decision {
            case .askProvider:
                providerButton(.apple)
                providerButton(.google)
            case .reuseLiveSession(let provider):
                // C-7: con una sesión de la nube viva no se elige método; se sigue con esa cuenta, y la tarjeta ya lo
                // anunció («Usarás tu cuenta de Yala actual…»). Ofrecer los dos botones mentiría.
                if let provider {
                    providerButton(provider)
                } else {
                    YalaPrimaryButton(L10n.UXL20N.continueCurrent, icon: "person.crop.circle.badge.checkmark") {
                        accept(.reuseLiveSession)
                    }
                    .accessibilityIdentifier("storage_activation_current")
                }
            case .blockedOtherAccount:
                // La tarjeta ya deshabilita «Activar» con esta decisión; si se llegara aquí por una carrera, no hay
                // botón que lleve a ninguna parte.
                EmptyView()
            }

            HStack(spacing: DS.Spacing.sm) {
                Button(L10n.Storage.Consent.privacyLink) { openURL(AppConstants.privacyURL) }
                    .accessibilityIdentifier("storage_activation_privacy")
                Text("·").accessibilityHidden(true)
                Button(L10n.Common.cancel) { dismiss() }
                    .accessibilityIdentifier("storage_activation_cancel")
            }
            .buttonStyle(.plain)
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
        .background(.bar)
    }

    /// Un botón de entrar con su marca, «Continuar con…» (verbo neutro: desde aquí se crea una cuenta al migrar o se
    /// entra en una que existe). Con sesión viva del mismo proveedor, sigue con ella sin volver a firmar.
    @ViewBuilder
    private func providerButton(_ provider: CloudSignInProvider) -> some View {
        let plan: CloudMigrationController.SignInPlan = {
            if case .reuseLiveSession = decision { return .reuseLiveSession }
            return .authenticateWith(provider)
        }()
        switch provider {
        case .apple:
            StorageAppleSignInButton(colorScheme: colorScheme, type: .continue) {
                DS.Haptic.selection()
                accept(plan)
            }
            .frame(height: 50)
            .accessibilityIdentifier("storage_activation_apple")
        case .google:
            GoogleSignInButton(variant: colorScheme == .dark ? .dark : .light, purpose: .continue) {
                DS.Haptic.selection()
                accept(plan)
            }
            .frame(height: 50)
            .accessibilityIdentifier("storage_activation_google")
        }
    }

    // MARK: - Acciones

    /// Aceptar ES el toque de entrar: se registra el consentimiento (persistencia GDPR + telemetría, como
    /// `CloudConsentView` con `persistsOnAccept`) antes de que nada firme ni migre, y la hoja baja.
    private func accept(_ plan: CloudMigrationController.SignInPlan) {
        CloudConsentRegistrar.register()
        MetricsService.cloudConsentAccepted(path: path.rawValue)
        onContinue(plan)
    }

    /// El archivo de todo, sin asistente. `scheduleTagBackfill: false`, como el rescate de cerrar sesión: el relleno de
    /// etiquetas guardaría cambios justo antes de mover los datos. Una vuelta después del toque, para que el indicador
    /// llegue a pintarse: la exportación bloquea el hilo principal.
    private func exportEverything() {
        guard !isExporting else { return }
        isExporting = true
        Task { @MainActor in
            await Task.yield()
            defer { isExporting = false }
            do {
                let result = try TransactionsExportService.export(
                    format: .xlsx, using: .allTransactions, columns: .default, in: modelContext,
                    scheduleTagBackfill: false)
                exportedFile = ExportedFile(urls: [result.fileURL])
            } catch {
                #if DEBUG
                print("CloudActivationSheet: Error exportando la copia antes de activar la nube: \(error)")
                #endif
                exportErrorMessage = SignOutBlockedCopy.personalExportFailureMessage(for: error)
                showExportError = true
            }
        }
    }
}
