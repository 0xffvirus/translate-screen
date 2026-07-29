import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var settings: AppSettings
    @State private var confirmsClear = false

    var body: some View {
        Group {
            if !settings.savesHistory {
                ContentUnavailableView {
                    Label("History Is Off", systemImage: "clock.badge.xmark")
                } description: {
                    Text("Turn on translation history in Settings if you want to keep recent results.")
                } actions: {
                    Button("Enable History") { settings.savesHistory = true }
                        .buttonStyle(.borderedProminent)
                }
            } else if history.items.isEmpty {
                ContentUnavailableView(
                    "No Translations Yet",
                    systemImage: "clock",
                    description: Text("Translated screenshots you choose to save will appear here.")
                )
            } else {
                List {
                    ForEach(history.items) { item in
                        NavigationLink {
                            HistoryDetailView(item: item)
                        } label: {
                            HistoryRow(item: item)
                        }
                    }
                    .onDelete(perform: history.delete)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !history.items.isEmpty, settings.savesHistory {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear All", systemImage: "trash", role: .destructive) {
                            confirmsClear = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear translation history?",
            isPresented: $confirmsClear,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) { history.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes saved screenshots and text from this device.")
        }
    }
}

private struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.secondary.opacity(0.1)
                        .overlay { Image(systemName: "photo") }
                }
            }
            .frame(width: 56, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.translatedText.split(separator: "\n").first.map(String.init) ?? "Translation")
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Text(item.sourceName)
                    Image(systemName: "arrow.right")
                    Text(item.targetName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text(item.date, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HistoryDetailView: View {
    let item: HistoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 5)
                }

                textCard(title: "Original", text: item.originalText)
                textCard(title: "Translation", text: item.translatedText)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(item.targetName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func textCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Text(text).font(.body).textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}
