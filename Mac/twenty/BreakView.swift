//
//  BreakView.swift
//  twenty
//
//  Created by Shouryan Nikam on 12/27/25.
//

import SwiftUI

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

#Preview {
    BreakView(timerManager: TimerManager())
}

