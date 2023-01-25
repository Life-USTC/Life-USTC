//
//  CourseCardView.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct CourseCardView: View {
    var course: Course
    @State var showPopUp = false

    var body: some View {
        VStack {
            Text(Course.startTimes[course.startTime - 1].clockTime)
            Spacer()

            Text(course.name)
                .lineLimit(nil)
            Text(course.classPositionString)
            if course.startTime != course.endTime {
                Divider()
                Text(course.classIDString)
                Text(course.classTeacherName)

                Spacer()
                Text(Course.endTimes[course.endTime - 1].clockTime)
            }
        }
        .lineLimit(1)
        .font(.system(size: 12))
        .padding(4)
        .frame(height: heightPerClass * Double(course.endTime - course.startTime + 1))
        .background {
            RoundedRectangle(cornerRadius: 8)
                .stroke(showPopUp ? Color.accentColor : Color.gray, lineWidth: 1)
//                .frame(width: stackWidth)
        }
        .onTapGesture {}
        .onLongPressGesture(minimumDuration: 0.6) {
#if os(iOS)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
#endif
            showPopUp = true
        }
        .sheet(isPresented: $showPopUp) {
            NavigationStack {
                VStack(alignment: .leading) {
                    Text(course.name)
                        .font(.title)
                    Text(Course.startTimes[course.startTime - 1].clockTime + " - " + Course.endTimes[course.endTime - 1].clockTime)
                        .bold()

                    List {
                        Text("Location: ".localized + course.classPositionString)
                        Text("Teacher: ".localized + course.classTeacherName)
                        Text("ID: ".localized + course.classIDString)
                        Text("Week: ".localized + course.weekString)
                        Text("Time: ".localized + "\(course.startTime) - \(course.endTime)")
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                }
                .hStackLeading()
                .padding()
            }
            .presentationDetents([.fraction(0.5)])
        }
    }
}
