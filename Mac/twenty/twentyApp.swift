//
//  twentyApp.swift
//  twenty
//
//  Created by Shouryan Nikam on 12/27/25.
//

import SwiftUI

@main
struct twentyApp: App {
    @StateObject private var timerManager = TimerManager()

    init() {
        // Keep the app menu-bar-only with no Dock icon, matching the existing version.
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        // The app lives only in the menu bar. The app is set as an agent
        // (LSUIElement), so it has no Dock icon.
        // The break screens are opened by BreakOverlayController.
        MenuBarExtra {
            MenuContentView(timerManager: timerManager)
        } label: {
            Image(systemName: timerManager.state == .breaking ? "eye.fill" : "eye")
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContentView: View {
    @ObservedObject var timerManager: TimerManager
    @State private var isHoveringQuit = false

    private var statusText: String {
        switch timerManager.state {
        case .idle: return "Ready"
        case .working: return "Working"
        case .breaking: return "Break"
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { timerManager.launchAtLogin },
            set: { timerManager.setLaunchAtLogin($0) }
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Text("twenty")
                    .font(.headline)
                Text("👀")
                Spacer()
            }

            // Bold countdown timer matching Windows
            VStack(spacing: 4) {
                Text(statusText)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Text(timerManager.displayTime)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.vertical, 6)

            Button(action: {
                if timerManager.state == .idle {
                    timerManager.start()
                } else {
                    timerManager.stop()
                }
            }) {
                Label(timerManager.state == .idle ? "Start" : "Stop",
                      systemImage: timerManager.state == .idle ? "play.fill" : "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(timerManager.state == .idle ? .accentColor : .red)

            Divider()

            // Settings
            VStack(spacing: 10) {
                durationRow(
                    title: "Work",
                    unit: "min",
                    value: $timerManager.workDurationMinutes,
                    range: 1...120,
                    step: 1
                )

                durationRow(
                    title: "Break",
                    unit: "sec",
                    value: $timerManager.breakDurationSeconds,
                    range: 1...300,
                    step: 5
                )

                Divider()
                    .padding(.vertical, 2)

                toggleRow("Launch at login", isOn: launchAtLoginBinding)

                toggleRow("Sounds", isOn: $timerManager.soundEnabled)

                soundRow("Break start", selection: $timerManager.breakStartSound)
                    .disabled(!timerManager.soundEnabled)
                    .opacity(timerManager.soundEnabled ? 1 : 0.45)

                soundRow("Break end", selection: $timerManager.breakEndSound)
                    .disabled(!timerManager.soundEnabled)
                    .opacity(timerManager.soundEnabled ? 1 : 0.45)
            }
            .padding(12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

            Divider()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .foregroundStyle(isHoveringQuit ? Color.red : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHoveringQuit ? Color.red.opacity(0.12) : Color.clear)
                )
                .onHover { isHoveringQuit = $0 }
                .animation(.easeInOut(duration: 0.12), value: isHoveringQuit)
            }
        }
        .padding(16)
        .frame(width: 260)
        .background(.ultraThickMaterial)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))
    }

    private func durationRow(
        title: String,
        unit: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Spacer()
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 44)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .onSubmit {
                    timerManager.clampSettings()
                }
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private func soundRow(_ title: String, selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(TimerManager.availableSounds, id: \.self) { sound in
                    Text(sound).tag(sound)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 110)
            .onChange(of: selection.wrappedValue) { _, newValue in
                timerManager.previewSound(newValue)
            }
        }
    }
}
