//
//  ColorExtension.swift
//  Life@USTC
//
//  Created by GitHub Copilot
//

import Oklch
import SwiftUI

extension Color {
    /// Generate a consistent color from a string using Oklch color space
    /// - Parameter seed: The string to hash for color generation
    /// - Returns: A Color with consistent lightness and chroma, varying hue based on the seed
    static func fromSeed(_ seed: String) -> Color {
        // Use djb2 hash algorithm for consistent hash values across runs
        var hash: UInt32 = 5381
        for char in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt32(char)
        }

        let hue = Double(hash % 360)
        return Color(oklch: .init(lightness: 0.85, chroma: 0.1, hue: .degrees(hue)))
    }
}
