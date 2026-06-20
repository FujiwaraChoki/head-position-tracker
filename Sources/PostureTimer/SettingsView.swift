import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings

    var body: some View {
        Form {
            Section("Timer") {
                Stepper("Focus: \(Int(settings.focusMinutes)) min",
                        value: $settings.focusMinutes, in: 1...120)
                Stepper("Short break: \(Int(settings.shortBreakMinutes)) min",
                        value: $settings.shortBreakMinutes, in: 1...60)
                Stepper("Long break: \(Int(settings.longBreakMinutes)) min",
                        value: $settings.longBreakMinutes, in: 1...60)
                Stepper("Sessions before long break: \(settings.sessionsBeforeLongBreak)",
                        value: $settings.sessionsBeforeLongBreak, in: 1...12)
            }

            Section {
                slider("Drifting threshold", value: $settings.fairThresholdDeg,
                       range: 3...30, unit: "°", format: "%.0f")
                slider("Slouch threshold", value: $settings.poorThresholdDeg,
                       range: 5...40, unit: "°", format: "%.0f")
                slider("Calibration time", value: $settings.calibrationSeconds,
                       range: 1...5, step: 0.5, unit: "s", format: "%.1f")
                Toggle("Flip slouch direction", isOn: $settings.invertPitch)
            } header: {
                Text("Posture")
            } footer: {
                Text("How far your head can drop below the calibrated upright baseline before it counts as drifting or slouching. Turn on “Flip” if leaning back is wrongly flagged as a slouch.")
            }

            Section {
                slider("Wait before alerting", value: $settings.slouchGraceSeconds,
                       range: 1...20, unit: "s", format: "%.0f")
                slider("Cooldown between alerts", value: $settings.alertCooldownSeconds,
                       range: 5...120, step: 5, unit: "s", format: "%.0f")
                Toggle("Play sound", isOn: $settings.soundEnabled)
                Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
                Toggle("System notification", isOn: $settings.notificationsEnabled)
            } header: {
                Text("Alerts")
            }

            Section {
                Button("Restore Defaults") { settings.restoreDefaults() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 580)
    }

    @ViewBuilder
    private func slider(_ title: String, value: Binding<Double>,
                        range: ClosedRange<Double>, step: Double = 1,
                        unit: String, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue) + unit)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }
}

#Preview {
    SettingsView(settings: Settings())
}
