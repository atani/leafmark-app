import XCTest
import ReadiumShared

extension XCTestCase {
    /// A fresh path under the temporary directory, deleted when the current
    /// test finishes. Call from `setUp` or from a test body.
    func makeTemporaryURL(_ prefix: String, pathExtension: String = "json") -> URL {
        let name = pathExtension.isEmpty
            ? "\(prefix)-\(UUID().uuidString)"
            : "\(prefix)-\(UUID().uuidString).\(pathExtension)"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name, isDirectory: pathExtension.isEmpty)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// Parses a Readium Locator, failing the test when the JSON is not one.
    func makeLocator(json: String) throws -> Locator {
        try XCTUnwrap(try? Locator(json: try JSONValue(jsonString: json), warnings: nil))
    }

    /// Locator JSON for a position in `href` at a total progression.
    func locatorJSON(href: String = "ch1.html", progression: Double) -> String {
        #"{"href":"\#(href)","type":"text/html","locations":{"totalProgression":\#(progression)}}"#
    }
}
