import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "JuiceLogo" asset catalog image resource.
    static let juiceLogo = DeveloperToolsSupport.ImageResource(name: "JuiceLogo", bundle: resourceBundle)

    /// The "dmgIcon" asset catalog image resource.
    static let dmgIcon = DeveloperToolsSupport.ImageResource(name: "dmgIcon", bundle: resourceBundle)

    /// The "dmgImage" asset catalog image resource.
    static let dmg = DeveloperToolsSupport.ImageResource(name: "dmgImage", bundle: resourceBundle)

    /// The "documentIcon" asset catalog image resource.
    static let documentIcon = DeveloperToolsSupport.ImageResource(name: "documentIcon", bundle: resourceBundle)

    /// The "documentImage" asset catalog image resource.
    static let document = DeveloperToolsSupport.ImageResource(name: "documentImage", bundle: resourceBundle)

    /// The "pkgIcon" asset catalog image resource.
    static let pkgIcon = DeveloperToolsSupport.ImageResource(name: "pkgIcon", bundle: resourceBundle)

    /// The "pkgImage" asset catalog image resource.
    static let pkg = DeveloperToolsSupport.ImageResource(name: "pkgImage", bundle: resourceBundle)

    /// The "zipIcon" asset catalog image resource.
    static let zipIcon = DeveloperToolsSupport.ImageResource(name: "zipIcon", bundle: resourceBundle)

    /// The "zipImage" asset catalog image resource.
    static let zip = DeveloperToolsSupport.ImageResource(name: "zipImage", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "JuiceLogo" asset catalog image.
    static var juiceLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .juiceLogo)
#else
        .init()
#endif
    }

    /// The "dmgIcon" asset catalog image.
    static var dmgIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dmgIcon)
#else
        .init()
#endif
    }

    /// The "dmgImage" asset catalog image.
    static var dmg: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dmg)
#else
        .init()
#endif
    }

    /// The "documentIcon" asset catalog image.
    static var documentIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .documentIcon)
#else
        .init()
#endif
    }

    /// The "documentImage" asset catalog image.
    static var document: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .document)
#else
        .init()
#endif
    }

    /// The "pkgIcon" asset catalog image.
    static var pkgIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .pkgIcon)
#else
        .init()
#endif
    }

    /// The "pkgImage" asset catalog image.
    static var pkg: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .pkg)
#else
        .init()
#endif
    }

    /// The "zipIcon" asset catalog image.
    static var zipIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .zipIcon)
#else
        .init()
#endif
    }

    /// The "zipImage" asset catalog image.
    static var zip: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .zip)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "JuiceLogo" asset catalog image.
    static var juiceLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .juiceLogo)
#else
        .init()
#endif
    }

    /// The "dmgIcon" asset catalog image.
    static var dmgIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .dmgIcon)
#else
        .init()
#endif
    }

    /// The "dmgImage" asset catalog image.
    static var dmg: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .dmg)
#else
        .init()
#endif
    }

    /// The "documentIcon" asset catalog image.
    static var documentIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .documentIcon)
#else
        .init()
#endif
    }

    /// The "documentImage" asset catalog image.
    static var document: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .document)
#else
        .init()
#endif
    }

    /// The "pkgIcon" asset catalog image.
    static var pkgIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .pkgIcon)
#else
        .init()
#endif
    }

    /// The "pkgImage" asset catalog image.
    static var pkg: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .pkg)
#else
        .init()
#endif
    }

    /// The "zipIcon" asset catalog image.
    static var zipIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .zipIcon)
#else
        .init()
#endif
    }

    /// The "zipImage" asset catalog image.
    static var zip: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .zip)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

