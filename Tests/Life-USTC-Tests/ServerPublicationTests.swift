import XCTest
@testable import Life_USTC

final class ServerPublicationTests: XCTestCase {
    private var client: ServerClient!
    private let timestamp = "2026-10-23T10:30:00+08:00"

    override func setUp() {
        MockURLProtocol.reset()
        client = ServerClient(configuration: .init(
            baseURL: URL(string: "https://publications.example")!,
            session: MockURLProtocol.mockSession(), tokenStore: MockTokenStore()
        ))
    }

    override func tearDown() {
        MockURLProtocol.reset()
        client = nil
    }

    func testDefaultPublicListUsesBoundedPageAndDoesNotOptIntoFolding() async throws {
        MockURLProtocol.stubJSON(page([item("first")]))
        let result = try await client.fetchPublications()
        XCTAssertEqual(result.data.first?.revision.title, "Campus news")
        XCTAssertNil(result.data.first?.foldGroup)
        XCTAssertNil(result.data.first?.revision.publishedAt)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.path, "/api/publications")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(query(request), ["page": "1", "pageSize": "20"])
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testPublicationFacetsUseDocumentedCombinedSourceAndOrganizationFilters() async throws {
        MockURLProtocol.stubJSON(page([item("folded", siblingCount: 2)], page: 3, totalPages: 4))
        let result = try await client.fetchPublications(filters: .init(
            type: .notice, sources: ["ustc-news", "student-office"], organizationLevels: [.office, .student],
            query: "  lecture + 中文 & notes  ", fold: true
        ), page: 3, pageSize: 50)
        XCTAssertEqual(result.data.first?.foldGroup?.siblingCount, 2)
        XCTAssertEqual(query(try XCTUnwrap(MockURLProtocol.capturedRequests.first)), [
            "type": "notice", "source": "ustc-news,student-office", "organizationLevel": "office,student",
            "query": "lecture + 中文 & notes", "fold": "1", "page": "3", "pageSize": "50"
        ])
    }

    func testServerDocumentedSearchSourceAndPageLimitsRejectInvalidRequests() async throws {
        let cases: [(ServerPublicationFilters, Int, Int)] = [
            (.init(), 0, 20), (.init(), 1, 51), (.init(), 100_001, 20),
            (.init(query: String(repeating: "😀", count: 101)), 1, 20),
            (.init(sources: (0..<21).map { "source-\($0)" }), 1, 20)
        ]
        for (filters, page, pageSize) in cases {
            do {
                _ = try await client.fetchPublications(filters: filters, page: page, pageSize: pageSize)
                XCTFail("The documented publication request limit must be respected")
            } catch ServerError.badRequest { }
        }
        XCTAssertTrue(MockURLProtocol.capturedRequests.isEmpty)
        MockURLProtocol.stubJSON(page([]))
        _ = try await client.fetchPublications(filters: .init(query: String(repeating: "😀", count: 100)))
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
    }

    func testDetailPreservesMarkdownImagesAttachmentsAttributionAndSiblingSources() async throws {
        MockURLProtocol.stubJSON(detail())
        let value = try await client.fetchPublication(id: "article")
        XCTAssertEqual(value.revision.bodyMarkdown, "# Heading\n\n**Verified article**")
        XCTAssertEqual(value.renderedBodyHtml, "<h1>Heading</h1><p><strong>Verified article</strong></p>")
        XCTAssertEqual(value.revision.bodyText, "Plain text must not replace the Markdown body")
        XCTAssertEqual(value.revision.author, "Author")
        XCTAssertEqual(value.revision.images?.first?.caption, "Photo caption")
        XCTAssertEqual(value.revision.images?.first?.url, "/api/publications/images/\(publicationHash)")
        XCTAssertEqual(value.revision.objects?.first?.kind, .asset)
        XCTAssertEqual(value.revision.objects?.first?.filename, "notice.pdf")
        XCTAssertEqual(value.revision.objects?.first?.size, 1234)
        XCTAssertEqual(value.alsoPublishedIn.first?.source.id, "student-office")
        XCTAssertNil(value.alsoPublishedIn.first?.publishedAt)
        XCTAssertEqual(MockURLProtocol.capturedRequests.first?.url?.path, "/api/publications/article")
    }

    func testMissingMarkdownStaysUnknownEvenWhenPlainTextExists() async throws {
        MockURLProtocol.stubJSON(detail(markdown: nil))
        let value = try await client.fetchPublication(id: "article")
        XCTAssertNil(value.revision.bodyMarkdown)
        XCTAssertEqual(value.renderedBodyHtml, "")
        XCTAssertEqual(value.revision.bodyText, "Plain text must not replace the Markdown body")
        XCTAssertNotNil(value.revision.sourcePageUrl)
    }

    func testSourceDirectoryIsUnpaginatedAndPreservesCountsAndUnknownSourceLevels() async throws {
        MockURLProtocol.stubJSON(directory())
        let value = try await client.fetchPublicationSources()
        XCTAssertEqual(value.totals.sourceCount, 1)
        XCTAssertEqual(value.totals.publicationCount, 8)
        XCTAssertEqual(value.groups.first?.knownOrganizationLevel, .office)
        XCTAssertEqual(value.groups.first?.sources.first?.hosts, ["office.ustc.edu.cn"])
        XCTAssertEqual(value.groups.first?.sources.first?.publicationCount, 8)
        let request = try XCTUnwrap(MockURLProtocol.capturedRequests.first)
        XCTAssertEqual(request.url?.path, "/api/publications/sources")
        XCTAssertTrue(query(request).isEmpty)
        var unknown = item("future")
        unknown["source"] = ["id": "future-source", "name": "Future source", "organizationLevel": "new-level"]
        MockURLProtocol.stubJSON(page([unknown]))
        let future = try await client.fetchPublications()
        XCTAssertEqual(future.data.first?.source.organizationLevel, "new-level")
        XCTAssertEqual(future.data.first?.source.knownOrganizationLevel, .unknown)
    }

    func testUnavailablePublicationBodyAndMissingPublicationRemainReadErrors() async throws {
        MockURLProtocol.stubJSON(["error": "Publication body storage unavailable"], statusCode: 503)
        do {
            _ = try await client.fetchPublication(id: "article")
            XCTFail("Unavailable body storage must not become an empty article")
        } catch ServerError.serverError { }
        MockURLProtocol.stubJSON(["error": "Publication not found"], statusCode: 404)
        do {
            _ = try await client.fetchPublication(id: "missing")
            XCTFail("Missing articles must remain distinct from empty bodies")
        } catch ServerError.notFound { }
    }

    @MainActor
    func testLoadMoreFailureRetainsReadArticlesAndRetriesTheSamePage() async {
        let model = ServerPublicationsModel(client: client)
        MockURLProtocol.stubJSON(page([item("first")], totalPages: 2))
        await model.load()
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.loadMore()
        XCTAssertEqual(model.publications.map(\.id), ["first"])
        XCTAssertEqual(model.pagination?.page, 1)
        XCTAssertNotNil(model.error)
        MockURLProtocol.stubJSON(page([item("second")], page: 2, totalPages: 2))
        await model.retry()
        XCTAssertEqual(model.publications.map(\.id), ["first", "second"])
        XCTAssertFalse(model.hasMore)
        XCTAssertNil(model.error)
        XCTAssertEqual(MockURLProtocol.capturedRequests.map { query($0)["page"] }, ["1", "2", "2"])
    }

    @MainActor
    func testFailedFirstPageRefreshRetriesRefreshEvenWhenCachedListHasMorePages() async {
        let model = ServerPublicationsModel(client: client)
        MockURLProtocol.stubJSON(page([item("previous")], totalPages: 2))
        await model.load()
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await model.load()
        XCTAssertEqual(model.publications.map(\.id), ["previous"])
        XCTAssertTrue(model.hasMore)
        MockURLProtocol.stubJSON(page([item("current")], totalPages: 2))
        await model.retry()
        XCTAssertEqual(model.publications.map(\.id), ["current"])
        XCTAssertEqual(MockURLProtocol.capturedRequests.map { query($0)["page"] }, ["1", "1", "1"])
    }

    @MainActor
    func testChangingFiltersHidesPreviousResultsAndRestartsPagination() async {
        let model = ServerPublicationsModel(client: client)
        MockURLProtocol.stubJSON(page([item("news")], totalPages: 2))
        await model.load()
        model.filters.type = .notice
        XCTAssertTrue(model.publications.isEmpty)
        XCTAssertNil(model.pagination)
        XCTAssertFalse(model.hasMore)
        MockURLProtocol.stubJSON(page([item("notice")]))
        await model.load()
        XCTAssertEqual(model.publications.map(\.id), ["notice"])
        XCTAssertEqual(query(MockURLProtocol.capturedRequests.last!)["page"], "1")
        XCTAssertEqual(query(MockURLProtocol.capturedRequests.last!)["type"], "notice")
    }

    @MainActor
    func testDetailAndDirectoryRetainCanonicalContentAfterFailedRefresh() async {
        let detailModel = ServerPublicationDetailModel(id: "article", client: client)
        let directoryModel = ServerPublicationSourcesModel(client: client)
        MockURLProtocol.stubJSON(detail())
        await detailModel.load()
        MockURLProtocol.stubJSON(directory())
        await directoryModel.load()
        MockURLProtocol.stubJSON(["error": "Unavailable"], statusCode: 503)
        await detailModel.load()
        await directoryModel.load()
        XCTAssertEqual(detailModel.publication?.revision.bodyMarkdown, "# Heading\n\n**Verified article**")
        XCTAssertNotNil(detailModel.error)
        XCTAssertEqual(directoryModel.directory?.totals.publicationCount, 8)
        XCTAssertNotNil(directoryModel.error)
    }

    private var publicationHash: String { String(repeating: "a", count: 64) }

    private func source(_ id: String = "ustc-news") -> [String: Any] {
        ["id": id, "name": id == "ustc-news" ? "USTC News" : "Student Office", "organizationLevel": "university"]
    }

    private func revision() -> [String: Any] {
        ["id": "revision", "revisionHash": publicationHash, "observedAt": timestamp, "title": "Campus news",
         "author": "Author", "publishedAt": NSNull(), "sourcePageUrl": "https://news.ustc.edu.cn/article"]
    }

    private func item(_ id: String, siblingCount: Int? = nil) -> [String: Any] {
        var value: [String: Any] = ["id": id, "canonicalUrl": "https://news.ustc.edu.cn/\(id)",
                                    "publicationType": "news", "source": source(), "revision": revision(), "objects": []]
        if let siblingCount { value["foldGroup"] = ["siblingCount": siblingCount] }
        return value
    }

    private func detail(markdown: String? = "# Heading\n\n**Verified article**") -> [String: Any] {
        var body = revision()
        body["bodyMarkdown"] = markdown as Any? ?? NSNull()
        body["bodyText"] = "Plain text must not replace the Markdown body"
        body["images"] = [["id": publicationHash, "url": "/api/publications/images/\(publicationHash)", "caption": "Photo caption"]]
        body["objects"] = [["kind": "asset", "sha256": publicationHash, "size": 1234, "contentType": "application/pdf",
                              "status": "verified", "url": "/api/publications/objects/asset/\(publicationHash)", "filename": "notice.pdf"]]
        return ["id": "article", "canonicalUrl": "https://news.ustc.edu.cn/article", "publicationType": "news",
                "source": source(), "revision": body,
                "renderedBodyHtml": markdown == nil ? "" : "<h1>Heading</h1><p><strong>Verified article</strong></p>",
                "alsoPublishedIn": [["id": "sibling", "canonicalUrl": "https://office.ustc.edu.cn/article",
                                      "source": source("student-office"), "publishedAt": NSNull()]]]
    }

    private func directory() -> [String: Any] {
        ["groups": [["organizationLevel": "office", "sourceCount": 1, "publicationCount": 8,
                     "sources": [["id": "student-office", "name": "Student Office", "organizationLevel": "office",
                                  "hosts": ["office.ustc.edu.cn"], "publicationCount": 8, "lastPublishedAt": timestamp]]]],
         "totals": ["sourceCount": 1, "publicationCount": 8]]
    }

    private func page(_ data: [[String: Any]], page: Int = 1, totalPages: Int = 1) -> [String: Any] {
        ["data": data, "pagination": ["page": page, "pageSize": 20, "total": data.count * totalPages,
                                      "totalPages": totalPages]]
    }

    private func query(_ request: URLRequest) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .map { ($0.name, $0.value ?? "") })
    }
}
