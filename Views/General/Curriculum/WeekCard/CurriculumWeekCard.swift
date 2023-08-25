//
//  CurriculumWeekCard.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023/8/25.
//

import Charts
import SwiftUI

struct CurriculumWeekCard: View {
    @ManagedData(.curriculum) var curriculum: Curriculum

    @State var currentSemester: Semester?
    @State var flipped = false
    @State var _date: Date = .now
    @State var lectures: [Lecture] = []
    @State var weekNumber: Int?

    var date: Date { _date.startOfWeek() }
    var flippedDegrees: Double { flipped ? 180 : 0 }

    var body: some View {
        ZStack {
            mainView.card()
                .flipRotate(flippedDegrees)
                .opacity(flipped ? 0 : 1)

            settingsView.card()
                .flipRotate(-180 + flippedDegrees)
                .opacity(flipped ? 1 : 0)
        }
        .onChange(of: currentSemester) {
            _ in updateLecturesAndWeekNumber()
        }
        .onChange(of: curriculum) { _ in
            updateLecturesAndWeekNumber()
            updateSemester()
        }
        .onChange(of: _date) { _ in
            updateLecturesAndWeekNumber()
            updateSemester()
        }
        .onAppear {
            updateLecturesAndWeekNumber()
            updateSemester()
        }
    }
}

extension CurriculumWeekCard {
    var refreshButton: some View {
        Button {
            _curriculum.triggerRefresh()
            updateLecturesAndWeekNumber()
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.caption)
        }
    }

    var flipButton: some View {
        Button {
            withAnimation(.spring) {
                flipped.toggle()
            }
        } label: {
            Label(
                flipped ? "Chart" : "Settings",
                systemImage: flipped ? "chart.bar.xaxis" : "gearshape"
            )
            .font(.caption)
        }
    }

    var topBar: some View {
        HStack {
            Text("Curriculum")
                .font(.system(.caption, design: .monospaced, weight: .bold))

            AsyncStatusLight(status: _curriculum.status)

            Spacer()

            refreshButton
            flipButton
        }
    }

    var mainView: some View {
        VStack {
            topBar
            CurriculumWeekView(
                lectures: lectures,
                _date: _date,
                currentSemesterName: currentSemester?.name ?? "All",
                weekNumber: weekNumber
            )
            .frame(height: 230)
            .asyncStatusOverlay(_curriculum.status, showLight: false)
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    if abs(value.translation.width) < 20 {
                        // too small a swipe
                        return
                    }

                    if value.translation.width < 0 {
                        _date = _date.add(day: 7)
                    } else {
                        _date = _date.add(day: -7)
                    }
                }
        )
    }
}

extension View {
    fileprivate func card() -> some View {
        padding()
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary, lineWidth: 0.2)
            }
    }

    fileprivate func flipRotate(_ degrees: Double) -> some View {
        rotation3DEffect(
            Angle(degrees: degrees),
            axis: (x: 0.0, y: 1.0, z: 0.0)
        )
    }
}
