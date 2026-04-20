import Foundation

struct AnnotationAnchor: Codable, Hashable, Sendable {
    let id: String
    let cfi: String
    let type: String   // "note" | "highlight"
}
