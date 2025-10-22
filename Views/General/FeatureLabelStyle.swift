import SwiftUI

struct FeatureLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: 0) {
            configuration.icon
                .foregroundColor(Color.accentColor)
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 50, height: 50)
                .padding(.horizontal, 10)
            configuration.title
                .foregroundColor(.primary)
                .lineLimit(2, reservesSpace: true)
                .font(.caption)
        }
    }
}
