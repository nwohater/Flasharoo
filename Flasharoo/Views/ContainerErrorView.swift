//
//  ContainerErrorView.swift
//  Flasharoo
//
//  Created by Brandon Lackey on 3/28/26.
//
//  Shown instead of RootView when the SwiftData ModelContainer fails to initialize.
//

import SwiftUI

struct ContainerErrorView: View {
    let errorMessage: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Unable to Launch")
                    .font(.largeTitle.bold())
                Text("Flasharoo could not open its database. This is usually temporary — try force-quitting and relaunching the app.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Link(destination: URL(string: "mailto:support@golackey.com?subject=Flasharoo%20Launch%20Error")!) {
                Label("Contact Support", systemImage: "envelope")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(32)
    }
}
