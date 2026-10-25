import XCTest
@testable import Life_USTC

final class SubscriptionImportTests: XCTestCase {
    private var client: ServerClient!
    private var tokens: MockTokenStore!

    override func setUp() {
        MockURLProtocol.reset()
        tokens = MockTokenStore()
        tokens.accessToken = "subscription-owner"
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://subscriptions.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: tokens
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
        tokens = nil
    }

    func testPastedCodeExtractionMatchesServerExamples() {
        XCTAssertEqual(ServerSubscriptionCodeParser.extractCodes(
            from: "MATH101 MATH.01 math.01 CS_A-2.03 cs-a_2 MATH.01"
        ), ["MATH101", "MATH.01", "math.01", "CS_A-2.03", "cs-a_2"])
        let prose = (0..<520).map { "word\($0)" }.joined(separator: " ")
        XCTAssertEqual(ServerSubscriptionCodeParser.extractCodes(
            from: "Paste \(prose) 2026-06-01 09.30 MATH101 001013.01 math_01 cs-a_2 DEV-CS201.01 math_01"
        ), ["MATH101", "001013.01", "math_01", "cs-a_2", "DEV-CS201.01"])
        XCTAssertEqual(ServerSubscriptionCodeParser.extractCodes(
            from: "Use COMP3001.01. Numeric example: 001013.01. \(String(repeating: "A", count: 65))"
        ), ["COMP3001.01", "001013.01"])
    }

    func testPreviewUsesSelectedSemesterAndDecodesMatchesAndSuggestions() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/workspace/subscriptions/query")
            XCTAssertEqual(request.url?.query, "locale=en-us")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer subscription-owner")
            let body = try self.body(request)
            XCTAssertEqual(body["codes"] as? [String], ["math101", "UNKNOWN.01"])
            XCTAssertEqual(body["semesterId"] as? Int, 2)
            XCTAssertNil(body["sectionIds"])
            return try self.response(request, self.previewBody())
        }
        let result = try await client.querySubscriptionCodes(
            codes: ["math101", "UNKNOWN.01"], semesterID: 2, locale: "en-us", expectedRevision: client.sessionRevision
        )
        XCTAssertEqual(result.semester?.id, 2)
        XCTAssertEqual(result.sections.map(\.id), [7, 8, 9])
        XCTAssertEqual(result.sections.map(\.jwId), [42, 43, 44])
        XCTAssertEqual(result.matchedCodes, ["math101"])
        XCTAssertEqual(result.unmatchedCodes, ["UNKNOWN.01"])
        XCTAssertEqual(result.suggestions["UNKNOWN.01"], ["MATH101.01"])
    }

    @MainActor
    func testLoadUsesCatalogSemestersAndPreviewExcludesExistingMembership() async throws {
        let model = await loadedModel()
        XCTAssertEqual(model.semesters.map(\.id), [1, 2])
        XCTAssertEqual(model.semesterID, 2)
        XCTAssertEqual(model.subscribedKinds, [8: .teachingAssistant])
        model.input = "MATH101 UNKNOWN.01"
        MockURLProtocol.stubJSON(previewBody())
        await model.match(locale: "en-us")
        XCTAssertEqual(model.selectedSectionIDs, [7, 9])
        XCTAssertTrue(model.canImport)
        model.toggleSelection(8)
        model.toggleSelection(42)
        XCTAssertEqual(model.selectedSectionIDs, [7, 9], "Existing IDs and university IDs cannot enter the selection")
        model.toggleSelection(9)
        XCTAssertEqual(model.selectedSectionIDs, [7])
        XCTAssertTrue(MockURLProtocol.capturedRequests.allSatisfy { $0.url?.path != "/api/workspace/subscriptions/batch" })
    }

    @MainActor
    func testEmptyAndOversizedDraftsDoNotSendPreviewAnd500CodesAreAllowed() async {
        let model = await loadedModel()
        MockURLProtocol.reset()
        model.input = "No course codes here"
        await model.match(locale: "en-us")
        XCTAssertNotNil(model.inputError)
        model.input = (1...501).map { "MATH101.\($0)" }.joined(separator: "\n")
        await model.match(locale: "en-us")
        XCTAssertNotNil(model.inputError)
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        model.input = (1...500).map { "MATH101.\($0)" }.joined(separator: "\n")
        XCTAssertNil(model.inputError)
        MockURLProtocol.stubJSON(previewBody(sections: []))
        await model.match(locale: "en-us")
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        XCTAssertFalse(model.canImport)
    }

    @MainActor
    func testQueryFailurePreservesDraftAndAllowsExplicitRetry() async {
        let model = await loadedModel()
        model.input = "MATH101 UNKNOWN.01"
        MockURLProtocol.stubJSON(["error": "Preview unavailable"], statusCode: 503)
        await model.match(locale: "en-us")
        XCTAssertEqual(model.error, "Preview unavailable")
        XCTAssertEqual(model.input, "MATH101 UNKNOWN.01")
        XCTAssertEqual(model.semesterID, 2)
        XCTAssertEqual(model.subscribedKinds, [8: .teachingAssistant])
        XCTAssertFalse(model.isMatching)
        MockURLProtocol.stubJSON(previewBody(sections: []))
        await model.match(locale: "en-us")
        XCTAssertNotNil(model.preview)
        XCTAssertEqual(model.preview?.unmatchedCodes, ["UNKNOWN.01"])
        XCTAssertNil(model.error)
        XCTAssertFalse(model.canImport)
    }

    @MainActor
    func testSelectedOnlyAppendPreservesConcurrentMembershipAndRoleAfterFailure() async throws {
        let model = await loadedModel()
        model.input = "MATH101 UNKNOWN.01"
        MockURLProtocol.stubJSON(previewBody())
        await model.match(locale: "en-us")
        model.toggleSelection(9)
        MockURLProtocol.stubJSON(["error": "Import unavailable"], statusCode: 503)
        await model.importSelection(locale: "en-us")
        XCTAssertEqual(model.input, "MATH101 UNKNOWN.01")
        XCTAssertEqual(model.selectedSectionIDs, [7])
        XCTAssertEqual(model.subscribedKinds, [8: .teachingAssistant])
        XCTAssertEqual(model.error, "Import unavailable")
        XCTAssertTrue(model.canImport)

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/workspace/subscriptions/batch")
            let body = try self.body(request)
            XCTAssertEqual(body["action"] as? String, "add")
            XCTAssertEqual(body["sectionIds"] as? [Int], [7])
            XCTAssertEqual(Set(body.keys), ["action", "sectionIds"])
            return try self.response(request, [
                "addedCount": 1, "unchangedCount": 0, "unmatchedSectionIds": [],
                "subscription": ["userId": "subscription-owner", "sections": [
                    ["id": 7, "jwId": 42, "code": "MATH101.01", "kind": "regular"],
                    ["id": 8, "jwId": 43, "code": "MATH101.02", "kind": "teaching_assistant"],
                    ["id": 10, "jwId": 45, "code": "PHYS101.01", "kind": "auditor"],
                ]],
            ])
        }
        await model.importSelection(locale: "en-us")
        XCTAssertEqual(model.result?.addedCount, 1)
        XCTAssertEqual(model.subscribedKinds, [7: .regular, 8: .teachingAssistant, 10: .auditor])
        XCTAssertTrue(model.selectedSectionIDs.isEmpty)
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isImporting)
        XCTAssertEqual(MockURLProtocol.capturedRequests.filter { $0.url?.path == "/api/workspace/subscriptions/batch" }.count, 2)
    }

    @MainActor
    func testEditingEitherDraftFieldInvalidatesThePreviousSelection() async {
        let model = await loadedModel()
        model.input = "MATH101"
        MockURLProtocol.stubJSON(previewBody())
        await model.match(locale: "en-us")
        model.input = "PHYS101"
        XCTAssertNil(model.preview)
        XCTAssertTrue(model.selectedSectionIDs.isEmpty)
        await model.importSelection(locale: "en-us")
        await model.match(locale: "en-us")
        XCTAssertNotNil(model.preview)
        model.semesterID = 1
        XCTAssertNil(model.preview)
        await model.importSelection(locale: "en-us")
        XCTAssertFalse(MockURLProtocol.capturedRequests.contains { $0.url?.path == "/api/workspace/subscriptions/batch" })
    }

    @MainActor
    func testSessionChangeHidesPrivatePreviewAndRejectsQueuedRequests() async throws {
        let model = await loadedModel()
        model.input = "MATH101"
        MockURLProtocol.stubJSON(previewBody())
        await model.match(locale: "en-us")
        let formerRevision = client.sessionRevision
        client.clearTokens()
        tokens.accessToken = "replacement-owner"
        MockURLProtocol.reset()
        XCTAssertNil(model.preview)
        XCTAssertTrue(model.subscribedKinds.isEmpty)
        await model.importSelection(locale: "en-us")
        do {
            _ = try await client.querySubscriptionCodes(
                codes: ["MATH101"], semesterID: 2, locale: "en-us", expectedRevision: formerRevision
            )
            XCTFail("An old preview must not read with a replacement account")
        } catch is CancellationError { }
        do {
            _ = try await client.appendMatchedSubscriptions(sectionIDs: [7], locale: "en-us", expectedRevision: formerRevision)
            XCTFail("An old selection must not write with a replacement account")
        } catch is CancellationError { }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        client.clearTokens()
        await model.load()
        XCTAssertEqual(model.input, "")
        XCTAssertNil(model.semesterID)
        XCTAssertTrue(model.selectedSectionIDs.isEmpty)
    }

    @MainActor
    func testEditingDraftDuringMetadataLoadDoesNotLeaveLoadingStuck() async throws {
        let model = deferredModel()
        defer { DeferredSubscriptionImportURLProtocol.reset() }
        let started = expectation(description: "All metadata reads started")
        started.expectedFulfillmentCount = 3
        DeferredSubscriptionImportURLProtocol.onRequest = { _ in started.fulfill() }
        let loading = Task { await model.load() }
        await fulfillment(of: [started], timeout: 2)
        model.input = "MATH101"
        model.semesterID = 1
        for pending in DeferredSubscriptionImportURLProtocol.requests {
            try pending.complete(initialBody(pending.request))
        }
        await loading.value
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.input, "MATH101")
        XCTAssertEqual(model.semesterID, 1)
        XCTAssertTrue(model.canMatch)
    }

    @MainActor
    func testMetadataReloadDoesNotLeaveAnInFlightPreviewStuck() async throws {
        let model = deferredModel()
        defer { DeferredSubscriptionImportURLProtocol.reset() }
        let queryStarted = expectation(description: "Preview started")
        DeferredSubscriptionImportURLProtocol.onRequest = { pending in
            if pending.request.url?.path == "/api/workspace/subscriptions/query" {
                queryStarted.fulfill()
            } else {
                try! pending.complete(self.initialBody(pending.request))
            }
        }
        await model.load()
        model.input = "MATH101"
        let matching = Task { await model.match(locale: "en-us") }
        await fulfillment(of: [queryStarted], timeout: 2)
        await model.load()
        XCTAssertFalse(model.isLoading)
        XCTAssertTrue(model.isMatching)
        let pending = try XCTUnwrap(DeferredSubscriptionImportURLProtocol.requests.first {
            $0.request.url?.path == "/api/workspace/subscriptions/query"
        })
        try pending.complete(previewBody())
        await matching.value
        XCTAssertFalse(model.isMatching)
        XCTAssertNotNil(model.preview)
        XCTAssertTrue(model.canImport)
    }

    @MainActor
    private func deferredModel() -> ServerSubscriptionImportModel {
        DeferredSubscriptionImportURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeferredSubscriptionImportURLProtocol.self]
        let client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://subscriptions.example")!,
            session: URLSession(configuration: configuration), tokenStore: tokens
        ))
        return ServerSubscriptionImportModel(client: client)
    }

    @MainActor
    private func loadedModel() async -> ServerSubscriptionImportModel {
        MockURLProtocol.requestHandler = { request in
            try self.response(request, self.initialBody(request))
        }
        let model = ServerSubscriptionImportModel(client: client)
        await model.load()
        XCTAssertNil(model.error)
        XCTAssertFalse(model.isLoading)
        return model
    }

    private func initialBody(_ request: URLRequest) -> [String: Any] {
        switch request.url?.path {
        case "/api/catalog/semesters":
            return ["data": [semester(1), semester(2)],
                    "pagination": ["page": 1, "pageSize": 100, "total": 2, "totalPages": 1]]
        case "/api/catalog/semesters/current":
            return semester(2)
        default:
            return ["subscription": ["sections": [
                ["id": 8, "jwId": 43, "code": "MATH101.02", "kind": "teaching_assistant"],
            ]]]
        }
    }

    private func semester(_ id: Int) -> [String: Any] {
        ["id": id, "code": "2026-\(id)", "nameCn": "Semester \(id)"]
    }

    private func previewBody(sections ids: [Int] = [7, 8, 9]) -> [String: Any] {
        ["semester": semester(2), "matchedCodes": ["math101"], "unmatchedCodes": ["UNKNOWN.01"],
         "suggestions": ["UNKNOWN.01": ["MATH101.01"]], "total": ids.count,
         "sections": ids.map { id in
             ["id": id, "jwId": id + 35, "code": "MATH101.\(id - 6)", "semester": semester(2),
              "course": ["id": 11, "jwId": 1001, "code": "MATH101", "nameCn": "Calculus"],
              "teachers": [["id": 3, "nameCn": "Teacher"]]]
         }]
    }

    private func response(_ request: URLRequest, _ body: [String: Any]) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
         try JSONSerialization.data(withJSONObject: body))
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty {
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class DeferredSubscriptionImportURLProtocol: URLProtocol {
    @MainActor static var requests: [DeferredSubscriptionImportURLProtocol] = []
    @MainActor static var onRequest: ((DeferredSubscriptionImportURLProtocol) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task { @MainActor in Self.requests.append(self); Self.onRequest?(self) }
    }
    override func stopLoading() {}

    @MainActor
    static func reset() {
        requests = []
        onRequest = nil
    }

    @MainActor
    func complete(_ json: [String: Any]) throws {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: json))
        client?.urlProtocolDidFinishLoading(self)
    }
}
