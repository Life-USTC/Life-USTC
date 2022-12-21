//
//  ContentView.swift
//  Shared
//
//  Created by TiankaiMa on 2022/12/14.
//

import SwiftUI
import SwiftyJSON


// main entry point, edit this when we need documentGroup or something like that...
// keep it unchanged before an iPad version is planned, which I have no idea how to implment that, especially UI
@main
struct Life_USTCApp: App {
    var body: some Scene {
        WindowGroup {
#if DEBUG1
            UstcUgTableView()
#else
            ContentView()
#endif
        }
    }
}

struct ContentView: View {
    // these four variables are used to deterime which sheet is required tp prompot to the user.
#if DEBUG
    @State var casLoginSheet: Bool = true
    @State var firstLogin: Bool = true
#else
    @State var casLoginSheet: Bool = false
    @AppStorage("firstLogin") var firstLogin: Bool = true
#endif
    
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
        .sheet(isPresented: $firstLogin) {
            UserTypeView(userTypeSheet: $firstLogin)
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $casLoginSheet) {
            CASLoginView(casLoginSheet: $casLoginSheet, title: "One more step...", displayMode: .large, isInSheet: true)
                .interactiveDismissDisabled(true)
        }
        .onAppear(perform: onLoadFunction)
    }
    
    func onLoadFunction() {
        loadPostCache()
        loadMainUser()
#if DEBUG
        let task = Task {
            //        DispatchQueue.main.async {
            await testFunction()
            //        }
        }
#endif
    }
    
#if DEBUG
// DO NOT PACK THESE FUNCTION INTO FINAL PRODUCT.
     func testFunction() async {
        var a = UstcCasClient(username: passportUsername, password: passportPassword)
        let result = a.loginToCAS()
        
        if result {
            print("Logged In")
            
            let session = URLSession(configuration: .default)
            if let cookies = a.casCookie {
                session.configuration.httpCookieStorage?.setCookies(cookies, for: ustcLoginUrl, mainDocumentURL: ustcLoginUrl)
            }
            // jw.ustc.edu.cn login.
            let request = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup())
            let newRequest = URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table")!)
            do {
                let (_, _) = try await session.data(for: request)
                let (_, response) = try await session.data(for: newRequest)
                
                let match = response.url?.absoluteString.matches(of: try! Regex(#"\d+"#))
                var tableID: String = "0"
                if let match {
                    if !match.isEmpty {
                        tableID = String(match.first!.0)
                    }
                }
                
                let (data, _) = try await session.data(for: URLRequest(url: URL(string: "https://jw.ustc.edu.cn/for-std/course-table/semester/281/print-data/\(tableID)?weekIndex=")!))
                
//                if let dataString = String(data: data, encoding: .utf8) {
//                    print(dataString)
//                }
                
                let json = try JSON(data: data)
                let id = json["studentTableVm"]["activities"][0]["lessonId"].stringValue
                print(id)
                
            } catch {
                print(error)
            }
        }
    }
#endif
}
