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

            Text("Look at something 20 feet away for 20 seconds.")
                .font(.title)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 10)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.timeRemaining / timerManager.breakDuration))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerManager.timeRemaining)

                Text("\(Int(timerManager.timeRemaining))")
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
        .ignoresSafeArea()
    }
}

/// Shows the break view on every screen except the main one.
/// The main screen uses the SwiftUI "break-overlay" window.
final class ExtraScreenOverlays {
    static let shared = ExtraScreenOverlays()
    private var windows: [NSWindow] = []

    func show(timerManager: TimerManager) {
        hide()
        for screen in NSScreen.screens where screen != NSScreen.main {
            let window = NSWindow(contentRect: screen.frame,
                                  styleMask: [.borderless],
                                  backing: .buffered,
                                  defer: false,
                                  screen: screen)
            window.level = .mainMenu + 1
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: BreakView(timerManager: timerManager))
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    func hide() {
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}

#Preview {
    BreakView(timerManager: TimerManager())
}

