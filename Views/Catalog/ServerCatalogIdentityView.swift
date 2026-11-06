import SwiftUI

/// Semantic field order is shared by compact rows and detail headers.
/// Keep actions outside the identity so browsing never implies a subscription.
enum ServerCatalogIdentityProminence: Equatable {
    case row, detail

    var titleFont: Font { self == .detail ? .title2.bold() : .headline }
}

struct ServerCourseIdentityView: View {
    let code: String
    let name: String
    var prominence: ServerCatalogIdentityProminence = .row

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(code)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("Course code") + Text(": ") + Text(code))
            Text(name)
                .font(prominence.titleFont)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(prominence == .detail ? [.isHeader] : [])
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ServerSectionIdentityView: View {
    let courseName: String?
    let teachers: [String]
    let code: String
    let semester: String?
    var prominence: ServerCatalogIdentityProminence = .row

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(courseName ?? code)
                .font(courseName == nil ? prominence.titleFont.monospaced() : prominence.titleFont)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(prominence == .detail ? [.isHeader] : [])
            if !teachers.isEmpty {
                Text(teachers.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if courseName != nil {
                Text(code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Section code") + Text(": ") + Text(code))
            }
            if let semester {
                Text(semester)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Semester") + Text(": ") + Text(semester))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Course and section identity") {
    List {
        Section("Course") {
            ServerCourseIdentityView(code: "COMP6001P", name: "计算机视觉 / Computer Vision")
            ServerCourseIdentityView(code: "COMP6001P", name: "计算机视觉 / Computer Vision", prominence: .detail)
        }
        Section("Teaching section") {
            ServerSectionIdentityView(courseName: "计算机视觉 / Computer Vision", teachers: ["张老师", "Professor Wang"],
                                      code: "COMP6001P.01", semester: "2026年秋季学期")
            ServerSectionIdentityView(courseName: "计算机视觉 / Computer Vision", teachers: ["张老师", "Professor Wang"],
                                      code: "COMP6001P.01", semester: "2026年秋季学期", prominence: .detail)
        }
        Section("Missing optional context") {
            ServerSectionIdentityView(courseName: nil, teachers: [], code: "COMP6001P.02", semester: nil)
        }
    }
}
