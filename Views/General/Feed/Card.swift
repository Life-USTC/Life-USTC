//
//  Card.swift
//  Life@USTC
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

var cardWidth: CGFloat {
    (UIApplication.shared.connectedScenes.first as? UIWindowScene)!.screen.bounds.width - 30
}

let cardHeight = 200.0

extension Color {
    /// Generate the color from hash value
    ///
    /// - Note: Output color matches following range:
    ///   hue: .random(in: 0...1)
    ///   saturation: .random(in: 0.25...0.55)
    ///   brightness: .random(in: 0.25...0.35, 0.75...0.85)
    init(with string: String, mode: ColorScheme) {
        let hash = Int(string.md5HexString.prefix(6), radix: 16)!
        let hue = Double(hash % 360) / 360
        let saturation = Double(hash % 30 + 25) / 100
        var brightness = 0.0
        if mode == .dark {
            brightness = Double(hash % 10 + 25) / 100
        } else {
            brightness = Double(hash % 10 + 75) / 100
        }
        self = Color(uiColor: UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
    }
}

struct Card: View {
    @Environment(\.colorScheme) var colorScheme
    var cardTitle: String
    var cardDescription: String?
    var leadingPropertyList: [(name: String, color: Color?)] = []
    var trailingPropertyList: [String] = []
    var imageURL: URL?
    var cornerRadius = 15.0
    var titleLength: Int {
        if cardDescription == "" || cardDescription == nil {
            return 4
        }
        return 2
    }

    var subtitleLength = 4
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.init(with: cardTitle, mode: colorScheme))
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .overlay(
                            LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .top, endPoint: .bottom)
                        )
                } placeholder: {
                    ProgressView()
                }
            }
        }
        .scaledToFill()
        .frame(width: cardWidth, height: cardHeight)
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading) {
                Text(cardTitle)
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.leading)
                    .lineLimit(titleLength)
                if let cardDescription {
                    Text(cardDescription)
                        .font(.caption2)
                        .fontWeight(.light)
                        .multilineTextAlignment(.leading)
                        .lineLimit(subtitleLength)
                }
            }
            .foregroundColor(.white)
            .padding()
        }
        .overlay(alignment: .topLeading) {
            HStack {
                ForEach(leadingPropertyList, id: \.name) { property in
                    ZStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(property.color ?? .accentColor)
                        Text(property.name)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(width: 60, height: 20)
                    .padding(.leading, -5)
                }
            }
            .padding(.top, 10)
            .padding(.leading, 20)
        }
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing) {
                ForEach(trailingPropertyList, id: \.self) { info in
                    Text(info)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundColor(.black)
                        .font(.caption)
                }
            }
            .padding([.top, .trailing], 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
    }
}
