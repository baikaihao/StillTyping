import Foundation

nonisolated enum AppResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        Bundle.module
        #else
        Bundle.main
        #endif
    }

    static func url(forResource name: String, withExtension extensionName: String) -> URL? {
        return bundle.url(forResource: name, withExtension: extensionName, subdirectory: "Resources")
            ?? bundle.url(forResource: name, withExtension: extensionName)
    }
}
