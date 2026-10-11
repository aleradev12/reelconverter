import AppKit
import SwiftUI

/// Observe the application's inherited appearance, not a window's overridden
/// SwiftUI environment. Returning to System must not reuse the previous override.
@MainActor
final class SystemAppearance: ObservableObject {
    @Published private(set) var colorScheme: ColorScheme
    private var observation: NSKeyValueObservation?

    init(application: NSApplication? = nil) {
        let application = application ?? .shared
        colorScheme = Self.scheme(for: application.effectiveAppearance)
        observation = application.observe(\.effectiveAppearance, options: [.new]) { [weak self] application, _ in
            Task { @MainActor [weak self] in
                self?.colorScheme = Self.scheme(for: application.effectiveAppearance)
            }
        }
    }

    static func scheme(for appearance: NSAppearance) -> ColorScheme {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }

    func resolvedScheme(preference: String) -> ColorScheme {
        switch preference {
        case "dark": .dark
        case "light": .light
        default: colorScheme
        }
    }
}
