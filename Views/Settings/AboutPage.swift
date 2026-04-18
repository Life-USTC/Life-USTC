//
//  AboutPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

struct AboutPage: View {
    @AppStorage("productionDebugEnabled") private var debugEnabled = false

    /// Rolling window of tap timestamps for 5-tap detection.
    @State private var tapTimestamps: [Date] = []
    @State private var showDebugAlert = false

    @State var contributorList: [(name: String, avatar: URL?)] = [
        (
            "tiankaima",
            URL(string: "https://avatars.githubusercontent.com/u/91816094?v=4")
        ),
        (
            "odeinjul",
            URL(string: "https://avatars.githubusercontent.com/u/42104346?v=4")
        ),
    ]

    var authorListView: some View {
        VStack {
            Text("Authors")
                .font(.system(.title2, design: .monospaced, weight: .semibold))

            VStack(alignment: .leading) {
                ForEach(contributorList, id: \.name) { contributor in
                    HStack {
                        AsyncImage(url: contributor.avatar) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 30, maxHeight: 30)
                                .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                        }

                        Text(contributor.name)
                            .fontWeight(.medium)
                            .font(.title3)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack {
            Spacer()

            ZStack(alignment: .topTrailing) {
                Image("Icon")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 2)
                    .onTapGesture {
                        handleLogoTap()
                    }
                    .accessibilityIdentifier("about_app_logo")

                if debugEnabled {
                    Image(systemName: "ladybug.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .offset(x: 6, y: -6)
                }
            }

            Text("Life@USTC")
                .font(.system(.title, weight: .bold))
            Text(Bundle.main.versionDescription)
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.secondary)

            if debugEnabled {
                Text("Debug Mode")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
            }

            Spacer()
                .frame(height: 50)

            authorListView

            Spacer()
        }
        .padding()
        .navigationTitle("About Life@USTC")
        .alert("Debug Mode", isPresented: $showDebugAlert) {
            Button("OK") {}
            if debugEnabled {
                Button("Disable", role: .destructive) {
                    debugEnabled = false
                }
            }
        } message: {
            Text(debugEnabled
                 ? "Production debug mode is now enabled. Debug logs and advanced settings are accessible."
                 : "Production debug mode has been disabled.")
        }
    }

    private func handleLogoTap() {
        let now = Date()
        // Keep only taps within the last 3 seconds
        tapTimestamps = tapTimestamps.filter { now.timeIntervalSince($0) < 3.0 }
        tapTimestamps.append(now)

        if tapTimestamps.count >= 5 && !debugEnabled {
            tapTimestamps.removeAll()
            debugEnabled = true
            showDebugAlert = true

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
