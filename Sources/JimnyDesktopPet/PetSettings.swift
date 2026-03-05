import SwiftUI
import AppKit

class PetSettings: ObservableObject {
    static let shared = PetSettings()

    // Appearance
    @Published var carWidth: CGFloat = 90
    @Published var speed: CGFloat = 2.0
    @Published var spriteFPS: Double = 10.0
    @Published var isPaused: Bool = false

    // Position (shared between animator and drag handler)
    @Published var xPosition: CGFloat = 0
    @Published var yPosition: CGFloat = 0  // 0 = bottom of screen

    // Interaction state
    @Published var isSelected: Bool = false
    @Published var isDragging: Bool = false

    // Car bounding rect in window coordinates (updated by animator each frame)
    var currentCarRect: NSRect = .zero
}
