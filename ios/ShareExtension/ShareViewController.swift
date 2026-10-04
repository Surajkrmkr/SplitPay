import Social
import UniformTypeIdentifiers
import os
import UIKit

final class ShareViewController: SLComposeServiceViewController {
  private let appGroup = "group.com.splitpay.expensetracker"
  private let pendingImagesKey = "pendingSharedImageNames"
  private let maximumImages = 5
  private let maximumImageBytes = 25 * 1024 * 1024
  private let logger = Logger(
    subsystem: "com.splitpay.expensetracker",
    category: "ShareExtension"
  )

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "SplitPay"
    placeholder = "Share a payment screenshot to import it in SplitPay."
  }

  override func isContentValid() -> Bool {
    sharedImageProviders().isEmpty == false
  }

  override func didSelectPost() {
    let providers = Array(sharedImageProviders().prefix(maximumImages))
    guard let directory = sharedImagesDirectory() else {
      logger.error("Could not create shared image cache directory.")
      extensionContext?.cancelRequest(
        withError: NSError(domain: "SplitPayShare", code: 1)
      )
      return
    }

    let group = DispatchGroup()
    let namesLock = NSLock()
    var savedNames: [String] = []
    for provider in providers {
      group.enter()
      let imageType = provider.registeredTypeIdentifiers.first {
        UTType($0)?.conforms(to: .image) == true
      } ?? UTType.image.identifier
      provider.loadFileRepresentation(forTypeIdentifier: imageType) { url, _ in
        defer { group.leave() }
        guard let url,
              let name = self.copyImage(at: url, from: provider, to: directory)
        else {
          return
        }
        namesLock.lock()
        savedNames.append(name)
        namesLock.unlock()
      }
    }

    group.notify(queue: .main) {
      guard !savedNames.isEmpty,
            let defaults = UserDefaults(suiteName: self.appGroup)
      else {
        self.logger.error("No shared images could be staged for the app.")
        self.extensionContext?.cancelRequest(
          withError: NSError(domain: "SplitPayShare", code: 2)
        )
        return
      }
      let pending = defaults.stringArray(forKey: self.pendingImagesKey) ?? []
      defaults.set(pending + savedNames, forKey: self.pendingImagesKey)
      self.logger.info("Staged \(savedNames.count) shared image(s).")
      self.logger.info(
        "Share Extension cannot launch its containing app; pending import is ready."
      )
      self.showSavedConfirmation(imageCount: savedNames.count)
    }
  }

  override func configurationItems() -> [Any]! {
    []
  }

  private func showSavedConfirmation(imageCount: Int) {
    let alert = UIAlertController(
      title: "Ready to import",
      message: imageCount == 1
        ? "Your screenshot is ready. Open SplitPay to review and add the transaction."
        : "\(imageCount) screenshots are ready. Open SplitPay to review and add the transactions.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
      self?.extensionContext?.completeRequest(returningItems: nil)
    })
    present(alert, animated: true)
  }

  private func sharedImageProviders() -> [NSItemProvider] {
    let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    return items.flatMap { $0.attachments ?? [] }.filter { provider in
      provider.registeredTypeIdentifiers.contains {
        UTType($0)?.conforms(to: .image) == true
      }
    }
  }

  private func sharedImagesDirectory() -> URL? {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup
    ) else {
      return nil
    }
    let directory = container
      .appendingPathComponent("Library", isDirectory: true)
      .appendingPathComponent("Caches", isDirectory: true)
      .appendingPathComponent("SplitPaySharedImages", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      return directory
    } catch {
      logger.error("Could not create shared image cache directory.")
      return nil
    }
  }

  private func copyImage(
    at source: URL,
    from provider: NSItemProvider,
    to directory: URL
  ) -> String? {
    guard let values = try? source.resourceValues(forKeys: [.fileSizeKey]),
          let size = values.fileSize,
          size > 0,
          size <= maximumImageBytes
    else {
      logger.warning("Rejected a shared image that was empty or exceeded the size limit.")
      return nil
    }
    let type = provider.registeredTypeIdentifiers
      .compactMap { UTType($0) }
      .first { $0.conforms(to: .image) }
    let fileExtension = type?.preferredFilenameExtension ?? "image"
    let name = "\(UUID().uuidString).\(fileExtension)"
    let destination = directory.appendingPathComponent(name)
    do {
      try FileManager.default.copyItem(at: source, to: destination)
      return name
    } catch {
      logger.error("Could not copy shared image into the App Group cache.")
      return nil
    }
  }
}
