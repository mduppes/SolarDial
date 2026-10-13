import Charts
import SolarDialCore
import SwiftUI

/// Today's colour temperature through the day, shaded with the colour itself.
struct DailyGraphView: View {
    let controller: TintController

    /// Headroom above the 6500 K maximum so the curve isn't drawn on the plot edge.
    private static let domain: ClosedRange<Double> = 1000...7000
    private static let gradientRange: ClosedRange<Double> = 1000...6500

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            graph(at: max(context.date, controller.settingsOpenedAt))
        }
    }

    private func graph(at now: Date) -> some View {
        let engine = controller.engine
        var timeFormat = Date.FormatStyle.dateTime.hour().minute()
        timeFormat.timeZone = engine.timeZone
        var axisFormat = Date.FormatStyle.dateTime.hour()
        axisFormat.timeZone = engine.timeZone
        let points = engine.dailyCurve(on: now, step: 600)
        let current = engine.evaluate(at: now)

        return VStack(alignment: .leading, spacing: 6) {
            Text("Now " + String(Int(current.kelvin.rounded())) + "K")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart {
                ForEach(points, id: \.date) { point in
                    AreaMark(
                        x: .value("Time", point.date),
                        yStart: .value("Kelvin", Self.domain.lowerBound),
                        yEnd: .value("Kelvin", point.result.kelvin))
                        .foregroundStyle(Self.kelvinGradient)
                        .opacity(0.85)
                    LineMark(x: .value("Time", point.date), y: .value("Kelvin", point.result.kelvin))
                        .foregroundStyle(.primary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
                .alignsMarkStylesWithPlotArea()
                if let sunrise = current.sunrise {
                    RuleMark(x: .value("Sunrise", sunrise))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(.orange.opacity(0.8))
                }
                if let sunset = current.sunset {
                    RuleMark(x: .value("Sunset", sunset))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(.orange.opacity(0.8))
                }
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(.red)
                    .annotation(position: .top, alignment: .leading) {
                        Text(now.formatted(timeFormat))
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
            }
            .chartYScale(domain: Self.domain)
            .chartXScale(domain: points.first!.date...points.last!.date)
            .chartYAxis {
                AxisMarks(values: [1000, 2500, 4000, 5500, 7000]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text(String(value.as(Int.self) ?? 0) + "K") }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: axisFormat)
                }
            }
            .frame(height: 150)
        }
        .padding(.vertical, 4)
    }

    /// Vertical gradient where each height is drawn in the colour of that temperature.
    private static let kelvinGradient: LinearGradient = {
        let span = domain.upperBound - domain.lowerBound
        let stops = stride(from: gradientRange.lowerBound, through: gradientRange.upperBound, by: 500).map { kelvin in
            let rgb = ColorTemperature.multipliers(kelvin: kelvin)
            return Gradient.Stop(
                color: Color(red: rgb.red, green: rgb.green, blue: rgb.blue),
                location: (kelvin - domain.lowerBound) / span)
        }
        return LinearGradient(gradient: Gradient(stops: stops), startPoint: .bottom, endPoint: .top)
    }()
}
