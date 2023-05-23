//
//  ExamPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/11.
//

import SwiftUI

struct ExamPreview: View {
    @State var exams: [Exam] = []
    @State var status: AsyncViewStatus = .inProgress
    @State var randomColor = exampleGradientList.randomElement() ?? []
    var body: some View {
        AsyncView(delegate: ExamDelegate.shared, showReloadButton: false) { $exams in
            if exams.isEmpty {
                return happyView
            } else {
                return makeView(with: exams)
            }
        }
    }

    func makeView(with exams: [Exam]) -> some View {
        VStack {
            ForEach(exams) { exam in
                HStack {
                    VStack(alignment: .leading) {
                        Text(exam.className)
                            .strikethrough(exam.isFinished)
                        Text(exam.classRoomName)
                            .font(.subheadline)
                            .foregroundColor(Color.gray)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(exam.rawTime.split(separator: " ")[0])
                            .fontWeight(.bold)
                        Text(exam.rawTime.split(separator: " ")[1])
                    }
                    .font(.system(.subheadline, design: .monospaced))
                }
                Divider()
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
                        .foregroundStyle(LinearGradient(colors: randomColor,
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing))
                }

                Spacer()

                Text("No More Exam!")
                    .font(.system(.body, design: .monospaced))
            }
            .padding(.horizontal, 8)
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: randomColor,
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
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
        ExamPreview()
        ExamPreview().happyView
    }
}
