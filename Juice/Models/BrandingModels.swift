import Foundation

struct BrandingConfig: Codable {
	var themeCssUrl: String?
	var customCss: String?
	var primaryLogoUrl: String?
	var logoUrl: String?
	var logoAltText: String?
	var brandingColor: BrandingColor?
}

struct BrandingColor: Codable {
	var headerColor: String?
	var headerFontColor: String?
	var navigationColor: String?
	var navigationFontColor: String?
	var highlightColor: String?
	var highlightFontColor: String?
}
