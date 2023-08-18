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
//            Text(course._startTime.clockTime)
//                .font(.system(size: 9))
//                .fontWeight(.bold)
//                .hStackLeading()
//            VStack(alignment: .center) {
//                Text(course.name)
//                    .multilineTextAlignment(.center)
//                    .lineLimit(nil)
//                    .font(.system(size: 12))
//                Text(course.roomName)
//                    .font(.system(size: 12))
//                    .fontWeight(.bold)
//            }
//            if course.length != 1 {
//                Divider()
//                Spacer()
//                Text(course.lessonCode)
//                    .font(.system(size: 9))
//                Text(course.teacherName)
//                    .font(.system(size: 9))
//                Text(course._endTime.clockTime)
//                    .font(.system(size: 9))
//                    .hStackTrailing()
//            }
        }
        .lineLimit(1)
        .padding(2)
//        .frame(height: heightPerClass * Double(course.length) - 4)
        .background {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.accentColor.opacity(0.1))
        }
        .onTapGesture {}
        .onLongPressGesture(minimumDuration: 0.6) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            showPopUp = true
        }
        .sheet(isPresented: $showPopUp) {
//            NavigationStack {
//                VStack(alignment: .leading) {
//                    Text(course.name)
//                        .foregroundColor(Color.accentColor)
//                        .font(.title)
//                        .fontWeight(.bold)
//                    Text(course._startTime.clockTime + " - " + course._endTime.clockTime)
//                        .bold()
//
//                    List {
//                        HStack {
//                            Text("Classroom: ".localized)
//                                .fontWeight(.semibold)
//                            Spacer()
//                            Text(course.roomName)
//                        }
//                        HStack {
//                            Text("Teacher: ".localized)
//                                .fontWeight(.semibold)
//                            Spacer()
//                            Text(course.teacherName)
//                        }
//                        HStack {
//                            Text("ID: ".localized)
//                                .fontWeight(.semibold)
//                            Spacer()
//                            Text(course.lessonCode)
//                        }
//                        HStack {
//                            Text("Week: ".localized)
//                                .fontWeight(.semibold)
//                            Spacer()
//                            Text(course.weekString)
//                        }
//                        HStack {
//                            Text("Time: ".localized)
//                                .fontWeight(.semibold)
//                            Spacer()
//                            Text(course.timeDescription)
//                        }
//                    }
//                    .listStyle(.plain)
//                    .scrollDisabled(true)
//                }
//                .hStackLeading()
//                .padding()
//            }
//            .presentationDetents([.fraction(0.5)])
        }
    }
}
