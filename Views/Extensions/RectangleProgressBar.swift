//
//  RectangleProgressBar.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023-04-08.
//

import SwiftUI

struct RectangleProgressBar: View {
    var height = 80.0
    var width = 400.0
    var startDate: Date
    var endDate: Date
    var color = Color.green

    func drawPath(in rect: CGSize, time: Double, progress: Double) -> Path {
        let path = Path { path in
            path.move(to: .zero)
            let total = 20
            for x in 0 ... total {
                let y = rect.height * Double(x) / Double(total)
                let offset = sin(2.0 * (Double.pi * y / rect.height) + time)
                let x = rect.width * (progress + 0.0125 * offset)
                path.addLine(to: .init(x: x, y: y))
            }
            path.addLine(to: .init(x: 0, y: rect.height))
        }

        return path
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.01)) { timeline in
            Canvas { context, size in
                let progress = (Date().timeIntervalSince1970 - startDate.timeIntervalSince1970) / (endDate.timeIntervalSince1970 - startDate.timeIntervalSince1970)
                context.fill(
                    drawPath(in: size, time: timeline.date.timeIntervalSince1970 * 4.8 + 1.2, progress: progress + 0.01),
                    with: .color(color.opacity(0.25)),
                    style: .init(antialiased: true)
                )

                context.fill(
                    drawPath(in: size, time: timeline.date.timeIntervalSince1970 * 2.4, progress: progress),
                    with: .color(color),
                    style: .init(antialiased: true)
                )
            }
            .frame(width: width, height: height)
        }
        .background {
            Rectangle()
                .fill(.background)
                .frame(width: width, height: height)
        }
    }
}

struct RectangleProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RectangleProgressBar(startDate: Date().addingTimeInterval(-15 * 60), endDate: Date().addingTimeInterval(45 * 60))
        }
    }
}
