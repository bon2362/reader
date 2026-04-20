import Foundation

struct SearchResult: Hashable, Sendable {
    let cfi: String
    let excerpt: String
}

struct AnnotationPosition: Hashable, Sendable, Identifiable {
    let id: String
    let cfi: String
    let type: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let visible: Bool

    init(
        id: String,
        x: Double,
        y: Double,
        type: String,
        cfi: String = "",
        width: Double = 0,
        height: Double = 0,
        visible: Bool = true
    ) {
        self.id = id
        self.cfi = cfi
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.visible = visible
    }
}
