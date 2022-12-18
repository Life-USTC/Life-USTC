//
//  Features.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

protocol Feature: Identifiable {
    var id: UUID { get }
    var name: String { get }
    var image: String? { get }
    var description: String { get }
    
    var url: URL { get }
}

struct USTCFeatures: Feature, Identifiable {
    var id = UUID()
    var name: String
    var image: String?
    var description: String
    var url: URL
}

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

let listOfUSTCFeatures: [USTCFeatures] =
[.init(name: "教务系统",
       image: "person.2",
       description: "本科生教务系统",
       url: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup()),
 .init(name: "公共查询",
       image: "doc.text.magnifyingglass",
       description: "查询教室使用情况",
       url: URL(string: "https://catalog.ustc.edu.cn/query/classroom")!),
 .init(name: "一卡通",
       image: "creditcard",
       description: "遗失、查询记录、门禁权限等",
       url: URL(string: "https://ecard.ustc.edu.cn/caslogin")!.ustcCASLoginMarkup()),
 .init(name: "学工一体化",
       image: "desktopcomputer",
       description: "奖学金、助学金、勤工助学等",
       url: URL(string: "https://xgyth.ustc.edu.cn/usp/index.aspx")!.ustcCASLoginMarkup()),
 .init(name: "瀚海教学网",
       image: "books.vertical",
       description: "本科教育提升计划-网络课程平台",
       url: URL(string: "http://course.ustc.edu.cn/sso/ustc")!.ustcCASLoginMarkup())]

let allFeatures: [String:[any Feature]] =
["ustc.edu.cn": listOfUSTCFeatures]

struct FeaturesView: View {
    @State var searchText = ""
    
    func featureListView(_ featureList: [any Feature]) -> some View {
        ForEach(featureList, id:\.id) { feature in
            NavigationLink(destination: Browser(url: feature.url,title: feature.name)) {
                HStack {
                    Image(systemName: feature.image!)
                        .frame(width: 30)
                        .foregroundColor(.accentColor)
                        .symbolRenderingMode(.hierarchical)
                    TitleAndSubTitle(title: feature.name, subTitle: feature.description, style: .substring)
                    Spacer()
                }
            }
        }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(allFeatures.sorted(by: {$0.key.hashValue < $1.key.hashValue}), id: \.key) { key, featureList in
                    Section {
                        featureListView(featureList)
                    } header: {
                        Text(key)
                    }
                }
            }
            .navigationTitle("Features")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {

                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
//            .searchable(text: $searchText,placement: .navigationBarDrawer(displayMode: .always))
        }
    }
}
