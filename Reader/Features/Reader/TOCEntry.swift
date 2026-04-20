import Foundation

struct TOCEntry: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let href: String
    let level: Int
}
