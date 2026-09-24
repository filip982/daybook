import DaybookPlatform
import SwiftUI

struct LocationNotAskedView: View {
    let onAllowLocation: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Weather where you are", systemImage: "location.circle")
        } description: {
            Text("Daybook uses your location to show the forecast for the place you are in right now.")
        } actions: {
            Button("Allow Location", action: onAllowLocation)
                .buttonStyle(.weatherAction)
        }
    }
}

struct LocationDeniedView: View {
    let onOpenSettings: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Location is off", systemImage: "location.slash")
        } description: {
            Text("Saved cities still work. Turn location on in Settings to see the weather where you are.")
        } actions: {
            Button("Open Settings", action: onOpenSettings)
                .buttonStyle(.weatherAction)
        }
    }
}

struct WeatherLoadingView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ProgressView {
            Text("Loading forecast")
        }
        .progressViewStyle(.circular)
        .controlSize(.large)
        .tint(.white)
        .padding(theme.spacing.large)
    }
}

struct WeatherFailedView: View {
    let error: WeatherError
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbolName)
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.weatherAction)
        }
    }

    private var title: String {
        switch error {
        case .offline: "No connection"
        case .server: "Weather service unavailable"
        case .decoding: "Unexpected forecast"
        case .notFound: "No forecast for this place"
        }
    }

    private var message: String {
        switch error {
        case .offline: "Daybook could not reach the weather service. Check your connection and try again."
        case .server: "The weather service is not responding right now. Try again in a moment."
        case .decoding: "The forecast came back in a form Daybook does not understand."
        case .notFound: "There is no forecast available for this location."
        }
    }

    private var symbolName: String {
        switch error {
        case .offline: "wifi.slash"
        case .server: "exclamationmark.icloud"
        case .decoding: "questionmark.circle"
        case .notFound: "mappin.slash"
        }
    }
}

struct WeatherActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(red: 0.11, green: 0.24, blue: 0.45))
            .padding(.horizontal, 20)
            .frame(minWidth: 44, minHeight: 44)
            .background(.white, in: .capsule)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
    }
}

extension ButtonStyle where Self == WeatherActionButtonStyle {
    static var weatherAction: Self { WeatherActionButtonStyle() }
}
