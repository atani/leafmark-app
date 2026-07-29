import Foundation

/// The app's own version, for display in the UI.
///
/// Readers who hit a rendering bug could not say which build they were running
/// — "I'm not sure a version number as the app gives no indication" — so a
/// report could not be matched to a release, and there was no way to tell
/// whether a shipped fix had actually reached them. Surfacing the version makes
/// every future report answerable.
enum AppInfo {
    /// Marketing version, e.g. `1.11`.
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Build number, e.g. `18`.
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    /// Version and build together, e.g. `1.11 (18)`. The build is included
    /// because two submissions can share a marketing version.
    static var versionDisplay: String {
        "\(version) (\(build))"
    }
}
