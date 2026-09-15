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
                NavigationLink {
                    YoungActivityCalendarView()
                } label: {
                    Label("Activity Calendar", systemImage: "calendar")
                }
                NavigationLink {
                    YoungOrganizersListView()
                } label: {
                    Label("Organizers", systemImage: "person.3")
                }
            } header: {
                Text("Second Classroom")
            } footer: {
                Text("Browse activities from young.ustc.edu.cn. Registration is completed on the official site.")
            }

            Section("Workspace") {
                NavigationLink {
                    WorkspaceCalendarView()
                } label: {
                    Label("My Calendar", systemImage: "calendar.badge.clock")
                }
                NavigationLink {
                    YoungEventSubscriptionsView()
                } label: {
                    Label("My Activities", systemImage: "figure.run.circle")
                }
                NavigationLink {
                    YoungOrganizerSubscriptionsView()
                } label: {
                    Label("Followed Organizers", systemImage: "person.2.circle")
                }
                NavigationLink {
                    YoungNotificationsView()
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
            }
        }
        .navigationTitle("Second Classroom")
    }
}
