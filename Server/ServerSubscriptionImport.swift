import Foundation

struct SubscriptionBatchAddRequest: Encodable {
    let action = "add"
    let sectionIds: [Int]
}

struct ServerSubscriptionQueryResponse: Decodable {
    let semester: MatchedSemester?
    let matchedCodes: [String]
    let unmatchedCodes: [String]
    let suggestions: [String: [String]]
    let sections: [ServerSectionSummary]
    let total: Int
}

struct ServerSubscriptionBatchResponse: Decodable {
    let addedCount: Int
    let unchangedCount: Int
    let unmatchedSectionIds: [Int]
    let subscription: CalendarSubscription?
}

extension ServerClient {
    func querySubscriptionCodes(
        codes: [String], semesterID: Int, locale: String, expectedRevision: UUID
    ) async throws -> ServerSubscriptionQueryResponse {
        try await request(
            .querySubscriptionCodes(MatchCodesRequest(codes: codes, semesterId: semesterID), locale: locale),
            expectedRevision: expectedRevision
        )
    }

    func appendMatchedSubscriptions(
        sectionIDs: [Int], locale: String, expectedRevision: UUID
    ) async throws -> ServerSubscriptionBatchResponse {
        let result: ServerSubscriptionBatchResponse = try await request(
            .appendMatchedSubscriptions(SubscriptionBatchAddRequest(sectionIds: sectionIDs), locale: locale),
            expectedRevision: expectedRevision
        )
        try await MainActor.run {
            try Task.checkCancellation()
            guard expectedRevision == sessionRevision else { throw CancellationError() }
            NotificationCenter.default.post(name: .serverSubscriptionsDidChange, object: nil)
        }
        return result
    }
}

enum ServerSubscriptionCodeParser {
    /// Same pasted-text token rules as server section-code-schema.ts.
    static func extractCodes(from text: String) -> [String] {
        let tokens = try! NSRegularExpression(pattern: "[A-Za-z0-9_.-]+")
        let shapes = [
            #"^(?=[A-Za-z0-9_.-]*[A-Za-z])(?=[A-Za-z0-9_.-]*\d)(?=[A-Za-z0-9_.-]*[_.-])[A-Za-z0-9_.-]+$"#,
            #"^(?=.*[A-Z])(?=(?:.*[A-Za-z]){2})(?=(?:.*\d){2})[A-Za-z0-9]+$"#,
            #"^\d{5,}\.\d{2,}$"#,
        ]
        var seen = Set<String>()
        return tokens.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let code = String(text[range]).replacingOccurrences(of: "[._-]+$", with: "", options: .regularExpression)
            guard code.count <= 64,
                  shapes.contains(where: { code.range(of: $0, options: .regularExpression) != nil }),
                  seen.insert(code).inserted else { return nil }
            return code
        }
    }
}
