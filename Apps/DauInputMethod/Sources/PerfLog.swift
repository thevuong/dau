import Foundation
import os

/// Timing of one key, for the open question A/B (cost of `selectedRange` per app).
///
/// D8: only numbers, a fixed event kind and the client's bundle ID are logged. Never the
/// characters typed, the engine output or any text read from the client.
///
/// Signposts are always emitted (near free unless Instruments records them). The per-key
/// `os.Logger` line is on in Debug builds and, in Release, only when the defaults key
/// `DauPerfLog` is true. `scripts/perf-report.sh` reads these lines with `log show`.
struct PerfLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "DauInputMethod"
    static let logger = Logger(subsystem: subsystem, category: "perf")
    static let signposter = OSSignposter(subsystem: subsystem, category: "perf")

    /// Event kinds. Raw values are parsed by scripts/perf-report.sh.
    enum Kind: String {
        /// Key went to the app unchanged, no client call.
        case pass
        /// selectedRange + insertText(replacementRange:).
        case replace
        /// insertText at the cursor without selectedRange (deleteCount 0).
        case insert
        /// selectedRange disagreed with the expected position (D11): engine reset.
        case mismatch
        /// selectedRange returned NSNotFound (no document access): engine reset.
        case unsupported
        /// Shortcut, navigation key, mouse click: engine reset (D4).
        case reset
        /// Underline mode (D13): setMarkedText with the word, no selectedRange.
        case mark
        /// Underline mode (D13): insertText of the marked word (word end or reset event),
        /// replacementRange NSNotFound, no selectedRange.
        case commit
        /// D20: selectedRange + attributedSubstring read a word before the cursor, the
        /// engine was seeded with it and the key replaced it (one insertText).
        case seed
        /// D20: a word was read and seeded, but the key does not apply to it
        /// ("viet" + j): the key went to the app unchanged.
        case seedPass = "seed_pass"
        /// D20: selectedRange (and attributedSubstring if there was text before the
        /// cursor) found no word to seed; the key was handled as the first of a word.
        case seedNone = "seed_none"
    }

    let enabled: Bool

    init() {
        #if DEBUG
        enabled = true
        #else
        enabled = UserDefaults.standard.bool(forKey: "DauPerfLog")
        #endif
    }

    @inline(__always) static func now() -> UInt64 {
        clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
    }

    /// - Parameters:
    ///   - selectedRangeNs: duration of the `selectedRange()` call, or -1 if not called.
    ///   - insertTextNs: duration of the `insertText` call (or, for `mark`, of the
    ///     `setMarkedText` call), or -1 if not called.
    ///   - readNs: duration of the `attributedSubstring` call (D20), or -1 if not called.
    func record(_ kind: Kind, handleNs: UInt64, selectedRangeNs: Int64, insertTextNs: Int64,
                readNs: Int64 = -1, app: String) {
        guard enabled else { return }
        PerfLog.logger.notice(
            "key kind=\(kind.rawValue, privacy: .public) handle_ns=\(handleNs, privacy: .public) sel_ns=\(selectedRangeNs, privacy: .public) ins_ns=\(insertTextNs, privacy: .public) read_ns=\(readNs, privacy: .public) app=\(app, privacy: .public)"
        )
    }

    /// Non-key events worth counting while testing (client changed, mode changed…).
    func note(_ event: StaticString, app: String) {
        guard enabled else { return }
        PerfLog.logger.notice("event name=\(String(describing: event), privacy: .public) app=\(app, privacy: .public)")
    }
}
