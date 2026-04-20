import SwiftUI

struct HighlightColorPicker: View {
    let onPick: (HighlightColor) -> Void
    var onDismiss: (() -> Void)? = nil
    var activeColor: HighlightColor? = nil
    var showDelete: Bool = false
    var onDelete: (() -> Void)? = nil
    var onNote: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(HighlightColor.allCases, id: \.self) { color in
                    Button { onPick(color) } label: {
                        Circle()
                            .fill(swatch(for: color))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(activeColor == color ? 0.6 : 0.15), lineWidth: activeColor == color ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                    .help(color.rawValue.capitalized)
                }
            }

            if let onNote {
                Button(action: onNote) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .hoverLift()
                .help("Заметка")
            }

            if showDelete {
                Button(action: { onDelete?() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .hoverLift()
                .help("Удалить")
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .hoverLift()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(radius: 8, y: 2)
    }

    private func swatch(for color: HighlightColor) -> Color {
        switch color {
        case .yellow: return .yellow
        case .red:    return .red
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        }
    }
}
