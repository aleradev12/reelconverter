import AppKit
import SwiftUI
import XCTest
@testable import ReelConverter

final class AppearanceTests: XCTestCase {
    @MainActor
    func testRenderedWindowReturnsToSystemWithoutFocusChange() async throws {
        let application = NSApplication.shared
        let original = application.appearance
        defer { application.appearance = original }
        application.appearance = NSAppearance(named: .darkAqua)
        let suite = "ReelConverterAppearanceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("system", forKey: "reelconverter.theme")
        let hosting = NSHostingView(rootView: ConverterView().defaultAppStorage(defaults))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 750, height: 595),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        let originalKeyWindow = application.keyWindow

        func capture(_ name: String) async throws -> NSColor {
            try await Task.sleep(nanoseconds: 200_000_000)
            hosting.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            if let path = ProcessInfo.processInfo.environment["REELCONVERTER_SCREENSHOT_DIRECTORY"] {
                let url = URL(fileURLWithPath: path).appendingPathComponent("\(name).png")
                try bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
            XCTAssertTrue(application.keyWindow === originalKeyWindow)
            // Left margin is the page background, not a card or control.
            return try XCTUnwrap(bitmap.colorAt(x: 5, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.deviceRGB))
        }

        let dark = try await capture("system-dark")
        XCTAssertLessThan(dark.redComponent, 0.2)
        defaults.set("light", forKey: "reelconverter.theme")
        let light = try await capture("explicit-light")
        XCTAssertGreaterThan(light.redComponent, 0.8)
        defaults.set("system", forKey: "reelconverter.theme")
        let restored = try await capture("restored-system-dark")
        XCTAssertLessThan(restored.redComponent, 0.2)
        XCTAssertEqual(restored.redComponent, dark.redComponent, accuracy: 0.02)
    }

    @MainActor
    func testReturningToSystemUsesApplicationAppearanceNotWindowOverride() {
        let application = NSApplication.shared
        let original = application.appearance
        defer { application.appearance = original }
        application.appearance = NSAppearance(named: .darkAqua)
        let appearance = SystemAppearance(application: application)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 750, height: 595),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .aqua)
        XCTAssertEqual(appearance.resolvedScheme(preference: "light"), .light)
        XCTAssertEqual(appearance.resolvedScheme(preference: "system"), .dark)
        XCTAssertEqual(appearance.resolvedScheme(preference: "dark"), .dark)
        XCTAssertEqual(appearance.resolvedScheme(preference: "system"), .dark)
        XCTAssertEqual(application.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), .darkAqua)
    }

    @MainActor
    func testSystemAppearanceChangesAreObserved() async throws {
        let application = NSApplication.shared
        let original = application.appearance
        defer { application.appearance = original }
        application.appearance = NSAppearance(named: .aqua)
        let appearance = SystemAppearance(application: application)
        XCTAssertEqual(appearance.resolvedScheme(preference: "system"), .light)
        application.appearance = NSAppearance(named: .darkAqua)
        for _ in 0..<100 where appearance.colorScheme != .dark {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(appearance.resolvedScheme(preference: "system"), .dark)
        XCTAssertEqual(appearance.resolvedScheme(preference: "light"), .light)
        application.appearance = NSAppearance(named: .aqua)
        for _ in 0..<100 where appearance.colorScheme != .light {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(appearance.resolvedScheme(preference: "system"), .light)
        XCTAssertEqual(appearance.resolvedScheme(preference: "dark"), .dark)
    }
}
