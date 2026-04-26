import SwiftUI

struct IPhoneTOCView: View {
    let store: IPhoneEPUBReaderStore
    let onSelect: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if store.tocItems.isEmpty {
                    ContentUnavailableView(
                        "Нет оглавления",
                        systemImage: "list.bullet",
                        description: Text("Книга не содержит оглавления.")
                    )
                } else {
                    List {
                        ForEach(Array(store.tocItems.enumerated()), id: \.offset) { idx, node in
                            Button {
                                if let chapterIdx = store.chapterIndexForTOCItem(node) {
                                    store.goToChapter(at: chapterIdx)
                                    onSelect()
                                }
                            } label: {
                                HStack(spacing: 0) {
                                    if node.level > 0 {
                                        Color.clear.frame(width: CGFloat(node.level) * 16)
                                    }
                                    Text(node.label)
                                        .font(node.level == 0 ? .body : .subheadline)
                                        .foregroundStyle(node.level == 0 ? .primary : .secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Оглавление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть", action: onSelect)
                }
            }
        }
    }
}
