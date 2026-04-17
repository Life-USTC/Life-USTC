//
//  MockURLProtocol.swift
//  Life-USTC-Tests
//
//  Intercepts URLSession requests for deterministic unit testing.
//

import Foundation

/// A URLProtocol subclass that intercepts requests and returns stubbed responses.
final class MockURLProtocol: URLProtocol {
    /// Map of URL path → (statusCode, responseData, headers).
    /// Set this before running tests.
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Captured requests for assertion.
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequests.append(request)

        guard let handler = Self.requestHandler else {
            let error = NSError(
                domain: "MockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No request handler set"]
            )
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    // MARK: - Helpers

    /// Reset state between tests.
    static func reset() {
        requestHandler = nil
        capturedRequests = []
    }

    /// Create a URLSession configured to use this mock protocol.
    static func mockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Convenience: stub a JSON response for any request.
    static func stubJSON(_ json: Any, statusCode: Int = 200) {
        requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: json)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }
    }

    /// Convenience: stub a raw Data response.
    static func stubData(_ data: Data, statusCode: Int = 200, contentType: String = "application/json") {
        requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": contentType]
            )!
            return (response, data)
        }
    }
}
