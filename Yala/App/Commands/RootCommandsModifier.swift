//
//  RootCommandsModifier.swift
//  Yala
//
//  Lo que la raíz de una ventana aporta al teclado y al arrastrar (fase 3 del carril adaptativo): publica las
//  acciones de los atajos globales para su escena y recibe los recibos que se sueltan sobre la app.
//

import PDFKit
import SwiftUI
import UniformTypeIdentifiers

struct RootCommandsModifier: ViewModifier {
    let navigation: SceneNavigation
    let sections: [ConfigurableTab]
    let canSearch: Bool
    let isGroupsOnly: Bool

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.rootCommands, actions)
            .onDrop(of: ReceiptDropHandler.acceptedTypes, isTargeted: nil) { providers in
                ReceiptDropHandler.handle(providers, isGroupsOnly: isGroupsOnly, navigation: navigation)
            }
    }

    private var actions: RootCommandActions {
        let navigation = navigation
        let canSearch = canSearch
        return RootCommandActions(
            sections: KeyboardCommandLogic.sectionTabs(orderedTabs: sections),
            canSearch: canSearch,
            isGroupsOnly: isGroupsOnly,
            perform: { RootCommandPerformer.perform($0, navigation: navigation, canSearch: canSearch) }
        )
    }
}

// MARK: - Soltar un recibo

/// Soltar una imagen o un PDF sobre Yala abre Nuevo registro por imagen (`ReceiptDropLogic`). Solo el primer
/// elemento: la pantalla de imagen trabaja con una. Un PDF entra como su primera página.
@MainActor
enum ReceiptDropHandler {
    static let acceptedTypes: [UTType] = [.image, .pdf]

    /// `true` si acepta el arrastre. Con algo presentado no lo acepta: el recibo se abriría debajo de esa hoja.
    static func handle(_ providers: [NSItemProvider], isGroupsOnly: Bool, navigation: SceneNavigation) -> Bool {
        guard ReceiptDropLogic.accepts(isGroupsOnly: isGroupsOnly) else { return false }
        guard KeyboardCommandLogic.globalCommandsAllowed(
            shellBlocker: navigation.shellModalBlocker,
            anythingPresented: ModalPresentationProbe.isAnythingPresented(
                in: SceneRegistry.shared.windowScene(for: navigation.id))
        ) else { return false }
        guard let provider = providers.first(where: { provider in
            acceptedTypes.contains { provider.hasItemConformingToTypeIdentifier($0.identifier) }
        }) else { return false }

        // El recibo se abre en la ventana sobre la que se soltó, que no tiene por qué ser la que está al frente.
        let windowID = navigation.id
        SceneRegistry.shared.noteFocused(windowID)
        switch ReceiptDropLogic.decide(canAccessImageInput: FeatureGateService.shared.canAccess(.imageInput)) {
        case .upgrade:
            RouterEntryGate.shared.submit(.navigate(.panel))
            RouterEntryGate.shared.submit(.presentUpgradeSheet(.image))
        case .present:
            let isPDF = provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier)
            let type = isPDF ? UTType.pdf : UTType.image
            _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                guard let data else {
                    #if DEBUG
                    print("ReceiptDropHandler: Error: no se pudo leer lo soltado: \(String(describing: error))")
                    #endif
                    return
                }
                Task { @MainActor in
                    receive(data, isPDF: isPDF, windowID: windowID)
                }
            }
        }
        return true
    }

    private static func receive(_ data: Data, isPDF: Bool, windowID: UUID) {
        let jpeg = isPDF ? firstPageJPEG(pdfData: data) : UIImage(data: data)?.jpegData(compressionQuality: 0.9)
        guard let jpeg else {
            #if DEBUG
            print("ReceiptDropHandler: Error: lo soltado no es una imagen legible")
            #endif
            return
        }
        guard let url = writePending(jpeg) else { return }
        // La lectura es asíncrona: entretanto el usuario pudo poner otra ventana al frente.
        SceneRegistry.shared.noteFocused(windowID)
        AppBootstrapper.shared.presentDroppedReceipt(url)
    }

    /// La primera página del PDF como imagen, a 2× para que el texto del recibo se lea.
    private static func firstPageJPEG(pdfData: Data) -> Data? {
        guard let page = PDFDocument(data: pdfData)?.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let size = CGSize(width: bounds.width * 2, height: bounds.height * 2)
        return page.thumbnail(of: size, for: .mediaBox).jpegData(compressionQuality: 0.9)
    }

    /// Al mismo sitio que la extensión de compartir (`SharedContainerService.pendingImagesURL`), con extensión `.jpg`
    /// para que `pendingImageURLs()` lo reconozca si hay que recuperarlo.
    private static func writePending(_ jpeg: Data) -> URL? {
        SharedContainerService.ensurePendingImagesDirectory()
        guard let directory = SharedContainerService.pendingImagesURL else { return nil }
        let url = directory.appendingPathComponent("drop-\(UUID().uuidString).jpg")
        do {
            try jpeg.write(to: url, options: .atomic)
            return url
        } catch {
            #if DEBUG
            print("ReceiptDropHandler: Error: \(error)")
            #endif
            return nil
        }
    }
}
