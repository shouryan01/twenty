//
//  TimerManager.swift
//  twenty
//
//  Created by Shouryan Nikam on 12/27/25.
//

import Foundation
import SwiftUI
import AppKit

enum TimerState {
    case idle
    case working
    case breaking
}

class TimerManager: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var timeRemaining: TimeInterval = 0

    // User settings (stored in UserDefaults for persistence)
    @AppStorage("workDurationMinutes") var workDurationMinutes: Double = 20
    @AppStorage("breakDurationSeconds") var breakDurationSeconds: Double = 20

    private var timer: Timer?

    var workDuration: TimeInterval { workDurationMinutes * 60 }
    var breakDuration: TimeInterval { breakDurationSeconds }

    func start() {
        startWork(playSound: false)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        timeRemaining = 0
    }

    private func startWork(playSound: Bool = true) {
        if playSound && state == .breaking {
            NSSound(named: "Glass")?.play()
        }
        state = .working
        timeRemaining = workDuration
        runTimer()
    }

    private func startBreak() {
        NSSound(named: "Bottle")?.play()
        state = .breaking
        timeRemaining = breakDuration
        runTimer()
    }

    private func runTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timer?.invalidate()
                self.timer = nil

                if self.state == .working {
                    self.startBreak()
                } else if self.state == .breaking {
                    self.startWork()
                }
            }
        }
    }

    var timeFormatted: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

