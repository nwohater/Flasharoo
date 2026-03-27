//
//  AssetURLSchemeHandler.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Resolves asset://{assetID} URLs in WKWebView to local media files.
//  Card HTML embeds drawings and images as <img src="asset://{assetID}">.
//

import Foundation
import WebKit
import UniformTypeIdentifiers

final class AssetURLSchemeHandler: NSObject, WKURLSchemeHandler {

    private let mediaBase: URL

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

            guard let fileURL = self.findFile(for: assetID),
                  let data    = try? Data(contentsOf: fileURL)
            else {
                urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                return
            }

            let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
                       ?? "application/octet-stream"
            let response = URLResponse(
                url: url,
                mimeType: mime,
                expectedContentLength: data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    // MARK: - File lookup

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
