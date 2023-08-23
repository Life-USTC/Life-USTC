//
//  USTC+WebFeatures.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import Foundation

extension USTCExports {
    var ustcWebFeatures: [USTCWebFeature] {
        [.init(
            name: "AAS(UG)",
            image: "person.2",
            description: "本科生教务系统",
            url: "https://jw.ustc.edu.cn/ucas-sso/login",
            markUp: true
        ),
        .init(
            name: "Library Appointment",
            image: "lasso.and.sparkles",
            description: "预约西区/高新区图书馆自习室",
            url: "https://lib.ustc.edu.cn/%e5%9b%be%e4%b9%a6%e9%a6%86%e7%a0%94%e4%bf%ae%e9%97%b4%e9%a2%84%e7%ba%a6%e7%b3%bb%e7%bb%9f/",
            markUp: true
        ),
        .init(
            name: "Meeting Room Appointment",
            image: "clock.badge.checkmark",
            description: "预约中区研讨室/青年之家会议室",
            url: "http://roombooking.cmet.ustc.edu.cn/api/cas/index",
            markUp: true
        ),
        .init(
            name: "Public Query",
            image: "doc.text.magnifyingglass",
            description: "查询教室使用情况",
            url: "https://catalog.ustc.edu.cn/query/classroom"
        ),
        .init(
            name: "E-Card",
            image: "creditcard",
            description: "遗失、查询记录、门禁权限等",
            url: "https://ecard.ustc.edu.cn/caslogin",
            markUp: true
        ),
        .init(
            name: "Physics Experiment",
            image: "chart.xyaxis.line",
            description: "预约/查看物理实验课程",
            url: "http://pems.ustc.edu.cn/index.php/web/login/loginCas.html",
            markUp: true
        ),
        .init(
            name: "Web Service",
            image: "globe.asia.australia",
            description: "申请/修改网络通、重置密码",
            url: "https://zczx.ustc.edu.cn/caslogin",
            markUp: true
        ),
        .init(
            name: "Work-integrated Learning",
            image: "desktopcomputer",
            description: "奖学金、助学金、勤工助学等",
            url: "https://xgyth.ustc.edu.cn/usp/index.aspx",
            markUp: true
        ),
        .init(
            name: "Hanhai Platform",
            image: "books.vertical",
            description: "本科教育提升计划-网络课程平台",
            url: "http://course.ustc.edu.cn/sso/ustc",
            markUp: true
        )]
    }
}

struct USTCWebFeature: Identifiable {
    var id = UUID()
    var name: String
    var image: String
    var description: String
    var url: URL

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

extension FeatureWithView {
    init(_ feature: USTCWebFeature) {
        self.init(
            image: feature.image,
            title: feature.name,
            subTitle: feature.description,
            destinationView: Browser(
                url: feature.url,
                title: feature.name.localized
            )
        )
    }
}
