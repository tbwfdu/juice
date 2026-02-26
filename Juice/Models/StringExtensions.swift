import Foundation

extension String {
    func firstCharToUpper() throws -> String {
        guard !isEmpty else {
            throw NSError(domain: "StringExtensions", code: 1, userInfo: [NSLocalizedDescriptionKey: "String cannot be empty"]) 
        }
        let first = prefix(1).uppercased()
        let rest = dropFirst()
        return first + rest
    }

    func toTitleCase() -> String {
        let parts = split(separator: " ")
        guard let first = parts.first else { return self }
        let firstWord = first.lowercased().capitalized
        if parts.count == 1 {
            return firstWord
        }
        return ([firstWord] + parts.dropFirst().map { String($0) }).joined(separator: " ")
    }
}
