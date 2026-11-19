//
//  BreakView.swift
//  twenty
//
//  Created by Shouryan Nikam on 12/27/25.
//

import SwiftUI
import AppKit

struct BreakView: View {
    @ObservedObject var timerManager: TimerManager

    var body: some View {
        VStack(spacing: 30) {
            Text("Break Time!")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)

            Text("Look at something at least 20 feet (6 m) away.")
                .font(.title)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 10)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: timerManager.progress)

                Text("\(Int(timerManager.timeRemaining))")
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .ignoresSafeArea()
    }
}

/// Shows the break screen on every screen.
/// This is the only code that opens break windows.
final class BreakOverlayController {
    static let shared = BreakOverlayController()

    private var windows: [NSWindow] = []
    private weak var timerManager: TimerManager?
    private var screenObserver: NSObjectProtocol?

    func show(timerManager: TimerManager) {
        self.timerManager = timerManager
        rebuildWindows()
        NSApplication.shared.activate(ignoringOtherApps: true)

        // If a monitor is plugged in or removed during a break, cover the new set of screens.
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.rebuildWindows()
            }
        }
    }

    func hide() {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        closeWindows()
        timerManager = nil
    }

    private func rebuildWindows() {
        closeWindows()
        guard let timerManager = timerManager else { return }

        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame,
                                  styleMask: [.borderless],
                                  backing: .buffered,
                                  defer: false,
                                  screen: screen)
            window.level = .mainMenu + 1
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: BreakView(timerManager: timerManager))
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func closeWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}

#Preview {
    BreakView(timerManager: TimerManager())
}
