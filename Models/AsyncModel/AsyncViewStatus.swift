//
//  AsyncViewStatus.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/23.
//

import Foundation

/// Instruct how the view should appear to user
enum AsyncViewStatus {
    case inProgress
    case cached // In between process from .inProgress -> .sucess. In this stage, the cached data is good to be rendered, just not up-to-date and would be replaced by other status
    case success

    // In ADD, you should always pass a placeholder
    case failure(String?) // if a out-of-date data is available, use this
    case lethalFailure(String?) // if no data is available, use this

    var canShowData: Bool {
        switch self {
        case .inProgress:
            return false
        case .success:
            return true
        case .failure:
            return true
        case .lethalFailure:
            return false
        case .cached:
            return true
        }
    }

    var isRefreshing: Bool {
        switch self {
        case .inProgress:
            return true
        case .success:
            return false
        case .failure:
            return false
        case .lethalFailure:
            return false
        case .cached:
            return true
        }
    }

    var hasError: Bool {
        switch self {
        case .inProgress:
            return false
        case .success:
            return false
        case .failure:
            return true
        case .lethalFailure:
            return true
        case .cached:
            return false
        }
    }

    var errorMessage: String {
        switch self {
        case .inProgress:
            return ""
        case .success:
            return ""
        case let .failure(string):
            return string ?? ""
        case let .lethalFailure(string):
            return string ?? ""
        case .cached:
            return ""
        }
    }
}
