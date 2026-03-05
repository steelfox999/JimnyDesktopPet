import AppKit
import SwiftUI

class OverlayWindow: NSPanel, NSMenuDelegate {
    private var globalClickMonitor: Any?
    private var globalMoveMonitor: Any?
    private var localDragMonitor: Any?
    private var carOffsetFromMouse: NSPoint = .zero

    init() {
        guard let screen = NSScreen.main else {
            fatalError("No screen available")
        }

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true  // pass-through by default
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.hidesOnDeactivate = false

        let hostingView = NSHostingView(rootView: AnimationView())
        hostingView.frame = self.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(hostingView)

        setupEventMonitors()
    }

    private func isPointOnCar(_ screenPoint: NSPoint) -> Bool {
        // Convert screen coordinates to window coordinates
        let windowPoint = NSPoint(
            x: screenPoint.x - self.frame.origin.x,
            y: screenPoint.y - self.frame.origin.y
        )
        let carRect = PetSettings.shared.currentCarRect.insetBy(dx: -10, dy: -10)
        return carRect.contains(windowPoint)
    }

    private func setupEventMonitors() {
        // Monitor global clicks (right-click for menu, double-click for drag)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self = self else { return }
            let screenPoint = NSEvent.mouseLocation

            guard self.isPointOnCar(screenPoint) else { return }

            if event.type == .rightMouseDown {
                self.showContextMenu(at: screenPoint)
            } else if event.type == .leftMouseDown && event.clickCount >= 2 {
                self.beginDrag(at: screenPoint)
            }
        }
    }

    private func showContextMenu(at screenPoint: NSPoint) {
        let menu = NSMenu()
        menu.delegate = self

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let pauseTitle = PetSettings.shared.isPaused ? "Resume" : "Pause"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Jimny", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Temporarily enable mouse events and activate app so menu stays open
        self.ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSPoint(
            x: screenPoint.x - self.frame.origin.x,
            y: screenPoint.y - self.frame.origin.y
        ), in: self.contentView)
    }

    private func beginDrag(at screenPoint: NSPoint) {
        let settings = PetSettings.shared
        settings.isSelected = true
        settings.isPaused = true

        let windowPoint = NSPoint(
            x: screenPoint.x - self.frame.origin.x,
            y: screenPoint.y - self.frame.origin.y
        )
        carOffsetFromMouse = NSPoint(
            x: windowPoint.x - settings.currentCarRect.origin.x,
            y: windowPoint.y - settings.currentCarRect.origin.y
        )

        // Enable mouse events for dragging
        self.ignoresMouseEvents = false

        // Monitor drag and mouse-up using local monitors (window now accepts events)
        localDragMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            guard let self = self else { return event }

            if event.type == .leftMouseDragged {
                let screenPt = NSEvent.mouseLocation
                let windowPt = NSPoint(
                    x: screenPt.x - self.frame.origin.x,
                    y: screenPt.y - self.frame.origin.y
                )
                DispatchQueue.main.async {
                    settings.isDragging = true
                    settings.xPosition = windowPt.x - self.carOffsetFromMouse.x
                    settings.yPosition = windowPt.y - self.carOffsetFromMouse.y
                }
                return nil  // consume the event
            }

            if event.type == .leftMouseUp {
                self.endDrag()
                return nil
            }

            return event
        }
    }

    private func endDrag() {
        let settings = PetSettings.shared
        settings.isSelected = false
        settings.isDragging = false
        settings.isPaused = false

        // Restore click-through
        self.ignoresMouseEvents = true

        // Remove local drag monitor
        if let monitor = localDragMonitor {
            NSEvent.removeMonitor(monitor)
            localDragMonitor = nil
        }
    }

    @objc private func openSettings() {
        SettingsPanel.shared.showCentered()
    }

    @objc private func togglePause() {
        PetSettings.shared.isPaused.toggle()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        self.ignoresMouseEvents = true
    }

    deinit {
        if let m = globalClickMonitor { NSEvent.removeMonitor(m) }
        if let m = globalMoveMonitor { NSEvent.removeMonitor(m) }
        if let m = localDragMonitor { NSEvent.removeMonitor(m) }
    }
}
