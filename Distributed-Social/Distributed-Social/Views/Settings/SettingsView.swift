//
//  SettingsView.swift
//  Distributed-Social
//

import SwiftUI

struct SettingsView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Link(destination: URL(string: Constants.Links.repository)!) {
                        Label("GitHub Repository", systemImage: "link")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .summerBackground()
            .navigationTitle("Settings")
        }
    }
}
