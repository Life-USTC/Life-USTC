//
//  FeedSetingsPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftData
import SwiftUI

struct FeedSetingsPage: View {
    @Query(sort: \FeedSource.name, order: .forward) var sourceEntities: [FeedSource]
    @AppStorage("feedSourceNameListToRemove") var removedNameList: [String] = []
    var dismissAction: (() -> Void)? = nil

    var body: some View {
        List {
            Section {
                ForEach(sourceEntities.map(\.name), id: \.self) { name in
                    Button {
                        if removedNameList.contains(name) {
                            removedNameList.removeAll(where: { $0 == name })
                        } else {
                            removedNameList.append(name)
                        }
                    } label: {
                        HStack {
                            Text(name)
                                .foregroundColor(.primary)
                            Spacer()
                            if !removedNameList.contains(name) {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Feed source to show")
                        .textCase(.none)
                }
            } footer: {
                Text("A reload may be required for this to take effect.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        try await Feed.update()
                    }
                } label: {
                    Label("Refresh List", systemImage: "arrow.clockwise")
                }
            }

            // Show Done button only when dismissAction is provided
            if let dismissAction = dismissAction {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismissAction()
                    } label: {
                        Label("Done", systemImage: "xmark")
                    }
                }
            }
        }
        .navigationTitle("Feed Source Settings")
        .task {
            Task {
                try await Feed.update()
            }
        }
    }
}
