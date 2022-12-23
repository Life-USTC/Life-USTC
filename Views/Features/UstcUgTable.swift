//
//  UstcUgTable.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/19.
//

import SwiftUI
import Charts

struct TableClass: Identifiable {
    var id = UUID()
    var dayOfWeek: Int
    var startTime: Int
    var endTime: Int
    var name: String
    var classIDString: String
    var classPositionString: String
    var classTeacherName: String
}

let heightPerClass = 55.0

// lazy version...
let classStartTimes: [DateComponents] =
[.init(hour: 7, minute: 50),
 .init(hour: 8, minute: 40),
 .init(hour: 9, minute: 45),
 .init(hour: 10, minute: 35),
 .init(hour: 11, minute: 25),
 .init(hour: 14, minute: 0),
 .init(hour: 14, minute: 50),
 .init(hour: 15, minute: 55),
 .init(hour: 16, minute: 45),
 .init(hour: 17, minute: 35),
 .init(hour: 19, minute: 30),
 .init(hour: 20, minute: 20),
 .init(hour: 21, minute: 10)]

let classEndTimes: [DateComponents] =
[.init(hour: 8, minute: 35),
 .init(hour: 9, minute: 25),
 .init(hour: 10, minute: 30),
 .init(hour: 11, minute: 20),
 .init(hour: 12, minute: 10),
 .init(hour: 14, minute: 45),
 .init(hour: 15, minute: 35),
 .init(hour: 16, minute: 40),
 .init(hour: 17, minute: 30),
 .init(hour: 18, minute: 20),
 .init(hour: 20, minute: 15),
 .init(hour: 21, minute: 5),
 .init(hour: 21, minute: 55)]

extension DateComponents {
    var clockTime: String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .none
        return dateFormatter.string(from: Date().stripTime() + self)
    }
}

struct TableClassCardView: View {
    var tableClass: TableClass
    @State var showPopUp = false
    
    var body: some View {
        VStack {
            Text(classEndTimes[tableClass.startTime - 1].clockTime)
                .font(.caption)
            Spacer()
            
            Text(tableClass.name)
                .font(.system(size: 14))
            Text(tableClass.classPositionString)
                .font(.system(size: 14))
            if tableClass.startTime != tableClass.endTime  {
                Divider()
                Text(tableClass.classIDString)
                    .font(.system(size: 8))
                Text(tableClass.classTeacherName)
                    .font(.system(size: 8))
                
                Spacer()
                Text(classEndTimes[tableClass.endTime - 1].clockTime)
                    .font(.caption)
            }
        }
        .lineLimit(1)
        .padding(4)
        .frame(height: heightPerClass * Double(tableClass.endTime - tableClass.startTime + 1))
        .background {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.gray, lineWidth: 1)
        }
        .onLongPressGesture {
            showPopUp = true
        }
        .sheet(isPresented: $showPopUp) {
            EmptyView()
        }
    }
    
    init(tableClass: TableClass) {
        self.tableClass = tableClass
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
                .padding(1)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            withAnimation {
                                showSatAndSun.toggle()
                            }
                        } label: {
                            Text("Sat&Sun")
                        }
                        
                        Button {
                            withAnimation {
                                showSatAndSun.toggle()
                            }
                        } label: {
                            Text("Sat&Sun")
                        }
                    }
                }
                .navigationTitle("Time Table")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func makeVStack(index: Int) -> some View {
        VStack {
            Text(daysOfWeek[index])
            ZStack(alignment: .top) {
                Color.clear
                
                ForEach(classes) { eachClass in
                    if eachClass.dayOfWeek == (index + 1) {
                        TableClassCardView(tableClass: eachClass)
                            .offset(y: Double(eachClass.startTime - 1) * heightPerClass)
                    }
                }
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.accentColor)
                    .offset(y: 5 * heightPerClass)
                    .opacity(0.5)
                
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.accentColor)
                    .offset(y: 9 * heightPerClass)
                    .opacity(0.5)
            }
        }
        .frame(width: UIScreen.main.bounds.width / 5, height: heightPerClass * 13)
    }
    
    var mainView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
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
            .scrollDisabled(!showSatAndSun)
        }
    }
}
