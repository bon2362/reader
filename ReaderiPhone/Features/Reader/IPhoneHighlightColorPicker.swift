import SwiftUI

struct IPhoneHighlightColorPicker: View {
    let onPick: (HighlightColor) -> Void
    var onDismiss: (() -> Void)? = nil
    var activeColor: HighlightColor? = nil
    var showDelete: Bool = false
    var onDelete: (() -> Void)? = nil
    var onNote: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    if activeColor == color, let onDelete {
                        onDelete()
                    } else {
                        onPick(color)
                    }
                } label: {
                    Circle()
                        .fill(swatch(for: color))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .stroke(
                                    Color.primary.opacity(activeColor == color ? 0.55 : 0.15),
                                    lineWidth: activeColor == color ? 2 : 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(colorName(color))
            }

            if let onNote {
                Divider()
                    .frame(height: 22)

                Button {
                    onNote()
                } label: {
                    Image(systemName: "note.text")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Добавить заметку")
            }

            if showDelete {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(radius: 8, y: 2)
    }

    private func colorName(_ color: HighlightColor) -> String {
        switch color {
        case .yellow: return "Жёлтый"
        case .red:    return "Красный"
        case .green:  return "Зелёный"
        case .blue:   return "Синий"
        case .purple: return "Фиолетовый"
        }
    }

    private func swatch(for color: HighlightColor) -> Color {
        switch color {
        case .yellow: return .yellow
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}
