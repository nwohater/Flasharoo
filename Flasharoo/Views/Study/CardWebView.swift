//
//  CardWebView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  WKWebView wrapper that renders card HTML (including MathJax / LaTeX).
//  A single WKWebView instance is reused across card flips — HTML is
//  replaced via loadHTMLString rather than creating a new view each time.
//

import SwiftUI
import WebKit

struct CardWebView: UIViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "heightReported")

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.setURLSchemeHandler(AssetURLSchemeHandler(), forURLScheme: "asset")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload when HTML actually changes to avoid flicker
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var lastHTML: String = ""

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "heightReported",
                  let raw = message.body as? NSNumber
            else { return }

            let height = CGFloat(raw.doubleValue)
            // Height is reported on the WKWebView's internal thread — marshal to main
            DispatchQueue.main.async { [weak self] in
                _ = self  // capture coordinator to keep it alive
            }
            // Post back via the binding on the next runloop tick
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .cardWebViewHeightChanged,
                    object: nil,
                    userInfo: ["height": height]
                )
            }
        }
    }
}

extension Notification.Name {
    static let cardWebViewHeightChanged = Notification.Name("cardWebViewHeightChanged")
}
