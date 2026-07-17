import XCTest
@testable import Leafmark

final class ContentKeyTests: XCTestCase {
    func testSameBytesProduceSameKey() {
        let bytes = Data("The Modern Prometheus".utf8)
        XCTAssertEqual(
            LibraryStore.contentKey(for: bytes),
            LibraryStore.contentKey(for: bytes),
            "同じバイト列は同じ contentKey"
        )
    }

    func testDifferentBytesProduceDifferentKey() {
        XCTAssertNotEqual(
            LibraryStore.contentKey(for: Data("a".utf8)),
            LibraryStore.contentKey(for: Data("b".utf8)),
            "異なるバイト列は異なる contentKey"
        )
    }

    func testKeyIsSha256HexOfContents() {
        // Known SHA-256("abc") vector, proving the key is real SHA-256 hex.
        XCTAssertEqual(
            LibraryStore.contentKey(for: Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testKeyFromFileMatchesKeyFromBytes() throws {
        let bytes = Data((0..<2048).map { UInt8($0 % 256) })
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("contentkey-\(UUID().uuidString).bin")
        try bytes.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(
            try LibraryStore.contentKey(forFileAt: url),
            LibraryStore.contentKey(for: bytes),
            "ファイル経由でもバイト列経由でも同じ contentKey"
        )
    }
}
