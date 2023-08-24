//
//  Card.swift
//  Life@USTC
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

let cardHeight = 200.0

@available(*, deprecated) struct Card: View {
    @Environment(\.colorScheme) var colorScheme
    var cardTitle: String
    var cardDescription: String?
    var leadingPropertyList: [(name: String, color: Color?)] = []
    var trailingPropertyList: [String] = []
    var imageURL: URL?
    var cornerRadius = 15.0
    var titleLength: Int {
        if cardDescription == "" || cardDescription == nil { return 4 }
        return 2
    }

    var subtitleLength = 4
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle().fill(Color(with: cardTitle, mode: colorScheme))
                if let imageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                            .overlay(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, .black]
                                    ),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                width: geo.size.width,
                                height: geo.size.height
                            )
                    } placeholder: {
                        ProgressView()
                    }
                }
            }
        }
        .frame(height: cardHeight)
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading) {
                Text(cardTitle).font(.title2).bold()
                    .multilineTextAlignment(.leading).lineLimit(titleLength)
                if let cardDescription {
                    Text(cardDescription).font(.caption2).fontWeight(.light)
                        .multilineTextAlignment(.leading)
                        .lineLimit(subtitleLength)
                }
            }
            .foregroundColor(.white).padding()
        }
        .overlay(alignment: .topLeading) {
            HStack {
                ForEach(leadingPropertyList, id: \.name) { property in
                    ZStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(property.color ?? .accentColor)
                        Text(property.name).font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(width: 60, height: 20).padding(.leading, -5)
                }
            }
            .padding(.top, 10).padding(.leading, 20)
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing) {
                ForEach(trailingPropertyList, id: \.self) { info in
                    Text(info).foregroundColor(.accentColor)
                        .fontWeight(.semibold).padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 8).fill(.background)
                        )
                        .font(.caption)
                }
            }
            .padding([.top, .trailing], 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .padding([.leading, .trailing], 2)
        .contentShape(
            .contextMenuPreview,
            RoundedRectangle(cornerRadius: cornerRadius)
        )
    }
}
