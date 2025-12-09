//
//  CurriculumDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/24.
//

import EventKit
import SwiftUI
import SwiftyJSON
import WidgetKit

extension USTCSchool {
    static var ustcCurriculumBehavior: CurriculumBehavior {
        return CurriculumBehavior(
            shownTimes: [
                7 * 60 + 50,
                9 * 60 + 45,
                11 * 60 + 20,
                14 * 60 + 0 - 105,
                15 * 60 + 55 - 105,
                17 * 60 + 30 - 105,
                19 * 60 + 30 - 105 - 65,
                21 * 60 + 5 - 105 - 65,
            ],
            highLightTimes: [
                12 * 60 + 10,
                18 * 60 + 20 - 105,
                21 * 60 + 55 - 105 - 65,
            ],
            convertTo: { value in
                value <= 730 ? value : value <= 1100 ? value - 105 : value - 170
            },
            convertFrom: { value in
                value <= 730 ? value : value <= 995 ? value + 105 : value + 170
            }
        )
    }
}
