import SwiftUI

struct TemperatureRangeBar: View {
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 6

    let span: TemperatureSpan
    let low: Double
    let high: Double
    var currentCelsius: Double?

    var body: some View {
        GeometryReader { proxy in
            let fractions = span.fractions(low: low, high: high)
            let width = proxy.size.width
            let start = width * fractions.start
            let length = max(width * (fractions.end - fractions.start), height)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: height)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [temperatureColor(low), temperatureColor(high)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: length, height: height)
                    .offset(x: max(min(start, width - length), 0))

                if let currentCelsius {
                    Circle()
                        .fill(.white)
                        .frame(width: height + 3, height: height + 3)
                        .offset(x: (width - height - 3) * span.fraction(of: currentCelsius))
                }
            }
            .frame(height: proxy.size.height, alignment: .center)
        }
        .frame(height: height + 4)
        .accessibilityHidden(true)
    }

    private func temperatureColor(_ celsius: Double) -> Color {
        let hue = 0.58 - 0.58 * span.fraction(of: celsius)
        return Color(hue: hue, saturation: 0.85, brightness: 0.95)
    }
}
