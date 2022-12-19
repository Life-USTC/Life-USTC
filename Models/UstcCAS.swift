//
//  UstcCAS.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Foundation

protocol CasClient {
    var casCookie: [HTTPCookie]? { get }
    var lastLogined: Date? { get }
    
    mutating func loginToCAS() -> Bool
    mutating func vaildCookie() -> [HTTPCookie]
    mutating func update(username: String, password: String)
    
    func checkLogined() -> Bool
}

let ustcLoginUrl = URL(string: "https://passport.ustc.edu.cn/login")!
struct UstcCasClient: CasClient {
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
        } else if self.loginToCAS() {
            return casCookie!
        } else {
            return []
        }
    }
    
    mutating func update(username: String, password: String) {
        self.username = username
        self.password = password
    }
    
    
    mutating func getLtTokenFromCAS() -> String {
        let session = URLSession(configuration: .default)
        let findLtStringRegex = try! Regex("LT-[0-9a-z]+")
        var ltToken = ""
        let semaphore = DispatchSemaphore(value: 0)
        var cookies: [HTTPCookie] = []
        let task = session.dataTask(with: ustcLoginUrl) { data, response, error in
            if let data = data, let dataString = String(data: data, encoding: .utf8) {
                let match = dataString.firstMatch(of: findLtStringRegex)
                if match == nil {
                    return
                }
                ltToken = String(match!.0)
                let httpRes: HTTPURLResponse = (response as? HTTPURLResponse)!
                cookies = HTTPCookie.cookies(withResponseHeaderFields: httpRes.allHeaderFields as! [String: String], for: httpRes.url!)
                semaphore.signal()
            } else {
                return
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        self.casCookie = cookies
        return ltToken
    }
    
    /// Call this function before using casCookie
    mutating func loginToCAS() -> Bool {
        if verified {
            // already verified, returns before double checking.
            // if we do need double checking (try the Cookie somewhere else, call `verifyToken()`)
            return true
        }
        let session = URLSession(configuration: .default)
        let semaphore = DispatchSemaphore(value: 0)
        let ltToken = getLtTokenFromCAS()
        let dataString = "model=uplogin.jsp&CAS_LT=\(ltToken)&service=&warn=&showCode=&qrcode=&username=\(self.username)&password=\(self.password)&LT=&button="
        var request = URLRequest(url: ustcLoginUrl)
        request.httpMethod = "POST"
        request.httpBody = dataString.data(using: .utf8)
        request.httpShouldHandleCookies = true
        if let casCookie {
            session.configuration.httpCookieStorage?.setCookies(casCookie, for: ustcLoginUrl, mainDocumentURL: ustcLoginUrl)
        }
        var cookies: [HTTPCookie]? = []
        let task = session.dataTask(with: request) { data, response, error in
            cookies = session.configuration.httpCookieStorage?.cookies
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        self.casCookie = cookies
        lastLogined = .now
        return self.casCookie?.contains(where: {$0.name == "logins"}) ?? false
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
