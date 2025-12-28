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
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    init() {
        // Use a slight delay to ensure NSApplication.shared is ready
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        // The Menu Bar Extra
        MenuBarExtra {
            VStack(spacing: 15) {
                Text("twenty 👀")
                    .font(.headline)

                Text(timerManager.state == .working ? "Working: \(timerManager.timeFormatted)" : (timerManager.state == .breaking ? "Break: \(timerManager.timeFormatted)" : "Idle"))
                    .font(.system(.title3, design: .monospaced))

                Divider()

                if timerManager.state == .idle {
                    Button(action: {
                        timerManager.start()
                    }) {
                        Label("Start Timer", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: {
                        timerManager.stop()
                    }) {
                        Label("Stop Timer", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Divider()

                // Duration Settings
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Work (min):")
                        Spacer()
                        TextField("", value: $timerManager.workDurationMinutes, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("Break (sec):")
                        Spacer()
                        TextField("", value: $timerManager.breakDurationSeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.horizontal)

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            .frame(width: 220)
        } label: {
            HStack {
                Image(systemName: timerManager.state == .breaking ? "eye.fill" : "eye")
                if timerManager.state != .idle {
                    Text(timerManager.timeFormatted)
                }
            }
        }
        .menuBarExtraStyle(.window)

        // Break Overlay Window (kept for the 20-second break)
        Window("Break Time", id: "break-overlay") {
            BreakView(timerManager: timerManager)
                .onAppear {
                    // Make the break window float above everything and be full screen
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "Break Time" }) {
                        window.level = .mainMenu + 1
                        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                        window.backgroundColor = .clear
                        window.isOpaque = false
                        window.hasShadow = false
                        window.titleVisibility = .hidden
                        window.titlebarAppearsTransparent = true
                        window.styleMask = [.borderless, .fullSizeContentView]

                        if let screen = NSScreen.main {
                            window.setFrame(screen.frame, display: true)
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .onChange(of: timerManager.state) { oldState, newState in
            if newState == .breaking {
                openWindow(id: "break-overlay")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } else if oldState == .breaking {
                dismissWindow(id: "break-overlay")
            }
        }
    }
}
