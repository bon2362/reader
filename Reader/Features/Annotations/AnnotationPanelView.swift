import SwiftUI

struct AnnotationPanelView: View {
    @Bindable var store: AnnotationPanelStore
    let onSelect: (AnnotationListItem) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabs
            Divider()
            content
        }
    }

    private var header: some View {
        HStack {
            Text("Аннотации")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var tabs: some View {
        Picker("", selection: $store.selectedTab) {
            ForEach(AnnotationPanelTab.allCases, id: \.self) { tab in
                Text("\(tab.localizedTitle) \(store.count(for: tab))")
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        let items = store.filteredItems
        if items.isEmpty {
            VStack {
                Spacer()
                Text("Пусто")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                Spacer()
            }
        } else {
            List {
                ForEach(items) { item in
                    AnnotationRowView(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(item) }
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct AnnotationRowView: View {
    let item: AnnotationListItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                Text(displayPreview)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let meta = metaLine {
                    Text(meta)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var icon: some View {
        switch item.kind {
        case .highlight:
            Circle()
                .fill(highlightColor(item.color))
                .frame(width: 14, height: 14)
                .padding(.top, 2)
        case .note:
            Image(systemName: "note.text")
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        case .sticky:
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 13))
                .foregroundStyle(.yellow)
        }
    }

    private var displayPreview: String {
        item.preview.isEmpty ? "(пусто)" : item.preview
    }

    private var metaLine: String? {
        switch item.kind {
        case .sticky:
            if let spine = item.spineIndex, let page = item.pageInChapter {
                return "Гл. \(spine + 1) · стр. \(page + 1)"
            }
            if let page = item.pageInChapter {
                return "Страница \(page + 1)"
            }
            return nil
        default:
            return nil
        }
    }

    private func highlightColor(_ color: HighlightColor?) -> Color {
        switch color {
        case .yellow: return .yellow
        case .red:    return .red
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        case nil:     return .gray
        }
    }
}
