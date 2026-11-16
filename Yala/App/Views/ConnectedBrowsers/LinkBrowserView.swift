//
//  LinkBrowserView.swift
//  Yala
//
//  Ajustes › Tu cuenta de Yala › Navegadores conectados › «Vincular un navegador» (Yala web, lote 2). Escanea el QR que
//  enseña la web (VisionKit) o deja escribir su código, enseña qué navegador es y desde dónde, y aprueba tras Face ID.
//  La lógica vive en `LinkBrowserModel`. Solo existe en Yala Dev, como la pantalla que la abre.
//

import SwiftUI
import Vision
import VisionKit

struct LinkBrowserView: View {
    @State private var model: LinkBrowserModel
    @State private var typed = ""
    @FocusState private var fieldFocused: Bool
    @Environment(\.dismiss) private var dismiss
    private let onLinked: () -> Void

    init(model: LinkBrowserModel, onLinked: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onLinked = onLinked
    }

    var body: some View {
        YalaSettingsList {
            switch model.phase {
            case .entering, .checking:
                entering
            case .confirm(let request), .approving(let request):
                confirm(request)
            case .linked(let request):
                linked(request)
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(ConnectedBrowsersText.linkTitle)
        .navigationBarTitleDisplayMode(.inline)
        // `dismissKeyboardOnTap()` no va aquí: su `onTapGesture` sobre una `List` se come los toques de las filas (medido:
        // «Continuar» y «Confirmar con Face ID» no respondían). El teclado baja al desplazar o con Intro.
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("link_browser_screen")
    }

    // MARK: - Leer el código

    @ViewBuilder
    private var entering: some View {
        YalaSettingsSection {
            Text(ConnectedBrowsersText.linkIntro)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if LinkCodeScanner.isAvailable {
                LinkCodeScanner { payload in
                    Task { await model.submit(payload) }
                }
                // Un escáner nuevo en cada intento: el anterior ya entregó su código.
                .id(model.attempt)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .accessibilityLabel(ConnectedBrowsersText.linkScannerLabel)
                .accessibilityIdentifier("link_browser_scanner")
            }
        }

        YalaSettingsSection(ConnectedBrowsersText.linkTypeHeader) {
            TextField(ConnectedBrowsersText.linkCodePlaceholder, text: $typed)
                .font(DS.Typography.title3.monospaced())
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($fieldFocused)
                .submitLabel(.go)
                .onSubmit { send() }
                .accessibilityIdentifier("link_browser_code_field")
            Button {
                send()
            } label: {
                HStack {
                    Text(ConnectedBrowsersText.linkContinue)
                    Spacer()
                    if model.phase == .checking { ProgressView() }
                }
                .contentShape(Rectangle())
            }
            .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty || model.phase == .checking)
            .accessibilityIdentifier("link_browser_continue")
        } footer: {
            if let problem = model.problem {
                Text(ConnectedBrowsersText.linkProblem(problem))
                    .foregroundStyle(DS.Semantic.errorForeground)
                    .accessibilityIdentifier("link_browser_problem")
            }
        }
    }

    private func send() {
        fieldFocused = false
        Task { await model.submit(typed) }
    }

    // MARK: - Confirmar

    @ViewBuilder
    private func confirm(_ request: WebLinkRequest) -> some View {
        let approving = model.phase == .approving(request)
        YalaSettingsSection(ConnectedBrowsersText.linkConfirmHeader) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label {
                    Text(ConnectedBrowsersText.browserTitle(navegador: request.navegador, sistema: request.sistema))
                        .font(DS.Typography.headline)
                } icon: {
                    Image(systemName: "macbook.and.iphone")
                }
                .accessibilityIdentifier("link_browser_confirm_browser")
                Text(ConnectedBrowsersText.linkWhere(city: request.ciudad, code: WebLinkCode.display(WebLinkCode.normalize(request.codigo) ?? request.codigo)))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, DS.Spacing.xs)
        } footer: {
            Text(ConnectedBrowsersText.linkWarning)
        }

        YalaSettingsSection {
            Button {
                Task { await model.confirm(reason: ConnectedBrowsersText.linkFaceIDReason) }
            } label: {
                HStack {
                    Label(ConnectedBrowsersText.linkConfirm, systemImage: "faceid")
                    Spacer()
                    if approving { ProgressView() }
                }
                .contentShape(Rectangle())
            }
            .disabled(approving)
            .accessibilityIdentifier("link_browser_confirm")
            Button(L10n.Action.cancel, role: .cancel) {
                model.restart()
            }
            .disabled(approving)
            .accessibilityIdentifier("link_browser_cancel")
        }
    }

    // MARK: - Hecho

    @ViewBuilder
    private func linked(_ request: WebLinkRequest) -> some View {
        YalaSettingsSection {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(ConnectedBrowsersText.linkDoneTitle, systemImage: "checkmark.circle.fill")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Semantic.successForeground)
                Text(ConnectedBrowsersText.linkDoneBody(ConnectedBrowsersText.browserTitle(navegador: request.navegador, sistema: request.sistema)))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, DS.Spacing.xs)
            .accessibilityIdentifier("link_browser_done")
        }
        YalaSettingsSection {
            Button(ConnectedBrowsersText.linkDoneButton) {
                onLinked()
                dismiss()
            }
            .accessibilityIdentifier("link_browser_done_button")
        }
    }
}

/// El escáner de QR de VisionKit. Solo existe donde el aparato lo permite (no en el simulador): ahí queda el campo.
private struct LinkCodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    @MainActor static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        do {
            try scanner.startScanning()
        } catch {
            #if DEBUG
            print("LinkCodeScanner: Error: \(error)")
            #endif
        }
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onCode: (String) -> Void
        private var delivered = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !delivered else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue, WebLinkCode.normalize(payload) != nil {
                    delivered = true
                    onCode(payload)
                    return
                }
            }
        }
    }
}
