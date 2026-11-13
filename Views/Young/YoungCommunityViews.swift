//
//  YoungCommunityViews.swift
//  Life@USTC
//
//  Native Second Classroom entry point.
//

import SwiftUI

struct YoungCommunityView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    YoungEventsListView()
                } label: {
                    Label("Activities", systemImage: "figure.run")
                }
                .accessibilityIdentifier("activities_list")
                NavigationLink {
                    YoungActivityCalendarView()
                } label: {
                    Label("Activity Calendar", systemImage: "calendar")
                }
                .accessibilityIdentifier("activities_calendar")
                NavigationLink {
                    YoungOrganizersListView()
                } label: {
                    Label("Organizers", systemImage: "person.3")
                }
                .accessibilityIdentifier("activities_organizers")
            } header: {
                Text("Second Classroom")
            } footer: {
                Text("Browse activities from young.ustc.edu.cn. Registration is completed on the official site.")
            }

        }
        .navigationTitle("Activities")
        .accountToolbar()
    }
}
