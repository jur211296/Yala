import UIKit
import UniformTypeIdentifiers

/// Guarda lo compartido en `PendingImages/` del App Group y abre Yala (`<scheme>://shared-image`), que lo lee.
///
/// Varias fotos a la vez (2026-10-11): Yala aparece hasta `SharedImageBatch.maxSharedImages` fotos
/// (`Info.plist`), guarda las primeras `SharedImageBatch.maxImages` como una tanda y la app avisa de las que no entraron.
/// La tanda va en el nombre de cada fichero (`SharedImageBatch.fileName`). Se escriben como `.part` y se renombran al
/// final, para que la recuperación de la app no lea media tanda.
///
/// Un PDF (UX 2.2 · L4-10): si no hay fotos, se guarda tal cual como `<UUID>.pdf` y la app lo trocea por el mismo
/// camino que un PDF soltado en el iPad, contraseña incluida.
class ShareViewController: UIViewController {

    /// App Group identifier from shared helper.
    private var appGroupIdentifier: String { WidgetURLHelper.appGroupIdentifier }

    /// URL Scheme from shared helper.
    private var urlScheme: String { WidgetURLHelper.urlScheme }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeWithError()
            return
        }

        let imageProviders = extensionItems
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        guard !imageProviders.isEmpty else {
            let pdfProvider = extensionItems
                .flatMap { $0.attachments ?? [] }
                .first { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }
            guard let pdfProvider else {
                completeWithError()
                return
            }
            loadPDFData(from: pdfProvider) { [weak self] data in
                guard let self = self else { return }
                guard let data = data else {
                    self.completeWithError()
                    return
                }
                self.savePDFToSharedContainer(data)
            }
            return
        }

        let toLoad = Array(imageProviders.prefix(SharedImageBatch.maxImages))
        loadImages(toLoad, loaded: []) { [weak self] loaded in
            guard let self = self else { return }
            guard !loaded.isEmpty else {
                self.completeWithError()
                return
            }
            self.saveBatchToSharedContainer(loaded, sharedCount: imageProviders.count)
        }
    }

    /// Carga las fotos una a una, en el orden compartido. Una que no se pudo cargar se salta: se guardan las demás.
    private func loadImages(
        _ providers: [NSItemProvider],
        loaded: [Data],
        completion: @escaping ([Data]) -> Void
    ) {
        guard let provider = providers.first else {
            completion(loaded)
            return
        }
        let rest = Array(providers.dropFirst())
        loadImageData(from: provider) { [weak self] data in
            guard let self = self else { return }
            var next = loaded
            if let data = data {
                next.append(data)
            }
            self.loadImages(rest, loaded: next, completion: completion)
        }
    }

    private func loadImageData(from provider: NSItemProvider, completion: @escaping (Data?) -> Void) {
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ShareViewController: Error loading image: \(error)")
                    #endif
                    completion(nil)
                    return
                }

                if let url = item as? URL {
                    do {
                        completion(try Data(contentsOf: url))
                    } catch {
                        #if DEBUG
                        print("ShareViewController: Error reading image data: \(error)")
                        #endif
                        completion(nil)
                    }
                } else if let image = item as? UIImage {
                    completion(image.jpegData(compressionQuality: 0.9))
                } else if let data = item as? Data {
                    completion(data)
                } else {
                    completion(nil)
                }
            }
        }
    }

    private func loadPDFData(from provider: NSItemProvider, completion: @escaping (Data?) -> Void) {
        provider.loadItem(forTypeIdentifier: UTType.pdf.identifier, options: nil) { item, error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("ShareViewController: Error loading PDF: \(error)")
                    #endif
                    completion(nil)
                    return
                }
                if let url = item as? URL {
                    do {
                        completion(try Data(contentsOf: url))
                    } catch {
                        #if DEBUG
                        print("ShareViewController: Error reading PDF data: \(error)")
                        #endif
                        completion(nil)
                    }
                } else if let data = item as? Data {
                    completion(data)
                } else {
                    completion(nil)
                }
            }
        }
    }

    /// Un PDF suelto, sin tanda: la app lo reconoce por la extensión y lo trocea (`ImageSelectionView.readSharedFile`).
    private func savePDFToSharedContainer(_ data: Data) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            completeWithError()
            return
        }
        let pendingImagesURL = containerURL.appendingPathComponent("PendingImages", isDirectory: true)
        let finalURL = pendingImagesURL.appendingPathComponent("\(UUID().uuidString).pdf")
        let partialURL = pendingImagesURL.appendingPathComponent(finalURL.lastPathComponent + SharedImageBatch.partialSuffix)
        do {
            try FileManager.default.createDirectory(at: pendingImagesURL, withIntermediateDirectories: true)
            try data.write(to: partialURL)
            try FileManager.default.moveItem(at: partialURL, to: finalURL)
            completeSuccessfully()
        } catch {
            #if DEBUG
            print("ShareViewController: Error saving PDF: \(error)")
            #endif
            removeLeftovers([partialURL])
            completeWithError()
        }
    }

    private func saveBatchToSharedContainer(_ images: [Data], sharedCount: Int) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            completeWithError()
            return
        }

        let pendingImagesURL = containerURL.appendingPathComponent("PendingImages", isDirectory: true)
        let batchID = SharedImageBatch.newBatchID()
        var written: [(partial: URL, final: URL)] = []

        do {
            try FileManager.default.createDirectory(at: pendingImagesURL, withIntermediateDirectories: true)

            for (index, data) in images.enumerated() {
                let name = SharedImageBatch.fileName(batchID: batchID, index: index, sharedCount: sharedCount)
                let finalURL = pendingImagesURL.appendingPathComponent(name)
                let partialURL = pendingImagesURL.appendingPathComponent(name + SharedImageBatch.partialSuffix)
                try data.write(to: partialURL)
                written.append((partialURL, finalURL))
            }
            for file in written {
                try FileManager.default.moveItem(at: file.partial, to: file.final)
            }

            completeSuccessfully()
        } catch {
            #if DEBUG
            print("ShareViewController: Error saving images: \(error)")
            #endif
            removeLeftovers(written.map(\.partial))
            completeWithError()
        }
    }

    /// Lo que quedó a medio escribir tras un fallo. Lo ya renombrado se queda: la app lo lee como una tanda más corta.
    private func removeLeftovers(_ partials: [URL]) {
        for url in partials where FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                #if DEBUG
                print("ShareViewController: Error removing partial file: \(error)")
                #endif
            }
        }
    }

    private func completeSuccessfully() {
        // Open the main app using dynamic URL scheme
        if let url = URL(string: "\(urlScheme)://shared-image") {
            var responder: UIResponder? = self
            while responder != nil {
                if let application = responder as? UIApplication {
                    application.open(url, options: [:], completionHandler: nil)
                    break
                }
                responder = responder?.next
            }
        }

        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func completeWithError() {
        extensionContext?.cancelRequest(withError: NSError(domain: "YalaShare", code: 1, userInfo: nil))
    }
}
