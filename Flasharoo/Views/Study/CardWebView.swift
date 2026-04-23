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

// Shared coordinator — WKScriptMessageHandler is cross-platform.
final class CardWebViewCoordinator: NSObject, WKScriptMessageHandler {
    var lastHTML: String = ""

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "heightReported",
              let raw = message.body as? NSNumber
        else { return }

        let height = CGFloat(raw.doubleValue)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .cardWebViewHeightChanged,
                object: nil,
                userInfo: ["height": height]
            )
        }
    }
}

#if os(iOS)
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
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
    }

    func makeCoordinator() -> CardWebViewCoordinator { CardWebViewCoordinator() }
}
#else
struct CardWebView: NSViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "heightReported")

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.setURLSchemeHandler(AssetURLSchemeHandler(), forURLScheme: "asset")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
    }

    func makeCoordinator() -> CardWebViewCoordinator { CardWebViewCoordinator() }
}
#endif

extension Notification.Name {
    static let cardWebViewHeightChanged = Notification.Name("cardWebViewHeightChanged")
}
