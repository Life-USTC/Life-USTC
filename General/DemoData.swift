import Foundation
import SwiftData

/// Seeds in-memory SwiftData container with rich demo content in one place.
enum DemoData {
    static func seed(_ context: ModelContext) {
        let curriculum = Curriculum()
        context.insert(curriculum)

        let primarySemester = Semester(
            jw_id: "251",
            name: "2025 秋季学期",
            startDate: Date().stripTime().add(day: -30),
            endDate: Date().stripTime().add(day: 120)
        )
        primarySemester.curriculum = curriculum
        curriculum.semesters.append(primarySemester)
        context.insert(primarySemester)

        let secondarySemester = Semester(
            jw_id: "241",
            name: "2024 春季学期",
            startDate: Date().stripTime().add(day: -210),
            endDate: Date().stripTime().add(day: -20)
        )
        secondarySemester.curriculum = curriculum
        curriculum.semesters.append(secondarySemester)
        context.insert(secondarySemester)

        let course1 = Course(
            jw_id: 15661,
            name: "数学分析 B1",
            courseCode: "MATH1006",
            lessonCode: "MATH1006.02",
            teacherName: "程艺",
            description: variedText("极限、连续与高阶求导"),
            credit: 6,
            dateTimePlacePersonText: "周一三五·东区五教"
        )
        attach(course: course1, to: primarySemester, in: context)
        addLectures(
            to: course1,
            schedule: [
                (1, 9, 45, 95, "5104"),
                (3, 9, 45, 95, "5104"),
                (5, 9, 45, 95, "5104"),
            ],
            teacher: "程艺",
            in: context
        )

        let course2 = Course(
            jw_id: 15249,
            name: "力学 A",
            courseCode: "PHYS1001A",
            lessonCode: "PHYS1001A.01",
            teacherName: "李阳",
            description: variedText("经典力学与实验小结", maxExtra: 140),
            credit: 4,
            additionalInfo: ["实验": "附带 2 次加分测验"],
            dateTimePlacePersonText: "周二四·第五教学楼"
        )
        attach(course: course2, to: primarySemester, in: context)
        addLectures(
            to: course2,
            schedule: [
                (2, 9, 45, 95, "5102"),
                (4, 7, 50, 95, "5102"),
            ],
            teacher: "李阳",
            in: context
        )

        let course3 = Course(
            jw_id: 20832,
            name: "计算机程序设计 A",
            courseCode: "CS1001A",
            lessonCode: "CS1001A.H1",
            teacherName: "孙广中",
            description: variedText("算法、链表与 UI 组件实践", minExtra: 20, maxExtra: 160),
            credit: 4,
            dateTimePlacePersonText: "周一二五·西活机房"
        )
        attach(course: course3, to: primarySemester, in: context)
        addLectures(
            to: course3,
            schedule: [
                (1, 19, 30, 145, "西活二楼机房"),
                (2, 15, 55, 95, "5306"),
                (5, 14, 0, 95, "5306"),
            ],
            teacher: "孙广中",
            in: context
        )

        let course4 = Course(
            jw_id: 16000,
            name: "大学物理-综合实验 B",
            courseCode: "PHYS1009B",
            lessonCode: "PHYS1009B.02",
            teacherName:
                "代如成, 刘应玲, 吴玉椿, 孙晓宇, 宋国锋, 岳盈, 张乔枫, 张华洋, 张增明, 张权, 张杨, 曲广媛, 曾华凌, 李恒一, 梁燕, 沈镇, 浦其荣, 王中平, 王晓方, 王鹤, 祝巍, 胡晓敏, 蔡俊, 赵伟, 赵霞, 郭玉刚, 陶小平, 韦先涛",
            description: variedText("综合实验·光学与电磁", minExtra: 50, maxExtra: 120),
            credit: 1,
            additionalInfo: ["着装": "请穿实验室外套"],
            dateTimePlacePersonText: "晚间·东区教一楼物理实验室"
        )
        attach(course: course4, to: primarySemester, in: context)
        addLectures(
            to: course4,
            schedule: [
                (0, 19, 30, 145, "东区教1楼物理实验室"),
                (6, 19, 30, 145, "东区教1楼物理实验室"),
                (7, 19, 30, 145, "东区教1楼物理实验室"),
            ],
            teacher: course4.teacherName,
            in: context
        )

        let course5 = Course(
            jw_id: 18001,
            name: "线性代数 A",
            courseCode: "MATH1002",
            lessonCode: "MATH1002-02",
            teacherName: "朱光",
            description: variedText("矩阵、行列式与几何应用", minExtra: 40, maxExtra: 90),
            credit: 4,
            dateTimePlacePersonText: "周二周五·东区四教"
        )
        attach(course: course5, to: secondarySemester, in: context)
        addLectures(
            to: course5,
            schedule: [
                (-180, 14, 0, 95, "4101"),
                (-177, 8, 0, 95, "4101"),
            ],
            teacher: course5.teacherName,
            in: context
        )

        let course6 = Course(
            jw_id: 19002,
            name: "英语写作",
            courseCode: "ENGL1001",
            lessonCode: "ENGL1001-05",
            teacherName: "Julia",
            description: variedText("Essay drafts, peer review, and presentations", minExtra: 10, maxExtra: 60),
            credit: 2,
            additionalInfo: ["提交": "Markdown / PDF 均可"],
            dateTimePlacePersonText: "周三·线上"
        )
        attach(course: course6, to: secondarySemester, in: context)
        addLectures(
            to: course6,
            schedule: [
                (-175, 18, 30, 110, "线上课堂")
            ],
            teacher: course6.teacherName,
            in: context
        )

        let exams: [Exam] = [
            Exam(
                lessonCode: "MATH10001.01",
                courseName: "数学分析 B1",
                typeName: "期末考试",
                startDate: Date().stripTime() + DateComponents(day: -1, hour: 14, minute: 0),
                endDate: Date().stripTime() + DateComponents(day: -1, hour: 16, minute: 30),
                classRoomName: "5401",
                classRoomBuildingName: "第五教学楼",
                classRoomDistrict: "东区",
                description: variedText("覆盖期中后所有章节")
            ),
            Exam(
                lessonCode: "PHYS1000.02",
                courseName: "大学物理 B1",
                typeName: "期中考试",
                startDate: Date().stripTime() + DateComponents(day: 7, hour: 9, minute: 0),
                endDate: Date().stripTime() + DateComponents(day: 7, hour: 11, minute: 0),
                classRoomName: "3203",
                classRoomBuildingName: "第三教学楼",
                classRoomDistrict: "西区",
                description: variedText("注意携带计算器与实验报告", minExtra: 5, maxExtra: 90)
            ),
        ]
        exams.forEach { context.insert($0) }

        let homeworkList: [Homework] = [
            Homework(
                title: "第一次作业",
                courseName: "数学分析 B1",
                dueDate: Date().add(day: 2)
            ),
            Homework(
                title: "Project draft",
                courseName: "计算机程序设计 A",
                dueDate: Date().add(day: 5) + DateComponents(hour: 20)
            ),
        ]
        homeworkList.forEach { context.insert($0) }

        let scoreSheet = ScoreSheet(
            gpa: 3.94,
            majorRank: 15,
            majorStdCount: 180,
            majorName: "计算机科学与技术",
            additionalMessage: variedText("成绩仅供参考，最终以教务处为准", minExtra: 10, maxExtra: 80)
        )
        context.insert(scoreSheet)

        let scoreEntries: [ScoreEntry] = [
            ScoreEntry(
                courseName: "数学分析 B1",
                courseCode: "MATH1006",
                lessonCode: "MATH1006.02",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 6.0,
                gpa: 4.3,
                score: "95"
            ),
            ScoreEntry(
                courseName: "线性代数 A",
                courseCode: "MATH1002",
                lessonCode: "MATH1002-02",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 4.0,
                gpa: 4.0,
                score: "90"
            ),
            ScoreEntry(
                courseName: "大学物理 B1",
                courseCode: "PHYS1001",
                lessonCode: "PHYS1001-03",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 4.0,
                gpa: 3.7,
                score: "85"
            ),
            ScoreEntry(
                courseName: "程序设计 II",
                courseCode: "CS1002",
                lessonCode: "CS1002-01",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 3.0,
                gpa: 4.3,
                score: "96"
            ),
            ScoreEntry(
                courseName: "英语写作",
                courseCode: "ENGL1001",
                lessonCode: "ENGL1001-05",
                semesterID: "241",
                semesterName: "2024 春季学期",
                credit: 2.0,
                gpa: 3.3,
                score: "80"
            ),
            ScoreEntry(
                courseName: "思想道德与法治",
                courseCode: "POLI1001",
                lessonCode: "POLI1001-02",
                semesterID: "221",
                semesterName: "2023 秋季学期",
                credit: 3.0,
                gpa: 4.0,
                score: "90"
            ),
            ScoreEntry(
                courseName: "体育 I",
                courseCode: "PE1001",
                lessonCode: "PE1001-08",
                semesterID: "221",
                semesterName: "2023 秋季学期",
                credit: 1.0,
                gpa: nil,
                score: "通过"
            ),
        ]
        scoreEntries.forEach { entry in
            entry.scoreSheet = scoreSheet
            scoreSheet.entries.append(entry)
            context.insert(entry)
        }

        let feedSource = FeedSource(
            url: URL(string: "https://www.teach.ustc.edu.cn/category/notice/feed")!,
            name: "教务处",
            detailText: variedText("官方通知流，长度会有起伏", minExtra: 5, maxExtra: 120),
            image: "person.crop.square.fill.and.at.rectangle",
            colorHex: "7676D0"
        )
        context.insert(feedSource)

        let feeds: [Feed] = [
            Feed(
                title: "我校成功举办2025年度教师教学能力提升营",
                keywords: Set(["信息"]),
                detailText: variedText("全天培训与小组演示"),
                datePosted: Date().add(day: -2),
                url: URL(string: "https://www.teach.ustc.edu.cn/2025/1103/c196a61489/page.htm")!,
                imageURL: URL(string: "https://www.teach.ustc.edu.cn/wp-content/uploads/2025/10/202510302.jpg"),
                colorHex: "ff0000"
            ),
            Feed(
                title: "本科生成绩录入维护通知",
                keywords: Set(["教务", "系统维护"]),
                detailText: variedText("录入窗口将于周末暂停，请提前保存草稿。", minExtra: 30, maxExtra: 90),
                datePosted: Date().add(day: -6),
                url: URL(string: "https://www.teach.ustc.edu.cn/2025/1101/c196a61455/page.htm")!,
                imageURL: nil,
                colorHex: "7676D0"
            ),
        ]
        feeds.forEach { feed in
            feed.source = feedSource
            feedSource.feeds.append(feed)
            context.insert(feed)
        }

        try? context.save()
    }

    private static func attach(course: Course, to semester: Semester, in context: ModelContext) {
        course.semester = semester
        semester.courses.append(course)
        context.insert(course)
    }

    private static func addLectures(
        to course: Course,
        schedule: [(Int, Int, Int, Int, String)],
        teacher: String,
        in context: ModelContext
    ) {
        for (dayOffset, startHour, startMinute, durationMinutes, location) in schedule {
            let (startDate, endDate) = lectureWindow(
                dayOffset: dayOffset,
                startHour: startHour,
                startMinute: startMinute,
                durationMinutes: durationMinutes
            )

            let lecture = Lecture(
                startDate: startDate,
                endDate: endDate,
                name: course.name,
                location: location,
                teacherName: teacher,
                periods: Double(durationMinutes) / 50.0,
                startIndex: startHour == 0 ? nil : max(1, (startHour - 7)),
                endIndex: startHour == 0
                    ? nil : max(1, (startHour - 7)) + Int(round(Double(durationMinutes) / 50.0)) - 1
            )
            lecture.course = course
            course.lectures.append(lecture)
            context.insert(lecture)
        }
    }

    private static func lectureWindow(
        dayOffset: Int,
        startHour: Int,
        startMinute: Int,
        durationMinutes: Int
    ) -> (Date, Date) {
        let start = Date().startOfWeek().add(day: dayOffset) + DateComponents(hour: startHour, minute: startMinute)
        let end = start + DateComponents(minute: durationMinutes)
        return (start, end)
    }

    private static func variedText(_ base: String, minExtra: Int = 8, maxExtra: Int = 60) -> String {
        let extraLength = Int.random(in: minExtra ... max(minExtra, maxExtra))
        let filler = String(repeating: " -", count: extraLength / 2)
        return base + filler
    }

    static var geoLocations: [GeoLocation] {
        [
            GeoLocation(
                name: "东区体育中心",
                latitude: 31.835946350451458,
                longitude: 117.2660348207498
            ),
            GeoLocation(
                name: "西区图书馆",
                latitude: 31.84231,
                longitude: 117.25511
            ),
        ]
    }
}
