import Accessibility
import SwiftUI

struct TemperatureRangeDescriptor: AXChartDescriptorRepresentable {
    let days: [DayForecast]
    let span: TemperatureSpan
    let formatter: WeatherFormatter
    let now: Date

    func makeChartDescriptor() -> AXChartDescriptor {
        let names = days.map { formatter.spokenDayName($0.date, now: now) }

        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Day",
            categoryOrder: names
        )

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Temperature",
            range: span.minimum...max(span.maximum, span.minimum + 1),
            gridlinePositions: []
        ) { formatter.spokenTemperature($0) }

        let series = [
            AXDataSeriesDescriptor(
                name: "Low",
                isContinuous: false,
                dataPoints: zip(names, days).map { name, day in
                    AXDataPoint(x: name, y: day.lowCelsius)
                }
            ),
            AXDataSeriesDescriptor(
                name: "High",
                isContinuous: false,
                dataPoints: zip(names, days).map { name, day in
                    AXDataPoint(x: name, y: day.highCelsius)
                }
            ),
        ]

        return AXChartDescriptor(
            title: "10-day temperature range",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }

    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {}
}
