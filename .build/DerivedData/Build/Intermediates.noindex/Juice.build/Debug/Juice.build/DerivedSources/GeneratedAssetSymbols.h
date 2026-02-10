#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "JuiceLogo" asset catalog image resource.
static NSString * const ACImageNameJuiceLogo AC_SWIFT_PRIVATE = @"JuiceLogo";

/// The "dmgIcon" asset catalog image resource.
static NSString * const ACImageNameDmgIcon AC_SWIFT_PRIVATE = @"dmgIcon";

/// The "dmgImage" asset catalog image resource.
static NSString * const ACImageNameDmgImage AC_SWIFT_PRIVATE = @"dmgImage";

/// The "documentIcon" asset catalog image resource.
static NSString * const ACImageNameDocumentIcon AC_SWIFT_PRIVATE = @"documentIcon";

/// The "documentImage" asset catalog image resource.
static NSString * const ACImageNameDocumentImage AC_SWIFT_PRIVATE = @"documentImage";

/// The "pkgIcon" asset catalog image resource.
static NSString * const ACImageNamePkgIcon AC_SWIFT_PRIVATE = @"pkgIcon";

/// The "pkgImage" asset catalog image resource.
static NSString * const ACImageNamePkgImage AC_SWIFT_PRIVATE = @"pkgImage";

/// The "zipIcon" asset catalog image resource.
static NSString * const ACImageNameZipIcon AC_SWIFT_PRIVATE = @"zipIcon";

/// The "zipImage" asset catalog image resource.
static NSString * const ACImageNameZipImage AC_SWIFT_PRIVATE = @"zipImage";

#undef AC_SWIFT_PRIVATE
