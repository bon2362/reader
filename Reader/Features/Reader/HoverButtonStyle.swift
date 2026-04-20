import SwiftUI

/// Subtle hover affordance: slight scale + opacity bump on hover.
/// Apply via `.buttonStyle(.plain).hoverLift()`.
struct HoverLift: ViewModifier {
    @State private var hovered = false

    func body(content: Content) -> some View {
        content
            .opacity(hovered ? 1.0 : 0.75)
            .scaleEffect(hovered ? 1.12 : 1.0)
            .onHover { hovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: hovered)
    }
}

extension View {
    func hoverLift() -> some View { modifier(HoverLift()) }
}

/// Circular icon button on ultraThinMaterial — used for floating reader controls.
struct FloatingIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    var size: CGFloat = 28

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(help)
        .hoverLift()
    }
}
