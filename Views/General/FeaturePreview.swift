//
//  FeaturePreviewView.swift
//  Life@USTC
//
//  Created by Ode on 2023/9/17.
//

import SwiftUI

struct FeatureLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: 0) {
            configuration.icon
                .foregroundColor(Color.accentColor)
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 50, height: 50)
                .padding(.horizontal, 10)
            configuration.title
                .foregroundColor(.primary)
                .lineLimit(2, reservesSpace: true)
                .font(.caption)
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
            destinationView: { ScoreDetailView() }
        ),
        .init(
            image: "bus",
            title: "Bus Timetable",
            subTitle: "",
            destinationView: { USTC_SchoolBusView() }
        ),
    ]
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        ) {
            ForEach(features) { feature in
                NavigationLink {
                    AnyView(feature.destinationView())
                } label: {
                    Label(feature.title, systemImage: feature.image)
                        .labelStyle(FeatureLabelStyle())
                }
            }
        }
    }
}
