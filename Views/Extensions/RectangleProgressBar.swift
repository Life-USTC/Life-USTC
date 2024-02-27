//
//  RectangleProgressBar.swift
//  Life@USTC
//
//  Created by Tiankai Ma on 2023-04-08.
//

import SwiftUI

@available(*, deprecated, message: "")
struct RectangleProgressBar: View {
    var width = 400.0
    var height = 50.0
    var startDate: Date
    var endDate: Date
    var colors = exampleGradientList.randomElement() ?? []
    var textWithPositionList: [(text: Text, at: (CGSize) -> CGPoint, anchor: UnitPoint)]

    init(
        width: Double = 400.0,
        height: Double = 50.0,
        startDate: Date,
        endDate: Date,
        colors: [Color] = exampleGradientList.randomElement() ?? [],
        textWithPositionList: [(
            text: Text, at: (CGSize) -> CGPoint, anchor: UnitPoint
        )]
    ) {
        self.width = width
        self.height = height
        self.startDate = startDate
        self.endDate = endDate
        self.colors = colors
        self.textWithPositionList = textWithPositionList
    }

    init(
        width: Double = 400.0,
        height: Double = 50.0,
        startDate: Date,
        endDate: Date,
        colors: [Color] = exampleGradientList.randomElement() ?? [],
        text: String
    ) {
        self.width = width
        self.height = height
        self.startDate = startDate
        self.endDate = endDate
        self.colors = colors
        textWithPositionList = [
            (
                Text(text),
                { CGPoint(x: $0.width / 2, y: $0.height / 2) },
                .center
            )
        ]
    }

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

    func draw(
        context: GraphicsContext,
        size: CGSize,
        timeline: TimelineViewDefaultContext,
        progress: Double
    ) {
        context.fill(
            drawPath(
                in: size,
                time: timeline.date.timeIntervalSince1970 * 4.8 + 1.2,
                progress: progress + 0.01
            ),
            with: .linearGradient(
                Gradient(colors: colors.map { $0.opacity(0.25) }),
                startPoint: .zero,
                endPoint: .init(x: size.width, y: size.height)
            ),
            style: .init(antialiased: true)
        )

        context.fill(
            drawPath(
                in: size,
                time: timeline.date.timeIntervalSince1970 * 2.4,
                progress: progress
            ),
            with: .linearGradient(
                Gradient(colors: colors),
                startPoint: .zero,
                endPoint: .init(x: size.width, y: size.height)
            ),
            style: .init(antialiased: true)
        )
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1 / 60)) { timeline in
            Canvas { context, size in
                let progress =
                    Date().timeIntervalSince(startDate)
                    / endDate.timeIntervalSince(startDate)

                draw(
                    context: context,
                    size: size,
                    timeline: timeline,
                    progress: progress
                )

                for _textWithPosition in textWithPositionList {
                    context.draw(
                        _textWithPosition.text.foregroundColor(.white),
                        at: _textWithPosition.at(size),
                        anchor: _textWithPosition.anchor
                    )
                }

                context.clipToLayer(
                    options: .inverse,
                    content: { clipContext in
                        draw(
                            context: clipContext,
                            size: size,
                            timeline: timeline,
                            progress: progress
                        )
                    }
                )

                context.clipToLayer(content: { clipContext in
                    for _textWithPosition in textWithPositionList {
                        clipContext.draw(
                            _textWithPosition.text.foregroundColor(.black),
                            at: _textWithPosition.at(size),
                            anchor: _textWithPosition.anchor
                        )
                    }
                })

                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: colors),
                        startPoint: .zero,
                        endPoint: .init(x: size.width, y: size.height)
                    )
                )
            }
            .frame(width: width, height: height)
        }
    }
}

@available(*, deprecated, message: "")
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
