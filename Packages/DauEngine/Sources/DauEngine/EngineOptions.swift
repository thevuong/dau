// User-facing engine options. Defaults follow D15.

public struct EngineOptions: Sendable, Equatable {
    public enum InputMethod: Sendable, Equatable {
        /// Telex (D15 default). A lone `w` becomes "ư" (D23).
        case telex
        /// Telex without the lone-`w` rule and without `[ ]` (D29).
        case simpleTelex
        /// VNI: 1–5 tones, 0 removes the tone, 6 â ê ô, 7 ơ ư, 8 ă, 9 đ. Letters are
        /// plain letters; w → qu exists only here, with consonant shortcuts (D23).
        case vni
    }

    public enum TonePlacement: Sendable, Equatable {
        /// "hoà, thuý" (D15 default).
        case modern
        /// "hòa, thúy".
        case classic
    }

    /// The "Nâng cao" group. One enum instead of two booleans because the two options
    /// are mutually exclusive (D22): the invalid combination cannot be expressed.
    public enum Advanced: Sendable, Equatable {
        case off
        /// Consonant shortcuts (D21): f → ph, j → gi at the start, g → ng, h → nh,
        /// k → ch at the end, applied only at a word boundary and only when the result
        /// is a valid syllable.
        case consonantShortcuts
        /// Accept z, f, w, j as initial consonants (D22). In Telex a leading w is
        /// always ư (D23), so only z, f, j matter there.
        case allowZFWJ
    }

    public var inputMethod: InputMethod
    public var tonePlacement: TonePlacement
    /// "Bỏ dấu tự do" (D28).
    public var freeMarking: Bool
    /// "Tự khôi phục từ không phải tiếng Việt" (D4, D30): only controls the restore at
    /// a word boundary. Spelling checks always run (D30).
    public var autoRestore: Bool
    public var advanced: Advanced

    public init(
        inputMethod: InputMethod = .telex,
        tonePlacement: TonePlacement = .modern,
        freeMarking: Bool = true,
        autoRestore: Bool = true,
        advanced: Advanced = .off
    ) {
        self.inputMethod = inputMethod
        self.tonePlacement = tonePlacement
        self.freeMarking = freeMarking
        self.autoRestore = autoRestore
        self.advanced = advanced
    }
}
