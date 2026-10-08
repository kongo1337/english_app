import StudyCore
import SwiftUI

/// All words of one dictionary: search, filters by level and status, sorting.
struct WordListView: View {
    let app: AppEnvironment
    let list: WordList

    @State private var filter: WordFilter

    init(app: AppEnvironment, list: WordList) {
        self.app = app
        self.list = list
        _filter = State(initialValue: WordFilter(list: list))
    }

    var body: some View {
        let words = filter.apply(to: app.study.catalog, progress: app.study.progress)
        List {
            Section {
                filterBar
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            Section {
                ForEach(words) { word in
                    NavigationLink {
                        WordDetailView(app: app, wordId: word.id)
                    } label: {
                        WordRow(word: word, status: app.study.status(of: word.id))
                    }
                    .listRowBackground(Theme.surface)
                }
            } header: {
                Text("Слов: \(words.count)")
                    .accessibilityIdentifier("wordCount")
            }
            if words.isEmpty {
                ContentUnavailableView.search
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        // The tab root hides the bar; the search field and the back button live in it.
        .toolbar(.visible, for: .navigationBar)
        .searchable(text: $filter.query, prompt: "Английское или русское слово")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Сортировка", selection: $filter.sort) {
                        ForEach(WordSort.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Сортировка")
            }
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            chipRow(CEFRLevel.allCases.filter { levelsInList.contains($0) }, selected: filter.levels, title: \.rawValue) {
                toggle(&filter.levels, $0)
            }
            chipRow(StatusFilter.allCases, selected: filter.statuses, title: \.title) {
                toggle(&filter.statuses, $0)
            }
        }
        .padding(.vertical, 4)
    }

    private var levelsInList: Set<CEFRLevel> {
        Set(app.study.catalog.words(in: list).map(\.cefr))
    }

    private func toggle<Element: Hashable>(_ set: inout Set<Element>, _ element: Element) {
        if set.contains(element) { set.remove(element) } else { set.insert(element) }
    }

    private func chipRow<Element: Hashable>(
        _ items: [Element], selected: Set<Element>, title: KeyPath<Element, String>,
        action: @escaping (Element) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let isOn = selected.contains(item)
                    Button { action(item) } label: {
                        Text(item[keyPath: title])
                            .font(Theme.Typography.caption)
                            .foregroundStyle(isOn ? Color.white : Theme.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 34)
                            .background(isOn ? Theme.accent : Theme.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityIdentifier("filter.\(item[keyPath: title])")
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct WordRow: View {
    let word: Word
    let status: WordStatus

    var body: some View {
        HStack(spacing: 12) {
            LevelChip(level: word.cefr)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.lemma)
                    .font(.system(.body, design: .serif, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(word.primaryTranslation)
                    .font(Theme.Typography.small)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: status.symbol)
                .foregroundStyle(status.color)
                .accessibilityLabel(status.title)
        }
        .accessibilityElement(children: .combine)
    }
}
