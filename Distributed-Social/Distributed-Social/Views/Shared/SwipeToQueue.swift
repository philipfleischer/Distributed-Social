//
//  SwipeToQueue.swift
//  Distributed-Social
//
//  "Swipe right to queue" for library rows. The system leading swipe action
//  parks a tappable button when the swipe stops halfway — this modifier
//  instead queues the song as soon as a short rightward drag is released
//  past the threshold, and the row always springs straight back.
//

import SwiftUI

struct SwipeToQueueModifier: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    /// Drag distance after which releasing queues the song.
    private static let threshold: CGFloat = 70

    /// @GestureState so the row snaps back automatically even when the
    /// system cancels the gesture (e.g. the list starts scrolling).
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.3)))
    private var offsetX: CGFloat = 0
    /// Tracks the threshold crossing so the "release to queue" haptic fires
    /// exactly once per drag.
    @State private var hasPassedThreshold = false

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .background(alignment: .leading) {
                if offsetX > 0 {
                    Image(systemName: "text.append")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(
                            Circle().fill(Color.green.opacity(offsetX >= Self.threshold ? 1 : 0.45))
                        )
                        .opacity(min(1, offsetX / Self.threshold))
                        .padding(.leading, 2)
                }
            }
            // simultaneousGesture: an exclusive .gesture claims leftward
            // drags too (even though we ignore them), which blocked the
            // List's trailing swipe-to-delete. Simultaneous lets the system
            // swipe run; we only ever react to rightward drags.
            .simultaneousGesture(drag, including: isEnabled ? .all : .subviews)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($offsetX) { value, state, _ in
                state = Self.dragOffset(for: value)
            }
            .onChanged { value in
                let passed = Self.dragOffset(for: value) >= Self.threshold
                if passed != hasPassedThreshold {
                    hasPassedThreshold = passed
                    if passed { Haptics.medium() }
                }
            }
            .onEnded { value in
                hasPassedThreshold = false
                if Self.dragOffset(for: value) >= Self.threshold {
                    action()
                }
            }
    }

    /// Rightward, horizontally dominant drags only; rubber-bands past the
    /// threshold so the row doesn't fly across the screen.
    private static func dragOffset(for value: DragGesture.Value) -> CGFloat {
        let w = value.translation.width
        guard w > 0, w > abs(value.translation.height) else { return 0 }
        return w <= threshold ? w : threshold + (w - threshold) / 3
    }
}

extension View {
    /// Queues on a short rightward drag (released past the threshold) with
    /// no revealed-button state — see SwipeToQueueModifier.
    func swipeToQueue(enabled: Bool = true, action: @escaping () -> Void) -> some View {
        modifier(SwipeToQueueModifier(isEnabled: enabled, action: action))
    }
}
