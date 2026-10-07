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
            .modifier(UITestReceiptDropSeam(navigation: navigation, isGroupsOnly: isGroupsOnly))
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
///
/// Lo que no se puede abrir (PDF vacío o protegido, imagen dañada) abre el mismo registro por imagen en su fallo
/// «No pude abrir este archivo», el de Archivo desde dentro. Hasta el 2026-10-07 solo se escribía en el log: el sistema
/// ya había dado el soltar por aceptado y el usuario no veía nada. Lo que nunca es imagen ni PDF no llega aquí: el
/// `onDrop` solo acepta `acceptedTypes`, así que el sistema lo rechaza antes de soltar.
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
                #if DEBUG
                if data == nil {
                    print("ReceiptDropHandler: Error: no se pudo leer lo soltado: \(String(describing: error))")
                }
                #endif
                Task { @MainActor in
                    receive(data, isPDF: isPDF, sink: .live(windowID: windowID))
                }
            }
        }
        return true
    }

    /// Lo que sale de lo soltado, sin efectos: el JPEG que se va a leer, o el fallo que se le enseña al usuario.
    enum Outcome: Equatable {
        case readable(jpeg: Data)
        case failed(ImageEntryFailure)
    }

    static func outcome(for data: Data?, isPDF: Bool) -> Outcome {
        guard let data else { return .failed(.unreadableFile) }
        let jpeg = isPDF ? firstPageJPEG(pdfData: data) : UIImage(data: data)?.jpegData(compressionQuality: 0.9)
        guard let jpeg else {
            #if DEBUG
            print("ReceiptDropHandler: Error: lo soltado no es una imagen legible")
            #endif
            return .failed(.unreadableFile)
        }
        return .readable(jpeg: jpeg)
    }

    /// A dónde va lo soltado. Separado para probar que ningún camino termina en silencio.
    struct Sink {
        var store: (Data) -> URL?
        var present: (URL) -> Void
        var fail: (ImageEntryFailure) -> Void

        static func live(windowID: UUID) -> Sink {
            Sink(
                store: writePending,
                present: { url in
                    // La lectura es asíncrona: entretanto el usuario pudo poner otra ventana al frente.
                    SceneRegistry.shared.noteFocused(windowID)
                    AppBootstrapper.shared.presentDroppedReceipt(url)
                },
                fail: { failure in
                    SceneRegistry.shared.noteFocused(windowID)
                    AppBootstrapper.shared.presentDroppedReceiptFailure(failure)
                }
            )
        }
    }

    /// Todo camino acaba en la hoja: con la foto, o con su fallo. Si no se puede guardar en `PendingImages/`, el archivo
    /// está bien y falló lo nuestro: `.generic`, no «no pude abrirlo».
    static func receive(_ data: Data?, isPDF: Bool, sink: Sink) {
        switch outcome(for: data, isPDF: isPDF) {
        case .failed(let failure):
            sink.fail(failure)
        case .readable(let jpeg):
            guard let url = sink.store(jpeg) else {
                sink.fail(.generic)
                return
            }
            sink.present(url)
        }
    }

    /// La primera página del PDF como imagen, a 2× para que el texto del recibo se lea. También la usa Archivo en el
    /// registro por imagen. Un PDF protegido con contraseña cuenta como ilegible: PDFKit lo entrega bloqueado y aquí no hay
    /// dónde pedir la contraseña.
    static func firstPageJPEG(pdfData: Data) -> Data? {
        guard let document = PDFDocument(data: pdfData), !document.isLocked,
              let page = document.page(at: 0) else { return nil }
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

// MARK: - Seam de XCUITest

/// `-uitest-receipt-drop` (`UITestHooks.receiptDrop`): suelta un recibo por `ReceiptDropHandler.handle` en cuanto la
/// ventana queda libre, una sola vez. Fuera de los XCUITest no hace nada.
private struct UITestReceiptDropSeam: ViewModifier {
    let navigation: SceneNavigation
    let isGroupsOnly: Bool
    @State private var dropped = false

    func body(content: Content) -> some View {
        #if DEBUG
        content.onChange(of: navigation.shellModalBlocker, initial: true) { _, blocker in
            guard !dropped, blocker == nil, let kind = UITestHooks.receiptDrop else { return }
            dropped = true
            let provider = NSItemProvider()
            let type: UTType
            let data: Data?
            switch kind {
            case "readable":
                type = .png
                data = UIImage(named: "ExampleImages/example-receipt-es")?.pngData()
            default:
                type = .pdf
                data = Data("no es un PDF".utf8)
            }
            provider.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
                completion(data, nil)
                return nil
            }
            let accepted = ReceiptDropHandler.handle([provider], isGroupsOnly: isGroupsOnly, navigation: navigation)
            print("UITestReceiptDropSeam: \(kind) aceptado=\(accepted)")
        }
        #else
        content
        #endif
    }
}
