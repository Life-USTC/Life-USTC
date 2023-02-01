//
//  FeaturesView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import Reeeed
import SwiftUI

struct FeaturesView: View {
    @State var searchText = ""
    var ustcFeatures: [String: [FeatureWithView]] {
        var results: [String: [FeatureWithView]] = [:]

        var tmp: [FeatureWithView] = []
        tmp.append(.init(image: "doc.richtext", title: "Feed", subTitle: "", destinationView: AllSourceView()))
        for feedSource in FeedSource.allToShow {
            tmp.append(.init(feedSource))
        }
        results["Feed"] = tmp

        tmp = [.init(image: "doc.text.magnifyingglass", title: "Classroom Status", subTitle: "", destinationView: ClassroomView())]
        results["Public"] = tmp

        tmp = [.init(image: "book", title: "Curriculum", subTitle: "", destinationView: CurriculumView()),
               .init(image: "calendar.badge.clock", title: "Exam", subTitle: "", destinationView: ExamView()),
               .init(image: "graduationcap", title: "Score", subTitle: "", destinationView: ScoreView())]
        results["UG AAS"] = tmp

        tmp = []
        for ustcWebFeature in FeaturesView.ustcWebFeatures {
            tmp.append(.init(ustcWebFeature))
        }
        results["Web"] = tmp

        return results
    }

    var ustcWebFeaturesSearched: [String: [FeatureWithView]] {
        if searchText.isEmpty {
            return ustcFeatures
        } else {
            var result: [String: [FeatureWithView]] = [:]
            for (key, value) in ustcFeatures {
                let tmp = value.filter {
                    $0.title.contains(searchText) ||
                        $0.subTitle.contains(searchText) ||
                        NSLocalizedString($0.title, comment: "").contains(searchText) ||
                        NSLocalizedString($0.subTitle, comment: "").contains(searchText)
                }
                if !tmp.isEmpty {
                    result[key] = tmp
                }
            }
            return result
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(ustcWebFeaturesSearched.sorted(by: { $0.value.count < $1.value.count }), id: \.key) { key, features in
                    Section {
                        ForEach(features) { feature in
                            NavigationLinkAddon {
                                feature.destinationView
                            } label: {
                                ListLabelView(image: feature.image,
                                              title: feature.title.localized,
                                              subTitle: feature.subTitle.localized)
                            }
                        }
                    } header: {
                        Text(key.localized)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Features")
            .scrollContentBackground(.hidden)
#if os(iOS)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
#endif
        }
    }
}

extension FeaturesView {
    struct FeatureWithView: Identifiable {
        var id = UUID()
        var image: String
        var title: String
        var subTitle: String
        var destinationView: AnyView

        init(image: String, title: String, subTitle: String, destinationView: any View) {
            self.image = image
            self.title = title
            self.subTitle = subTitle
            self.destinationView = .init(destinationView)
        }

        init(_ feedSource: FeedSource) {
            image = feedSource.image ?? "doc.richtext"
            title = feedSource.name
            subTitle = feedSource.description ?? ""
            destinationView = .init(FeedSourceView(feedSource: feedSource))
        }

        init(_ ustcWebFeature: USTCWebFeature) {
            image = ustcWebFeature.image
            title = ustcWebFeature.name
            subTitle = ustcWebFeature.description
            destinationView = .init(Browser(url: ustcWebFeature.url, title: ustcWebFeature.name))
        }
    }

    struct USTCWebFeature: Identifiable {
        var id = UUID()
        var name: String
        var image: String
        var description: String
        var url: URL

        init(id: UUID = UUID(), name: String, image: String, description: String, url: URL) {
            self.id = id
            self.name = name
            self.image = image
            self.description = description
            self.url = url
        }

        init(id: UUID = UUID(), name: String, image: String, description: String, url: String, markUp: Bool = false) {
            self.id = id
            self.name = name
            self.image = image
            self.description = description
            if markUp {
                self.url = URL(string: url)!.ustcCASLoginMarkup()
            } else {
                self.url = URL(string: url)!
            }
        }
    }

    static let ustcWebFeatures: [USTCWebFeature] =
        [.init(name: "教务系统(本科)",
               image: "person.2",
               description: "本科生教务系统",
               url: "https://jw.ustc.edu.cn/ucas-sso/login",
               markUp: true),
         .init(name: "公共查询",
               image: "doc.text.magnifyingglass",
               description: "查询教室使用情况",
               url: "https://catalog.ustc.edu.cn/query/classroom"),
         .init(name: "网络通服务",
               image: "globe.asia.australia",
               description: "申请/修改网络通、重置密码",
               url: "https://zczx.ustc.edu.cn/caslogin",
               markUp: true),
         .init(name: "大物预约选课平台",
               image: "chart.xyaxis.line",
               description: "预约/查看物理实验课程",
               url: "http://pems.ustc.edu.cn/index.php/web/login/loginCas.html",
               markUp: true),
         .init(name: "中区教室预约",
               image: "clock.badge.checkmark",
               description: "预约中区研讨室/青年之家会议室",
               url: "http://roombooking.cmet.ustc.edu.cn/api/cas/index",
               markUp: true),
         .init(name: "一卡通",
               image: "creditcard",
               description: "遗失、查询记录、门禁权限等",
               url: "https://ecard.ustc.edu.cn/caslogin",
               markUp: true),
         .init(name: "学工一体化",
               image: "desktopcomputer",
               description: "奖学金、助学金、勤工助学等",
               url: "https://xgyth.ustc.edu.cn/usp/index.aspx",
               markUp: true),
         .init(name: "瀚海教学网",
               image: "books.vertical",
               description: "本科教育提升计划-网络课程平台",
               url: "http://course.ustc.edu.cn/sso/ustc",
               markUp: true)]
}

struct FeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        FeaturesView()
    }
}
