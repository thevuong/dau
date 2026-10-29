import AppKit

/// Finds the host app (Dấu, the Settings app) for the input menu's "Cài đặt Dấu…".
///
/// Not "whatever LaunchServices returns for the bundle ID": on a development machine
/// LaunchServices may know many old copies (DerivedData, temporary builds), and
/// `urlForApplication(withBundleIdentifier:)` can pick any of them. The order is:
///
/// 1. A running copy of the host app: the user already has it; activate that one.
/// 2. The app this bundle is nested in (`Dau.app/Contents/Library/Input Methods/`), when
///    the input method runs from inside the app.
/// 3. The installed input method is a copy made by the host app (M5), so a matching host
///    app has the same version: among the copies LaunchServices knows, keep those whose
///    CFBundleShortVersionString and CFBundleVersion equal the input method's, preferring
///    one in an Applications folder. No match: nothing is opened (logged by the caller),
///    rather than an older or newer app.
///
/// TODO(M5): the installer can record the host app's path in the shared settings; use it
/// first once it exists.
enum HostApp {
    /// Info.plist key of the input method holding the host app's bundle ID
    /// (`$(BUNDLE_ID_PREFIX)` in project.yml), so the ID is never written in code.
    static let bundleIDInfoKey = "DauHostAppBundleIdentifier"

    /// Why `url` chose the app it returned (for the log).
    enum Reason: String {
        case running
        case enclosing
        case sameVersion = "same-version"
    }

    /// The host app to open and why, or nil if none fits.
    static func url(bundle: Bundle = .main, workspace: NSWorkspace = .shared) -> (url: URL, reason: Reason)? {
        guard let hostID = bundle.object(forInfoDictionaryKey: bundleIDInfoKey) as? String,
              !hostID.isEmpty, !hostID.contains("$(") else { return nil }

        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: hostID)
            .first(where: { $0.bundleURL != nil && !$0.isTerminated }),
           let url = running.bundleURL {
            return (url, .running)
        }
        if let parent = enclosingApp(of: bundle.bundleURL),
           Bundle(url: parent)?.bundleIdentifier == hostID {
            return (parent, .enclosing)
        }
        let candidates = workspace.urlsForApplications(withBundleIdentifier: hostID)
            .filter { Version(bundle: Bundle(url: $0)) == Version(bundle: bundle) }
        if let url = preferred(candidates) {
            return (url, .sameVersion)
        }
        return nil
    }

    /// `X.app` for `X.app/Contents/Library/Input Methods/<bundle>`, else nil.
    static func enclosingApp(of bundleURL: URL) -> URL? {
        let inputMethods = bundleURL.deletingLastPathComponent()
        let library = inputMethods.deletingLastPathComponent()
        let contents = library.deletingLastPathComponent()
        let app = contents.deletingLastPathComponent()
        guard inputMethods.lastPathComponent == "Input Methods",
              library.lastPathComponent == "Library",
              contents.lastPathComponent == "Contents",
              app.pathExtension == "app" else { return nil }
        return app
    }

    /// First copy inside an Applications folder (/Applications, ~/Applications), else the
    /// first candidate.
    static func preferred(_ candidates: [URL]) -> URL? {
        candidates.first { $0.pathComponents.dropLast().contains("Applications") } ?? candidates.first
    }

    /// Marketing version + build number; nil parts never match.
    struct Version: Equatable {
        var short: String?
        var build: String?

        init(short: String?, build: String?) {
            self.short = short
            self.build = build
        }

        init(bundle: Bundle?) {
            short = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            build = bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        }

        static func == (a: Version, b: Version) -> Bool {
            guard let aShort = a.short, let aBuild = a.build else { return false }
            return aShort == b.short && aBuild == b.build
        }
    }
}
