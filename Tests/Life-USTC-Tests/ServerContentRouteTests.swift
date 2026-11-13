import XCTest
@testable import Life_USTC

final class ServerContentRouteTests: XCTestCase {
    private let base = URL(string: "https://life.example")!

    func testSupportedPublicAndWorkspaceDestinationsRoundTrip() {
        let routes: [ServerContentRoute] = [
            .course(1001), .section(42), .teacher(3), .youngEvent("event-1"),
            .organizer("organizer-1"), .comment("comment-1"), .publicProfile("student"),
            .publication("publication-1"), .publicationSources, .todos, .homeworks, .exams, .calendar,
        ]
        for route in routes {
            XCTAssertEqual(ServerContentRoute(url: route.url(baseURL: base), baseURL: base), route)
        }
        XCTAssertEqual(Set(routes).count, routes.count)
        XCTAssertNotEqual(ServerContentRoute.course(42), .section(42))
    }

    func testCustomSchemeUsesTheSameNativeSectionIdentity() {
        let url = URL(string: "dev.tiankaima.life-ustc://catalog/sections/42")!
        XCTAssertEqual(ServerContentRoute(url: url, baseURL: base), .section(42))
    }

    func testOAuthCallbackAndWebsiteOnlyPagesStayOutsideContentRouting() {
        for raw in [
            "dev.tiankaima.life-ustc://auth/callback?code=test-code&state=test-state",
            "https://life.example/account/settings/security",
            "https://life.example/admin", "https://life.example/search?q=course",
            "https://life.example/community/comments/guide",
            "https://life.example/catalog/sections/42/comments",
            "https://life.example/api/catalog/links/resolve?slug=academic",
        ] {
            XCTAssertNil(ServerContentRoute(url: URL(string: raw)!, baseURL: base), raw)
        }
    }

    func testOtherBackendAndInvalidCatalogIdentifiersDoNotOpenCurrentBackendObjects() {
        XCTAssertNil(ServerContentRoute(url: URL(string: "https://another.example/catalog/sections/42")!, baseURL: base))
        XCTAssertNil(ServerContentRoute(url: URL(string: "https://life.example/catalog/sections/0")!, baseURL: base))
        XCTAssertNil(ServerContentRoute(url: URL(string: "https://life.example/catalog/courses/missing")!, baseURL: base))
    }

    func testWebHandoffsPreserveSearchTextAndCanonicalLinkSlug() {
        let search = ServerWebLinks.workspaceSearch("作业 & calendar", baseURL: base)
        XCTAssertEqual(search.path, "/search")
        XCTAssertEqual(URLComponents(url: search, resolvingAgainstBaseURL: false)?.queryItems,
                       [.init(name: "q", value: "作业 & calendar")])
        let link = ServerWebLinks.campusLink("academic", baseURL: base)
        XCTAssertEqual(link.path, "/api/catalog/links/resolve")
        XCTAssertEqual(URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems,
                       [.init(name: "slug", value: "academic")])
    }

    func testPrimaryOwnersRetainPublicPrivateAndPersonalCalendarBoundaries() {
        let groups: [(ServerContentRoute.PrimaryDestination, [ServerContentRoute])] = [
            (.workspace, [.workspace, .todos, .homeworks, .exams, .subscriptions,
                          .activitySubscriptions, .organizerFollows, .notifications]),
            (.calendar, [.calendar]),
            (.campus, [.campus, .catalog, .course(1001), .section(42), .teacher(3),
                       .comment("comment-1"), .publicProfile("student"), .publication("news-1"), .publicationSources]),
            (.activities, [.activities, .activityCalendar, .organizers, .youngEvent("event-1"), .organizer("organizer-1")]),
        ]
        for (owner, routes) in groups {
            for route in routes {
                XCTAssertEqual(route.primaryDestination, owner)
                XCTAssertEqual(ContentViewTab(primaryDestination: owner).rawValue,
                               [ServerContentRoute.PrimaryDestination.workspace: 1, .calendar: 2, .campus: 3, .activities: 4][owner])
            }
        }
    }

    func testNewNativeRootsAndActivityViewsRoundTripWithoutDuplicatePrimarySheets() {
        let routes: [ServerContentRoute] = [.workspace, .campus, .catalog, .activities,
            .activityCalendar, .organizers, .subscriptions, .activitySubscriptions, .organizerFollows, .notifications]
        for route in routes {
            XCTAssertEqual(ServerContentRoute(url: route.url(baseURL: base), baseURL: base), route)
        }
        XCTAssertEqual(Set(routes.map(\.id)).count, routes.count)
        XCTAssertEqual(ServerContentRoute(url: base, baseURL: base), .workspace)
        // Existing personal-calendar query parsing is unchanged; this does not
        // claim that native calendar state now consumes these parameters.
        XCTAssertEqual(ServerContentRoute(url: URL(string: "https://life.example/workspace/calendar?view=week#today")!, baseURL: base), .calendar)
        for route in [ServerContentRoute.workspace, .campus, .activities, .calendar] {
            XCTAssertTrue(route.opensPrimaryRoot)
        }
        for route in [ServerContentRoute.activityCalendar, .subscriptions, .notifications, .course(1001)] {
            XCTAssertFalse(route.opensPrimaryRoot)
        }
    }

    func testNewRootFiltersDatesFragmentsAndUnknownViewsKeepWebsiteFallback() {
        for path in ["/?q=course", "/#section", "/campus?q=course", "/workspace?view=notifications", "/workspace#section", "/catalog?search=course",
                     "/catalog/young-events?active=true", "/catalog/young-events#section", "/catalog/young-events/calendar?month=2026-10",
                     "/catalog/young-events/organizers?search=student", "/workspace/subscriptions?view=notifications",
                     "/workspace/subscriptions/activities?view", "/workspace/subscriptions/activities?view=", "/workspace/subscriptions/activities?view=unknown", "/workspace/subscriptions/activities?view=notifications&unread=true",
                     "/workspace/subscriptions/activities?view=events&view=notifications", "/campus#section"] {
            XCTAssertNil(ServerContentRoute(url: URL(string: "https://life.example" + path)!, baseURL: base), path)
        }
        XCTAssertNil(ServerContentRoute(url: URL(string: "https://foreign.example/campus")!, baseURL: base))
        XCTAssertNil(ServerContentRoute(url: URL(string: "dev.tiankaima.life-ustc://auth/campus")!, baseURL: base))
    }

}
