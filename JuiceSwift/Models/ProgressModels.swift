import Foundation

struct DownloadProgress: Codable {
    var downloadPercent: Int? = 0
    var downloadPercentString: String = "0%"
    var isComplete: Bool = false
    var inProgress: Bool = false
    var isSuccess: Bool = false
    var downloadExists: Bool = false
    var fullFilePath: String? = ""
    var iconFilePath: String? = nil
    var fileSize: Int64 = 0
    var fileSizeStr: String?
    var currentState: String? = "Waiting..."
    var isIndeterminate: Bool? = false

    enum CodingKeys: String, CodingKey {
        case downloadPercent
        case downloadPercentString
        case isComplete
        case inProgress
        case isSuccess
        case downloadExists
        case fullFilePath
        case iconFilePath
        case fileSize
        case fileSizeStr
        case currentState
        case isIndeterminate
    }
}

struct UploadProgress: Codable {
    var uploadProgressString: String = "Uploading. This may be a few mins..."
    var uploadPercent: Int = 0
    var isComplete: Bool = false
    var inProgress: Bool = false
    var isSuccess: Bool = false
    var appExists: Bool = false
    var fullFilePath: String? = ""
    var fileSize: Int64?
    var fileSizeStr: String?
    var currentState: String? = "Waiting..."
}

struct MetadataProgress: Codable {
    var metadataProgressString: String = "Generating Metadata"
    var isComplete: Bool = false
    var inProgress: Bool = false
    var isSuccess: Bool = false
    var currentState: String? = "Waiting..."
}
