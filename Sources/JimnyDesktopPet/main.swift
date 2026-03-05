import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var overlayWindow: OverlayWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayWindow = OverlayWindow()
        overlayWindow.orderFront(nil)
    }
}

let appDelegate = AppDelegate()
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = appDelegate
app.run()
