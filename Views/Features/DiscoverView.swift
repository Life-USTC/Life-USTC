import SwiftUI

struct DiscoverView: View {
    var body: some View {
        List {
            Section("Explore") {
                NavigationLink { ServerCampusSearchView() } label: { Label("Search Campus", systemImage: "magnifyingglass") }
                    .accessibilityIdentifier("discover_search")
                NavigationLink { ServerCatalogView() } label: { Label("Course catalog", systemImage: "books.vertical") }
                    .accessibilityIdentifier("discover_catalog")
                NavigationLink { YoungCommunityView() } label: { Label("Second Classroom", systemImage: "figure.run") }
                NavigationLink { ServerPublicationsView() } label: { Label("News and Notices", systemImage: "newspaper") }
                    .accessibilityIdentifier("discover_publications")
            }
            Section("Campus") {
                NavigationLink { ServerCampusLinksView() } label: { Label("Campus Links", systemImage: "link") }
                    .accessibilityIdentifier("discover_links")
                NavigationLink { ServerBusPlannerView() } label: { Label("Bus Timetable", systemImage: "bus") }
                    .accessibilityIdentifier("discover_bus")
                NavigationLink { ServerCampusWeatherView() } label: { Label("Campus Weather", systemImage: "cloud.sun") }
                    .accessibilityIdentifier("discover_weather")
                NavigationLink { ServerRoomMapView() } label: { Label("Room Maps", systemImage: "map") }
                    .accessibilityIdentifier("discover_rooms")
            }
            Section("University services") {
                NavigationLink { AllSourceView() } label: { Label("Feed", systemImage: "newspaper") }
                    .accessibilityIdentifier("discover_feed")
                NavigationLink { FeaturesView() } label: { Label("University services", systemImage: "building.columns") }
                    .accessibilityIdentifier("discover_university")
            }
        }
        .navigationTitle("Discover")
    }
}
