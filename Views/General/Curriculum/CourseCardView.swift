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
        VStack(spacing: 3) {
            Text(Course.startTimes[course.startTime - 1].clockTime)
                .font(.system(size: 9))
                .fontWeight(.bold)
                .hStackLeading()
            VStack(alignment: .center) {
                Text(course.name)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .font(.system(size: 12))
                Text(course.classPositionString)
                    .font(.system(size: 12))
                    .fontWeight(.bold)
            }
            if course.startTime != course.endTime {
                Divider()
                Spacer()
                Text(course.classIDString)
                    .font(.system(size: 9))
                Text(course.classTeacherName)
                    .font(.system(size: 9))
                Text(Course.endTimes[course.endTime - 1].clockTime)
                    .font(.system(size: 9))
                    .hStackTrailing()
            }
        }
        .lineLimit(1)
        .padding(2)
        .frame(height: heightPerClass * Double(course.endTime - course.startTime + 1) - 4)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.accentColor.opacity(0.1))
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
                        .foregroundColor(Color.accentColor)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(Course.startTimes[course.startTime - 1].clockTime + " - " + Course.endTimes[course.endTime - 1].clockTime)
                        .bold()

                    List {
                        HStack {
                            Text("Classroom: ".localized)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(course.classPositionString)
                        }
                        HStack {
                            Text("Teacher: ".localized)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(course.classTeacherName)
                        }
                        HStack {
                            Text("ID: ".localized)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(course.classIDString)
                        }
                        HStack {
                            Text("Week: ".localized)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(course.weekString)
                        }
                        HStack {
                            Text("Time: ".localized)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(course.startTime) - \(course.endTime)")
                        }
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
