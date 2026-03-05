import SwiftUI
import AppKit

struct AnimationSequence {
    let frames: [NSImage]
}

enum PetState {
    case driving
    case waterCrossing(frameIndex: Int)
}

class SpriteAnimator: ObservableObject {
    @Published var currentFrame: Int = 0
    @Published var movingRight: Bool = true
    @Published var state: PetState = .driving
    @Published var verticalOffset: CGFloat = 0

    let sequences: [String: AnimationSequence]
    let settings = PetSettings.shared

    private var moveTimer: Timer?
    private var frameTimer: Timer?
    private var nextObstacleTime: TimeInterval = 0

    init() {
        var loaded: [String: AnimationSequence] = [:]
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
        let candidates = [
            execURL.deletingLastPathComponent().appendingPathComponent("frames"),
            execURL.deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("frames"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("frames"),
        ]

        var framesDir: URL?
        for candidate in candidates {
            let testFile = candidate.appendingPathComponent("drive").appendingPathComponent("frame_00.png")
            if FileManager.default.fileExists(atPath: testFile.path) {
                framesDir = candidate
                break
            }
        }

        if let framesDir = framesDir {
            let fm = FileManager.default
            if let subdirs = try? fm.contentsOfDirectory(atPath: framesDir.path) {
                for subdir in subdirs {
                    let subdirURL = framesDir.appendingPathComponent(subdir)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: subdirURL.path, isDirectory: &isDir), isDir.boolValue else { continue }

                    var frames: [NSImage] = []
                    if let files = try? fm.contentsOfDirectory(atPath: subdirURL.path) {
                        let pngFiles = files.filter { $0.hasSuffix(".png") }.sorted()
                        for file in pngFiles {
                            let path = subdirURL.appendingPathComponent(file)
                            if let img = NSImage(contentsOf: path) {
                                frames.append(img)
                            }
                        }
                    }
                    if !frames.isEmpty {
                        loaded[subdir] = AnimationSequence(frames: frames)
                    }
                }
            }
        }

        if loaded["drive"] == nil {
            let placeholder = NSImage(size: NSSize(width: 180, height: 137))
            loaded["drive"] = AnimationSequence(frames: [placeholder])
        }

        self.sequences = loaded
        self.nextObstacleTime = Self.randomObstacleDelay()
    }

    private static func randomObstacleDelay() -> TimeInterval {
        return TimeInterval.random(in: 3.0...8.0)
    }

    var currentImage: NSImage {
        switch state {
        case .driving:
            let driveFrames = sequences["drive"]!.frames
            return driveFrames[currentFrame % driveFrames.count]
        case .waterCrossing(let frameIndex):
            guard let seq = sequences["water_crossing"] else {
                return sequences["drive"]!.frames[0]
            }
            return seq.frames[min(frameIndex, seq.frames.count - 1)]
        }
    }

    /// Drive aspect ratio — used for hit-testing and base car height
    var driveAspect: CGFloat {
        let img = sequences["drive"]!.frames[0]
        return img.size.width > 0 ? img.size.height / img.size.width : 137.0 / 180.0
    }

    /// Current frame's aspect ratio — used for rendering so frames aren't squished
    var currentAspect: CGFloat {
        let img = currentImage
        return img.size.width > 0 ? img.size.height / img.size.width : driveAspect
    }

    func start(screenWidth: CGFloat) {
        moveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let s = self.settings
                if s.isPaused || s.isDragging { return }

                let carW = s.carWidth
                let isWater: Bool
                if case .waterCrossing = self.state { isWater = true } else { isWater = false }
                let spd = isWater ? s.speed * 0.35 : s.speed

                if self.movingRight {
                    s.xPosition += spd
                    if s.xPosition + carW >= screenWidth {
                        self.movingRight = false
                    }
                } else {
                    s.xPosition -= spd
                    if s.xPosition <= 0 {
                        self.movingRight = true
                    }
                }

                if case .driving = self.state {
                    self.nextObstacleTime -= 1.0 / 60.0
                    if self.nextObstacleTime <= 0 {
                        self.triggerWaterCrossing()
                    }
                    self.verticalOffset = 0
                } else {
                    let bounce = sin(Date().timeIntervalSinceReferenceDate * 8) * 2
                    self.verticalOffset = bounce
                }

                let carH = carW * self.driveAspect
                s.currentCarRect = NSRect(
                    x: s.xPosition,
                    y: s.yPosition,
                    width: carW,
                    height: carH
                )
            }
        }

        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.125, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.settings.isPaused && !self.settings.isSelected { return }

                switch self.state {
                case .driving:
                    let driveFrames = self.sequences["drive"]!.frames
                    self.currentFrame = (self.currentFrame + 1) % driveFrames.count

                case .waterCrossing(let frameIndex):
                    guard let seq = self.sequences["water_crossing"] else {
                        self.finishWaterCrossing()
                        return
                    }
                    let nextIdx = frameIndex + 1
                    if nextIdx >= seq.frames.count {
                        self.finishWaterCrossing()
                    } else {
                        self.state = .waterCrossing(frameIndex: nextIdx)
                    }
                }
            }
        }
    }

    private func triggerWaterCrossing() {
        guard sequences["water_crossing"] != nil else {
            nextObstacleTime = Self.randomObstacleDelay()
            return
        }
        state = .waterCrossing(frameIndex: 0)
    }

    private func finishWaterCrossing() {
        state = .driving
        currentFrame = 0
        verticalOffset = 0
        nextObstacleTime = Self.randomObstacleDelay()
    }

    func stop() {
        moveTimer?.invalidate()
        frameTimer?.invalidate()
    }
}

struct AnimationView: View {
    @StateObject private var animator = SpriteAnimator()
    @ObservedObject private var settings = PetSettings.shared

    var body: some View {
        GeometryReader { geo in
            let img = animator.currentImage
            let carW = settings.carWidth
            let driveH = carW * animator.driveAspect
            let frameH = carW * animator.currentAspect

            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .frame(width: carW, height: frameH)
                .scaleEffect(x: animator.movingRight ? 1 : -1, y: 1)
                .overlay(
                    Group {
                        if settings.isSelected {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.blue, lineWidth: 2)
                                .frame(width: carW, height: driveH)
                        }
                    },
                    alignment: .top
                )
                // Anchor car top: keep top edge fixed, water extends downward
                .position(
                    x: settings.xPosition + carW / 2,
                    y: geo.size.height - settings.yPosition - driveH + frameH / 2
                        + animator.verticalOffset
                )
                .onAppear {
                    let carH = carW * animator.driveAspect
                    settings.currentCarRect = NSRect(
                        x: settings.xPosition,
                        y: settings.yPosition,
                        width: carW,
                        height: carH
                    )
                    animator.start(screenWidth: geo.size.width)
                }
                .onDisappear {
                    animator.stop()
                }
        }
    }
}
