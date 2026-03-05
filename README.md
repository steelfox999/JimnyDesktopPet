Jimny Desktop Pet
=================

A Suzuki Jimny animated desktop pet for macOS. A tiny pixel-art Jimny drives
back and forth across the bottom of your screen, occasionally splashing through
water crossings. You can drag it around, pause it, resize it, and adjust its
speed from a settings panel.


Features
--------

- Animated sprite-based driving animation (12 frames)
- Water crossing obstacle events with bounce effect (21 frames)
- Drag-and-drop: double-click the car to pick it up, drop it anywhere
- Right-click context menu: Settings, Pause/Resume, Quit
- Floating settings panel to adjust size (40-300pt) and speed (0.5-8x)
- Runs as a menu-bar accessory app (no Dock icon)
- Overlays all windows and workspaces


Requirements
------------

- macOS 13 (Ventura) or later
- Swift 5.9 or later
- Accessibility permission (macOS will prompt on first launch)


How to Build & Run
------------------

1. Clone the repository and cd into it:

       git clone <repo-url>
       cd JimnyDesktopPet

2. Build with Swift Package Manager:

       swift build -c release

3. Run the built binary:

       .build/release/JimnyDesktopPet

   The app looks for the frames/ directory relative to the binary location or
   the current working directory. If you run from the project root, the frames
   will be found automatically.

4. macOS will ask for Accessibility permission the first time the app detects
   global mouse clicks. Grant it in System Settings > Privacy & Security >
   Accessibility.


How to Use
----------

- The Jimny drives left and right along the bottom of your screen.
- Right-click the car to open the context menu:
    - Settings... : opens a floating panel to adjust size and speed
    - Pause / Resume : stops or resumes driving
    - Quit Jimny : exits the app
- Double-click the car to grab it, then drag it anywhere on screen. Release
  the mouse button to drop it; driving resumes automatically.


How It Works (Architecture)
---------------------------

The app is a pure Swift Package Manager project with no third-party
dependencies. It uses only Apple frameworks (AppKit and SwiftUI).

Source files in Sources/JimnyDesktopPet/:

  main.swift
      App entry point. Creates an NSApplication with .accessory activation
      policy (no Dock icon), instantiates the overlay window, and starts the
      run loop.

  PetSettings.swift
      Shared singleton (ObservableObject) holding the car's position, size,
      speed, pause state, drag state, and bounding rect. Bridges data between
      the animation engine, overlay window, and settings UI.

  AnimationView.swift
      The sprite animation engine. SpriteAnimator loads PNG frames from the
      frames/ directory at startup, manages drive/water-crossing state
      transitions, and runs two timers: one for movement (60 fps) and one for
      frame cycling (~8 fps). AnimationView is the SwiftUI view that renders
      the current sprite and positions it on screen.

  OverlayWindow.swift
      A full-screen transparent NSPanel set to .floating level with
      click-through (ignoresMouseEvents). Uses NSEvent global monitors to
      detect right-clicks and double-clicks on the car. Handles drag-and-drop
      by temporarily enabling mouse events on the window. Also manages the
      right-click context menu.

  StatusBarController.swift
      Contains SettingsView (SwiftUI) and SettingsPanel (NSPanel). The
      settings panel is a floating window with sliders for car size and speed,
      a pause toggle, and a quit button.

Supporting files:

  Package.swift
      Swift PM manifest. Targets macOS 13+. Uses unsafeFlags to embed
      Info.plist into the binary via the -sectcreate linker flag.

  Info.plist
      Sets the bundle identifier and LSUIElement=true (hides Dock icon).

  frames/
      Sprite frames organized in subdirectories. Each subdirectory is an
      animation sequence loaded by name:
        frames/drive/           - 12 PNG frames for the driving animation
        frames/water_crossing/  - 21 PNG frames for the water crossing event


Adding Custom Animations
------------------------

To add a new animation sequence:

1. Create a new subdirectory under frames/ (e.g., frames/my_animation/).
2. Add numbered PNG files: frame_00.png, frame_01.png, etc.
3. The animator loads all subdirectories at startup. You can reference the
   new sequence by its directory name in the SpriteAnimator code.

The drive sequence is required. All others are optional. If water_crossing is
missing, the water crossing event is silently skipped.


Security & Privacy
------------------

This app was reviewed for security. No vulnerabilities were found.

NO NETWORK ACCESS
    The app makes zero HTTP requests, has no URL connections, no telemetry,
    no analytics, and no update checks. It is entirely offline.

NO DATA COLLECTION OR PERSISTENCE
    The app does not use UserDefaults, does not write files, does not save
    settings, and does not store any data to disk. All state exists only in
    memory while the app is running.

NO THIRD-PARTY DEPENDENCIES
    The app uses only Apple's AppKit and SwiftUI frameworks. There are no
    external packages, libraries, or SDKs.

ACCESSIBILITY PERMISSION
    The app uses NSEvent.addGlobalMonitorForEvents to detect mouse clicks on
    the car while other applications are in the foreground. This requires
    macOS Accessibility permission. The app only monitors left-click and
    right-click events and only acts when clicks land within the car's
    bounding rectangle. No keystrokes are monitored.

NOT SANDBOXED
    The app is not sandboxed, which is expected for a desktop pet that
    overlays all windows using a floating NSPanel. The only file system
    access is reading PNG sprite frames from the local frames/ directory.

NOT NOTARIZED
    Unless you notarize the build yourself, macOS Gatekeeper may block it.
    To allow it, go to System Settings > Privacy & Security and click
    "Open Anyway" after the first launch attempt, or remove the quarantine
    attribute:
        xattr -d com.apple.quarantine .build/release/JimnyDesktopPet

unsafeFlags IN PACKAGE.SWIFT
    The Package.swift uses .unsafeFlags to pass -sectcreate to the linker,
    which embeds Info.plist into the binary. The "unsafe" designation is a
    Swift Package Manager term meaning the package cannot be used as a
    dependency by other packages. It is not a security concern.

DEBUG ENTITLEMENT
    The com.apple.security.get-task-allow entitlement exists only in debug
    builds, which is standard Swift/Xcode behavior. Release builds do not
    include it.

PROVIDED AS-IS
    This software is provided as-is, without warranty of any kind. See the
    LICENSE file for full terms. You are responsible for reviewing the code
    and ensuring it meets your requirements before running it.


License
-------

This project is licensed under the MIT License. See the LICENSE file for
details.


Disclaimer: This was made with completely using Claude Code & Gemini Nano Banana 2
