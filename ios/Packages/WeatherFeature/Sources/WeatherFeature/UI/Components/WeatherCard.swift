import DaybookPlatform
import SwiftUI

struct WeatherCard<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.medium)
            .background(fill, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.cardStroke, lineWidth: 1))
    }

    private var fill: Color {
        reduceTransparency ? Color(red: 0.16, green: 0.24, blue: 0.38) : theme.cardFill
    }
}
