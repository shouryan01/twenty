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

    var body: some Scene {
        // The app lives only in the menu bar. The app is set as an agent
        // (LSUIElement), so it has no Dock icon.
        // The break screens are opened by BreakOverlayController.
        MenuBarExtra {
            MenuContentView(timerManager: timerManager)
        } label: {
            HStack {
                Image(systemName: timerManager.state == .breaking ? "eye.fill" : "eye")
                if timerManager.state != .idle {
                    Text(timerManager.timeFormatted)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContentView: View {
    @ObservedObject var timerManager: TimerManager

    private var statusText: String {
        switch timerManager.state {
        case .idle: return "Ready"
        case .working: return "Working"
        case .breaking: return "Break"
        }
    }

    private var ringColor: Color {
        timerManager.state == .breaking ? .green : .accentColor
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

            // Progress ring with the time
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: timerManager.state == .idle ? 1 : CGFloat(timerManager.progress))
                    .stroke(ringColor.opacity(timerManager.state == .idle ? 0.25 : 1),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: timerManager.progress)

                VStack(spacing: 2) {
                    Text(timerManager.displayTime)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

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
                Stepper(value: $timerManager.workDurationMinutes, in: 1...120, step: 1) {
                    settingLabel("Work", "\(Int(timerManager.workDurationMinutes)) min")
                }

                Stepper(value: $timerManager.breakDurationSeconds, in: 5...300, step: 5) {
                    settingLabel("Break", "\(Int(timerManager.breakDurationSeconds)) sec")
                }

                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .toggleStyle(.switch)

                Toggle("Sounds", isOn: $timerManager.soundEnabled)
                    .toggleStyle(.switch)
            }

            Divider()

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func settingLabel(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
