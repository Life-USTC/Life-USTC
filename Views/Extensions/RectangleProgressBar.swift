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
    var colors = exampleGradientList.randomElement() ?? []
    var text: String = ""

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
    
    func draw(context: GraphicsContext, size: CGSize, timeline: TimelineViewDefaultContext, progress: Double) {
        context.fill(
            drawPath(in: size,
                     time: timeline.date.timeIntervalSince1970 * 4.8 + 1.2,
                     progress: progress + 0.01),
            with: .linearGradient(Gradient(colors: colors.map { $0.opacity(0.25) }),
                                  startPoint: .zero,
                                  endPoint: .init(x: size.width, y: size.height)),
            style: .init(antialiased: true)
        )
        
        context.fill(
            drawPath(in: size,
                     time: timeline.date.timeIntervalSince1970 * 2.4,
                     progress: progress),
            with: .linearGradient(Gradient(colors: colors),
                                  startPoint: .zero,
                                  endPoint: .init(x: size.width, y: size.height)),
            style: .init(antialiased: true)
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1 / 60)) { timeline in
            Canvas { context, size in
                let progress = (Date().timeIntervalSince1970 - startDate.timeIntervalSince1970) / (endDate.timeIntervalSince1970 - startDate.timeIntervalSince1970)
                
                draw(context: context,
                     size: size,
                     timeline: timeline,
                     progress: progress)
                
                context.draw(
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .bold(),
                    at: .init(x: size.width / 2, y: size.height / 2),
                    anchor: .center
                )
                
                context.clipToLayer(options: .inverse, content: { clipContext in
                    draw(context: clipContext,
                         size: size,
                         timeline: timeline,
                         progress: progress)
                })
                
                context.clipToLayer(content: { clipContext in
                    clipContext.draw(
                        Text(text)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .bold(),
                        at: .init(x: size.width / 2, y: size.height / 2),
                        anchor: .center
                    )
                })
                
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .linearGradient(Gradient(colors: colors),
                                                    startPoint: .zero,
                                                    endPoint: .init(x: size.width, y: size.height))
                )
            }
            .frame(width: width, height: height)
        }
    }
}

struct RectangleProgressBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RectangleProgressBar(
                startDate: Date().addingTimeInterval(-15 * 60),
                endDate: Date().addingTimeInterval(10 * 60),
                text: "Example TEXT"
            )
            RectangleProgressBar(
                startDate: Date().addingTimeInterval(-15 * 60),
                endDate: Date().addingTimeInterval(5 * 60),
                colors: [.black],
                text: "!!!!!!"
            )
        }
    }
}
