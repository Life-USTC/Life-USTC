//
//  AutoUpdateDelegate.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import Foundation

/// Delegate to update a given file from URL, and store it locally in the app's document directory
/// also provides method to retrive data from local file, asynchronizely
class AutoUpdateDelegate {
    var name: String
    var remoteURL: URL
    var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }

    init(name: String, remoteURL: URL) {
        self.name = name
        self.remoteURL = remoteURL
    }

    func update() async throws {
        print("network<\(name)>: updating from url \(remoteURL)")
        let data = try await URLSession.shared.data(from: remoteURL)
        try data.0.write(to: localURL)
    }

    func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: localURL.path)
    }

    func retrive() async throws -> Data {
        if isAvailable() {
            print("network<\(name)>: local cache found, using it")
            return try Data(contentsOf: localURL)
        } else {
            print("network<\(name)>: local cache not found, updating")
            try await update()
            return try await retrive()
        }
    }

    func retriveLocal() throws -> Data? {
        if isAvailable() {
            print("network<\(name)>: local cache found, using it")
            return try Data(contentsOf: localURL)
        } else {
            print("network<\(name)>: local cache not found, updating for next time")
            Task {
                try? await update()
            }
            return nil
        }
    }
}

extension AutoUpdateDelegate {
    static var feedList: AutoUpdateDelegate = .init(name: FeedSource.localFeedJSONName,
                                                    remoteURL: FeedSource.remoteURL)

    static var allFiles: [AutoUpdateDelegate] {
        [feedList]
    }

    static func updateAll() async throws {
        for file in allFiles {
            try await file.update()
        }
    }
}
