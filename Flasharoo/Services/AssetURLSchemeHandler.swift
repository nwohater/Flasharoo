//
//  AssetURLSchemeHandler.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Resolves asset://{assetID} URLs in WKWebView to local media files.
//  Card HTML embeds drawings and images as <img src="asset://{assetID}">.
//  When the local file is missing (pending CloudKit download), a placeholder image is served.
//

import Foundation
import WebKit
import UniformTypeIdentifiers

final class AssetURLSchemeHandler: NSObject, WKURLSchemeHandler {

    private let mediaBase: URL

    /// A minimal 40×40 gray placeholder PNG (1×1 pixel scaled via CSS).
    /// Generated once at init and reused for all missing-asset responses.
    private let placeholderData: Data = {
        let size = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemGray4.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            // Cloud icon in center
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .light)
            if let icon = UIImage(systemName: "icloud.and.arrow.down", withConfiguration: config) {
                let tinted = icon.withTintColor(.systemGray2, renderingMode: .alwaysOriginal)
                let x = (size.width - tinted.size.width) / 2
                let y = (size.height - tinted.size.height) / 2
                tinted.draw(at: CGPoint(x: x, y: y))
            }
        }
        return image.pngData() ?? Data()
    }()

    override init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        mediaBase = appSupport.appendingPathComponent("media", isDirectory: true)
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url  = urlSchemeTask.request.url,
              url.scheme == "asset"
        else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        // asset://{assetID}  →  host is the UUID string
        let assetID = url.host ?? url.lastPathComponent

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            if let fileURL = self.findFile(for: assetID),
               let data    = try? Data(contentsOf: fileURL) {
                let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                           ?? "application/octet-stream"
                self.respond(to: urlSchemeTask, url: url, data: data, mimeType: mime)
            } else {
                // File not present locally — serve placeholder while CloudKit downloads it
                self.respond(to: urlSchemeTask, url: url,
                             data: self.placeholderData, mimeType: "image/png")
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    // MARK: - Helpers

    private func respond(
        to task: any WKURLSchemeTask,
        url: URL,
        data: Data,
        mimeType: String
    ) {
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: nil
        )
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    private func findFile(for assetID: String) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: mediaBase,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator {
            if fileURL.deletingPathExtension().lastPathComponent == assetID {
                return fileURL
            }
        }
        return nil
    }
}
