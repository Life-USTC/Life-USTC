//
//  HomeworkDetailView.swift
//  学在科大
//
//  Created by TianKai Ma on 2023/12/1.
//

import SwiftUI

struct SingleHomeWorkView: View {
    let homework: Homework
    
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading) {
                Text(homework.title)
                    .font(.system(.title2, weight: .bold))
                    .strikethrough(homework.isFinished)
                    .foregroundColor(homework.isFinished ? .gray : .primary)
                
                Text(homework.courseName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer(minLength: 25)
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                    Text(homework.dueDate, style:  .date)
                    Text(homework.dueDate, style:  .time)
                }
                .font(.callout)
            }
            
            Spacer()
            
            if homework.isFinished {
                Text("Finished".localized)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

            } else {
                Text(homework.dueDate, style: .relative)
                    .fontWeight(.bold)
                    .foregroundColor(
                        homework.daysLeft <= 1 ? .red : .accentColor
                    )
            }
        }
        .padding(.vertical, 2)
    }
}

struct HomeworkDetailView: View {
    @ManagedData(.homework) var homeworks: [Homework]
    
    var archivedHomework: [Homework] {
        homeworks.filter { $0.dueDate < Date() }.sorted { $0.dueDate > $1.dueDate }
    }
    
    var newHomework: [Homework] {
        homeworks.filter { $0.dueDate > Date() }.sorted { $0.dueDate < $1.dueDate }
    }
    
    var body: some View {
        List {
            Section {
                ForEach(newHomework) { homework in
                    SingleHomeWorkView(homework: homework)
                }
                
                ForEach(archivedHomework) { homework in
                    SingleHomeWorkView(homework: homework)
                }
            }  header: {
                AsyncStatusLight(status: _homeworks.status)
            } footer: {
                Text("disclaimer")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal)
        .refreshable {
            _homeworks.triggerRefresh()
        }
        .navigationTitle("Homework (Blackboard)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
}
