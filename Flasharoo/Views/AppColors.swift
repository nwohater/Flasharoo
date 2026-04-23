// AppColors.swift — Paper theme design tokens
import SwiftUI

extension Color {
    // Surfaces
    static let paperBg       = Color(hex: "F5F1E8")  // page — warm off-white
    static let paperEl       = Color(hex: "FBF8F1")  // elevated card surface
    static let paperSurface  = Color.white            // pure white card

    // Ink
    static let paperInk      = Color(hex: "2A2418")  // primary text
    static let paperInkMid   = Color(hex: "5B5242")  // secondary text
    static let paperInkMuted = Color(hex: "8A7F6A")  // placeholder/muted

    // Accent — warm ochre/amber
    static let paperAccent     = Color(hex: "B8722C")
    static let paperAccentSoft = Color(hex: "E9D8B8")
    static let paperAccentInk  = Color(hex: "7A4A16")

    // Rating colors (background fills)
    static let ratingAgainBg  = Color(hex: "C05A3E")
    static let ratingHardBg   = Color(hex: "E6C999")
    static let ratingGoodBg   = Color(hex: "A8C495")
    static let ratingEasyBg   = Color(hex: "A8C0D4")

    // Rating ink colors
    static let ratingHardInk  = Color(hex: "5C3A10")
    static let ratingGoodInk  = Color(hex: "2E4A21")
    static let ratingEasyInk  = Color(hex: "1E3A50")

    // Card state colors
    static let stateNew       = Color(hex: "3D7A9A")
    static let stateLearn     = Color(hex: "B8722C")
    static let stateReview    = Color(hex: "5C8A4A")
    static let stateSusp      = Color(hex: "8A7F6A")

    // Adaptive system backgrounds — resolves UIKit on iOS, AppKit on macOS
    #if os(iOS)
    static let adaptiveSecondaryBg  = Color(UIColor.secondarySystemBackground)
    static let adaptiveGroupedBg    = Color(UIColor.systemGroupedBackground)
    static let adaptiveTertiaryFill = Color(UIColor.tertiarySystemFill)
    #else
    static let adaptiveSecondaryBg  = Color(NSColor.windowBackgroundColor)
    static let adaptiveGroupedBg    = Color(NSColor.controlBackgroundColor)
    static let adaptiveTertiaryFill = Color(NSColor.controlColor)
    #endif

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
