import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = PetSettings.shared
    var quitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Jimny Desktop Pet")
                .font(.headline)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Size: \(Int(settings.carWidth))pt")
                    .font(.caption)
                Slider(value: $settings.carWidth, in: 40...300, step: 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Speed: \(String(format: "%.1f", settings.speed))")
                    .font(.caption)
                Slider(value: $settings.speed, in: 0.5...8.0, step: 0.5)
            }

            Toggle("Paused", isOn: $settings.isPaused)

            Divider()

            Button("Quit") {
                quitAction()
            }
        }
        .padding(16)
        .frame(width: 220)
    }
}

/// Floating settings panel — opened via right-click context menu on the car.
class SettingsPanel: NSPanel {
    static let shared = SettingsPanel()

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 280),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.title = "Jimny Settings"
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.contentView = NSHostingView(
            rootView: SettingsView(quitAction: {
                NSApplication.shared.terminate(nil)
            })
        )
    }

    func showCentered() {
        self.center()
        self.orderFront(nil)
    }
}
