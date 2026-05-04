import Foundation

struct Shortcut: Codable, Equatable {
    var modifiers: [Modifier]
    var key: String

    enum Modifier: String, Codable, CaseIterable, Identifiable {
        case command
        case option
        case control
        case shift

        var id: String { rawValue }

        var label: String {
            switch self {
            case .command: "Cmd"
            case .option: "Opt"
            case .control: "Ctrl"
            case .shift: "Shift"
            }
        }
    }

    static func preset(key: String) -> Shortcut {
        Shortcut(modifiers: [.control, .option, .command], key: key)
    }

    static let supportedKeys: [String] = Array("1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)

    var displayText: String {
        let prefix = orderedModifiers.map(\.label).joined(separator: "+")
        return prefix.isEmpty ? key.uppercased() : prefix + "+" + key.uppercased()
    }

    var orderedModifiers: [Modifier] {
        Modifier.allCases.filter { modifiers.contains($0) }
    }
}
