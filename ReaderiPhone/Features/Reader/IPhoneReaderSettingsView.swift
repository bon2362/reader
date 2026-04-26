import SwiftUI

struct IPhoneReaderSettingsView: View {
    @Bindable var store: IPhoneEPUBReaderStore
    @Environment(\.dismiss) private var dismiss

    private let fontSizeRange: ClosedRange<Double> = 14...24
    private let lineHeightOptions: [(label: String, value: Double)] = [
        ("Узкий", 1.4),
        ("Средний", 1.65),
        ("Широкий", 2.0)
    ]

    var body: some View {
        NavigationStack {
            List {
                // MARK: Theme
                Section("Тема") {
                    HStack(spacing: 12) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            themeButton(theme)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Font size
                Section("Размер шрифта") {
                    HStack(spacing: 12) {
                        Text("A")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(store.fontSize) },
                                set: { store.fontSize = Int($0.rounded()) }
                            ),
                            in: fontSizeRange,
                            step: 1
                        )
                        Text("A")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text("Текущий размер: \(store.fontSize) pt")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // MARK: Line height
                Section("Межстрочный интервал") {
                    HStack(spacing: 8) {
                        ForEach(lineHeightOptions, id: \.value) { option in
                            lineHeightButton(label: option.label, value: option.value)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Настройки текста")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    private func themeButton(_ theme: ReaderTheme) -> some View {
        let isSelected = store.readerTheme == theme
        return Button {
            store.readerTheme = theme
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeBackground(theme))
                    .frame(height: 44)
                    .overlay(
                        Text("Аа")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(themeTextColor(theme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func lineHeightButton(label: String, value: Double) -> some View {
        let isSelected = abs(store.lineHeight - value) < 0.05
        return Button {
            store.lineHeight = value
        } label: {
            Text(label)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func themeBackground(_ theme: ReaderTheme) -> Color {
        switch theme {
        case .auto:  return Color(UIColor.systemBackground)
        case .light: return Color(red: 0.980, green: 0.973, blue: 0.957)
        case .sepia: return Color(red: 0.961, green: 0.937, blue: 0.878)
        case .dark:  return Color(red: 0.102, green: 0.102, blue: 0.102)
        }
    }

    private func themeTextColor(_ theme: ReaderTheme) -> Color {
        switch theme {
        case .auto:  return .primary
        case .light: return Color(red: 0.102, green: 0.102, blue: 0.102)
        case .sepia: return Color(red: 0.231, green: 0.180, blue: 0.102)
        case .dark:  return Color(red: 0.910, green: 0.894, blue: 0.863)
        }
    }
}
