import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupIdentifier = "group.com.jurgenschmidt.yala"

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

        var imageFound = false

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    imageFound = true
                    loadImage(from: provider)
                    return
                }
            }
        }

        if !imageFound {
            completeWithError()
        }
    }

    private func loadImage(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] item, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading image: \(error)")
                    self.completeWithError()
                    return
                }

                var imageData: Data?

                if let url = item as? URL {
                    imageData = try? Data(contentsOf: url)
                } else if let image = item as? UIImage {
                    imageData = image.jpegData(compressionQuality: 0.9)
                } else if let data = item as? Data {
                    imageData = data
                }

                guard let data = imageData else {
                    self.completeWithError()
                    return
                }

                self.saveImageToSharedContainer(data)
            }
        }
    }

    private func saveImageToSharedContainer(_ imageData: Data) {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            completeWithError()
            return
        }

        let pendingImagesURL = containerURL.appendingPathComponent("PendingImages", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: pendingImagesURL, withIntermediateDirectories: true)

            let fileName = "\(UUID().uuidString).jpg"
            let fileURL = pendingImagesURL.appendingPathComponent(fileName)

            try imageData.write(to: fileURL)

            completeSuccessfully()
        } catch {
            print("Error saving image: \(error)")
            completeWithError()
        }
    }

    private func completeSuccessfully() {
        // Open the main app
        if let url = URL(string: "yala://shared-image") {
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
