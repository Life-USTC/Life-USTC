//
//  UstcCAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Foundation

let ustcLoginUrl = URL(string: "https://passport.ustc.edu.cn/login")!
let findLtStringRegex = try! Regex("LT-[0-9a-z]+")

extension URL {
    func CASLoginMarkup(casServer: URL) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "service", value: components.url!.absoluteString)]
        return URL(string: "\(casServer)/login?service=\(components.url!.absoluteString)")!
    }

    func ustcCASLoginMarkup() -> URL {
        return CASLoginMarkup(casServer: URL(string: "https://passport.ustc.edu.cn")!)
    }
}

struct UstcCasClient {
    var username: String
    var password: String
    
    init(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    var casCookie: [HTTPCookie]? = nil
    var lastLogined: Date? = nil
    
    var verified: Bool {
        if casCookie == nil {
            return false
        }
        if lastLogined == nil {
            return false
        }
        if (lastLogined! + DateComponents(minute: 15) > Date()) {
            return true
        }
        return false
    }
    
    mutating func vaildCookie() -> [HTTPCookie] {
        if verified {
            return casCookie!
//        } else if self.loginToCAS() {
//            return casCookie!
        } else {
            return []
        }
    }
    
    mutating func update(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    
    mutating func getLtTokenFromCAS() async throws -> String {
        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(from: ustcLoginUrl)
        if let dataString = String(data: data, encoding: .utf8) {
            let match = dataString.firstMatch(of: findLtStringRegex)
            if match == nil {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
            }
            
            let ltToken = String(match!.0)
            let httpRes: HTTPURLResponse = (response as? HTTPURLResponse)!
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpRes.allHeaderFields as! [String: String], for: httpRes.url!)
            print(cookies)
            self.casCookie = cookies
            return ltToken
        }
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
    }
    
    /// Call this function before using casCookie
    mutating func loginToCAS() async -> Bool {
        if verified {
            // already verified, returns before double checking.
            // if we do need double checking (try the Cookie somewhere else, call `verifyToken()`)
            return true
        }
        do {
            let session = URLSession(configuration: .default)
            let ltToken = try await getLtTokenFromCAS()
            let dataString = "model=uplogin.jsp&CAS_LT=\(ltToken)&service=&warn=&showCode=&qrcode=&username=\(self.username)&password=\(self.password)&LT=&button="
            var request = URLRequest(url: ustcLoginUrl)
            request.httpMethod = "POST"
            request.httpBody = dataString.data(using: .utf8)
            request.httpShouldHandleCookies = true
            if let casCookie {
                session.configuration.httpCookieStorage?.setCookies(casCookie, for: ustcLoginUrl, mainDocumentURL: ustcLoginUrl)
            }
            var cookies: [HTTPCookie]? = []
            _ = try await session.data(for: request)
            cookies = session.configuration.httpCookieStorage?.cookies
            self.casCookie = cookies
            lastLogined = .now
            return self.casCookie?.contains(where: {$0.name == "logins"}) ?? false
        } catch {
            print(error)
            return false
        }
    }
        
    func checkLogined() -> Bool {
//        if !verified {
//            return false
//        }
        
        // TODO: communicate with CAS server to check if cookie is valid, return true for now
//        return false
        return true
    }
}

