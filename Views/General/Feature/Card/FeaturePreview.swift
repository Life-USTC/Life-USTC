//
//  FeaturePreview.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/17.
//

import SwiftUI

struct SingleFeaturePreview: View {
    var feature: FeatureWithView
    var body: some View {
        NavigationLink {
            AnyView(feature.destinationView())
        } label: {
            Label(feature.title.localized, systemImage: feature.image)
                .labelStyle(FeatureLabelStyle())
        }
    }
}

struct FeaturePreview: View {
    var features: [FeatureWithView] = [
        .init(
            image: "book",
            title: "Curriculum",
            subTitle: "",
            destinationView: { CurriculumDetailView() }
        ),
        .init(
            image: "calendar.badge.clock",
            title: "Exam",
            subTitle: "",
            destinationView: { ExamDetailView() }
        ),
        .init(
            image: "graduationcap",
            title: "Score",
            subTitle: "",
            destinationView: { ScoreView() }
        ),
        .init(
            image: "doc.text.magnifyingglass",
            title: "Classroom Status",
            subTitle: "",
            destinationView: { USTCClassroomView() }
        ),
        .init(
            image: "bus",
            title: "Bus Timetable",
            subTitle: "",
            destinationView: { USTC_SchoolBusView() }
        ),
        FeatureWithView(
            .init(
                name: "Email",
                image: "mail.stack",
                description: "科大邮箱",
                url:
                    "https://mail.ustc.edu.cn",
                markUp: false
            )
        ),
        FeatureWithView(
            .init(
                name: "AAS",
                image: "person.2",
                description: "本科生教务系统",
                url: "https://jw.ustc.edu.cn/ucas-sso/login",
                markUp: true
            )
        ),
        FeatureWithView(
            .init(
                name: "Library",
                image: "book",
                description: "图书馆",
                url: "https://lib.ustc.edu.cn",
                markUp: false
            )
        ),

    ]
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        ) {
            ForEach(features) { feature in
                SingleFeaturePreview(feature: feature)
            }
        }
    }
}

#Preview {
    FeaturePreview()
}
