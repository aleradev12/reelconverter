import Darwin
import Foundation
import XCTest
@testable import ReelConverter

final class OutputFileTests: XCTestCase {
    private var directory: URL!
    private let manager = FileManager.default

    override func setUpWithError() throws {
        let root = ProcessInfo.processInfo.environment["REELCONVERTER_TEST_DIRECTORY"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) } ?? manager.temporaryDirectory
        directory = root.appendingPathComponent("reelconverter-test-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: false)
    }

    override func tearDownWithError() throws {
        if let directory { try manager.removeItem(at: directory) }
    }

    private func file(_ name: String) -> URL { directory.appendingPathComponent(name) }

    func testPublishesAndRemovesTemporaryName() throws {
        let temporary = file(".reelconverter-test.mp4")
        let output = file("Видео café.mp4")
        let bytes = Data("encoded video".utf8)
        try bytes.write(to: temporary)
        XCTAssertEqual(try OutputFile.publish(temporary: temporary, output: output), output)
        XCTAssertEqual(try Data(contentsOf: output), bytes)
        XCTAssertFalse(manager.fileExists(atPath: temporary.path))
    }

    func testPreservesExistingFilesAndAddsSuffix() throws {
        let temporary = file(".reelconverter-test.mp4")
        let output = file("video.mp4")
        try Data("new".utf8).write(to: temporary)
        try Data("original".utf8).write(to: output)
        try Data("earlier".utf8).write(to: file("video (1).mp4"))
        let result = try OutputFile.publish(temporary: temporary, output: output)
        XCTAssertEqual(result, file("video (2).mp4"))
        XCTAssertEqual(try Data(contentsOf: result), Data("new".utf8))
        XCTAssertEqual(try Data(contentsOf: output), Data("original".utf8))
        XCTAssertEqual(try Data(contentsOf: file("video (1).mp4")), Data("earlier".utf8))
    }

    func testPreservesDirectoryAtOutputName() throws {
        let temporary = file(".reelconverter-test.mp4")
        let output = file("video.mp4")
        try Data("new".utf8).write(to: temporary)
        try manager.createDirectory(at: output, withIntermediateDirectories: false)
        XCTAssertEqual(try OutputFile.publish(temporary: temporary, output: output), file("video (1).mp4"))
        var isDirectory: ObjCBool = false
        XCTAssertTrue(manager.fileExists(atPath: output.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testConcurrentPublicationsNeverOverwriteEachOther() async throws {
        let output = file("video.mp4")
        let sources = try (0..<12).map { index -> URL in
            let source = file(".reelconverter-\(index).mp4")
            try Data("video \(index)".utf8).write(to: source)
            return source
        }
        let results = try await withThrowingTaskGroup(of: URL.self) { group in
            for source in sources {
                group.addTask { try OutputFile.publish(temporary: source, output: output) }
            }
            var urls: [URL] = []
            for try await url in group { urls.append(url) }
            return urls
        }
        XCTAssertEqual(Set(results).count, sources.count)
        let contents = try Set(results.map { try Data(contentsOf: $0) })
        XCTAssertEqual(contents, Set((0..<12).map { Data("video \($0)".utf8) }))
    }

    func testMissingSourceThrowsWithoutReplacingExistingOutput() throws {
        let output = file("video.mp4")
        try Data("original".utf8).write(to: output)
        XCTAssertThrowsError(try OutputFile.publish(temporary: file("missing.mp4"), output: output)) { error in
            XCTAssertEqual((error as NSError).domain, NSPOSIXErrorDomain)
            XCTAssertEqual((error as NSError).code, Int(ENOENT))
        }
        XCTAssertEqual(try Data(contentsOf: output), Data("original".utf8))
    }

    func testExclusiveCopyFallback() throws {
        let temporary = file(".reelconverter-test.mp4")
        let output = file("video.mp4")
        let bytes = Data(repeating: 0x5A, count: 1_000_000)
        try bytes.write(to: temporary)
        try OutputFile.copyExclusively(temporary: temporary, output: output)
        XCTAssertEqual(try Data(contentsOf: output), bytes)
        XCTAssertFalse(manager.fileExists(atPath: temporary.path))
    }

    func testExclusiveCopyDoesNotOverwrite() throws {
        let temporary = file(".reelconverter-test.mp4")
        let output = file("video.mp4")
        try Data("new".utf8).write(to: temporary)
        try Data("original".utf8).write(to: output)
        XCTAssertThrowsError(try OutputFile.copyExclusively(temporary: temporary, output: output)) { error in
            XCTAssertEqual((error as NSError).code, Int(EEXIST))
        }
        XCTAssertEqual(try Data(contentsOf: output), Data("original".utf8))
        XCTAssertEqual(try Data(contentsOf: temporary), Data("new".utf8))
    }

    func testCopyRejectsNonRegularSource() throws {
        let temporary = file("source-directory")
        let output = file("video.mp4")
        try manager.createDirectory(at: temporary, withIntermediateDirectories: false)
        XCTAssertThrowsError(try OutputFile.copyExclusively(temporary: temporary, output: output))
        XCTAssertFalse(manager.fileExists(atPath: output.path))
        XCTAssertTrue(manager.fileExists(atPath: temporary.path))
    }

    func testMissingDestinationDirectoryKeepsTemporaryFile() throws {
        let temporary = file(".reelconverter-test.mp4")
        try Data("new".utf8).write(to: temporary)
        XCTAssertThrowsError(try OutputFile.publish(temporary: temporary, output: file("missing/video.mp4"))) { error in
            XCTAssertEqual((error as NSError).code, Int(ENOENT))
        }
        XCTAssertEqual(try Data(contentsOf: temporary), Data("new".utf8))
    }
}
