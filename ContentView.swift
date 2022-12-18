//
//  ContentView.swift
//  Shared
//
//  Created by TiankaiMa on 2022/12/14.
//

import SwiftUI


// main entry point, edit this when we need documentGroup or something like that...
// keep it unchanged before an iPad version is planned, which I have no idea how to implment that, especially UI
@main
struct Life_USTCApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
#if DEBUG
    @State var loginSheet: Bool = false
    @State var firstLogin: Bool = false
#else
    @State var loginSheet: Bool = false
    @AppStorage("firstLogin") var firstLogin: Bool = true
#endif
    
    @AppStorage("userType") var userType: UserType?
    @AppStorage("passportUsername") var passportUsername: String = ""
    @AppStorage("passportPassword") var passportPassword: String = ""
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "square.stack.3d.up")
                }
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "doc.richtext")
                }
            FeaturesView()
                .tabItem {
                    Label("Features", systemImage: "square.grid.2x2.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .sheet(isPresented: $firstLogin, content: newUserSheet)
        .sheet(isPresented: $loginSheet) {
            LoginSheet($loginSheet)
        }
        .onAppear(perform: onLoadFunction)
    }
    
    func onLoadFunction() {
        loadPostCache()
        loadMainUser()
#if DEBUG
//        DispatchQueue.main.async {
//            testFunction()
//        }
#endif
    }
    
#if DEBUG
    func testFunction() {
        var a = UstcCasClient(username: passportUsername, password: passportPassword)
        let result = a.loginToCAS()
        
        if result {
            print("Logged In")
            
            let session = URLSession(configuration: .default)
            if let cookies = a.casCookie {
                session.configuration.httpCookieStorage?.setCookies(cookies, for: ustcLoginUrl, mainDocumentURL: ustcLoginUrl)
            }
            let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup())
            
            var cookies: [HTTPCookie]? = []
            let semaphore = DispatchSemaphore(value: 0)
            let task = session.dataTask(with: request) { data, response, error in
                print(data,response,error)
                cookies = session.configuration.httpCookieStorage?.cookies
                semaphore.signal()
            }
            task.resume()
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
//            print(cookies)
            
            let newURL = URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!
            let newSemaphore = DispatchSemaphore(value: 1)
            let newTask = session.dataTask(with: URLRequest(url: newURL)) { data, response, error in
                print(data,response,error)
                if let data = data, let dataStirng = String(data: data, encoding: .utf8) {
                    print(dataStirng)
                }
                newSemaphore.signal()
            }
            newTask.resume()
            _ = newSemaphore.wait(timeout: .distantFuture)
        }
    }
#endif
}
