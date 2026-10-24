import SwiftUI

struct ServerContentDestination: View {
    let route: ServerContentRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case .course(let id): ServerCourseDetailView(jwId: id)
        case .section(let id): ServerSectionDetailView(jwId: id)
        case .teacher(let id): ServerTeacherDetailView(id: id)
        case .youngEvent(let id): YoungEventDetailView(youngId: id)
        case .organizer(let id): YoungOrganizerDetailView(organizerId: id)
        case .comment(let id): ServerCommentThreadView(commentID: id)
        case .publicProfile(let id): ServerPublicUserProfileView(identifier: id)
        case .publication(let id): ServerPublicationDetailView(id: id)
        case .publicationSources: ServerPublicationSourcesView()
        case .todos: TodoListView()
        case .homeworks: ServerHomeworkListView()
        case .exams: ServerWorkspaceExamsView()
        case .calendar: WorkspaceCalendarView()
        }
    }
}

struct ServerContentShareButton: View {
    let route: ServerContentRoute

    var body: some View {
        ShareLink(item: route.url(baseURL: ServerClient.shared.baseURL)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .accessibilityIdentifier("share_content")
    }
}
