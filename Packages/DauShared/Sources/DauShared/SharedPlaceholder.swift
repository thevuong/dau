// Placeholder so the package builds during M0.
// Settings keys and the compatibility list model land here in M3/M4.

/// Marker type proving the module compiles and links. Remove when real code lands.
public enum SharedPlaceholder {
    /// Info.plist key, present in both bundles, whose value is the App Group identifier
    /// (expanded from the `APP_GROUP_ID` build setting in project.yml).
    public static let appGroupInfoKey = "DauAppGroupIdentifier"
}
