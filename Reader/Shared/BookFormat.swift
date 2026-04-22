import Foundation

enum BookFormat: String, Codable, Hashable, Sendable {
    case epub
    case pdf

    var badgeTitle: String {
        rawValue.uppercased()
    }
}
