import Charts
import FluxCore
import SwiftUI

/// Today's colour temperature through the day, shaded with the colour itself.
struct DailyGraphView: View {
    let controller: TintController

    private static let domain: ClosedRange<Double> = 1000...6500

    var body: some View {
        let engine = controller.engine
        let now = Date()
        let points = engine.dailyCurve(on: now, step: 600)
        let current = engine.evaluate(at: now)

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
                    .foregroundStyle(.secondary)
            }
            if let sunset = current.sunset {
                RuleMark(x: .value("Sunset", sunset))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.secondary)
            }
            RuleMark(x: .value("Now", now))
                .foregroundStyle(.red)
                .annotation(position: .top, alignment: .center) {
                    Text("\(Int(current.kelvin.rounded()))K")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
        .chartYScale(domain: Self.domain)
        .chartYAxis {
            AxisMarks(values: [1000, 2000, 3000, 4000, 5000, 6500]) { value in
                AxisGridLine()
                AxisValueLabel { Text("\(value.as(Int.self) ?? 0)K") }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .frame(height: 150)
    }

    /// Vertical gradient where each height is drawn in the colour of that temperature.
    private static let kelvinGradient: LinearGradient = {
        let stops = stride(from: domain.lowerBound, through: domain.upperBound, by: 500).map { kelvin in
            let rgb = ColorTemperature.multipliers(kelvin: kelvin)
            return Gradient.Stop(
                color: Color(red: rgb.red, green: rgb.green, blue: rgb.blue),
                location: (kelvin - domain.lowerBound) / (domain.upperBound - domain.lowerBound))
        }
        return LinearGradient(gradient: Gradient(stops: stops), startPoint: .bottom, endPoint: .top)
    }()
}
