//
//  Card.swift
//  Life@USTC
//
//  Created by TiankaiMa on 2022/12/15.
//

import SwiftUI

extension String {
    func makeColor() -> Color {
        let hash = abs(self.hashValue)
        // Genrate the color from hash value
        // hue: .random(in: 0...1)
        // saturation: .random(in: 0.25...0.75)
        // brightness: .random(in: 0.45...0.55)

        let hue = Double(hash % 360) / 360
        let saturation = Double(hash % 50 + 25) / 100
        let brightness = Double(hash % 10 + 45) / 100

        return Color(uiColor: UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
    }
}

struct Card: View {
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
                .foregroundColor(cardTitle.makeColor())
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
        .frame(height:200)
        .overlay(alignment: .bottomLeading) {
            // title and subtitle
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
            // labels
            HStack {
                ForEach(leadingPropertyList, id: \.name) { property in
                    ZStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(property.color)
                        Text(property.name)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(width: 60, height: 20)
                    .padding(.leading, -5)
                }
            }
            .padding(.top, 10)
            .padding(.leading,20)
        }
        .overlay(alignment: .topTrailing) {
            // time and author info
            VStack(alignment: .trailing) {
                ForEach(trailingPropertyList, id:\.self) { info in
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
            .padding([.top,.trailing],10)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: cornerRadius))
    }
}
