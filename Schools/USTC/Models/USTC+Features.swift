//
//  USTC+Features.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/7/9.
//

import SwiftUI

extension FeatureWithView {
    init(
        name: LocalizedStringKey,
        image: String,
        description: LocalizedStringKey,
        url: String,
        markUp: Bool = false
    ) {
        let finalURL: URL
        if markUp {
            finalURL = URL(string: url)!.ustcCASLoginMarkup()
        } else {
            finalURL = URL(string: url)!
        }

        self.init(
            image: image,
            title: name,
            subTitle: description,
            destinationView: {
                Browser(url: finalURL, title: name)
            }
        )
    }
}

extension USTCExports {
    var ustcPublicFeatures: [FeatureWithView] {
        [
            .init(
                image: "bus",
                title: "Bus Timetable",
                subTitle: "",
                destinationView: { USTC_SchoolBusView() }
            ),
            .init(
                name: "Teaching Secretary",
                image: "mail.stack",
                description: "教学秘书联系方式",
                url: "https://www.teach.ustc.edu.cn/service/svc-student/4427.html",
            ),
            .init(
                name: "Public Query",
                image: "doc.text.magnifyingglass",
                description: "查询教室使用情况",
                url: "https://catalog.ustc.edu.cn/query/classroom"
            ),
            .init(
                name: "Calendar",
                image: "calendar",
                description: "教学日历",
                url: "https://www.teach.ustc.edu.cn/calendar/",
            ),
        ]
    }

    var ustcAASFeatures: [FeatureWithView] {
        [
            .init(
                image: "rectangle.stack",
                title: "Homework (BB)",
                subTitle: "",
                destinationView: { HomeworkDetailView() }
            ),
            {
                switch ustcStudentType {
                case .undergraduate:
                    return FeatureWithView(
                        name: "AAS",
                        image: "person.2",
                        description: "本科生教务系统",
                        url: "https://jw.ustc.edu.cn/ucas-sso/login",
                        markUp: true
                    )
                case .graduate:
                    return FeatureWithView(
                        name: "Graduate AAS",
                        image: "person.2",
                        description: "研究生教务系统",
                        url: "http://yjs1.ustc.edu.cn/gsapp/sys/yjsemaphome/portal/index.do",
                        markUp: true
                    )
                }
            }(),
            .init(
                name: "Course Selection Result",
                image: "list.clipboard",
                description: "选课结果",
                url: "https://app.ustc.edu.cn/site/timeTableQuery/index",
            ),
            .init(
                name: "Hanhai Platform",
                image: "books.vertical",
                description: "本科教育提升计划 - 网络课程平台",
                url: "http://course.ustc.edu.cn/sso/ustc",
                markUp: true
            ),
            .init(
                name: "Teaching Quality Management Platform",
                image: "chart.bar.xaxis",
                description: "教学质量管理平台",
                url: "https://tqm.ustc.edu.cn/wx?universitycode=10358&sourcefrom=qywx",
            ),
        ]
    }

    var ustcMeetingRoomFeatures: [FeatureWithView] {
        [
            .init(
                name: "Meeting Room Appointment for Central Campus",
                image: "building.columns",
                description: "预约中区研讨室/青年之家会议室",
                url: "http://roombooking.cmet.ustc.edu.cn/api/cas/index",
                markUp: true
            ),
            .init(
                name: "Meeting Room Appointment for West Campus",
                image: "building.2",
                description: "西区未来学习中心",
                url: "http://ic.lib.ustc.edu.cn/"
            ),
            .init(
                name: "Meeting Room Appointment for Gaoxin Campus",
                image: "building.fill",
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
        ]
    }

    var ustcWebFeatures: [FeatureWithView] {
        [
            .init(
                name: "Visitor Entry",
                image: "person.badge.key",
                description: "亲友入校",
                url: "https://passport.ustc.edu.cn/login?service=http%3A%2F%2Fbwcqyrx.ustc.edu.cn%2Fweixin%2Fvalidate",

            ),
            .init(
                name: "Second Classroom",
                image: "2.circle",
                description: "第二课堂",
                url: "https://young.ustc.edu.cn/login/ustc-h5-product/pages/logtransit/logtransit",
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
                name: "Student Fitness Test",
                image: "figure.strengthtraining.traditional",
                description: "学生体测",
                url: "https://tc.ustc.edu.cn/fitness/login/ustc/loginRedirect",
                markUp: true
            ),
            .init(
                name: "Email",
                image: "envelope",
                description: "科大邮箱",
                url: "https://mail.ustc.edu.cn/coremail/ustc/cas/casCoremailLogin.jsp?device=mobile",

            ),
            .init(
                name: "E-Card",
                image: "creditcard",
                description: "遗失、查询记录、门禁权限等",
                url: "https://ecard.ustc.edu.cn/caslogin",
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
                name: "Library",
                image: "book",
                description: "图书馆",
                url: "https://lib.ustc.edu.cn",
            ),
            .init(
                name: "TA",
                image: "person.3.fill",
                description: "助教管理系统",
                url: "https://tam.cmet.ustc.edu.cn/ustcta-server/ucas-sso/login",
                markUp: true
            ),
            .init(
                name: "Vista",
                image: "globe.asia.australia",
                description: "国际交流",
                url: "https://vista.ustc.edu.cn/",
            ),
            .init(
                name: "Mental Health Education and Counseling Center",
                image: "heart.text.square",
                description: "微笑在线",
                url: "https://smile.ustc.edu.cn",
            ),
            .init(
                name: "Work-integrated Learning",
                image: "desktopcomputer",
                description: "奖学金、助学金、勤工助学等",
                url: "https://xgyth.ustc.edu.cn/usp/index.aspx",
                markUp: true
            ),
            .init(
                name: "Course Rating",
                image: "person.fill.questionmark",
                description: "评课社区",
                url: "https://icourse.club",
            ),
        ]
    }
}
