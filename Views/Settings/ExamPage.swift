//
//  ExamPage.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/2/1.
//

import SwiftUI

struct ExamSettingView: View {
    @AppStorage("hiddenExamName", store: UserDefaults.appGroup)
    var hiddenExamName: [String] = []

    func delete(at offsets: IndexSet) {
        hiddenExamName.remove(atOffsets: offsets)
    }

    var body: some View {
        List {
            Section {
                ForEach(hiddenExamName.indices, id: \.self) { index in
                    TextField("Name", text: $hiddenExamName[index])
                }
                .onDelete(perform: delete)

                Button {
                    if hiddenExamName.filter(\.isEmpty).isEmpty {
                        // refuse to add new empty string if there's already an empty location
                        hiddenExamName.append("")
                    }
                } label: {
                    Label("Add new", systemImage: "plus")
                }
            } header: {
                Text("Exam name to hide").textCase(.none)
            } footer: {
                Text(
                    "When exam contains these words, they will be shown at the bottom even they comes first in time"
                )
            }
            EmptyView()
        }
        .navigationBarTitle("Exam Settings", displayMode: .inline)
    }
}

struct ExamSettingView_Previews: PreviewProvider {
    static var previews: some View { ExamSettingView() }
}
