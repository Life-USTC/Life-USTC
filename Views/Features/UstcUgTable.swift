//
//  UstcUgTable.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI
import Charts

struct TableClass {
    var dayOfWeek: Int
    var startTime: Int
    var endTime: Int
    var name: String
    var classIDString: String
    var classPositionString: String
    var classTeacherName: String
}

struct TableClassCardView: View {
    let tableclass: TableClass
    
    var body: some View {
        VStack {
            Text(tableclass.name)
            Text(tableclass.classIDString)
            Text(tableclass.classTeacherName)
            Text(tableclass.classPositionString)
        }
        .lineLimit(1)
        .font(.caption)
        .foregroundColor(.white)
        .padding()
        .frame(height: 100 * Double(tableclass.endTime - tableclass.startTime))
        .background {
            RoundedRectangle(cornerRadius: 8)
                .foregroundColor(.accentColor)
        }
    }
}



struct UstcUgTableView: View {
    // Better preview here..?
    
    @State var showSatAndSun = false
    let daysOfWeek: [LocalizedStringKey] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map({LocalizedStringKey(stringLiteral: $0)})
    @State var classes: [TableClass] = []
    
    var body: some View {
        NavigationStack {
            mainView
                .padding()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation {
                                showSatAndSun.toggle()
                            }
                        } label: {
                            Text("Sat&Sun")
//                            Label("Show Saturday and Sunday", systemImage: "square.stack.3d.down.right")
                        }
                    }
                }
                .navigationTitle("Time Table")
        }
    }
    
    func makeVStack(index: Int) -> some View {
        VStack {
            Text(String(index + 1))
            Text(daysOfWeek[index])
            ZStack {
//                ForEach
                TableClassCardView(tableclass: TableClass(dayOfWeek: 1, startTime: 1, endTime: 3, name: "数学分析", classIDString: "MATH1001", classPositionString: "5204", classTeacherName: "testName"))
            }
            .frame(height: 100 * 9)
        }
//        .border(.blue)
        .padding([.leading, .trailing], 1)
        .frame(width: (UIScreen.main.bounds.width - 80) / 3)
    }
    
    var mainView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(0..<5) { index in
                        makeVStack(index: index)
                    }
                    if showSatAndSun {
                        ForEach(5..<7) { index in
                            makeVStack(index: index)
                        }
                    }
                }
            }
        }
//        .scrollDisabled(!showSatAndSun)
    }
}
