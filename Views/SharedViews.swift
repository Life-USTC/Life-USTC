//
//  SharedViews.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/7.
//

import SwiftUI

var SharedScoreView: some View {
    ScoreView(scoreDeleage: USTCScoreDelegate.shared)
}
