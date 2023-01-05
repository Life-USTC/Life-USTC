//
//  SwiftExtension.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import Foundation

func doubleForEach<T: Equatable>(_ array: [T], _ function: @escaping (T, T) -> Void) {
    for element in array {
        for secondElement in array {
            if element == secondElement {
                break
            }
            function(element, secondElement)
        }
    }
}
