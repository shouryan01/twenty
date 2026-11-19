//
//  TimerManager.swift
//  twenty
//
//  Created by Shouryan Nikam on 12/27/25.
//

import Foundation
import SwiftUI
import AppKit
import ServiceManagement

enum TimerState {
    case idle
    case working
    case breaking
}

class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var timeRemaining: TimeInterval = 0
    @Published private(set) var phaseLength: TimeInterval = 1

    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    // User settings (stored in UserDefaults for persistence)
    @AppStorage("workDurationMinutes") var workDurationMinutes: Double = 20
    @AppStorage("workDurationSeconds") var workDurationSeconds: Double = 10
    @AppStorage("workUseSeconds") var workUseSeconds: Bool = false
    @AppStorage("breakDurationSeconds") var breakDurationSeconds: Double = 20
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("breakStartSound") var breakStartSound: String = "Bottle"
    @AppStorage("breakEndSound") var breakEndSound: String = "Glass"

    private var timer: Timer?
    private var phaseEnd = Date()

    // Values are clamped so a bad setting can never give a zero or negative duration.
    var workDuration: TimeInterval {
        if workUseSeconds {
            return min(max(workDurationSeconds, 1), 7200)
        }
        return min(max(workDurationMinutes, 1), 120) * 60
    }
    var breakDuration: TimeInterval { min(max(breakDurationSeconds, 1), 300) }

    func clampSettings() {
        workDurationMinutes = min(max(workDurationMinutes.rounded(), 1), 120)
        workDurationSeconds = min(max(workDurationSeconds.rounded(), 1), 7200)
        breakDurationSeconds = min(max(breakDurationSeconds.rounded(), 1), 300)
    }

    init() {
        // After the Mac wakes from sleep, the time away counts as a rest.
        // Start a new work period so the timer is not wrong.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.state != .idle else { return }
            self.startWork(playSound: false)
        }

        // If the app starts at login, start the timer too.
        if launchAtLogin {
            start()
        }
    }

    // MARK: - Control

    func start() {
        clampSettings()
        startWork(playSound: false)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        timeRemaining = 0
        BreakOverlayController.shared.hide()
    }

    private func startWork(playSound: Bool = true) {
        if playSound && state == .breaking {
            play(breakEndSound)
        }
        BreakOverlayController.shared.hide()
        begin(.working, length: workDuration)
    }

    private func startBreak() {
        play(breakStartSound)
        begin(.breaking, length: breakDuration)
        BreakOverlayController.shared.show(timerManager: self)
    }

    private func begin(_ newState: TimerState, length: TimeInterval) {
        state = newState
        phaseLength = length
        phaseEnd = Date().addingTimeInterval(length)
        timeRemaining = length
        runTimer()
    }

    private func runTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps the timer running while menus or other UI are tracking.
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func tick() {
        // The remaining time comes from an end date, so it stays correct
        // even if a tick is late.
        let remaining = phaseEnd.timeIntervalSinceNow
        if remaining > 0 {
            timeRemaining = remaining.rounded(.up)
            return
        }

        timer?.invalidate()
        timer = nil
        if state == .working {
            startBreak()
        } else if state == .breaking {
            startWork()
        }
    }

    func previewSound(_ name: String) {
        NSSound(named: name)?.play()
    }

    private func play(_ name: String) {
        guard soundEnabled else { return }
        NSSound(named: name)?.play()
    }

    // MARK: - Display

    /// Progress from 1 (full) to 0 (done) for the current phase.
    var progress: Double {
        guard phaseLength > 0 else { return 0 }
        return min(max(timeRemaining / phaseLength, 0), 1)
    }

    /// The time shown in the popover. When idle, it shows the work duration.
    var displayTime: String {
        format(state == .idle ? workDuration : timeRemaining)
    }

    /// The time shown in the menu bar. It is only used while running.
    var timeFormatted: String {
        format(timeRemaining)
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("twenty: could not change launch at login: \(error.localizedDescription)")
        }
        // Refresh the switch so it shows the real state.
        objectWillChange.send()
    }
}
