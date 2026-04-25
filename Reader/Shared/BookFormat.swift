import Foundation

enum BookFormat: String, Codable, Hashable, Sendable {
    case epub
    case pdf
    case fb2

    var badgeTitle: String {
        rawValue.uppercased()
    }
}
