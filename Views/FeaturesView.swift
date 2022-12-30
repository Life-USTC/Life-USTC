//
//  Features.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct USTCWebFeatures: Identifiable {
    var id = UUID()
    var name: String
    var image: String
    var description: String
    var url: URL
}

let listOfUSTCWebFeatures: [USTCWebFeatures] =
    [.init(name: "教务系统(本科)",
           image: "person.2",
           description: "本科生教务系统",
           url: URL(string: "https://jw.ustc.edu.cn/ucas-sso/login")!.ustcCASLoginMarkup()),
     .init(name: "公共查询",
           image: "doc.text.magnifyingglass",
           description: "查询教室使用情况",
           url: URL(string: "https://catalog.ustc.edu.cn/query/classroom")!),
     .init(name: "网络通服务",
           image: "globe.asia.australia",
           description: "申请/修改网络通、重置密码",
           url: URL(string: "https://zczx.ustc.edu.cn/caslogin")!.ustcCASLoginMarkup()),
     .init(name: "大物预约选课平台",
           image: "chart.xyaxis.line",
           description: "预约/查看物理实验课程",
           url: URL(string: "http://pems.ustc.edu.cn/index.php/web/login/loginCas.html")!.ustcCASLoginMarkup()),
     .init(name: "中区教室预约",
           image: "clock.badge.checkmark",
           description: "预约中区研讨室/青年之家会议室",
           url: URL(string: "http://roombooking.cmet.ustc.edu.cn/api/cas/index")!.ustcCASLoginMarkup()),
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

struct ListLabelView: View {
    var image: String
    var title: String
    var subTitle: String

    var body: some View {
        HStack {
            Image(systemName: image)
                .frame(width: 30)
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            if subTitle.isEmpty {
                Text(title)
                    .bold()
            } else {
                TitleAndSubTitle(title: title, subTitle: subTitle, style: .substring)
            }
            Spacer()
        }
    }
}

struct FeaturesView: View {
    @State var searchText = ""

    func featureListView(_ featureList: [USTCWebFeatures]) -> some View {
        ForEach(featureList, id: \.id) { feature in
            NavigationLink(destination: Browser(url: feature.url, title: feature.name)) {
                ListLabelView(image: feature.image, title: feature.name, subTitle: feature.description)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: AllSourceView()) {
                        ListLabelView(image: "doc.richtext", title: "Feed", subTitle: "")
                    }

                    ForEach(defaultFeedSources, id: \.id) { feedSource in
                        NavigationLink(destination: FeedSourceView(feedSource: feedSource)) {
                            ListLabelView(image: feedSource.image ?? "doc.richtext", title: feedSource.name, subTitle: feedSource.description ?? "")
                        }
                    }
                } header: {
                    Text("Feed")
                }

                Section {
                    NavigationLink(destination: CurriculumView()) {
                        ListLabelView(image: "book", title: "Curriculum", subTitle: "")
                    }
                } header: {
                    Text("UG AAS")
                }

                Section {
                    featureListView(listOfUSTCWebFeatures)
                } header: {
                    Text("Web")
                }
            }
            .navigationTitle("Features")
//            .searchable(text: $searchText,placement: .navigationBarDrawer(displayMode: .always))
        }
    }
}
