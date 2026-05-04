import SwiftUI

struct SnippetEditorCard: View {
    @Binding var snippet: Snippet

    let onSendTest: (Snippet) -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("启用这条快捷短语", isOn: $snippet.isEnabled)

                TextField("名称", text: $snippet.title)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $snippet.content)
                    .font(.body)
                    .frame(minHeight: 60, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                shortcutEditor

                Toggle("发送后自动回车", isOn: $snippet.autoEnter)

                HStack {
                    Button("测试发送") {
                        onSendTest(snippet)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
            }
            .padding(.top, 4)
        } label: {
            Text(snippet.title.isEmpty ? "未命名短语" : snippet.title)
                .font(.headline)
        }
    }

    private var shortcutEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷键")

            HStack {
                ForEach(Shortcut.Modifier.allCases) { modifier in
                    Toggle(
                        modifier.label,
                        isOn: Binding(
                            get: { snippet.shortcut.modifiers.contains(modifier) },
                            set: { enabled in
                                if enabled {
                                    if !snippet.shortcut.modifiers.contains(modifier) {
                                        snippet.shortcut.modifiers.append(modifier)
                                    }
                                } else {
                                    snippet.shortcut.modifiers.removeAll { $0 == modifier }
                                }
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                }
            }

            Picker("按键", selection: $snippet.shortcut.key) {
                ForEach(Shortcut.supportedKeys, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)

            Text("当前组合: \(snippet.shortcut.displayText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
