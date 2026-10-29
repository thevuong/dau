import DauEngine

extension DauSettings {
    /// Engine options for these settings. "Thêm dấu cho từ đã gõ" and the per-app
    /// settings are handled by the input method, not the engine.
    public var engineOptions: EngineOptions {
        EngineOptions(
            inputMethod: typingMethod.engineValue,
            tonePlacement: tonePlacement == .modern ? .modern : .classic,
            freeMarking: freeMarking,
            autoRestore: autoRestore,
            advanced: advanced.engineValue
        )
    }
}

extension DauSettings.TypingMethod {
    public var engineValue: EngineOptions.InputMethod {
        switch self {
        case .telex: .telex
        case .vni: .vni
        case .simpleTelex: .simpleTelex
        }
    }
}

extension DauSettings.Advanced {
    public var engineValue: EngineOptions.Advanced {
        switch self {
        case .off: .off
        case .consonantShortcuts: .consonantShortcuts
        case .allowZFWJ: .allowZFWJ
        }
    }
}
