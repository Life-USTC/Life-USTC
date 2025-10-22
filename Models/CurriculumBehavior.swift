//
//  CurriculumBehavior.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/24.
//

import SwiftUI

/// Configuration for curriculum display behavior
/// Controls which time slots are shown and highlighted, and time conversion functions
struct CurriculumBehavior {
    /// Time slots to show in the curriculum view (e.g., [1, 2, 3, 4, 5])
    var shownTimes: [Int] = []

    /// Time slots to highlight (e.g., current class time)
    var highLightTimes: [Int] = []

    /// Function to convert time slot index for display
    /// Default is identity function { $0 }
    var convertTo: (Int) -> Int = { $0 }

    /// Function to convert from displayed time back to internal representation
    /// Default is identity function { $0 }
    var convertFrom: (Int) -> Int = { $0 }
}
