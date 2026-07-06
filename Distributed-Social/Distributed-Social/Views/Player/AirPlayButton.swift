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
