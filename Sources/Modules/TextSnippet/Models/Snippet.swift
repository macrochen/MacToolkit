import Foundation

struct Snippet: Codable, Identifiable, Equatable {
    let id: UUID
    var isEnabled: Bool
    var title: String
    var content: String
    var shortcut: Shortcut
    var autoEnter: Bool

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        title: String,
        content: String,
        shortcut: Shortcut,
        autoEnter: Bool = true
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.title = title
        self.content = content
        self.shortcut = shortcut
        self.autoEnter = autoEnter
    }
}

extension Snippet {
    static let defaults: [Snippet] = [
        Snippet(title: "收到", content: "收到，我来处理。", shortcut: .preset(key: "1")),
        Snippet(title: "稍等", content: "稍等一下，我马上回复你。", shortcut: .preset(key: "2")),
        Snippet(title: "谢谢", content: "谢谢！", shortcut: .preset(key: "3")),
        Snippet(title: "好的", content: "好的", shortcut: .preset(key: "4")),
        Snippet(title: "马上", content: "马上处理。", shortcut: .preset(key: "5"))
    ]
}
