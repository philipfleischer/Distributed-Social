import SwiftUI

private class NavFinderView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Walk the responder chain to find the UINavigationController and
        // disable its interactive pop gesture. Called after the view is fully
        // embedded in the hierarchy, so the nav controller is always present.
        DispatchQueue.main.async { self.disablePopGesture() }
    }

    private func disablePopGesture() {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let nav = next as? UINavigationController {
                nav.interactivePopGestureRecognizer?.isEnabled = false
                return
            }
            responder = next
        }
    }
}

private struct SwipeBackDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { NavFinderView() }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    func disableSwipeBack() -> some View {
        background(SwipeBackDisabler())
    }
}
