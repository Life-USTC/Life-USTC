import Foundation
import SwiftData
import SwiftUI
import UIKit
import WidgetKit
import XCTest
@testable import Life_USTC

/// Runs on the native iOS simulator. These are actual source views rendered
/// with fixed in-memory fixtures, separately from the end-to-end UI captures.
final class CalendarSundayNativeRenderTests: XCTestCase {
    @MainActor
    func testFixedCalendarViewsRenderNativeBeforeAfterFixtures() throws {
        continueAfterFailure = false
        let configURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "CalendarVisualConfig", withExtension: "json"))
        let config = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as? [String: Any])
        let locale = Locale(identifier: config["locale"] as? String == "zh-Hans" ? "zh_CN" : "en_US")
        let previousZone = NSTimeZone.default
        let previousSchool: School? = SchoolSystem.current
        let previousDemo = UserDefaults.appGroup.object(forKey: "appShouldPresentDemo")
        let previousWeekend = UserDefaults.standard.object(forKey: "HideWeekendinCurriculum")
        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        SchoolSystem.current = USTCSchool.make()
        UserDefaults.appGroup.set(true, forKey: "appShouldPresentDemo")
        UserDefaults.standard.set(false, forKey: "HideWeekendinCurriculum")
        defer {
            NSTimeZone.default = previousZone
            SchoolSystem.current = previousSchool
            if let previousDemo { UserDefaults.appGroup.set(previousDemo, forKey: "appShouldPresentDemo") }
            else { UserDefaults.appGroup.removeObject(forKey: "appShouldPresentDemo") }
            if let previousWeekend { UserDefaults.standard.set(previousWeekend, forKey: "HideWeekendinCurriculum") }
            else { UserDefaults.standard.removeObject(forKey: "HideWeekendinCurriculum") }
        }

        let schema = Schema([Curriculum.self, Semester.self, Course.self, Lecture.self, Exam.self,
                             Homework.self, ScoreSheet.self, ScoreEntry.self, FeedSource.self, Feed.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let curriculum = Curriculum()
        context.insert(curriculum)
        let spring = Semester(jw_id: "visual-spring", name: "Spring fixture", startDate: date("2026-03-02"), endDate: date("2026-07-10"))
        let autumn = Semester(jw_id: "visual-autumn", name: "Autumn fixture", startDate: date("2026-08-31"), endDate: date("2027-01-15"))
        for semester in [spring, autumn] {
            context.insert(semester)
            semester.curriculum = curriculum
        }
        var lectures: [Lecture] = []
        for (index, key) in ["2026-03-01", "2026-03-02", "2026-03-08", "2026-03-09", "2027-01-15", "2027-01-16"].enumerated() {
            let course = Course(jw_id: index + 1, name: "Calendar fixture \(index + 1)", courseCode: "CAL", lessonCode: "CAL.\(index + 1)", teacherName: "Fixture teacher")
            context.insert(course)
            course.semester = key.hasPrefix("2027") ? autumn : spring
            let lecture = Lecture(startDate: date(key + "T08:15:00+08:00"), endDate: date(key + "T09:45:00+08:00"),
                                  name: course.name, location: "Room 101", teacherName: "Fixture teacher", startIndex: 1, endIndex: 2)
            context.insert(lecture)
            lecture.course = course
            lectures.append(lecture)
        }
        try context.save()

        let width = UIScreen.main.bounds.width
        for key in ["2026-03-01", "2026-03-08", "2027-01-16"] {
            let anchor = date(key)
            try render(CurriculumDetailView(referenceDate: anchor).modelContainer(container),
                       name: "legacy-detail-body-\(key)", width: width, height: 600, locale: locale)
            try render(CurriculumWeekViewVerticalNew(lectures: lectures, referenceDate: anchor, hideWeekend: true),
                       name: "legacy-hide-weekend-\(key)", width: width, height: 500, locale: locale)
            // The byte-identical production Widget source is added only to
            // the QA app target. This proves native entry-view rendering,
            // not WidgetKit extension-process/timeline delivery.
            try render(CurriculumWeekWidgetEntryView(entry: CurriculumWeekEntry(), referenceDate: anchor)
                .modelContainer(container).environment(\.widgetFamily, .systemExtraLarge),
                       name: "widget-entry-view-native-render-\(key)", width: width, height: 320, locale: locale)
        }
        var metadata = config
        metadata["hostLocale"] = Locale.current.identifier
        metadata["defaultTimeZone"] = NSTimeZone.default.identifier
        metadata["screenWidth"] = width
        metadata["screenScale"] = UIScreen.main.scale
        metadata["systemVersion"] = UIDevice.current.systemVersion
        metadata["widgetScope"] = "Original entry-view source compiled in QA app target; extension timeline/process not exercised"
        XCTAssertTrue(Locale.current.identifier.hasPrefix(config["locale"] as? String == "zh-Hans" ? "zh" : "en"))
        let provenance = XCTAttachment(data: try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]),
                                       uniformTypeIdentifier: "public.json")
        provenance.name = "native-render-provenance"
        provenance.lifetime = .keepAlways
        add(provenance)
    }

    @MainActor
    private func render<Content: View>(_ content: Content, name: String, width: CGFloat, height: CGFloat, locale: Locale) throws {
        let renderer = ImageRenderer(content: content.frame(width: width, height: height)
            .background(Color(uiColor: .systemBackground)).environment(\.locale, locale))
        renderer.scale = UIScreen.main.scale
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value.count == 10 ? value + "T00:00:00+08:00" : value)!
    }
}
