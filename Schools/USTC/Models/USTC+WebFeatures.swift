//
//  USTC+WebFeatures.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

struct USTCWebFeature: Identifiable {
    var id = UUID()
    var name: LocalizedStringKey
    var image: String
    var description: LocalizedStringKey
    var url: URL

    init(
        id: UUID = UUID(),
        name: LocalizedStringKey,
        image: String,
        description: LocalizedStringKey,
        url: String,
        markUp: Bool = false
    ) {
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
            destinationView: {
                Browser(url: feature.url, title: feature.name)
            }
        )
    }
}

extension USTCExports {
    var ustcWebFeatures: [USTCWebFeature] {
        [
            .init(
                name: "AAS",
                image: "person.2",
                description: "本科生教务系统",
                url: "https://jw.ustc.edu.cn/ucas-sso/login",
                markUp: true
            ),
            .init(
                name: "Graduate AAS",
                image: "person.2",
                description: "研究生教务系统",
                url: "http://yjs1.ustc.edu.cn/gsapp/sys/yjsemaphome/portal/index.do",
                markUp: true
            ),
            .init(
                name: "Library",
                image: "book",
                description: "图书馆",
                url: "https://lib.ustc.edu.cn",
                markUp: false
            ),
            // .init(
            //     name: "Library Appointment",
            //     image: "lasso.and.sparkles",
            //     description: "预约西区/高新区图书馆自习室",
            //     url:
            //         "https://lib.ustc.edu.cn/%e5%9b%be%e4%b9%a6%e9%a6%86%e7%a0%94%e4%bf%ae%e9%97%b4%e9%a2%84%e7%ba%a6%e7%b3%bb%e7%bb%9f/",
            //     markUp: false
            // ),
            .init(
                name: "Email",
                image: "mail.stack",
                description: "科大邮箱",
                url: "https://mail.ustc.edu.cn",
                markUp: false
            ),
            .init(
                name: "Teaching Secretary",
                image: "envelope",
                description: "教学秘书联系方式",
                url: "https://www.teach.ustc.edu.cn/service/svc-student/4427.html",
                markUp: false
            ),
            .init(
                name: "Course Rating",
                image: "person.fill.questionmark",
                description: "评课社区",
                url: "https://icourse.club",
                markUp: false
            ),
            .init(
                name: "Calendar",
                image: "calendar",
                description: "教学日历",
                url: "https://www.teach.ustc.edu.cn/calendar/",
                markUp: false
            ),
            .init(
                name: "TA",
                image: "person.3",
                description: "助教管理系统",
                url: "https://ta.cmet.ustc.edu.cn/casLogin.do",
                markUp: true
            ),
            .init(
                name: "Teacher Homepage",
                image: "person.crop.square",
                description: "教师主页",
                url: "https://faculty.ustc.edu.cn/",
                markUp: false
            ),
            .init(
                name: "Vista",
                image: "globe.asia.australia",
                description: "国际交流",
                url: "https://vista.ustc.edu.cn/",
                markUp: false
            ),
            .init(
                name: "Meeting Room Appointment for Central Campus",
                image: "clock.badge.checkmark",
                description: "预约中区研讨室/青年之家会议室",
                url: "http://roombooking.cmet.ustc.edu.cn/api/cas/index",
                markUp: true
            ),
            .init(
                name: "Meeting Room Appointment for West Campus",
                image: "clock.badge.checkmark",
                description: "西区未来学习中心",
                url: "http://ic.lib.ustc.edu.cn/",
            ),
            .init(
                name: "Meeting Room Appointment for Gaoxin Campus",
                image: "clock.badge.checkmark",
                description: "高新校区交流体验中心",
                url: "http://hs.lib.ustc.edu.cn/account/Login",
                markUp: true
            ),
            .init(
                name: "Art Education Center Appointment",
                image: "music.note.list",
                description: "艺术教学中心场馆预约",
                url: "http://roombooking.cmet.ustc.edu.cn/booking/api/cas/index",
                markUp: true
            ),
            .init(
                name: "Mental Health Education and Counseling Center",
                image: "heart.text.square",
                description: "微笑在线",
                url: "https://smile.ustc.edu.cn",
                markUp: false
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
                url:
                    "http://pems.ustc.edu.cn/index.php/web/login/loginCas.html",
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
                description: "本科教育提升计划 - 网络课程平台",
                url: "http://course.ustc.edu.cn/sso/ustc",
                markUp: true
            ),
        ]
    }
}
