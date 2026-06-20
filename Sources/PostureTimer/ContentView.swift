import SwiftUI
import Charts

struct ContentView: View {
    var model: AppModel

    var body: some View {
        VStack(spacing: 20) {
            timerSection
            controls
            postureSection
            sessionSection
        }
        .padding(24)
        .frame(width: 460)
        .onChange(of: model.settings.timerConfigToken) { _, _ in
            model.applyTimerSettings()
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        VStack(spacing: 10) {
            Text(model.mode.title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(model.timeString)
                .font(.system(size: 76, weight: .light, design: .rounded))
                .monospacedDigit()

            ProgressView(value: model.progress)

            HStack(spacing: 6) {
                ForEach(0..<model.sessionsBeforeLongBreak, id: \.self) { index in
                    Image(systemName: index < model.streakFilled ? "circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(index < model.streakFilled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Reset") { model.reset() }
            Button(model.isRunning ? "Pause" : "Start") { model.toggle() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            Button("Skip") { model.skip() }
        }
        .controlSize(.large)
        .buttonStyle(.bordered)
    }

    // MARK: - Posture

    private var postureSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(model.connection.label, systemImage: model.connection.symbol)
                        .font(.subheadline)
                        .foregroundStyle(model.connection == .denied ? .red : .secondary)
                    Spacer()
                    Button("Recalibrate") { model.recalibrate() }
                        .controlSize(.small)
                        .disabled(!model.isTracking)
                }

                HStack(spacing: 12) {
                    Image(systemName: model.postureState.symbol)
                        .font(.largeTitle)
                        .foregroundStyle(model.postureState.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.postureStatusText)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(model.postureState.color)
                        Text(model.postureDetailText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Gauge(value: model.postureScore, in: 0...100) {
                    Text("Uprightness")
                } currentValueLabel: {
                    Text("\(Int(model.postureScore))")
                }
                .tint(model.postureState.color)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Posture", systemImage: "figure.seated.side")
        }
    }

    // MARK: - Session

    private var sessionSection: some View {
        GroupBox {
            VStack(spacing: 14) {
                if model.hasSessionData {
                    Chart(model.chartSamples, id: \.elapsed) { sample in
                        AreaMark(
                            x: .value("Minute", sample.elapsed / 60),
                            y: .value("Posture", sample.score)
                        )
                        .foregroundStyle(.tint.opacity(0.15))

                        LineMark(
                            x: .value("Minute", sample.elapsed / 60),
                            y: .value("Posture", sample.score)
                        )
                        .interpolationMethod(.monotone)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxisLabel("uprightness")
                    .chartXAxisLabel("minutes")
                    .frame(height: 150)
                } else {
                    Text("Your posture trace appears here once a focus session starts.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                }

                HStack {
                    stat("Upright", model.hasSessionData ? "\(Int(model.goodFraction * 100))%" : "—")
                    Divider()
                    stat("Avg score", model.hasSessionData ? "\(Int(model.averageScore))" : "—")
                    Divider()
                    stat("Alerts", "\(model.alertCount)")
                }
                .frame(height: 42)
            }
            .padding(4)
        } label: {
            Label("This session", systemImage: "chart.xyaxis.line")
        }
    }

    private func stat(_ caption: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView(model: AppModel())
}
