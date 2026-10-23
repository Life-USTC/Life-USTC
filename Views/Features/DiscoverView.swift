import SwiftUI

struct DiscoverView: View {
    var body: some View {
        List {
            Section("Explore") {
                NavigationLink {
                    ServerCatalogView()
                } label: {
                    Label("Course catalog", systemImage: "books.vertical")
                }
                .accessibilityIdentifier("discover_catalog")
                NavigationLink {
                    YoungCommunityView()
                } label: {
                    Label("Second Classroom", systemImage: "figure.run")
                }
                NavigationLink {
                    AllSourceView()
                } label: {
                    Label("Feed", systemImage: "newspaper")
                }
                .accessibilityIdentifier("discover_feed")
                NavigationLink {
                    USTCBusView()
                } label: {
                    Label("Bus Timetable", systemImage: "bus")
                }
            }
            Section("University services") {
                NavigationLink {
                    FeaturesView()
                } label: {
                    Label("University services", systemImage: "building.columns")
                }
                .accessibilityIdentifier("discover_university")
            }
        }
        .navigationTitle("Discover")
    }
}
