import Foundation

@MainActor
final class SnippetStore: ObservableObject {
    @Published var snippets: [Snippet] = [] {
        didSet {
            save()
        }
    }

    private let defaultsKey = "tap-enter.snippets"

    init() {
        load()
    }

    func update(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        var updated = snippets
        updated[index] = snippet
        snippets = limited(updated)
    }

    func resetDefaults() {
        snippets = limited(Snippet.defaults)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([Snippet].self, from: data)
        else {
            snippets = limited(Snippet.defaults)
            return
        }

        snippets = limited(decoded)
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(snippets) else { return }
        UserDefaults.standard.set(encoded, forKey: defaultsKey)
    }

    private func limited(_ snippets: [Snippet]) -> [Snippet] {
        Array(snippets.prefix(5))
    }
}
