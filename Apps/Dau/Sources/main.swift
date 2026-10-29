import Foundation

// Dấu's interface is Vietnamese only, but the bundle also ships en.lproj (InfoPlist
// strings, so Finder shows "Dấu" on English systems — D24). Without help, an English
// system would pick "en" and mix English system menus and panels with Vietnamese
// strings. Pin this process to "vi" before AppKit picks a localization.
//
// Not the registration domain: the global domain's AppleLanguages (always set) beats
// it, measured: preferredLocalizations stayed ["en"]. The argument domain beats the
// global domain, lives only in this process and changes no system setting (N4).
// A -AppleLanguages argument on the command line is respected.
private func pinVietnameseLocalization() {
    let defaults = UserDefaults.standard
    var arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
    guard arguments["AppleLanguages"] == nil else { return }
    arguments["AppleLanguages"] = ["vi"]
    defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
}

pinVietnameseLocalization()

#if DEBUG
// Debug check without opening a window: prints the chosen localization and exits.
if CommandLine.arguments.contains("--print-localizations") {
    print(Bundle.main.preferredLocalizations)
    exit(0)
}
#endif

DauApp.main()
