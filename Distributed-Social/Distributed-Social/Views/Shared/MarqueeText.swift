//
//  MarqueeText.swift
//  Distributed-Social
//
//  Single-line text that stays within its container width. If the text is
//  wider than the container it slowly slides back and forth so the whole
//  string is readable without growing the layout.
//

import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font = .headline
    var color: Color = .skyBlue

    @State private var textWidth: CGFloat = 0
    @State private var offsetX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { textGeo in
                        Color.clear.onAppear {
                            textWidth = textGeo.size.width
                            startSlidingIfNeeded(containerWidth: geo.size.width)
                        }
                    }
                )
                .offset(x: offsetX)
                .frame(maxHeight: .infinity, alignment: .leading)
                .onAppear { startSlidingIfNeeded(containerWidth: geo.size.width) }
                .onDisappear { stopSliding() }
        }
        .frame(height: 22)
        .clipped()
    }

    private func startSlidingIfNeeded(containerWidth: CGFloat) {
        let overflow = textWidth - containerWidth
        // offsetX != 0 means the slide is already running.
        guard overflow > 0, offsetX == 0 else { return }
        // Slide speed scales with how much text is hidden.
        withAnimation(
            .linear(duration: Double(overflow) / 20)
            .repeatForever(autoreverses: true)
            .delay(1.5)
        ) {
            offsetX = -overflow
        }
    }

    /// Cancels the repeat-forever slide when the view scrolls off screen —
    /// an endless animation on an invisible view keeps the render loop
    /// awake and drains the battery.
    private func stopSliding() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { offsetX = 0 }
    }
}
