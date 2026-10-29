import DauEngine
import DauShared

/// Applies settings to one controller's engine. Pure, unit tested.
enum EngineSettings {
    /// Gives `engine` the options of `settings`. When they differ, the word being typed
    /// is dropped first (`reset()`): its letters were built under the old rules (another
    /// typing method, tone placement…), and continuing it under the new ones could
    /// replace text the user never typed that way. Nothing is restored (D4: only a word
    /// boundary restores).
    ///
    /// Returns true if the options changed (and the engine was reset).
    @discardableResult
    static func apply(_ settings: DauSettings, to engine: inout VietEngine) -> Bool {
        let options = settings.engineOptions
        guard engine.options != options else { return false }
        engine.reset()
        engine.options = options
        return true
    }
}
