//
//  SwiftUIAddons.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2022/12/17.
//

import SwiftUI

struct HStackLeading: ViewModifier {
    func body(content: Content) -> some View {
        HStack {
            content
            Spacer()
        }
    }
}

extension View {
    func hStackLeading() -> some View {
        modifier(HStackLeading())
    }
}

enum TitleAndSubTitleStyle {
    case substring
    case reverse
    case caption
}

struct TitleAndSubTitle: View {
    var title: String
    var subTitle: String
    var style: TitleAndSubTitleStyle

    var body: some View {
        VStack(alignment: .leading) {
            switch style {
            case .substring:
                Text(title)
                    .font(.body)
                    .bold()
                    .padding(.bottom, 1)
                Text(subTitle)
                    .font(.caption)
            case .reverse:
                Text(subTitle)
                    .foregroundColor(.secondary)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.title2)
                    .bold()
            case .caption:
                Text(title)
                    .font(.title2)
                    .bold()
                Text(subTitle)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .bold()
            }
        }
        .hStackLeading()
    }

    init(title: String, subTitle: String, style: TitleAndSubTitleStyle) {
        self.title = NSLocalizedString(title, comment: "")
        self.subTitle = NSLocalizedString(subTitle, comment: "")
        self.style = style
    }
}

struct BigButtonStyle: ButtonStyle {
    var size: CGFloat = 1.0
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background {
                RoundedRectangle(cornerRadius: 10 * size)
                    .frame(width: 250 * size, height: 50 * size)
                    .foregroundColor(.accentColor)
            }
            .padding()
    }
}

func Text(_ input: String) -> Text {
    Text(LocalizedStringKey(input))
}
