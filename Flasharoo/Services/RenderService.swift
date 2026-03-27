//
//  RenderService.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/26/26.
//
//  Produces a complete HTML page string for a card side.
//  The WKWebView loads this string with baseURL = Bundle.main.resourceURL
//  so relative paths (card.css, MathJax/) resolve to the app bundle.
//

import Foundation

final class RenderService {
    static let shared = RenderService()

    private let template: String

    private init() {
        if let url = Bundle.main.url(forResource: "card-template", withExtension: "html"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            template = content
        } else {
            template = Self.minimalTemplate
        }
    }

    // MARK: - Public

    /// Returns a full HTML page with the card's front, or front + back when revealed.
    func render(card: Card, revealed: Bool) -> String {
        let content = revealed
            ? "\(card.front)<hr class=\"card-divider\">\(card.back)"
            : card.front
        return template.replacingOccurrences(of: "{{CONTENT}}", with: content)
    }

    /// Returns a full HTML page for arbitrary HTML content (e.g. previews).
    func render(html: String) -> String {
        template.replacingOccurrences(of: "{{CONTENT}}", with: html)
    }

    // MARK: - Fallback (if bundle resource is missing)

    private static let minimalTemplate = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        body { font-family: -apple-system, sans-serif; font-size: 18px;
               padding: 20px; text-align: center; background: transparent; }
        @media (prefers-color-scheme: dark) { body { color: #fff; } }
      </style>
    </head>
    <body><div id="card-content">{{CONTENT}}</div></body>
    </html>
    """
}
