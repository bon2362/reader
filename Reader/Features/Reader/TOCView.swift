import SwiftUI

struct TOCView: View {
    @Bindable var store: TOCStore
    let onSelect: (TOCEntry) -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Оглавление")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Закрыть оглавление")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if store.entries.isEmpty {
                VStack {
                    Spacer()
                    Text("Оглавление недоступно")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(store.entries, selection: $store.currentEntryId) { entry in
                    Button(action: { onSelect(entry) }) {
                        HStack(spacing: 4) {
                            Text(entry.label.isEmpty ? "—" : entry.label)
                                .font(.system(size: 12, weight: entry.id == store.currentEntryId ? .semibold : .regular))
                                .foregroundStyle(entry.id == store.currentEntryId ? Color.accentColor : Color.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.leading, CGFloat(entry.level) * 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tag(entry.id)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 220)
        .background(.regularMaterial)
    }
}
