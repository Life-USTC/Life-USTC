//
//  CAS.swift
//  USTC-API
//
//  Created by Tiankai Ma on 2023/6/27.
//
import OpenAPIURLSession

public struct USTC_CAS_Client {
    public init() {}

    public func getGreeting(name _: String?) async throws -> String {
        let client = Client(
            serverURL: try Servers.server1(),
            transport: URLSessionTransport()
        )
        let response = try await client.post_login(.init(query: .init()))
        switch response {
        case let .ok(okResponse):
            switch okResponse.body {
            case let .json(greeting): return greeting.message
            }
        case let .badRequest(badResponse):
            switch badResponse.body {
            case let .json(response): return response.message
            }
        case let .undocumented(statusCode: statusCode, _):
            return "🙉 \(statusCode)"
        case .unauthorized: return ""
        case .forbidden: return ""
        case .internalServerError: return ""
        }
    }
}
