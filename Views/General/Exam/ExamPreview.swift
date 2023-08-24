//
//  ExamPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import Combine
import SwiftUI

struct ExamPreview: View {
    var exams: [Exam]
    @State var randomColor = exampleGradientList.randomElement() ?? []

    var body: some View {
        Group {
            if exams.isEmpty {
                happyView
            } else {
                makeView(with: exams)
            }
        }
    }

    func makeView(with exams: [Exam]) -> some View {
        VStack {
            ForEach(exams, id: \.lessonCode) { exam in
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(exam.courseName)
                                .fontWeight(.bold)
                                .strikethrough(exam.isFinished)
                            Text(exam.classRoomName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(exam.startDate.description(with: .current))
                            Text(exam.endDate.description(with: .current))
                                .font(.caption)
                                .foregroundColor(Color.secondary)
                        }
                        .font(.system(.body, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    Spacer()
                    if exam.isFinished {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray)
                            .frame(height: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: randomColor,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 5)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(style: .init(lineWidth: 1))
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 60)
            }
        }
    }

    var happyView: some View {
        VStack {
            Spacer()
            HStack {
                ZStack {
                    Image(systemName: "checklist.checked")
                        .symbolRenderingMode(.hierarchical)
                        .fontWeight(.light)
                        .font(.largeTitle)
                        .foregroundStyle(Color.orange)
                }

                Spacer()

                Text("No More Exam!")
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 8)
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.orange)
                .frame(height: 5)
        }
        .background {
            RoundedRectangle(cornerRadius: 5)
                .stroke(style: .init(lineWidth: 1))
                .fill(Color.gray.opacity(0.3))
        }
        .frame(height: 60)
    }
}

struct ExamPreview_Previews: PreviewProvider {
    static var previews: some View {
        ExamPreview(exams: [.example, .example])
        ExamPreview(exams: [])
    }
}
