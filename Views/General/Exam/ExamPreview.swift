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

    func makeView(with exam: Exam) -> some View {
        makeRectangleView(colors: exam.isFinished ? [.gray] : randomColor) {
            HStack {
                VStack(alignment: .leading) {
                    Text(exam.courseName)
                        .fontWeight(.bold)
                        .strikethrough(exam.isFinished)
                    Text(exam.classRoomName)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(exam.startDate, style: .date)
                        .font(.system(.body, design: .monospaced))
                    Text(exam.startDate ... exam.endDate)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    var happyView: some View {
        makeRectangleView(colors: [.orange]) {
            HStack {
                Image(systemName: "checklist.checked")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(.largeTitle, weight: .light))
                    .foregroundStyle(Color.orange)

                Spacer()

                Text("No More Exam!")
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    func makeView(with exams: [Exam]) -> some View {
        VStack {
            ForEach(exams, id: \.lessonCode) { exam in
                makeView(with: exam)
            }
        }
    }
}

@ViewBuilder
private func makeRectangleView(
    colors: [Color] = [.gray],
    mainView: @escaping () -> any View
) -> some View {
    VStack {
        AnyView(mainView())
            .frame(height: 50)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)

        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 5)
    }
    .overlay {
        RoundedRectangle(cornerRadius: 5)
            .stroke(style: .init(lineWidth: 1))
            .fill(Color.gray.opacity(0.3))
    }
    .clipped()
    .frame(height: 60)
}

struct ExamPreview_Previews: PreviewProvider {
    static var previews: some View {
        ExamPreview(exams: [.example, .example])
        ExamPreview(exams: [])
    }
}
