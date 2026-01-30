import SwiftUI
import SwiftData

struct NotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LocalNote.createdAt, order: .reverse) private var notes: [LocalNote]

    @State private var selectedType: NoteType?
    @State private var searchText = ""

    private var filteredNotes: [LocalNote] {
        var result = notes

        if let type = selectedType {
            result = result.filter { $0.type == type }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.contentEn.localizedCaseInsensitiveContains(searchText) ||
                $0.contentCn.contains(searchText)
            }
        }

        return result
    }

    private var weeklyCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return notes.filter { $0.createdAt > weekAgo }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stats
            HStack {
                Text("总计 \(notes.count) 条")
                    .font(.caption)
                Spacer()
                Text("本周新增 \(weeklyCount) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))

            // Filter
            Picker("类型", selection: $selectedType) {
                Text("全部").tag(nil as NoteType?)
                Text("词汇").tag(NoteType.vocabulary as NoteType?)
                Text("例句").tag(NoteType.expression as NoteType?)
            }
            .pickerStyle(.segmented)
            .padding()

            // Notes List
            if filteredNotes.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text("暂无笔记")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(filteredNotes) { note in
                    NoteRow(note: note)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("我的笔记")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索笔记")
    }
}

struct NoteRow: View {
    let note: LocalNote

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(note.contentEn)
                        .font(.headline)

                    if let phonetic = note.phonetic {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(note.type == .vocabulary ? "词汇" : "例句")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(note.type == .vocabulary ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                        .foregroundStyle(note.type == .vocabulary ? .blue : .green)
                        .clipShape(Capsule())
                }

                Text(note.contentCn)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                // TODO: 播放发音
            } label: {
                Image(systemName: "speaker.wave.2")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        NotesView()
    }
}
