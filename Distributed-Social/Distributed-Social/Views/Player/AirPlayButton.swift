//
//  AirPlayButton.swift
//  Distributed-Social
//
//  System AirPlay route picker, themed to match the player header.
//

import SwiftUI
import AVKit

struct AirPlayButton: UIViewRepresentable {
    let tint: Color

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor(tint)
        picker.activeTintColor = UIColor(tint)
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(tint)
        uiView.activeTintColor = UIColor(tint)
    }
}

/// Zero-size UIViewRepresentable that holds an AVRoutePickerView and fires it
/// when `trigger` flips to true — lets us put "AirPlay" inside a SwiftUI Menu.
struct AirPlayTriggerView: UIViewRepresentable {
    @Binding var trigger: Bool

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.alpha = 0.001
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        guard trigger else { return }
        DispatchQueue.main.async {
            for sub in uiView.subviews {
                if let btn = sub as? UIButton {
                    btn.sendActions(for: .touchUpInside)
                    break
                }
            }
            trigger = false
        }
    }
}
